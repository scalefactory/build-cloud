module BuildCloud::Component

    # Using idiom for putting class methods in mixin
    # http://stackoverflow.com/questions/10692961/inheriting-class-methods-from-mixins
    
    def self.included(base)
        base.send :include, InstanceMethods
        base.extend ClassMethods
    end

    module InstanceMethods

        def [](key)
            @options[key]
        end

        def has_key?(key)
            @options.has_key?(key)
        end

        def exists?
            !read.nil?
        end

        def ready_timeout
            30
        end

        def wait_until_ready

            unless read.class.method_defined?(:ready?)
                @log.debug("Can't wait for readiness on #{read.class.to_s}")
                return
            end

            timeout = ready_timeout # default from this superclass

            wait_timer = 1
            start_time = Time.now.to_i

            begin

                if fog_object.ready?
                    @log.info("Object ready")
                    return true
                end

                @log.debug("Object not yet ready. Sleeping #{wait_timer}s")

                sleep( wait_timer )

                if wait_timer < 60
                    wait_timer *= 2
                end

                time_diff = Time.now.to_i - start_time

            end while time_diff < timeout

            @log.error("Timed out after #{timeout} waiting for #{read.class}")

        end

        def required_options( *required )

            cn = self.class.name.split('::').last
            missing = []

            required.each do |o|
                missing << o unless @options.has_key?(o)
            end

            if missing.length > 0
                raise "#{cn} requires missing #{missing.join(', ')} option#{missing.length > 1 ? 's' : ''}" 
            end 

        end

        def require_one_of( *required )

            cn = self.class.name.split('::').last

            intersection = @options.keys & required

            if intersection.length != 1
                raise "#{cn} requires only one of #{required.join(', ')}"
            end
    

        end

        def to_s
            return @options.to_yaml
        end

    end

    module ClassMethods

        # implied "self." for all methods here

        def load( items, fog_interfaces, log )

            objects = self.send :class_variable_get, :@@objects

            items.each do |item|
                objects << self.new( fog_interfaces, log, item )
            end

            objects

        end

         
        def search(options)

            objects = self.send :class_variable_get, :@@objects

            objects.select { |o|

                matches = true

                options.each_pair do |k,v|

                    unless o.has_key?(k) and o[k] == v
                        matches = false
                    end

                end

                matches

            }

        end

        def objects 
            self.send :class_variable_get, :@@objects
        end

    end

end
