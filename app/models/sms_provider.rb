class SmsProvider < ActiveRecord::Base
  belongs_to :sms_tariff


  def test_login
    out = ""
    begin
      log = self.connect_to_clickatell
      logger.fatal(log.inspect)
      if log[0].to_s == 'ERR:'
        out = "<img title='Error' src='#{Web_Dir}/images/icons/cross.png' alt='Error' id='test_err_#{self.id}'/>"
      else
        out = "<img title='Ok' src='#{Web_Dir}/images/icons/check.png' alt='Ok' id='test_ok_#{self.id}'/>"
      end
    rescue Exception => e
      MorLog.log_exception(e, Time.now.to_i, 'sms', 'providers')
      out = "<img title='Error' src='#{Web_Dir}/images/icons/cross.png' alt='Error' id='test_err_#{self.id}'/>"
    end
    return out
  end


  def send_sms_clickatell(sms, options={})
    log = self.connect_to_clickatell
    if log[0].to_s == 'ERR:'
      if log[1].gsub(/,/, '').to_i <= 7
        sms.status_code = "0" + log[1].gsub(/,/, '')
      else
        sms.status_code = log[1].gsub(/,/, '')
      end
      sms.user_rate = 0
      sms.user_price = 0
      sms.reseller_rate = 0
      sms.reseller_price = 0
      sms.provider_rate = 0
      sms.provider_price = 0
    else
      string = ""
      string += "&from=#{self.sms_from}" if !self.sms_from.blank?
      if options[:unicode].to_i != 0
        string += "&unicode=1"
        mtext = CGI.escape(options[:message].to_s.strip.unpack("U*").collect {|s| ( "0"*3+ s.to_i.to_s(16))[-4..-1] }.join(""))
      else
        mtext= CGI.escape(options[:message].to_s.strip)
      end
      message_id = Net::HTTP.get_response("api.clickatell.com", "/http/sendmsg?api_id=#{self.api_id.to_s.strip}&password=#{self.password.to_s.strip}&user=#{self.login.to_s.strip}&to=#{options[:to].to_s.strip}&callback=3&concat=#{options[:sms_numbers].to_s}&text=#{mtext}#{string}")
      code = message_id.body.split(" ")
      if code[0].to_s == 'ERR:'
        if code[1].gsub(/,/, '').to_i <= 7
          sms.status_code = "0" + code[1].gsub(/,/, '').to_s
        else
          sms.status_code = code[1].gsub(/,/, '').to_s
        end
      else
        sms.clickatell_message_id = code[1].to_s
      end
    end
    sms.save
    #MorLog.my_debug "http://api.clickatell.com/http/sendmsg?api_id=#{self.api_id.to_s.strip}&password=#{self.password.to_s.strip}&user=#{self.login.to_s.strip}&to=#{options[:to].to_s.strip}&callback=3&concat=#{options[:sms_numbers].to_s.to_s}&text=#{mtext}#{string}"
    #return sms.sms_status_code_tip
  end


  def send_sms_email(sms, user, options={})
    email = Email.find(:first, :conditions => ["name = 'sms'"])
    unless email
      email = Email.new({:name=>"sms", :template=>1, :format=>"html", :owner_id=>0, :body=>"", :subject=>"", :date_created=>Time.now().to_s(:db)})
      email.save
    end
    opt = options.merge({:email_to_address=>options[:to].strip + self.sms_provider_domain.strip, :sms_id=>sms.id, :email_from_user=>user, :owner=>user.owner_id})
    to = []
    to << user
    Email.send_email(email, to, Confline.get_value("Email_from"), "sms_email_sent", opt)
    if self.wait_for_good_email.to_i != 1 and self.wait_for_bad_email.to_i != 1
      user.frozen_balance = user.frozen_balance.to_f - Email.nice_number(options[:user_price].to_f).to_f
      user.save
      if options[:reseller] == 1
        user_r = sms.reseller
        user_r.frozen_balance = user_r.frozen_balance.to_f - Email.nice_number(options[:reseller_price].to_f).to_f
        user_r.save
      end
    end
    sms.status_code = 0
    sms.save
    #return sms.sms_status_code_tip
  end


  def connect_to_clickatell
    begin    
      login = Net::HTTP.get_response("api.clickatell.com", "/http/auth?api_id=#{api_id}&password=#{password}&user=#{login}")      
      log = login.body.split(" ")
    rescue Exception => e
      MorLog.log_exception(e, Time.now.to_i, 'sms', 'providers')
      log = []
      log[0] = 'ERR:' 
    end   
    log
  end
end