module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybooker
        autoload 'Helper', File.dirname(__FILE__) + '/moneybooker/helper'
        autoload 'Notification', File.dirname(__FILE__) + '/moneybooker/notification'
        autoload 'Return', File.dirname(__FILE__) + '/moneybooker/return'

        mattr_accessor :secret_word
        mattr_accessor :test_url
        mattr_accessor :production_url
        mattr_accessor :service_url

        self.test_url = 'https://www.moneybookers.com/app/payment.pl'
        self.production_url = 'https://www.moneybookers.com/app/payment.pl'
        self.secret_word = "change me!"

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification(post)
          Notification.new(post)
        end

        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
