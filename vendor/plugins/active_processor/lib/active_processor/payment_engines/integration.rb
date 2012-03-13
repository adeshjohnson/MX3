# -*- encoding : utf-8 -*-
module ActiveProcessor
  module PaymentEngines
    class Integration < PaymentEngine
      extend Forwardable

      # Instance of gateway (ActiveMerchant gateway or integration)
      attr_accessor :gateway
      # Instance of gateway (ActiveMerchant gateway or integration)
      attr_accessor :name
      # Test mode
      attr_accessor :test

      def initialize(engine, name, options = {}, fields = {})
        @name = name.to_s
        @instance = ActiveMerchant::Billing::Base.integration(name.to_s.capitalize.to_sym)

        super(engine, name, options, fields)
      end

      def display_name
        @name.to_s.humanize
      end

      def valid_settings?
        if !get(:config, 'max_amount').to_f.zero? and !get(:config, 'min_amount').to_f.zero? and get(:config, 'max_amount').to_f < get(:config, 'min_amount').to_f
          @errors.store("min_amount", "gateway_error_min_amount_more_than_max")
        end
      end


      def valid?(params)
        for param, value in params[@engine][@name]
          set(:form, { param => value }) # field validations
        end

        if get(:config, 'min_amount').to_i > 0
          if exchange(params[@engine][@name]['amount'], params[@engine][@name]['currency'], @settings['default_currency']).to_i < get(:config, 'min_amount').to_i * 100.0
            @errors.store("amount", "gateway_error_min_amount")
          end
        end

        if get(:config, 'max_amount').to_i > 0
          if exchange(params[@engine][@name]['amount'], params[@engine][@name]['currency'], params[@engine][@name]['default_currency']).to_i > get(:config, 'max_amount').to_i * 100.0
            @errors.store("amount", "gateway_error_max_amount")
          end
        end

        return (@errors.size > 0) ? false : true
      end

      def pay(user, ip, params)
        if self.get(:config, "tax_in_amount").to_s == "excluded"
          gross = exchange(params[@engine][@name]['amount'], params[@engine][@name]['currency'], @settings['default_currency']).to_f
          money = ActiveProcessor.configuration.substract_tax.call(user, gross).to_f
          origin_with_tax = params[@engine][@name]['amount'].to_f
          orig = ActiveProcessor.configuration.substract_tax.call(user, origin_with_tax).to_f
        else
          money = exchange(params[@engine][@name]['amount'], params[@engine][@name]['currency'], @settings['default_currency']).to_f
          gross = ActiveProcessor.configuration.calculate_tax.call(user, money).to_f
          origin_with_tax = ActiveProcessor.configuration.calculate_tax.call(user, params[@engine][@name]['amount']).to_f
          orig = params[@engine][@name]['amount'].to_f
        end
        orig_tax = origin_with_tax - orig
        tax = gross - money
        @payment = OpenStruct.new({
            :money => money,
            :orig_amount => orig,
            :orig_tax => orig_tax,
            :orig_with_tax => round_to_cents(origin_with_tax).to_f,
            :tax => round_to_cents(tax).to_f,
            :auth_config => {}
          })

        @payment.orig_tax = (@payment.orig_with_tax - @payment.orig_amount)
        @payment.amount = gross.ceil / 100.0
      end

      def notify_url
        "/payment_gateways/#{@engine}/#{@name}/notify"
      end

      def return_url
        "/payments/personal_payments"
      end

      def cancel_return_url
        "/callc/main"
      end

      private

      def exchange(amount, curr1, curr2)
        amount = amount.to_f * ActiveProcessor.configuration.currency_exchange.call(curr1, curr2) if defined? ActiveProcessor.configuration.currency_exchange
        return round_to_cents(amount).to_f * 100.0
      end

      def round_to_cents(amount)
        return sprintf("%.2f", amount)
      end

    end
  end
end
