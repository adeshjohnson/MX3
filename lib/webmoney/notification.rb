# -*- encoding : utf-8 -*-
# Original Module for Paypal
# Rewritten for Webmoney by Uknown
# Changed by A.Mazunin 08.05.2008
# Some variables are useless. 
module WebMoney

  class Notification
    attr_accessor :params
    attr_accessor :raw

    # URLs for Merchant Store. If in Russian - webmoney.ru. If in English wmtransfer.com
    #default
    @@ipn_url_en = 'https://merchant.wmtransfer.com/lmi/payment.asp'
    @@ipn_url_ru = 'https://merchant.webmoney.ru/lmi/payment.asp'

    def Notification.ipn_url(gw = 0)
      gw.to_i == 0 ? @@ipn_url_ru : @@ipn_url_en
    end

    def initialize(post)
      empty!
      parse(post)
    end

    # Was the transaction complete?
    def complete?
      status == "Completed"
    end

    # When was this payment received by the client. 
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

    def tax
      params['tax']
    end

    def custom
      params['custom']
    end

    def pending_reason
      params['pending_reason']
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
      @params = Hash.new
      @raw = ""
    end

    def my_debug(msg)
      File.open("/tmp/mor_debug.txt", "a") { |f|
        f << msg.to_s
        f << "\n"
      }
    end


    # Acknowledge the transaction. Originally for Paypal. Webmoney does not required aknowledgement

    def acknowledge
      uri = URI.parse(self.class.ipn_url)
      status = nil
      Net::HTTP.start(uri.host, uri.port) do |request|
        status = request.post(uri.path, raw + "&cmd=_notify-validate").body
      end
      status == "VERIFIED"
    end

    private

    # Take the posted data and move the relevant data into a hash
    def parse(post)

      @raw = post
      for line in post.split('&')
        key, value = *line.scan(%r{^(\w+)\=(.*)$}).flatten
        params[key] = CGI.unescape(value)
      end
    end

  end
end
