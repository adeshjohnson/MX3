# -*- encoding : utf-8 -*-
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HsbcSecureEpaymentsGateway < Gateway

      CARD_TYPE_MAPPINGS = {:visa => 1, :master => 2, :american_express => 8, :solo => 9, :switch => 10, :maestro => 14}

      COUNTRY_CODE_MAPPINGS = {
          'CA' => 124, 'GB' => 826, 'US' => 840
      }

      CURRENCY_MAPPINGS = {
          'USD' => 840, 'GBP' => 826, 'CAD' => 124, 'EUR' => 978
      }

      HSBC_CVV_RESPONSE_MAPPINGS = {
          '0' => 'X',
          '1' => 'M',
          '2' => 'N',
          '3' => 'P',
          '4' => 'S',
          '5' => 'X',
          '6' => 'I',
          '7' => 'U'
      }

      TRANSACTION_STATUS_MAPPINGS = {
          :accepted => "A",
          :declined => "D",
          :fraud => "F",
          :error => "E",
          :void => "V",
          :reserved => "U"
      }

      APPROVED = 1
      DECLINED = 50
      DECLINED_FRAUDULENT = 500
      DECLINED_FRAUDULENT_VOIDED = 501
      DECLINED_FRAUDULENT_REVIEW = 502
      CVV_FAILURE = 1055
      FRAUDULENT = [DECLINED_FRAUDULENT, DECLINED_FRAUDULENT_VOIDED, DECLINED_FRAUDULENT_REVIEW, CVV_FAILURE]

      # HSBC can operate in many test modes:
      #    "Y" = test; always return yes,
      #    "N" = test; always return no,
      #    "R" = reject,
      #    "P" = production; LIVE TRANSACTIONS. DO NOT USE IN TEST MODE)
      class_attribute :test_mode
      self.test_mode = "Y"

      # PaymentMech type can only be "CreditCard" at present but may change
      class_attribute :payment_mech_type
      self.payment_mech_type = "CreditCard"

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US', 'GB']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :switch, :solo, :maestro]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.hsbc.co.uk/1/2/business/cards-payments/secure-epayments'

      # The name of the gateway
      self.display_name = 'HSBC Secure ePayments'

      # Default currency is US$
      #self.default_currency = "GBP"

      # HSBC amounts are always in cents
      self.money_format = :cents

      TEST_URL = 'https://www.secure-epayments.apixml.hsbc.com'
      LIVE_URL = 'https://www.secure-epayments.apixml.hsbc.com'

      def initialize(options = {})
        requires!(options, :login, :password, :client_id, :xml_url, :default_geteway_currency)
        @options = options
        super
      end

      def test?
        @options[:test] || super
      end

      def purchase(money, credit_card, options = {})
        options = {
            :money => money,
            :credit_card => credit_card,
            :currency => self.options[:default_geteway_currency]
        }.merge(options)
        xml = build_request { |xml| insert_purchase_data(xml, options) }
        commit('purchase', xml)
      end

      def authorize(money, credit_card, options = {})
        options = {
            :money => money,
            :credit_card => credit_card,
            :currency => self.options[:default_geteway_currency]
        }.merge(options)
        xml = build_request { |xml| insert_authorize_data(xml, options) }
        commit('authorize', xml)
      end

      def capture(money, authorization, options = {})
        options = {
            :money => money,
            :authorization => authorization,
            :currency => self.options[:default_geteway_currency]
        }.merge(options)
        xml = build_request { |xml| insert_capture_data(xml, options) }
        # puts xml
        # puts "************************************************************"
        commit('capture', xml)
      end

      def void(authorization, options = {})
        options = {
            :authorization => authorization
        }.merge(options)
        xml = build_request { |xml| insert_void_data(xml, options) }
        commit('void', xml)
      end

      private

      def build_request(&block)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
        xml.EngineDocList do
          xml.DocVersion(:DataType => "String") { |x| x.text! "1.0" }
          xml.EngineDoc do
            xml.ContentType(:DataType => "String") { |x| x.text! "OrderFormDoc" }
            xml.User do
              xml.ClientId(:DataType => "S32") { |x| x.text! self.options[:client_id] }
              xml.Name(:DataType => "String") { |x| x.text! self.options[:login] }
              xml.Password(:DataType => "String") { |x| x.text! self.options[:password] }
            end
            xml.Instructions do
              xml.Pipeline(:DataType => "String") { |x| x.text! "Payment" }
            end
            yield(xml)
          end
        end
      end

      def insert_authorize_data(xml, options = {})
        xml.OrderFormDoc do
          xml.Mode(:DataType => "String") { |x| x.text! self.test? ? self.class.test_mode : "P" }
          xml.Consumer do
            xml.PaymentMech do
              xml.Type(:DataType => "String") { |x| x.text! self.class.payment_mech_type }
              xml.CreditCard do
                credit_card = options[:credit_card]
                xml.Number(:DataType => "String") { |x| x.text! credit_card.number }
                xml.Expires(:DataType => "ExpirationDate") { |x| x.text! "#{format(credit_card.month, :two_digits)}/#{format(credit_card.year, :two_digits)}" }
                xml.Cvv2Val(:DataType => "String") { |x| x.text! credit_card.verification_value } unless credit_card.verification_value.blank?
                xml.Cvv2Indicator(:DataType => "String") { |x| x.text! "1" } unless credit_card.verification_value.blank?
              end
            end
            add_billing_address(xml, options)
            add_shipping_address(xml, options)
          end
          add_transaction_element(xml, "PreAuth", options)
        end
      end

      def insert_purchase_data(xml, options = {})
        xml.OrderFormDoc do
          xml.Id(:DataType => "String") { |x| x.text! 'order_number_1' }
          xml.Mode(:DataType => "String") { |x| x.text! self.test? ? self.class.test_mode : "P" }
          xml.Consumer do
            xml.PaymentMech do
              xml.Type(:DataType => "String") { |x| x.text! self.class.payment_mech_type }
              xml.CreditCard do
                credit_card = options[:credit_card]
                xml.Number(:DataType => "String") { |x| x.text! credit_card.number }
                xml.Expires(:DataType => "ExpirationDate") { |x| x.text! "#{format(credit_card.month, :two_digits)}/#{format(credit_card.year, :two_digits)}" }
                xml.Cvv2Val(:DataType => "String") { |x| x.text! credit_card.verification_value } unless credit_card.verification_value.blank?
                xml.Cvv2Indicator(:DataType => "String") { |x| x.text! "1" } unless credit_card.verification_value.blank?
              end
            end
            add_billing_address(xml, options)
            add_shipping_address(xml, options)
          end
          add_transaction_element(xml, "Auth", options)
        end
      end

      def insert_capture_data(xml, options = {})
        xml.OrderFormDoc do
          xml.Mode(:DataType => "String") { |x| x.text! self.test? ? self.class.test_mode : "P" }
          add_transaction_element(xml, "PostAuth", options)
        end
      end

      def insert_void_data(xml, options = {})
        xml.OrderFormDoc do
          xml.Mode(:DataType => "String") { |x| x.text! self.test? ? self.class.test_mode : "P" }
          add_transaction_element(xml, "Void", options)
        end
      end

      def add_billing_address(xml, options = {})
        if options[:billing_address]
          xml.BillTo do
            xml.Location do
              xml.Email(:DataType => "String") { |x| x.text! options[:email] } if options[:email]
              xml.TelVoice(:DataType => "String") { |x| x.text! options[:billing_address][:phone] } if options[:billing_address][:phone]
              add_address(xml, options[:billing_address])
            end
          end
        end
      end

      def add_shipping_address(xml, options = {})
        if options[:shipping_address]
          xml.ShipTo do
            xml.Location do
              xml.Email(:DataType => "String") { |x| x.text! options[:email] } if options[:email]
              xml.TelVoice(:DataType => "String") { |x| x.text! options[:shipping_address][:phone] } if options[:shipping_address][:phone]
              add_address(xml, options[:shipping_address])
            end
          end
        end
      end

      def add_address(xml, address_opts = {})
        xml.Address(:DataType => "String") do
          xml.Name(:DataType => "String") { |x| x.text! address_opts[:name] } if address_opts[:name]
          xml.Company(:DataType => "String") { |x| x.text! address_opts[:company] } if address_opts[:company]
          xml.Street1(:DataType => "String") { |x| x.text! address_opts[:address1] } if address_opts[:address1]
          xml.Street2(:DataType => "String") { |x| x.text! address_opts[:address2] } if address_opts[:address2]
          xml.City(:DataType => "String") { |x| x.text! address_opts[:city] } if address_opts[:city]
          xml.StateProv(:DataType => "String") { |x| x.text! address_opts[:state] } if address_opts[:state]
          xml.Country(:DataType => "String") { |x| x.text! COUNTRY_CODE_MAPPINGS[address_opts[:country]].to_s } if address_opts[:country]
          xml.PostalCode(:DataType => "String") { |x| x.text! address_opts[:zip] } if address_opts[:zip]
        end
      end

      def add_transaction_element(xml, transaction_type, options = {})
        xml.Transaction do
          xml.Type(:DataType => "String") { |x| x.text! transaction_type }
          case transaction_type
            when 'PreAuth', 'Auth'
              xml.CurrentTotals do
                xml.Totals do
                  xml.Total(:DataType => "Money", :Currency => CURRENCY_MAPPINGS[self.options[:default_geteway_currency]].to_s) { |x| x.text! amount(options[:money]) }
                end
              end
            when 'PostAuth', 'Void'
              xml.Id(:DataType => "String") { |x| x.text! options[:authorization] }
              xml.CurrentTotals do
                xml.Totals do
                  xml.Total(:DataType => "Money", :Currency => CURRENCY_MAPPINGS[self.options[:default_geteway_currency]].to_s) { |x| x.text! amount(options[:money]) }
                end
              end
          end
        end
      end

      def commit(action, xml)
        ActiveProcessor.log("------------------------")
        ActiveProcessor.log(xml)
        response = parse(action, ssl_post(self.options[:xml_url], xml, "Content-Type" => "application/xml"))
        ActiveProcessor.log("*******************************")
        ActiveProcessor.log(response.to_yaml)
        Response.new(success_from(action, response), message_from(response), response, options_from(response))
      end

      def parse(action, response_xml)
        response = {}
        xml = REXML::Document.new(response_xml)

        messages = xml.root.elements['EngineDoc/MessageList']
        overview = xml.root.elements['EngineDoc/Overview']
        transaction = xml.root.elements["EngineDoc/OrderFormDoc/Transaction"]

        unless messages.blank?
          response[:severity] = messages.elements['MaxSev'].text.to_i unless messages.elements['MaxSev'].blank?
          response[:advised_action] = messages.elements['Message/AdvisedAction'].text.to_i unless messages.elements['Message/AdvisedAction'].blank?
          response[:error_message] = messages.elements['Message/Text'].text unless messages.elements['Message/Text'].blank?
        end

        unless overview.blank?
          response[:return_code] = overview.elements['CcErrCode'].text.to_i unless overview.elements['CcErrCode'].blank?
          response[:return_message] = overview.elements['CcReturnMsg'].text unless overview.elements['CcReturnMsg'].blank?
          response[:transaction_id] = overview.elements['TransactionId'].text unless overview.elements['TransactionId'].blank?
          response[:auth_code] = overview.elements['AuthCode'].text unless overview.elements['AuthCode'].blank?
          response[:transaction_status] = overview.elements['TransactionStatus'].text unless overview.elements['TransactionStatus'].blank?
          response[:mode] = overview.elements['Mode'].text unless overview.elements['Mode'].blank?
        end

        unless transaction.blank?
          response[:avs_code] = transaction.elements['CardProcResp/AvsRespCode'].text unless transaction.elements['CardProcResp/AvsRespCode'].blank?
          response[:avs_display] = transaction.elements['CardProcResp/AvsDisplay'].text unless transaction.elements['CardProcResp/AvsDisplay'].blank?
          response[:cvv2_resp] = transaction.elements['CardProcResp/Cvv2Resp'].text unless transaction.elements['CardProcResp/Cvv2Resp'].blank?
        end
        response
      end

      def options_from(response)
        options = {}
        options[:authorization] = response[:transaction_id]
        options[:test] = response[:mode].blank? || response[:mode] != "P"
        options[:fraud_review] = FRAUDULENT.include?(response[:return_code])
        options[:cvv_result] = HSBC_CVV_RESPONSE_MAPPINGS[response[:cvv2_resp]] unless response[:cvv2_resp].blank?
        options[:avs_result] = avs_code_from(response)
        options
      end

      def success_from(action, response)
        response[:return_code] == APPROVED &&
            !response[:transaction_id].nil? &&
            !response[:auth_code].nil? &&
            response[:transaction_status] == case action
                                               when 'authorize', 'purchase', 'capture'
                                                 TRANSACTION_STATUS_MAPPINGS[:accepted]
                                               when 'void'
                                                 TRANSACTION_STATUS_MAPPINGS[:void]
                                               else
                                                 nil
                                             end
      end

      def message_from(response)
        response[:return_message] || response[:error_message]
      end

      def avs_code_from(response)
        return {:code => 'U'} if response[:avs_display].blank?
        {
            :code => case response[:avs_display]
                       when "YY"
                         "Y"
                       when "YN"
                         "A"
                       when "NY"
                         "W"
                       when "NN"
                         "C"
                       when "FF"
                         "G"
                       else
                         "R"
                     end
        }
      end

    end
  end
end

