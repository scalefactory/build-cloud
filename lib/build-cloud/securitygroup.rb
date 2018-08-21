class BuildCloud::SecurityGroup

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        sg = self.search( :name => name ).first

        unless sg
            raise "Couldn't get a SecurityGroup object for #{name} - is it defined?"
        end

        sg_fog = sg.read

        unless sg_fog
            raise "Couldn't get a SecurityGroup fog object for #{name} - is it created?"
        end

        sg_fog.group_id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name, :description)
        require_one_of(:vpc_id, :vpc_name)

    end

    def create

        options = @options.dup

        authorized_ranges = []
        if options[:authorized_ranges]
            authorized_ranges = options[:authorized_ranges]
            options.delete(:authorized_ranges)
        end

        if exists?
            # If exists update tags
            if options[:tags]
                create_tags(options[:tags])
            end
        else

            @log.info( "Creating security group #{@options[:name]}" )

            unless options[:vpc_id]

                options[:vpc_id] = BuildCloud::VPC.get_id_by_name( options[:vpc_name] )
                options.delete(:vpc_name)

            end

            security_group = @compute.security_groups.new( options )
            security_group.save

            @log.debug( security_group.inspect )

        end

        rationalise_rules( authorized_ranges )

    end

    def rationalise_rules( authorized_ranges )

        security_group = read

        current_rules = []
        rules_to_add  = []

        # Read all the existing rules from the SG object. Turn what we find into
        # a list of hashes, where the hash parameter names match those that we use
        # in the YAML description.  This will aid comparison of current vs. desired rules
        
        security_group.ip_permissions.each do |r|

            if r['groups'] != []

                r['groups'].each do |group|

                    c = {
                        :min_port    => r['fromPort'],
                        :max_port    => r['toPort'],
                        :ip_protocol => r['ipProtocol'],
                        :name        => @compute.security_groups.select { |sg| sg.group_id == group['groupId'] }.first.name,
                    }

                    current_rules << c

                end

            end

            if r['ipRanges'] != []

                r['ipRanges'].each do |ipRange|

                    c = {
                        :min_port    => r['fromPort'],
                        :max_port    => r['toPort'],
                        :ip_protocol => r['ipProtocol'],
                        :cidr_ip     => ipRange['cidrIp'],
                    }

                    current_rules << c

                end

            end

        end

        # Work through the list of desired rules.

        authorized_ranges.each do |r|

            # If we find a current rule that matches the desired rule, then
            # remove that from the list of current rules - you'll see why later.

            already_exists = false
            current_rules.delete_if do |c|
               if c == r
                  @log.debug ( "#{r.inspect} already exists" )
                  already_exists = true
                  true # so that delete_if removes the list item
               end 
            end

            unless already_exists

                # If the rule doesn't exist already, flag it to be added.
                # We do this *after* deleting old rules since some changes
                # to existing rules can cause conflict and error.
                # (eg. changing a rule from matching a sg name to matching
                # a cidr block causes this)

                rules_to_add << r

            end

        end

        # At the end of this loop, anything left in the current_rules list
        # represents a rule that's present on the infra, but should be deleted
        # (since there's no matching desired rule), so delete those.
        # Changing a rule maps to "delete old rule, create new one".

        current_rules.each do |r|

            @log.debug ( "Revoking superfluous #{r.inspect}" )

            # Translate sg name into id - looking up with API so we can reference SG names not in the config yaml
            if r.has_key?(:name) 
                groups = @compute.security_groups.select { |sg| sg.name == r[:name] }
                if groups.count == 0
                    raise "Can't find security group id for group name '#{r[:name]}'"
                end
                r[:group] = groups.first.group_id
            end


            security_group.revoke_port_range( 
                r.delete(:min_port)..r.delete(:max_port), r
            )

        end

        # Add any new rules that are required.

        rules_to_add.each do |r|

            @log.debug( "Adding #{r.inspect}" )

            # Translate sg name into id - looking up with API so we can reference SG names not in the config yaml
            if r.has_key?(:name) 
                groups = @compute.security_groups.select { |sg| sg.name == r[:name] }
                if groups.count == 0
                    raise "Can't find security group id for group name '#{r[:name]}'"
                end
                r[:group] = groups.first.group_id
            end

            security_group.authorize_port_range(
                r.delete(:min_port)..r.delete(:max_port), r
            )

        end

    end

    def read
        @compute.security_groups.select { |sg| sg.name == @options[:name] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting security group #{@options[:name]}" )

        fog_object.destroy

    end

    def create_tags(tags)
        # force symbols to strings in yaml tags
        resolved_tags = fog_object.tags.dup.merge(tags.collect{|k,v| [k.to_s, v]}.to_h)
        if resolved_tags != fog_object.tags
            @log.info("Updating tags for security group #{fog_object.name}")
            @compute.create_tags( fog_object.group_id.to_s, tags )
        end
    end

end

