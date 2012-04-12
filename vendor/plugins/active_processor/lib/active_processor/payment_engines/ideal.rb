# -*- encoding : utf-8 -*-
module ActiveProcessor
  module PaymentEngines
    class Ideal < PaymentEngine
      require 'yaml'

      attr_accessor :name
      attr_accessor :instance
      attr_accessor :response

      @@acquirers = {"ING" => {:test => "https://idealtest.secure-ing.com:443/ideal/iDeal", :live => "https://ideal.secure-ing.com:443/ideal/iDeal"}}

      def self.acquirers
        @@acquirers
      end

      def acquirer_url
        if initiate_gateway
          return ActiveMerchant::Billing::IdealGateway.acquirer_url
        else
          return []
        end
      end

      def initialize(engine, name, options = {}, fields = {})
        @name = name.to_s

        super(engine, name, options, fields)
      end

      def valid_settings?
        if !get(:config, 'max_amount').to_f.zero? and !get(:config, 'min_amount').to_f.zero? and get(:config, 'max_amount').to_f < get(:config, 'min_amount').to_f
          @errors.store("min_amount", "gateway_error_min_amount_more_than_max")
        end

        ActiveMerchant::Billing::IdealGateway.passphrase = get(:config, "passphrase")

        begin
          file = get(:config, "private_key_file")
          if file and file.respond_to?(:read) and file.size > 0
            text = file.read
            ActiveMerchant::Billing::IdealGateway.private_key = text
            set(:config, {"private_key_file" => text})
          end
        rescue Exception => e
          set(:config, {"private_key_file" => ''})
          @errors.store("private_key_file", "private_key_file_is_invalid")
        end

        begin
          file = get(:config, "private_certificate_file")
          if file and file.respond_to?(:read) and file.size > 0
            text = file.read
            ActiveMerchant::Billing::IdealGateway.private_certificate = text
            set(:config, {"private_certificate_file" => text})
          end
        rescue Exception => e
          set(:config, {"private_certificate_file" => ''})
          @errors.store("private_certificate_file", "private_certificate_file_is_invalid")
        end

        begin
          file = get(:config, "ideal_certificate_file")
          if file and file.respond_to?(:read) and file.size > 0
            text = file.read
            ActiveMerchant::Billing::IdealGateway.ideal_certificate = text
            set(:config, {"ideal_certificate_file" => text})
          end
        rescue Exception => e
          set(:config, {"ideal_certificate_file" => ''})
          @errors.store("ideal_certificate_file", "ideal_certificate_file_is_invalid")
        end
      end

      def valid?(params)
        for param, value in params[@engine][@name]
          set(:form, {param => value}) # field validations
        end
        params[@engine][@name]['amount'] = exchange(params[@engine][@name]['amount'], params[@engine][@name]['currency'], "EUR").to_f
        if get(:config, 'min_amount').to_i > 0
          if params[@engine][@name]['amount'].to_i < get(:config, 'min_amount').to_i
            params[@engine][@name]['amount'] = get(:config, 'min_amount').to_i
          end
        end

        if get(:config, 'max_amount').to_i > 0
          if params[@engine][@name]['amount'].to_i > get(:config, 'max_amount').to_i
            params[@engine][@name]['amount'] = get(:config, 'max_amount').to_i
          end
        end

        return (@errors.size > 0) ? false : true
      end

      def pay(user, ip, params)
        if self.get(:config, "tax_in_amount").to_s == "excluded"
          gross = params[@engine][@name]['amount'].to_f
          money = round_to_cents(ActiveProcessor.configuration.substract_tax.call(user, gross)).to_f
        else
          money = params[@engine][@name]['amount'].to_f
          gross = round_to_cents(ActiveProcessor.configuration.calculate_tax.call(user, money)).to_f
        end

        tax = gross - money
        @payment = Payment.create_for_user(user, {:pending_reason => "waiting_response", :paymenttype => [@engine, @name].join("_"), :currency => "EUR", :gross => gross, :tax => tax, :amount => money})
        @payment.save
        if purchase_options = {
            :issuer_id => params[:issuer_id].to_s,
            :order_id => @payment.id.to_s,
            :return_url => self.get_to(nil, "notify"),
            :description => self.get(:config, "description").to_s,
            :expiration_period => "PT60M",
            :entrance_code => @payment.id.to_s
        }
          a = initiate_gateway
          return false unless a
          gateway = ActiveMerchant::Billing::IdealGateway.new
          @response = gateway.setup_purchase((@payment.gross * 100).to_i, purchase_options)

          if @response.success?
            @payment.transaction_id = @response.transaction_id
            @payment.save
            return true
          else
            @payment.destroy
            return false
          end
        else
          return false
        end
      end

      def redirect_url
        @response.service_url
      end

      def display_name
        "iDeal"
      end

      def get_issuers
        conf = Confline.get_value("Ideal_Issuers_List_Time")
        issuers_db = Confline.get_value2("Ideal_Issuers_List")
        type = Confline.get_value("Ideal_Issuers_List_Type").to_i
        # Small hack "Time.now() - 1.year" makes Time.parse take 1 year from now as a default time if confline is empty.
        if Time.parse(conf, Time.now() - 1.year) + 1.day > Time.now and !issuers_db.to_s.blank? and self.get(:config, "test").to_i == type
          issuers = YAML::load(issuers_db)
        else
          a = initiate_gateway
          return [] unless a
          gateway = ActiveMerchant::Billing::IdealGateway.new
          issuers = gateway.issuers.list
          if issuers.size > 0
            Confline.set_value("Ideal_Issuers_List_Type", self.get(:config, "test").to_i)
            Confline.set_value("Ideal_Issuers_List_Time", Time.now.to_s(:db))
            Confline.set_value2("Ideal_Issuers_List", issuers.to_yaml)
          end
        end
        issuers
      end

      def check_response(payment)
        a = initiate_gateway
        return false, "Contact_administrator" unless a
        gateway = ActiveMerchant::Billing::IdealGateway.new
        transaction = gateway.capture(payment.transaction_id)

        if transaction.success?
          confirmation = self.get(:config, "payment_confirmation")
          user = User.find_by_id(payment.user_id)
          if confirmation.blank? or confirmation == "none"
            return true, finish_transaction(user, payment)
          else
            return true, make_wait_for_confirmation(user, payment)
          end
        else
          return false, set_error_messages(transaction, payment)
        end
      end

      private

      def finish_transaction(user, payment)
        payment.update_attributes({:completed => 1, :shipped_at => Time.now, :pending_reason => "Completed"})
        exchange_rate = ActiveProcessor.configuration.currency_exchange.call('EUR', Currency.get_default.name)
        Action.add_action_hash(payment.user_id,
                               {:action => "payment: #{self.settings['name']}",
                                :data => "User successfully payed using #{self.settings['name']} (iDeal)",
                                :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{payment.fee} #{payment.currency} | sent: #{payment.gross} #{payment.currency}",
                                :data2 => "payment id: #{payment.id}",
                                :data4 => "authorization: #{payment.transaction_id}"
                               })
        user.balance += payment.amount.to_f * exchange_rate
        if get(:config, "transaction_fee_enabled").to_i == 1
          fee = get(:config, "transaction_fee_amount").to_f
          fee_payment = payment.dup
          fee_payment.attributes = {:paymenttype => "ideal_ideal_fee", :fee => 0, :tax => 0, :shipped_at => Time.now,
                                    :completed => 1, :pending_reason => "Completed", :amount => fee*-1, :gross => fee*-1}
          fee_payment.save
          Action.add_action(user.id, "payment: #{self.settings['name']} fee", "User paid ideal fee: #{fee} EUR")
          user.balance -= fee.to_f * exchange_rate
        end
        user.save
        return _('Transaction_complete')
      end

      def make_wait_for_confirmation(user, payment)
        payment.update_attributes({:completed => 0, :pending_reason => "Waiting for confirmation"})

        Action.add_action_hash(payment.user_id,
                               {:action => "payment: #{self.settings['name']}",
                                :data => "User successfully payed, waiting for payment approval #{self.settings['name']} (iDeal)",
                                :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{payment.fee} #{payment.currency} | sent: #{payment.gross} #{payment.currency}",
                                :data2 => "payment id: #{payment.id}",
                                :data4 => "authorization: #{payment.transaction_id}"})

        if self.get(:config, 'payment_notification').to_i == 1
          owner = User.find_by_id(user.owner_id)
          email = Email.find(:first, :conditions => {:name => 'payment_notification_regular', :owner_id => owner.id})
          variables = Email.email_variables(owner, nil, {:payment => payment, :payment_notification => OpenStruct.new({}), :payment_type => "#{self.name} (#{self.engine})"})
          EmailsController::send_email(email, Confline.get_value("Email_from", owner.id), [owner], variables)
        end
        #flash[:status] = _('Transaction_waiting_for_confirmation')
      end

      def set_error_messages(transaction, payment)
        case transaction.status
          when :canceled then
            payment.update_attributes({:pending_reason => "Canceled", :shipped_at => Time.now})
            return _('Transaction_was_canceled')
          when :expired
            payment.update_attributes({:pending_reason => "Expired", :shipped_at => Time.now})
            return _('Transaction_has_expired')
          when :failure
            payment.update_attributes({:pending_reason => "Failure", :shipped_at => Time.now})
            return _('Transaction_has_failed')
          when :open
            return _('Transaction_not_yet_complete')
          else
            return _('Other_status')+": "+transaction.status.to_s
        end
      end

      def initiate_gateway
        begin
          ActiveMerchant::Billing::IdealGateway.live_url = @@acquirers[self.get(:config, "ideal_acquirer")][:live]
          ActiveMerchant::Billing::IdealGateway.test_url = @@acquirers[self.get(:config, "ideal_acquirer")][:test]
          ActiveMerchant::Billing::IdealGateway.merchant_id = self.get(:config, "merchant_id")
          ActiveMerchant::Billing::IdealGateway.passphrase = self.get(:config, "passphrase")
          ActiveMerchant::Billing::IdealGateway.private_key = self.get(:config, "private_key_file")
          ActiveMerchant::Billing::IdealGateway.private_certificate = self.get(:config, "private_certificate_file")
          ActiveMerchant::Billing::IdealGateway.ideal_certificate = self.get(:config, "ideal_certificate_file")
          ActiveMerchant::Billing::Base.gateway_mode = (self.get(:config, "test").to_i == 1 ? :test : :live)
          return true
        rescue
          return false
        end
      end

      def exchange(amount, curr1, curr2)
        amount = amount.to_f * ActiveProcessor.configuration.currency_exchange.call(curr1, curr2) if defined? ActiveProcessor.configuration.currency_exchange
        return round_to_cents(amount).to_f
      end

      def round_to_cents(amount)
        return sprintf("%.2f", amount)
      end
    end
  end
end
