# -*- encoding : utf-8 -*-
require 'net/http'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybooker
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            params['status'] == "2"
          end 

          def item_id
            params['transaction_id']
          end

          def transaction_id
            params['mb_transaction_id']
          end

          def currency
            params['currency']
          end

          # When was this payment received by the client. 
          def received_at
            Time.now
          end

          def payer_email
            params['pay_from_email']
          end

          def receiver_email
            params['pay_to_email']
          end 

          def security_key
            params['md5sig']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          def fee
            0
          end

          # Was this a test transaction?
          def test?
            Moneybookers.service_url == 'http://www.moneybookers.com/app/test_payment.pl'
          end

          def status
            params['status']
          end

          def verify(secret)
            return false if security_key.blank?

            Digest::MD5.hexdigest("#{params['merchant_id']}#{params['transaction_id']}#{secret}#{params['mb_amount']}#{params['mb_currency']}#{params['status']}").upcase == security_key.upcase
          end

          def acknowledge
            true
          end

        end
      end
    end
  end
end
