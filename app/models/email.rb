# -*- encoding : utf-8 -*-
class Email < ActiveRecord::Base

  require 'net/smtp'
  require 'enumerator'
  require 'smtp_tls'
  require 'net/pop'
  #require 'tmail'

  ALLOWED_VARIABLES = ["server_ip", "device_type", "device_username", "device_password", "login_url", "login_username", "username", "first_name",
                       "last_name", "full_name", "balance", "nice_balance", "warning_email_balance", "nice_warning_email_balance",
                       "currency", "user_email", "company_email", "email", "company", "primary_device_pin", "login_password", "user_ip",
                       "amount", "date", "auth_code", "transaction_id", "customer_name", "description", "company_name", "url", "trans_id", "email",
                       "cc_purchase_details", "monitoring_amount", "monitoring_block", "monitoring_users", "monitoring_type", "payment_amount", "payment_payer_first_name",
                       "payment_payer_last_name", "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
                       "payment_currency", "payment_type", "payment_fee", "call_list", "user_id", "device_id", "caller_id", "calldate", "source", "destination", "billsec"
  ]

  def destroy_everything

    #rate details
    for rd in self.ratedetails
      rd.destroy
    end

    #advanced rate details
    for ard in self.aratedetails
      ard.destroy
    end

    self.destroy
  end

  validate do |email|
    email.must_have_valid_variables
  end

  def Email.address_validation(addres)
    out = false
    if addres.match(/^[a-zA-Z0-9_\+-]+(\.[a-zA-Z0-9_\+-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.([a-zA-Z]{2,6})$/)
      out = true
    end
    out
  end

  # PAY ATTENTION
  # variable names should differ because if you name variable 'a' all other variables will be replace by its content!! ! !
  def Email.email_variables(user, device = nil, variables = {}, options = {})
    nnd = options[:nice_number_digits].to_i if options[:nice_number_digits]
    nnd = Confline.get_value("Nice_Number_Digits") if !nnd
    nnd = 2 if !nnd or nnd == ""
    user = User.find(:first, :include => [:devices, :address], :conditions => ["users.id = ?", user.to_i]) if user.class != User
    device = user.primary_device if !device
    currency = Currency.find(1)
    user.usertype == "reseller" ? owner_id = user.id : owner_id = user.owner_id
    company_email = Confline.get_value("Company_Email", owner_id)
    opts = {
        :owner => user.owner_id.to_s,
        :server_ip => Confline.get_value("Asterisk_Server_IP").to_s,
        :device_type => "",
        :device_username => "",
        :device_password => "",
        :primary_device_pin => "",
        :login_url => Web_URL.to_s + Web_Dir.to_s,
        :login_username => user.username.to_s,
        :username => user.username.to_s,
        :login_password => "*****",
        :user_ip => "",
        :amount => "",
        :date => "",
        :auth_code => "",
        :transaction_id => "",
        :customer_name => "",
        :description => "",
        :first_name => user.first_name.to_s,
        :last_name => user.last_name.to_s,
        :full_name => user.first_name.to_s + " " + user.last_name.to_s,
        :balance => user.balance.to_s,
        :nice_balance => User.current ? Email.nice_number(user.balance * Currency.count_exchange_rate(User.current.currency.name, user.currency.name), {:nice_number_digits => nnd, :global_decimal => options[:global_decimal], :change_decimal => options[:change_decimal]}).to_s : user.currency.name,
        :warning_email_balance => user.warning_email_balance.to_s,
        :nice_warning_email_balance => Email.nice_number(user.warning_email_balance.to_s, {:nice_number_digits => nnd, :global_decimal => options[:global_decimal], :change_decimal => options[:change_decimal]}),
        :currency => user.currency.name,
        :user_email => options[:user_email_card] ? options[:user_email_card] : user.address.email,
        :cc_purchase_details => "",
        :company_email => company_email,
        :email => company_email,
        :company => Confline.get_value("Company", owner_id),
        :monitoring_amount => "",
        :monitoring_block => "",
        :monitoring_users => "",
        :monitoring_type => "",
        :payment_amount => "",
        :payment_payer_first_name => "",
        :payment_payer_last_name => "",
        :payment_payer_email => "",
        :payment_seller_email => "",
        :payment_receiver_email => "",
        :payment_date => "",
        :payment_fee => "",
        :payment_currency => "",
        :payment_type => "",
        :user_id => "",
        :device_id => "",
        :caller_id => "" ,
        :calldate=>"",
        :source=>"",
        :destination=>"",
        :billsec=>""
    }
    if device
      opts = opts.merge({
                            :device_type => device.device_type.to_s,
                            :device_username => device.username.to_s,
                            :device_password => device.secret.to_s,
                            :primary_device_pin => device.pin.to_s
                        })
    end
    if variables[:monitoring] && variables[:monitoring_users_list] && variables[:monitoring_type]
      opts = opts.merge({
                            :monitoring_amount => variables[:monitoring].amount,
                            :monitoring_block => variables[:monitoring].block,
                            :monitoring_type => variables[:monitoring_type],
                            :monitoring_users => variables[:monitoring_users_list].collect { |u| [u.id, u.username, u.balance].join(" ") }.join("\n").strip
                        })
    end
    if variables[:payment] && variables[:payment_notification] && variables[:payment_type]
      opts = opts.merge({
                            :payment_amount => variables[:payment].amount,
                            :payment_payer_first_name => variables[:payment].first_name,
                            :payment_payer_last_name => variables[:payment].last_name,
                            :payment_payer_email => variables[:payment].payer_email,
                            :payment_seller_email => variables[:payment].user.owner.email,
                            :payment_receiver_email => (variables[:payment_notification].respond_to?(:account)) ? variables[:payment_notification].account : variables[:payment_notification].receiver_email,
                            :payment_date => variables[:payment].date_added,
                            :payment_fee => variables[:payment].fee,
                            :payment_currency => variables[:payment].currency,
                            :payment_type => variables[:payment_type]
                        })
    end
    opts = opts.merge(variables)
    return opts
  end

  def Email.map_variables_for_api(params)
    opts = {}
    ALLOWED_VARIABLES.each{ |var|
      opts[var.to_sym] = params[var.to_sym].to_s
    }
    return opts
  end

  def Email.nice_number(number, options = {})
    n = "0.00"
    if options[:nice_number_digits].to_i > 0
      n = sprintf("%0.#{options[:nice_number_digits]}f", number.to_d) if number
    else
      nn ||= Confline.get_value("Nice_Number_Digits").to_i
      nn = 2 if nn == 0
      n = sprintf("%0.#{nn}f", number.to_d) if number
    end
    if options[:change_decimal]
      n = n.gsub('.', options[:global_decimal])
    end
    n
  end

  def Email.send_email(email, email_to, email_from, action, options = {})

    User.exists_resellers_confline_settings(options[:owner].to_i) if options[:owner].to_i != 0

    sending_batch_size = Confline.get_value("Email_Batch_Size", options[:owner].to_i).to_i
    sending_batch_size = 50 if sending_batch_size.to_i == 0
    smtp_server = Confline.get_value("Email_Smtp_Server", options[:owner].to_i)
    #set default
    #if (domain = Confline.get_value("Email_Domain",options[:owner].to_i).to_s).blank?
    #Confline.set_value("Email_Domain", "localhost.localdomain",options[:owner].to_i)
    domain = "localhost.localdomain"
    #end
    login = Confline.get_value("Email_Login", options[:owner].to_i)
    psw = Confline.get_value("Email_Password", options[:owner].to_i)
    port = Confline.get_value("Email_port", options[:owner].to_i)
    mail = ""

    login_type = :login
    if login.to_s.length == 0 or psw.to_s.length == 0
      login = nil
      psw = nil
      login_type = nil
    end

    string = []
    options[:from] = email_from
    email_to.each_slice(sending_batch_size) { |users_slice|
      begin
        Net::SMTP.start(smtp_server, port, domain, login, psw, login_type) do |sender|
          users_slice.each do |user|
            options[:email_to_address] = user.email if  action != 'sms_email_sent'
            if !options[:email_to_address].blank?
              tmail = UserMailer.create_umail(user, action, email, options) #UserMailer.create_sent_sms(options[:email_to_address], options[:to], Confline.get_value("Email_from"), email, {:body=> options[:message]})
              mail += tmail.encoded
              #sender.sendmail tmail.encoded, tmail.from, options[:email_to_address]
                                                                            #              action = Action.new({:user_id=>email_from.id, :date=>Time.now, :action=>action, :target_type=>"Sms", :target_id=>options[:sms_id],  :data=>options[:email_to_address]})
              status = Action.create_email_sending_action(user, action, email, options)
            else
              #If thare are a lot of empty emails there is a rist to generate to much
              #actions and performance might suffer from that. didn't want to change
              #Action.create_email.. who knows what i might break, so status handling
              #was copy-pasted from that method. ticket #5037
              #options[:er_type] = 1
              #status =  Action.create_email_sending_action(user, action, email, options)
              status = _('Emeil_is_empty')
              status += " " + user.first_name + " " + user.last_name if user.class.to_s == 'User'
            end
            string << status
          end
        end
      end
    }
    return string
  end

  def must_have_valid_variables
    body.scan(/<%=?(\s*\S+\s*)%>|<%[^=]?[0-9a-zA-Z +=]*%>/).flatten.each do |var|
      unless !var.blank? and ALLOWED_VARIABLES.include?(var.strip)
        errors.add(:body, "invalid variable") # it is not translated because we do not print errors in the form!
        return false
      end
    end
  end

end
