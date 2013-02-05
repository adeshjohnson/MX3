# -*- encoding : utf-8 -*-
class SmsMessage < ActiveRecord::Base
  belongs_to :reseller, :class_name => 'User', :foreign_key => 'reseller_id'
  belongs_to :user

  def destination
    Destination.find(:first, :conditions => "prefix = '#{self.prefix}'")
  end

  def sms_status_code
    case self.status_code.to_s
      when "0"
        out = "sent"
      when "1"
        out = "failed"
      when "2"
        out = "failed"
      when "3"
        out = "failed"
      when "4"
        out = "failed"
      when "5"
        out = "failed"
      when "001"
        out = "Message unknown"
      when "002"
        out = "Message queued"
      when "003"
        out = "Delivered to gateway"
      when "004"
        out = "Received by recipient"
      when "005"
        out = "Error with message"
      when "006"
        out = "User cancelled message delivery"
      when "007"
        out = "Error delivering message"
      when "008"
        out = "OK"
      when "009"
        out = "Routing error"
      when "010"
        out = "Message expired"
      when "011"
        out = "Message queued for later delivery"
      when "012"
        out = "Out of credit"
      when "0001"
        out = "Authentication failed"
      when "0002"
        out = "Unknown username or password"
      when "0003"
        out = "Session ID expired"
      when "0004"
        out = "Account frozen"
      when "0005"
        out = "Missing session ID"
      when "0007"
        out = "IP Lockdown violation"
      when "101"
        out = "Invalid or missing parameters"
      when "102"
        out = "Invalid user data header"
      when "103"
        out = "Unknown API message ID"
      when "104"
        out = "Unknown client message ID"
      when "105"
        out = "Invalid destination address"
      when "106"
        out = "Invalid source address"
      when "107"
        out = "Empty message"
      when "108"
        out = "Invalid or missing API ID"
      when "109"
        out = "Missing message ID"
      when "110"
        out = "Error with email message"
      when "111"
        out = "Invalid protocol"
      when "112"
        out = "Invalid message type"
      when "113"
        out = "Maximum message parts exceeded"
      when "114"
        out = "Cannot route message"
      when "115"
        out = "Message expired"
      when "116"
        out = "Invalid Unicode data"
      when "120"
        out = "Invalid delivery time"
      when "121"
        out = "Destination mobile number blocked"
      when "122"
        out = "Destination mobile opted out"
      when "123"
        out = "Invalid Sender ID"
      when "201"
        out = "Invalid batch ID"
      when "202"
        out = "No batch template"
      when "301"
        out = "No credit left"
      when "302"
        out = "Max allowed credit"
      when "6"
        out = "failed"
    end
    out
  end

  def sms_status_code_tip
    case self.status_code.to_s
      when "0"
        out = "0 - sent, SMS is sent"
      when "1"
        out = "1 - failed, system owner does not have rate for this destination"
      when "2"
        out = "2 - failed, reseller does not have rate for this destination"
      when "3"
        out = "3 - failed, user does not have rate for this destination"
      when "4"
        out = "4 - failed, some error from provider"
      when "5"
        out = "5 - failed, insufficient balance"
      when "6"
        out = "6 - failed, api returns no good keywords"
      when "001"
        out = "001 - The message ID is incorrect or reporting isdelayed."
      when "002"
        out = "002 - The message could not be delivered and has been queued for attempted redelivery."
      when "003"
        out = "003 - Delivered to the upstream gateway or network(delivered to the recipient)."
      when "004"
        out = "004 - Confirmation of receipt on the handset of the recipient."
      when "005"
        out = "005 - There was an error with the message, probably caused by the content of the message itself."
      when "006"
        out = "006 - The message was terminated by an internal mechanism."
      when "007"
        out = "007 - An error occurred delivering the message to the handset."
      when "008"
        out = "008 - Message received by gateway."
      when "009"
        out = "009 - The routing gateway or network has had an error routing the message."
      when "010"
        out = "010 - Message has expired before we were able to deliver it to the upstream gateway. No charge applies."
      when "011"
        out = "011 - Message has been queued at the gateway for delivery at a later time (delayed delivery)."
      when "012"
        out = "012 - The message cannot be delivered due to a lack of funds in your account. Please re-purchase credits."
      when "0001"
        out = "0001 - Authentication failed"
      when "0002"
        out = "0002 - Unknown username or password"
      when "0003"
        out = "0003 - Session ID expired"
      when "0004"
        out = "0004 - Account frozen"
      when "0005"
        out = "0005 - Missing session ID"
      when "0007"
        out = "0007 - You have locked down the API instance to a specific IP address and then sent from an IP address different to the one you set."
      when "101"
        out = "101 - Invalid or missing parameters"
      when "102"
        out = "102 - Invalid user data header"
      when "103"
        out = "103 - Unknown API message ID"
      when "104"
        out = "104 - Unknown client message ID"
      when "105"
        out = "105 - Invalid destination address"
      when "106"
        out = "106 - Invalid source address"
      when "107"
        out = "107 - Empty message"
      when "108"
        out = "108 - Invalid or missing API ID"
      when "109"
        out = "109 - This can be either a client message ID or API message ID."
      when "110"
        out = "110 - Error with email message"
      when "111"
        out = "111 - Invalid protocol"
      when "112"
        out = "112 - Invalid message type"
      when "113"
        out = "113 - The text message component of the message is greater than the permitted 160 characters (70 Unicode characters)."
      when "114"
        out = "114 - This implies that the gateway is not currently routing messages to this network prefix. Please email support@clickatell.com with the mobile number in question."
      when "115"
        out = "115 - Message expired"
      when "116"
        out = "116 - Invalid Unicode data"
      when "120"
        out = "120 - Invalid delivery time"
      when "121"
        out = "121 - This number is not allowed to receive messages from us and has been put on our block list."
      when "122"
        out = "122 - Destination mobile opted out"
      when "123"
        out = "123 - A sender ID needs to be registered and validated before it can be successfully used in message sending."
      when "201"
        out = "201 - Invalid batch ID"
      when "202"
        out = "202 - No batch template"
      when "301"
        out = "301 - No credit left"
      when "302"
        out = "302 - Max allowed credit"
    end
    out
  end


  def sms_send(user, user_tariff, number, lcr, sms_numbers, message, options = {})
    sql="SELECT * FROM (
          SELECT sms_providers.id as 'providers_id', provider_type,  A.prefix as 'prefix', sms_rates.price, currencies.exchange_rate AS 'e_rate' FROM sms_providers
            JOIN (SELECT sms_lcrproviders.* FROM  sms_lcrproviders WHERE sms_lcrproviders.sms_lcr_id = '#{lcr.id}' and sms_lcrproviders.active = 1) AS p ON (p.sms_provider_id = sms_providers.id)
            JOIN sms_tariffs ON (sms_providers.sms_tariff_id = sms_tariffs.id)
            LEFT JOIN sms_rates ON (sms_rates.sms_tariff_id = sms_tariffs.id)
            JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{number}', 1, LENGTH(destinations.prefix)) ORDER BY LENGTH(destinations.prefix) DESC) as A ON (A.prefix = sms_rates.prefix)
            LEFT JOIN currencies ON (currencies.name = sms_tariffs.currency)
          ORDER BY LENGTH(A.prefix) DESC) AS B
        GROUP BY B.providers_id
        ORDER BY B.price / B.e_rate ASC "

    res = ActiveRecord::Base.connection.select_one(sql)

    self.user_rate = 0
    self.user_price = 0
    self.reseller_rate = 0
    self.reseller_price = 0
    self.provider_rate = 0
    self.provider_price = 0

    if not res or (res and (res["prefix"] == nil or res["prefix"] == ''))
      self.status_code = 1
      self.save
      return false
    end

    unless self.sms_set_rates_and_user(user, sms_numbers, user_tariff, number, res["provider_type"].to_s == 'api' ? 1 : 0)
      return false
    end


    self.prefix = res["prefix"]

    #============================= provider is ok ==============================
    prov_id = res["providers_id"]
    prov_rate = res["price"].to_d / res["e_rate"].to_d
    prov_type = res["provider_type"]
    self.provider_id = prov_id
    provider = SmsProvider.find_by_id(prov_id)
    self.provider_rate = prov_rate
    self.provider_price = Email.nice_number(prov_rate * sms_numbers.to_i)
    #===========================================================================

    if prov_type.to_s == 'clickatell'
      provider.send_sms_clickatell(self, {:message => message, :sms_numbers => sms_numbers, :to => number, :unicode => options[:sms_unicode].to_i})
    end
    if prov_type.to_s == 'sms_email'
      if user.owner_id == 0
        provider.send_sms_email(self, user, {:message => message, :sms_numbers => sms_numbers, :to => number, :user_price => self.user_price.to_d, :unicode => options[:sms_unicode].to_i})
      else
        provider.send_sms_email(self, user, {:message => message, :sms_numbers => sms_numbers, :to => number, :user_price => self.user_price.to_d, :reseller => 1, :reseller_price => self.reseller_price.to_d, :unicode => options[:sms_unicode].to_i})
      end
    end
    if prov_type.to_s == 'api'
      if options[:src]
        provider.send_sms_api(self, user, {:message => message, :sms_numbers => sms_numbers, :to => number, :unicode => options[:sms_unicode].to_i, :src => options[:src]})
      else
        provider.send_sms_api(self, user, {:message => message, :sms_numbers => sms_numbers, :to => number, :unicode => options[:sms_unicode].to_i})
      end
    end

    self.save
  end


  def sms_set_rates_and_user(user, sms_numbers, user_tariff, number, api = 0)

    if user.owner_id != 0
      reseller = User.find(:first, :conditions => ["id = ? ", user.owner_id])
      reseller_tariff = reseller.sms_tariff

      unless reseller_tariff
        self.status_code = 2
        self.save
        return false
      end

      reseller_rate = SmsMessage.sms_rate(reseller_tariff.id, number)

      unless  reseller_rate
        self.status_code = 2
        self.save
        return false
      end

      r_price = (reseller_rate.price.to_d / Currency.find(:first, :conditions => ["name='#{reseller_tariff.currency}'"]).exchange_rate.to_d).to_d
      unless check_user_for_sms(reseller, (r_price * sms_numbers).to_d)
        self.status_code = 5
        self.save
        return false
      end
    end


    unless user_tariff or (user.owner_id != 0 and reseller_rate)
      self.status_code = 2
      self.save
      return false
    end

    user_rate = SmsMessage.sms_rate(user_tariff.id, number)

    unless user_rate
      self.status_code = 3
      self.save
      return false
    end

    price = (user_rate.price.to_d / Currency.find(:first, :conditions => ["name='#{user_tariff.currency}'"]).exchange_rate.to_d).to_d

    unless check_user_for_sms(user, (price * sms_numbers.to_d).to_d)
      self.status_code = 5
      self.save
      return false
    end

    self.user_rate = Email.nice_number(price)
    self.user_price = Email.nice_number(price * sms_numbers).to_d
    freze_user_balance_for_sms(user, self.user_price) if api == 0
    if user.owner_id != 0
      self.reseller_id = reseller.id
      self.reseller_rate = Email.nice_number(r_price)
      self.reseller_price = Email.nice_number(r_price * sms_numbers).to_d
      freze_user_balance_for_sms(reseller, self.reseller_price) if api == 0
    end

    self.save

    return true
  end


  def check_user_for_sms(user, sms_price)
    out = true
    if user.postpaid.to_i == 0
      bal = user.balance.to_d - sms_price.to_d
      if bal.to_d < 0.to_d
        out = false
      end
    else
      bal = user.balance.to_d - sms_price.to_d
      if user.credit.to_i > -1
        if bal.to_d < (-1 * user.credit.to_d)
          out = false
        end
      end
    end
    return out
  end

  def freze_user_balance_for_sms(user, sms_price)
    #  logger.info "freze_user_balance: #{user.id}"
    #  logger.info "before balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
    user.balance = user.balance.to_d - sms_price.to_d
    user.frozen_balance = user.frozen_balance.to_d + sms_price.to_d
    user.save
    #   logger.info "after balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
  end


  def SmsMessage.sms_rate(tariff_id, number)

    sql = "SELECT sms_rates.* FROM sms_rates  JOIN
          ( SELECT prefix FROM destinations WHERE prefix =  SUBSTRING('#{number}', 1, LENGTH(destinations.prefix))  ORDER BY LENGTH(destinations.prefix) DESC) AS A ON (A.prefix = sms_rates.prefix)
           WHERE sms_tariff_id = #{tariff_id}
           ORDER BY LENGTH(sms_rates.prefix) DESC
            LIMIT 1;"

    rate = SmsRate.find_by_sql(sql)
    rate[0]
  end


  def charge_user
    user = self.user
    # logger.info "charge_user: #{user.id}"
    # logger.info "before balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
    user.frozen_balance = user.frozen_balance.to_d - self.user_price.to_d
    owner = user.owner
    if owner.id != 0
      owner.frozen_balance = owner.frozen_balance.to_d - self.reseller_price.to_d
      owner.save
    end
    user.save
    # logger.info "after balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
  end


  def return_sms_price_to_user
    user = self.user
    # logger.info "return_user: #{user.id}"
    # logger.info "before balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
    user.frozen_balance = user.frozen_balance.to_d - self.user_price.to_d
    user.balance = user.balance.to_d + self.user_price.to_d
    owner = user.owner
    if owner.id != 0
      owner.frozen_balance = owner.frozen_balance.to_d - self.reseller_price.to_d
      owner.balance = owner.balance.to_d + self.reseller_price.to_d
      owner.save
    end
    user.save
    # logger.info "after balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
  end

  # converted attributes for user in current user currency
  def user_price
    b = read_attribute(:user_price)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def user_rate
    b = read_attribute(:user_rate)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  # converted attributes for user in current user currency
  def reseller_price
    b = read_attribute(:reseller_price)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  # converted attributes for user in current user currency
  def provider_price
    b = read_attribute(:reseller_price)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

end
