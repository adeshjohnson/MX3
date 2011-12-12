module ActiveProcessor
  module PaymentEngines
    class GoogleCheckout < PaymentEngine
      attr_accessor :name
      attr_accessor :instance
      attr_accessor :response

      def initialize(engine, name, options = {}, fields = {})
        @name = name.to_s

        super(engine, name, options, fields)
      end
      
      def valid_settings?
        if !get(:config, 'max_amount').to_f.zero? and !get(:config, 'min_amount').to_f.zero? and get(:config, 'max_amount').to_f < get(:config, 'min_amount').to_f
          @errors.store("min_amount", "gateway_error_min_amount_more_than_max")
        end
      end

      def valid?(params)
        MorLog.my_debug("Before")
        init_config

        for param, value in params[@engine][@name]
          set(:form, { param => value }) # field validations
        end

        params[@engine][@name]['amount'] = round_to_cents(params[@engine][@name]['amount']).to_i*100 # Paverciam centais.
        MorLog.my_debug("#{params[@engine][@name]['amount'].to_i} #{params[@engine][@name]['currency']}")
        if get(:config, 'min_amount').to_i > 0
          if exchange(params[@engine][@name]['amount'], params[@engine][@name]['currency'], get(:config, 'default_geteway_currency')).to_i < get(:config, 'min_amount').to_i * 100.0
            #@errors.store("amount", "gateway_error_min_amount")
            params[@engine][@name]['amount'] = exchange(get(:config, 'min_amount').to_i, get(:config, 'default_geteway_currency'), params[@engine][@name]['currency']) * 100
          end
        end

        if get(:config, 'max_amount').to_i > 0
          if exchange(params[@engine][@name]['amount'], params[@engine][@name]['currency'], get(:config, 'default_geteway_currency')).to_i > get(:config, 'max_amount').to_i * 100.0
            #@errors.store("amount", "gateway_error_max_amount")
            params[@engine][@name]['amount'] = exchange(get(:config, 'max_amount').to_i, get(:config, 'default_geteway_currency'), params[@engine][@name]['currency']) * 100
          end
        end
        MorLog.my_debug("After")
        MorLog.my_debug("#{params[@engine][@name]['amount'].to_i} #{params[@engine][@name]['currency']}")
        return (@errors.size > 0) ? false : true
      end

      def pay(user, ip, params)
        payment_default_currency = get(:config, 'default_geteway_currency').to_s
        original_currency = params[@engine][@name]['currency'].to_s
        original_amount = params[@engine][@name]['amount'].to_f
        init_config
        if self.get(:config, "tax_in_amount").to_s == "excluded"
          gross = exchange(original_amount, original_currency, payment_default_currency)
          money = ActiveProcessor.configuration.substract_tax.call(user, gross)
          origin_with_tax = original_amount
        else
          money = exchange(original_amount,original_currency, payment_default_currency)
          gross = ActiveProcessor.configuration.calculate_tax.call(user, money)
          origin_with_tax = ActiveProcessor.configuration.calculate_tax.call(user, original_amount)
        end
        
        @payment = OpenStruct.new({
            :money => money,
            :orig_amount => original_amount.to_f,
            :orig_tax => 0,
            :orig_with_tax => round_to_cents(origin_with_tax).to_f,
            :tax => round_to_cents(gross).to_f - money,
            :orig_currency => original_currency,
            :currency => payment_default_currency
          })
        @payment.orig_tax = (@payment.orig_with_tax - @payment.orig_amount)
        @payment.amount = gross.ceil
      end

      def init
        init_config
        @instance
      end

      def notification_handler
        init_config
        @instance.create_notification_handler
      end

      def display_name
        "Google Checkout"
      end

      def redirect_url
        @response.redirect_url
      end

      private

      def exchange(amount, curr1, curr2)
        amount = amount.to_f * ActiveProcessor.configuration.currency_exchange.call(curr1, curr2) if defined? ActiveProcessor.configuration.currency_exchange
        return round_to_cents(amount).to_f
      end

      def round_to_cents(amount)
        return sprintf("%.2f", amount.to_f).to_f
      end

      def init_config
        return unless @instance.nil?

        auth_config = {}
        # we choose only those fields for authentication which have attribute for=authentication in configuration
        @fields['config'].clone.delete_if{ |item, conf| conf['for'] != "authentication" }.each {|field, configuration|
          auth_config[field.to_sym] = configuration['html_options']['value']
        }
        auth_config[:use_sandbox] = (auth_config[:use_sandbox].to_i == 0 ? false : true)
        @instance = Google4R::Checkout::Frontend.new(auth_config)
        @instance.tax_table_factory = ::TaxTableFactory.new
      end

    end
  end
end

