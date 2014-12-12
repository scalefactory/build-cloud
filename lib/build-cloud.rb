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
        
        first_config_file = options[:config].shift

        @config = YAML::load( File.open( first_config_file ) )

        cli_include_files = options[:config]

        include_files = []

        cli_include_files.each do |inc|
            include_files << File.expand_path( inc, File.dirname( first_config_file))
        end

        if include_yaml = @config.delete(:include)
            if include_yaml.is_a?(Array)
                include_yaml.each do |yml|
                    include_files << File.expand_path( yml, File.dirname( first_config_file))
                end
            else
                include_files.push( File.expand_path( include_yaml, File.dirname( first_config_file)) )
            end
        end
        
        include_files.each do |include_file|

            if File.exists?( include_path )
                @log.info( "Including YAML file #{include_path}" )
                included_conf = YAML::load( File.open( include_path ) )
                @config = @config.merge(included_conf) do |keys, oldval, newval|
                    (newval.is_a?(Array) ? (oldval + newval).uniq : newval)
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

        fog_options = {
            :aws_access_key_id     => @config[:aws_access_key_id] ||= ENV['AWS_ACCESS_KEY'],
            :aws_secret_access_key => @config[:aws_secret_access_key] ||= ENV['AWS_SECRET_KEY'],
            :region                => @config[:aws_region],
        }

        @fog_interfaces = {

            :compute     => Fog::Compute::AWS.new( fog_options ),
            :s3          => Fog::Storage::AWS.new( fog_options ),
            :as          => Fog::AWS::AutoScaling.new( fog_options ),
            :elb         => Fog::AWS::ELB.new( fog_options ),
            :iam         => Fog::AWS::IAM.new( fog_options ),
            :rds         => Fog::AWS::RDS.new( fog_options ),
            :elasticache => Fog::AWS::Elasticache.new( fog_options ),
            :r53         => Fog::DNS::AWS.new(
                :aws_access_key_id     => @config[:aws_access_key_id] ||= ENV['AWS_ACCESS_KEY'],
                :aws_secret_access_key => @config[:aws_secret_access_key] ||= ENV['AWS_SECRET_KEY'],
            )

        }

    end

end

