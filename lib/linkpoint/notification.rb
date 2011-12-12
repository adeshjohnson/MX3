module Linkpoint

  class Notification
    attr_accessor :params
    attr_accessor :raw

    cattr_accessor :ipn_url
    #production environment
    @@ipn_url = "https://www.linkpointcentral.com/lpc/servlet/lppay"
    #test environment
    @@ipn_test_url = "https://www.staging.yourpay.com/lpc/servlet/lppay"

    def initialize(post)
      my_debug("init notification")
      empty!
      parse(post)
      my_debug("post parsed")
    end

    def Notification.get_ipn_url(test = 0)
      if test == 1
        return @@ipn_test_url
      else
        return @@ipn_url
      end
    end

    # Was the transaction complete?
    def complete?
      status == "APPROVED"
    end

    def received_at
      Time.parse params['ttime']
    end

    # Whats the status of this transaction?
    def status
      params['status']
    end

    # Id of this transaction (paypal number)
    def transaction_id
      params['oid']
    end

    # What type of transaction are we dealing with?
    #  "cart" "send_money" "web_accept" are possible here.
    def type
      params['txnorg']
    end

    # the money amount we received in X.2 decimal.
    def gross
      params['subtotal']
    end

    # What currency have we been dealing with
    def currency
      params['currency']
    end

     def approval_code
      params['approval_code']
    end

    def email
      params['merchantemail']
    end

    def country
      params['scountry']
    end
#
#    def tax
#      params['tax']
#    end
#
    def custom
      params['custom']
    end
#
    def pending_reason
      params['failReason']
    end
    #-------------------------------------------------------

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


    def acknowledge
      my_debug("init acknowledge")
      uri = URI.parse(self.class.ipn_url)
      status = nil

	  if @request.request_uri.host == uri.host
		 my_debug("acknowledge passed")
		true
		else
		  my_debug("acknowledge not passed")
		  false
		end
      #Net::HTTP.start(uri.host, uri.port) do |request|
      #  status = request.post(uri.path, raw + "&cmd=_notify-validate").body
      #end

     # status == "APPROVED"

    end

    private

    # Take the posted data and move the relevant data into a hash
    def parse(post)

    my_debug(post)

      @raw = post
      for line in post.split('&')


        if line.include? "status" or line.include? "ttime" or line.include? "oid" or line.include? "txnorg" or line.include? "chargetotal" or line.include? "currency" or line.include? "failReason" or line.include? "custom"
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          params[key] = CGI.unescape(value)
        end

        my_debug(key+" "+params[key])
      end
     my_debug("parse successful")
    end

  end
end