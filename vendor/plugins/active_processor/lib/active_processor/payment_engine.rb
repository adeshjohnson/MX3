# -*- encoding : utf-8 -*-
module ActiveProcessor
  class PaymentEngine
    attr_reader :engine
    attr_reader :gateway
    attr_reader :fields
    attr_reader :instance
    attr_reader :errors
    attr_reader :post_to
    attr_reader :get_to
    attr_reader :settings
    attr_reader :payment

    def initialize(engine, gateway, options, fields)
      @engine, @gateway, @errors = engine.to_s, gateway.to_s, {}
      @fields = adjust_fields(options, fields)
      @settings = options['settings']
    end

    def each_field_for(scope = :form, &block)
      @fields[scope.to_s].sort_by { |k, v| v['position'] }.each(&block)
    end

    def set(scope, params = {})
      name, value, config = params.keys.first.to_s, params.values.first, @fields[scope.to_s]

      if name == "logo_image"
        if value.respond_to?(:read) # uploading file
          valid, message, ext= valid_logo?(value)
          if valid
            message = "custom_#{@gateway}_#{@engine}_logo.#{ext}"
            File.open(Rails.root + "/app/assets/images/logo/#{message}", "w") { |f| f.write(value.read) }
            value = message
          else
            @errors.store(name, message)
            value = get(:config, :logo_image).to_s
          end
        end

        value = @fields[scope.to_s][name.to_s]['html_options']['value'] if value.blank? and @fields[scope.to_s] and @fields[scope.to_s][name.to_s] and @fields[scope.to_s][name.to_s]['html_options'] and @fields[scope.to_s][name.to_s]['html_options']['value'] and !@fields[scope.to_s][name.to_s]['html_options']['value'].blank?

      end

      if value.kind_of?(StringIO)
        params = {name => {'html_options' => {'value' => value}}}
      elsif value.kind_of?(Hash)
        params = {}
        value.each_pair { |key, val|
          params.merge!({"#{name}[#{key}]" => {'html_options' => {'value' => val.strip}}})
        }
      else
        params = {name => {'html_options' => {'value' => value.to_s.strip}}}
      end

      for field, value in params
        if config[field].has_key?('validates')
          if mismatches_validation(value['html_options']['value'], config[field]['validates']['with'])
            @errors.store(field, config[field]['validates']['message'])
          end
        end
      end

      @fields = @fields.deep_merge(Hash[scope.to_s, params])
    end

    def get(scope, name)
      raise ActiveProcessor::GatewayEngineError.new("No such field was found for this gateway") unless @fields[scope.to_s].has_key?(name.to_s)

      return @fields[scope.to_s][name.to_s]['html_options']['value']
    end

    def display_form(options = {}, &block)

      @template ||= options['template'] if options.has_key?('template')

      if block_given?
        block.call(self, ActiveProcessor::FormHelper)
      else
        view = (@template) ? File.read(@template) : File.dirname(__FILE__) + '/views/payment-form.html.erb'
        erb = ::File.read view

        return ERB.new(erb).result(binding)
      end
    end

    def post_to(prefix, action = nil)
      action ||= "pay"
      @post_to ||= prefix + "/payment_gateways/#{@engine}/#{@gateway}/#{action}"
    end

    def get_to(prefix, action, id = nil)
      arr = [Web_URL, Web_Dir.to_s.gsub("/", ""), prefix.to_s.gsub("/", ""), "payment_gateways".to_s.gsub("/", ""), @engine.to_s.gsub("/", ""), @gateway.to_s.gsub("/", ""), action.to_s.gsub("/", ""), id.to_s.gsub("/", "")].collect { |el| el.to_s unless el.to_s.blank? }
      @get_to ||= arr.compact.join("/")
      @get_to
    end

    private

    def valid_logo?(file)
      if file.size > 0
        if file.size < 102400
          filename = sanitize_filename(file.original_filename)
          ext = filename.split(".").last.downcase
          if ['jpg', 'jpeg', 'png', 'gif'].include?(ext)
            return true, filename, ext
          else
            return false, _('Not_a_picture'), nil
          end
        else
          return false, _('Logo_to_big_max_size_100kb'), nil
        end
      else
        return false, _('Zero_size_file'), nil
      end
    end

    # Sanitizes uploaded file name
    def sanitize_filename(file_name)
      # get only the filename, not the whole path (from IE)
      just_filename = File.basename(file_name)
      # replace all none alphanumeric, underscore or perioids with underscore
      just_filename.gsub(/[^\w\.\_]/, '_')
    end

    def adjust_fields(config, custom_fields)
      fields = {}
      custom_fields ||= {}
      ['config', 'form'].each { |scope|
        if config.has_key?(scope.to_s)
          result = config[scope.to_s]['fields'].dup

          if config[scope.to_s].has_key?('excludes')
            # delete the unnecessary default fields
            result = result.delete_if {
                |key, value| config[scope.to_s]['excludes'].include?(key)
            } unless config[scope.to_s]['excludes'].nil?
          end
          if config[scope.to_s].has_key?('includes')
            # add necessary custom fields
            result.merge!(config[scope.to_s]['includes']) unless config[scope.to_s]['includes'].nil?
          end
          fields[scope] = result
        end
      }

      return fields.deep_merge(custom_fields.deep_stringify_keys)
    end

    # validation according to the regexp
    def mismatches_validation(field, regex)
      if field.match(regex)
        if field.match(regex)[0].eql?(field)
          return false
        end
      end
      return true
    end
  end
end
