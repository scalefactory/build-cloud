require 'fog'
require 'yaml'
require 'pry'
require 'logger'
require 'pp'

class BuildCloud

    @config
    @log
    @infrastructure
    @mock

    def initialize( options )

        @log = options[:logger] or Logger.new( STDERR )
        @mock = options[:mock] or false

        # Parse the first config file. We'll merge the remainder (if any) into
        # this one, regardless of whether they're passed on the command line
        # or in the YAML for this file itself.
        first_config_file = options[:config].shift
        @config = YAML::load( File.open( first_config_file ) )

        # include_files is going to be a list of files that we're going to
        # merge in to the first file.
        include_files = []

        # Work out the full, standardised pathnames for any further files
        # specified on the command line.  note that options[:config] only
        # contains the extra files at this point, as we shifted the first
        # one off the array earlier.
        #
        # IMPORTANT: relative paths given on the command line are considered
        # to be relative to $CWD. This decision is based on the principle of
        # least surprise, as that is how everything else works.
        cli_include_files = options[:config]
        cli_include_files.each do |inc|
            include_files << File.absolute_path( inc )
        end

        # Now look in the :include key in the YAML of the first file for
        # either a single, or an array of files to include. Work out the
        # standardised paths for each of these files, and push them onto
        # the include_files array.
        #
        # IMPORTANT: relative paths given in the :include key in the YAML
        # are considered to be relative to the config file specified, not
        # $CWD. This is to ensure consistency of application and backwards
        # compatibility. If this were relative to $CWD, a relative path
        # specified in the file could have different meanings, and would end
        # up being unpredictable.
        if include_yaml = @config.delete(:include)
            if include_yaml.is_a?(Array)
                # the :include key is an array, we need to iterate over it
                include_yaml.each do |yml|
                    include_files << File.expand_path( yml, File.dirname( File.absolute_path(first_config_file) ) )
                end
            else
                # the :include key is a scalar, so just standardise that path
                include_files.push( File.expand_path( include_yaml, File.dirname( File.absolute_path(first_config_file) ) ) )
            end
        end

        include_files.each do |include_path|

            if File.exists?( include_path )
                @log.info( "Including YAML file #{include_path}" )
                included_conf = YAML::load( File.open( include_path ) )
                @config = @config.merge(included_conf) do |keys, oldval, newval|
                    # we're iterating over elements that are in both the
                    # config we've parsed so far, and the new file.
                    (newval.is_a?(Array) ? (oldval + newval).uniq : newval)
                    # oldval is from the existing config, newval is the incoming
                    # value from this file. if newval is an array, merge it in with
                    # what we already have, and make it unique. if newval is a
                    # string, the new value takes precedence over what we have
                    # already.
                    #
                    # edge cases:
                    # 1. if we have a key :foo which is a scalar, and then a
                    # :foo in a subsequent file which is an array (or v.v.)
                    # then this will blow up. I think this is acceptable.
                    # 2. if we have, eg. an instance, defined twice in
                    # separate files, then the behaviour of uniq is to use
                    # the entire hash as a test for uniqueness. Therefore
                    # if the definition of those instances varies slightly,
                    # the attempt to create those instances will likely fail.
                end

            end

        end

        @log.debug( @config.inspect )

        new_config = recursive_interpolate_config(@config)
        @config = new_config

        @log.debug( @config.inspect )

        connect_fog

        BuildCloud::dispatch.each_pair do |component, klass|

            if @config.has_key?(component)
                klass.load( @config[component], @fog_interfaces, @log )
            end

        end

    end

    def pry
        binding.pry
    end

    def find( component, options )

        if BuildCloud::dispatch.has_key?( component )
            BuildCloud::dispatch[component].search(options)
        else
            []
        end

    end

    def all

        objects = []

        BuildCloud::create_order.each do |component|
            next unless BuildCloud::dispatch.has_key?( component )
            objects.concat BuildCloud::dispatch[component].objects()
        end

        objects

    end

    private

    def self.dispatch

        {
            :vpcs                   => BuildCloud::VPC,
            :internet_gateways      => BuildCloud::InternetGateway,
            :subnets                => BuildCloud::Subnet,
            :route_tables           => BuildCloud::RouteTable,
            :zones                  => BuildCloud::Zone,
            :security_groups        => BuildCloud::SecurityGroup,
            :network_interfaces     => BuildCloud::NetworkInterface,
            :routes                 => BuildCloud::Route,
            :launch_configurations  => BuildCloud::LaunchConfiguration,
            :load_balancers         => BuildCloud::LoadBalancer,
            :as_groups              => BuildCloud::ASGroup,
            :r53_record_sets        => BuildCloud::R53RecordSet,
            :rds_servers            => BuildCloud::RDSServer,
            :db_subnet_groups       => BuildCloud::DbSubnetGroup,
            :db_parameter_groups    => BuildCloud::DbParameterGroup,
            :cache_subnet_groups    => BuildCloud::CacheSubnetGroup,
            :cache_clusters         => BuildCloud::CacheCluster,
            :cache_parameter_groups => BuildCloud::CacheParameterGroup,
            :iam_roles              => BuildCloud::IAMRole,
            :s3_buckets             => BuildCloud::S3Bucket,
            :instances              => BuildCloud::Instance,
            :ebs_volumes            => BuildCloud::EBSVolume,
            :dhcp_options_sets      => BuildCloud::DHCPOptionsSet,
        }

    end

    def self.create_order
        [
            :dhcp_options_sets,
            :vpcs,
            :internet_gateways,
            :iam_roles,
            :subnets,
            :db_subnet_groups,
            :cache_subnet_groups,
            :route_tables,
            :zones,
            :security_groups,
            :network_interfaces,
            :routes,
            :db_parameter_groups,
            :rds_servers,
            :cache_parameter_groups,
            :cache_clusters,
            :launch_configurations,
            :load_balancers,
            :as_groups,
            :r53_record_sets,
            :s3_buckets,
            :ebs_volumes,
            :instances,
        ]
    end

    def self.search( type, options )
        BuildCloud::dispatch[type].search(options)
    end

    def recursive_interpolate_config(h)

        # Work through the given config replacing all strings matching
        # %{..x..} by looking up ..x.. in the existing @config hash and
        # substituting the template with the value

        case h
        when Hash
            Hash[
            h.map do |k, v|
                [ k, recursive_interpolate_config(v) ]
            end
            ]
        when Enumerable
            h.map { |v| recursive_interpolate_config(v) }
        when String

            while h =~ /%\{(.+?)\}/
                var = $1
                val = ""

                if @config.has_key?(var.to_sym)
                    val = @config[var.to_sym]
                else
                    raise "Attempt to interpolate with non-existant key '#{var}'"
                end

                h.gsub!(/%\{#{var}\}/, val)

            end

            h

        else
            h
        end

    end

    def connect_fog

        @mock and Fog.mock!

        fog_options_regionless = {
            :aws_access_key_id     => @config[:aws_access_key_id] ||= ENV['AWS_ACCESS_KEY_ID'],
            :aws_secret_access_key => @config[:aws_secret_access_key] ||= ENV['AWS_SECRET_ACCESS_KEY'],
        }

        fog_options = fog_options_regionless.merge( { :region => @config[:aws_region] } )

        @fog_interfaces = {

            :compute     => Fog::Compute::AWS.new( fog_options ),
            :s3          => Fog::Storage::AWS.new( fog_options.merge(:path_style => true)),
            :as          => Fog::AWS::AutoScaling.new( fog_options ),
            :elb         => Fog::AWS::ELB.new( fog_options ),
            :iam         => Fog::AWS::IAM.new( fog_options_regionless ),
            :rds         => Fog::AWS::RDS.new( fog_options ),
            :elasticache => Fog::AWS::Elasticache.new( fog_options ),
            :r53         => Fog::DNS::AWS.new( fog_options_regionless )
        }

    end

end
