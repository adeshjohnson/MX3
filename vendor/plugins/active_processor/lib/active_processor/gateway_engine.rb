# -*- encoding : utf-8 -*-
module ActiveProcessor
  module GatewayEngine

    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      def find(quantity, options = {})
        new(quantity, options)
      end

      def fields
        @fields ||= {}
      end

      def field(engine, scope, name, options = {})
        if options.is_a?(Proc)
          fields.deep_merge!({ engine.to_s => { scope.to_s => { name.to_s => options.call } } })
        else
          fields.deep_merge!({ engine.to_s => { scope.to_s => { name.to_s => options } } })
        end
      end

      def filters
        @filters ||= []
      end

      def filter(name, arg)
        filters.push({ name => arg })

        define_method name do |input|
          self.gateways.each { |engine, gateways|
            gateways.reject!{ |name, gateway| arg.call(gateway, input)  }
          }
          self
        end
      end

    end

    module InstanceMethods
      # Currently used gateway
      attr_accessor :engine

      # Currently used gateway
      attr_accessor :gateway

      # User that uses the engine
      attr_accessor :user

      # gateways
      attr_accessor :gateways

      # Quantity
      attr_reader :quantity

      # Configuration
      attr_reader :configuration

      # Attributes
      attr_accessor :attributes

      # Form path
      attr_accessor :template

      # Post to
      attr_accessor :post_to

      # Params
      attr_accessor :params

      # Mode
      attr_reader :mode

      def initialize(quantity = :first, options = {})
        @engine, @gateway, @template, @post_to, @user, @mode = options.values_at(:engine, :gateway, :template, :post_to, :for_user, :mode)
        @quantity = quantity

        yield self if block_given?

        process
      end


      def for_user(user)
        @user = user
        run(["on", @engine, "user_set"], ["on","user_set"])
        self
      end

      def user_is_set?
        not @user.nil?
      end

      def display_form(options = {}, &block)
        options.stringify_keys!

        @template ||= options['template'] if options.has_key?('template')

        if block_given?
          block.call(self, ActiveProcessor::FormHelper)
        else
          view = (@template) ? File.read(@template) : File.dirname(__FILE__) + '/views/configuration-form.html.erb'
          erb  = ::File.read view

          return ERB.new(erb).result(binding)
        end
      end

      def query(options = {})
        options.stringify_keys!

        if options.has_key?('field')
          raise ActiveProcessor::GatewayEngineError.new("You should set gateway, engine and scope(config, form) when querying field") if options['gateway'].nil? || options['engine'].nil? || options['scope'].nil?

          begin
            ActiveProcessor.log("querying gateway: #{options['engine']} #{options['gateway']} #{options['scope']} #{options['field']}")
            @gateways[options['engine'].to_s][options['gateway'].to_s].fields[options['scope'].to_s][options['field'].to_s]['value']
          rescue NoMethodError
            raise ActiveProcessor::GatewayEngineError.new("No such field was found")
          end
        elsif options.has_key?('gateway')
          raise ActiveProcessor::GatewayEngineError.new("You should set engine when querying gateway") if options['engine'].nil?

          ActiveProcessor.log("querying gateway: #{options['engine']} #{options['gateway']}")
          @gateways[options['engine'].to_s][options['gateway'].to_s]
        elsif options.has_key?('engine')

          ActiveProcessor.log("querying gateway: #{options['engine']}")
          @gateways[options['engine'].to_s]
        else
          @gateways.values.first.values.first
        end
      end

      def size
        @gateways.inject(0) {|s,en| s += en.last.keys.size}
      end

      # Assumes the params structure of:
      # { :engine => { :gateway => { :param1 => "value", :param2 => "value" } }
      # e.g. { :gateways => { :bogus => { :login => "value", :password => "value" } }
      def update_with(scope, params = {})
        @params, errors = params, 0 # these may be needed in callback
        run("on","before",scope.to_s,"update")

        @params.each { |engine, gateways|
          gateways.each { |gateway, settings|
            ActiveProcessor.log("updating gateway: #{gateway} #{scope}")
            settings.each { |name, value|
              @gateways[engine][gateway].set(scope, { name => value })
              errors += @gateways[engine][gateway].errors.size
            }
            if @gateways[engine][gateway].respond_to?(:valid_settings?)
              @gateways[engine][gateway].valid_settings?
              errors += @gateways[engine][gateway].errors.size
            end
          }
        }

        run("on","after",scope.to_s,"update")

        return (errors == 0) ? true : false
      end

      # Pay using these parameters
      def pay_with(gateway, ip, params = {})
        @params = params # for callbacks
        run(["on","before","payment","validation"],["on","before",@engine,"payment","validation"])
        ActiveProcessor.log("validating gateway: #{gateway.name} #{gateway.engine}")
        if gateway.valid?(params)
          ActiveProcessor.log("validated successfully: #{gateway.name} #{gateway.engine}")
          run(["on","after","payment","validation"],["on","after",@engine,"payment","validation"])
          ActiveProcessor.log("paying with gateway: #{gateway.name} #{gateway.engine}")
          if gateway.pay(@user, ip, params)
            ActiveProcessor.log("successfully payed with: #{gateway.name} #{gateway.engine}")
            run(["on","after","successful","payment"],["on","after",@engine,"successful","payment"])
            return true
          else
            ActiveProcessor.log("failed to pay with: #{gateway.name} #{gateway.engine}")
            run(["on","after","failed","payment"],["on","after",@engine,"failed","payment"])
            return false
          end
        else
          ActiveProcessor.log("failed to validate: #{gateway.name} #{gateway.engine}")
          run(["on","after","failed","payment","validation"],["on","after",@engine,"failed","payment","validation"])
          return false
        end
      end

      def to_hash
        @gateways
      end

      def process
        # Data for concrete gateway
        if @quantity == :first
          sanity_check

          @gateways = { @engine.to_s => { @gateway.to_s => ActiveProcessor::PaymentEngines.const_get(@engine.to_s.classify.to_sym).new(@engine, @gateway, ActiveProcessor.configuration.data[@engine.to_s][@gateway.to_s], self.class.fields[@engine.to_s]) } }

          run("on","first","find") unless @mode == :update
        elsif @quantity == :enabled
          @gateways, @attributes = {}, {}

          ActiveProcessor.configuration.data['enabled'].each { |engine, gateways|
            gateways.each { |gateway|
              @gateways.deep_merge!({ engine.to_s => { gateway.to_s => ActiveProcessor::PaymentEngines.const_get(engine.to_s.classify.to_sym).new(engine, gateway, ActiveProcessor.configuration.data[engine][gateway], self.class.fields[engine.to_s]) } })
            }
          }

          run("on","enabled","find") unless @mode == :update
        else
          # ..or all gateways from this engine
          raise ActiveProcessor::GatewayEngineError.new("There is no engine defined by this name") unless ActiveProcessor.configuration.data['enabled'].keys.include?(@engine.to_s)

          @gateways, @attributes = {}, {}

          ActiveProcessor.configuration.data['enabled'][@engine.to_s].each { |gateway|
            @gateways.deep_merge!({ @engine.to_s => { gateway.to_s => ActiveProcessor::PaymentEngines.const_get(@engine.to_s.classify.to_sym).new(@engine, gateway, ActiveProcessor.configuration.data[@engine.to_s][gateway], self.class.fields[@engine.to_s]) } })
          }

          run("on","all","find") unless @mode == :update
        end

        run("on","find") unless @mode == :update

        @gateways
      end

      def post_to
        @post_to ||= "update"
      end

      private

      # Checks wether all required variables are present and data can be accessed in configuration.
      # Required due to lazy nature of data access.
      def sanity_check
        raise ActiveProcessor::GatewayEngineError.new("You should set engine and gateway first") if @engine.nil? || @gateway.nil?
        raise ActiveProcessor::GatewayEngineError.new("There is no engine defined by this name") unless ActiveProcessor.configuration.data['enabled'].keys.include?(@engine.to_s)
        raise ActiveProcessor::GatewayEngineError.new("There is no gateway enabled for this engine") unless ActiveProcessor.configuration.data['enabled'][@engine.to_s].include?(@gateway.to_s)
      end

      def run(*args)
        case args.first.class.to_s
        when "String"
          method = args.join("_")
          send(method) if self.respond_to?(method)
        when "Array"
          for callback in args
            method = callback.join("_")
            send(method) if self.respond_to?(method)
          end
        end
      end

    end

  end
end
