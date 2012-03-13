# -*- encoding : utf-8 -*-
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybooker
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super

            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              Moneybooker.service_url = "http://www.moneybookers.com/app/test_payment.pl"
            end

            add_field('amount2_description', options[:amount2_description]) # Tax
            add_field('amount3_description', options[:amount3_description]) # Shipping
          end

          mapping :account, 'pay_to_email'
          mapping :amount, 'amount'
          mapping :order, 'transaction_id'

          mapping :customer, :first_name => 'firstname',
                             :last_name  => 'lastname',
                             :email      => 'pay_from_email',
                             :phone      => 'phone_number'

          mapping :billing_address, :city     => 'city',
                                    :address1 => 'address',
                                    :address2 => 'address2',
                                    :state    => 'state',
                                    :zip      => 'postal_code',
                                    :country  => 'country'

          mapping :notify_url, 'status_url'
          mapping :return_url, 'return_url'
          mapping :cancel_return_url, 'cancel_url'
          mapping :description, 'recipient_description'
          mapping :tax, 'amount2'
          mapping :shipping, 'amount3'
          mapping :currency, 'currency'
        end
      end
    end
  end
end
