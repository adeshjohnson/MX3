module Paypal
  # Parser and handler for incoming Instant payment notifications from paypal.
  # The Example shows a typical handler in a rails application.
  #
  # Example
  #
  #   class BackendController < ApplicationController
  #
  #     def paypal_ipn
  #       notify = PaypalNotification.new(request.raw_post)
  #
  #       order = Ogrder.find(notify.item_id)
  #
  #       if notify.acknowledge
  #         begin
  #
  #           if notify.complete? and order.total == notify.amount
  #             order.status = 'success'
  #
  #             shop.ship(order)
  #           else
  #             logger.error("Failed to verify Paypal's notification, please investigate")
  #           end
  #
  #         rescue => e
  #           order.status        = 'failed'
  #           raise
  #         ensure
  #           order.save
  #         end
  #       end
  #
  #       render :nothing
  #     end
  #   end

  class ConnectionError < StandardError # :nodoc:
  end

  class RetriableConnectionError < StandardError # :nodoc:
  end

  class ResponseError < StandardError # :nodoc:
    attr_reader :response

    def initialize(response, message = nil)
      @response = response
      @message  = message
    end

    def to_s
      "Failed with #{response.code} #{response.message if response.respond_to?(:message)}"
    end
  end

  class Notification


    attr_accessor :params
    attr_accessor :raw

    # Overwrite this url. It points to the Paypal sandbox by default.
    # Please note that the Paypal technical overview (doc directory)
    # speaks of a https:// address for production use. In my tests
    # this https address does not in fact work.
    #
    # Example:
    #   Paypal::Notification.ipn_url = http://www.paypal.com/cgi-bin/webscr
    #
    cattr_accessor :ipn_url
    cattr_accessor :test_ipn_url
    @@test_ipn_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr'
    @@ipn_url = 'https://www.paypal.com/cgi-bin/webscr'
    MAX_RETRIES = 3

    # Creates a new paypal object. Pass the raw html you got from paypal in.
    # In a rails application this looks something like this
    #
    #   def paypal_ipn
    #     paypal = Paypal::Notification.new(request.raw_post)
    #     ...
    #   end
    def initialize(post)
      empty!
      parse(post)
    end

    # Was the transaction complete?
    def complete?
      status == "Completed"# or status == "Canceled_Reversal"
    end

    # Was the transaction reversed?
    def reversed?
      status == "Reversed"
    end

    # When was this payment received by the client.
    # sometimes it can happen that we get the notification much later.
    # One possible scenario is that our web application was down. In this case paypal tries several
    # times an hour to inform us about the notification
    def received_at
      Time.parse params['payment_date']
    end

    # Whats the status of this transaction?
    def status
      params['payment_status']
    end

    # Id of this transaction (paypal number)
    def transaction_id
      params['txn_id']
    end

    # What type of transaction are we dealing with?
    #  "cart" "send_money" "web_accept" are possible here.
    def type
      params['txn_type']
    end

    # the money amount we received in X.2 decimal.
    def gross
      params['mc_gross']
    end

    # the markup paypal charges for the transaction
    def fee
      params['mc_fee']
    end

    # What currency have we been dealing with
    def currency
      params['mc_currency']
    end

    # This is the item number which we submitted to paypal
    def item_id
      params['item_number']
    end

    # This is the invocie which you passed to paypal
    def invoice
      params['invoice']
    end

    # This is the custom field which you passed to paypal
    def invoice
      params['invoice']
    end

    # ---------------- my custom changes -------------------

    def first_name
      params['first_name']
    end

    def last_name
      params['last_name']
    end

    def payer_email
      params['payer_email']
    end

    def residence_country
      params['residence_country']
    end

    def payer_status
      params['payer_status']
    end

    def receiver_email
      params['receiver_email']
    end

    def tax
      params['tax']
    end

    def custom
      params['custom']
    end

    def pending_reason
      params['pending_reason']
    end

    def business
      params['business']
    end
    #-------------------------------------------------------

    # This combines the gross and currency and returns a proper Money object.
    # this requires the money library located at http://dist.leetsoft.com/api/money
    def amount
      amount = gross.sub(/[^\d]/, '').to_i
      Money.new(amount, currency)
    end

    # reset the notification.
    def empty!
      @params  = Hash.new
      @raw     = ""
    end

    def my_debug(msg)
      File.open("/tmp/mor_debug.txt", "a") { |f|
        f << msg.to_s
        f << "\n"
      }
    end


    # Acknowledge the transaction to paypal. This method has to be called after a new
    # ipn arrives. Paypal will verify that all the information we received are correct and will return a
    # ok or a fail.
    #
    # Example:
    #
    #   def paypal_ipn
    #     notify = PaypalNotification.new(request.raw_post)
    #
    #     if notify.acknowledge
    #       ... process order ... if notify.complete?
    #     else
    #       ... log possible hacking attempt ...
    #     end
    def acknowledge(url = self.class.ipn_url)
      uri = URI.parse(url)
      retry_exceptions do
        begin
          my_debug(Time.now.to_s(:db) + '  ---  Try send IPN to Paypal')
          status = nil
          request = Net::HTTP.new(uri.host, uri.port)
          request.use_ssl = true
          request.verify_mode = OpenSSL::SSL::VERIFY_NONE
          status = request.post(uri.path, @raw.to_s + "&cmd=_notify-validate").body
          status == "VERIFIED"
        rescue SocketError => e
          my_debug e.to_yaml
          raise RetriableConnectionError, "Can not connect to remote server"
        rescue EOFError => e
          my_debug e.to_yaml
          raise ConnectionError, "The remote server dropped the connection"
        rescue Errno::ECONNRESET => e
          my_debug e.to_yaml
          raise ConnectionError, "The remote server reset the connection"
        rescue Errno::ECONNREFUSED => e
          my_debug e.to_yaml
          raise RetriableConnectionError, "The remote server refused the connection"
        rescue Timeout::Error, Errno::ETIMEDOUT => e
          my_debug e.to_yaml
          raise ConnectionError, "The connection to the remote server timed out"
        end
      end
    end

      private

      # Take the posted data and move the relevant data into a hash
      def parse(post)

#	my_debug(post)

        @raw = post
        for line in post.to_s.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          params[key] = CGI.unescape(value)
        end
      end

      def retry_exceptions
        retries = MAX_RETRIES
        begin
          yield
        rescue Paypal::RetriableConnectionError => e
          retries -= 1
          sleep(rand(10))
          retry unless retries.zero?
          raise ConnectionError, e.message
        rescue Paypal::ConnectionError
          retries -= 1
          sleep(rand(10))
          retry if !retries.zero?
          raise
        end
      end

    end
  end
