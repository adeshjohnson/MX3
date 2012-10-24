# -*- encoding : utf-8 -*-
class EmailsController < ApplicationController
  require 'net/smtp'
  require 'enumerator'
  require 'smtp_tls'
  require 'net/pop'
  #require 'tmail'
  #require 'pop_ssl'
  BASE_DIR = "/tmp/attachements"
  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize, :except => [:email_callback]
  before_filter :find_email, :only => [:edit, :update, :show_emails, :list_users, :destroy, :send_emails, :send_emails_from_cc]
  before_filter :find_session_user, :only => [:edit, :update, :show_emails, :destroy]

  def index
    redirect_to :action => :list and return false
  end

  def new
    @page_title = _('New_email')
    @page_icon = "add.png"
    @help_link = 'http://wiki.kolmisoft.com/index.php/Email_variables'
    @email = Email.new
    #   @user = User.find(session[:user_id])
  end

  def create
    @page_title = _('New_email')
    @page_icon = "add.png"

    @email = Email.new(params[:email])
    @email.date_created = Time.now
    @email.callcenter = session[:user_cc_agent]
    @email.owner_id = session[:user_id]
    if @email.save
      flash[:status] = _('Email_was_successfully_created')
      if session[:user_cc_agent].to_i != 1
        redirect_to :action => 'list'
      else
        redirect_to :action => 'emeils_callcenter'
      end
    else
      flash[:notice] = _('Email_was_not_created')
      render :action => 'new'
    end
  end

=begin
 In before filter : @email, @user
=end

  def edit
    @help_link = 'http://wiki.kolmisoft.com/index.php/Email_variables'
    @page_title = _('Edit_email')+": " + @email.name
    @page_icon = "edit.png"
  end

=begin
 In before filter : @email, @user
=end

  def update
    @user = User.find_by_id(session[:user_id])
    unless @user
      flash[:notice] = _('User_was_not_found')
      render :controller => "callc", :action => 'main'
    end

    if @email.update_attributes(params[:email])
      @email.save
      flash[:status] = _('Email_was_successfully_updated')
      # redirect_to :action => 'list', :id => params[:id], :ccc=>@ccc
      if session[:user_cc_agent].to_i != 1
        redirect_to :action => 'list'
      else
        redirect_to :action => 'emeils_callcenter'
      end
    else
      flash[:notice] = _('Email_was_not_updated') + ": " + _("Wrong_email_variables") + " <a href='http://wiki.kolmisoft.com/index.php/Email_variables'>wiki</a>"
      render :action => 'edit', :id => params[:id], :ccc => @ccc
    end
  end

  def list
    @page_title = _('Emails')
    @page_icon = "email.png"

    @emails = Email.select('*').where(["owner_id= ? and (callcenter='0' or callcenter is null)", session[:user_id]]).joins("LEFT JOIN (SELECT data, data2, COUNT(*) as emails FROM actions WHERE action = 'email_sent' GROUP BY data2) as actions ON (emails.id = actions.data2)").all
    @email_sending_enabled = Confline.get_value("Email_Sending_Enabled", 0).to_i == 1
    if @emails.size.to_i == 0 and session[:usertype] == "reseller"
      user=User.find(session[:user_id])
      user.create_reseller_emails
      @emails = Email.find(:all,
                           :conditions => ["owner_id= ? and (callcenter='0' or callcenter is null)", session[:user_id]],
                           :joins => "LEFT JOIN (SELECT data, data2, COUNT(*) as emails FROM actions WHERE action = 'email_sent' GROUP BY data2) as actions ON (emails.id = actions.data2)")
    end
  end

  def emeils_callcenter
    @page_title = _('Emails')
    @page_icon = "email.png"
    if session[:usertype].to_s != "admin"
      @emails = Email.find(:all, :conditions => ["(owner_id= ? or owner_id='0') and callcenter='1'", session[:user_id]])
    else
      @emails = Email.find(:all, :conditions => "callcenter='1'")
    end
    @email_sending_enabled = Confline.get_value("Email_Sending_Enabled", 0).to_i == 1
  end

=begin
 In before filter : @email, @user
=end

  def show_emails
    @page_title = _('show_emails')+": " + @email.name
    @page_icon = "email.png"
  end

=begin
 In before filter : @email
=end

  def list_users
    @page_title = _('Email_sent_to_users')+": " + @email.name
    @page_icon = "view.png"

    @page = 1
    @page = params[:page].to_i if params[:page] and params[:page].to_i > 0

    @total_pages = (Action.count(:conditions => ["data2 = ? AND action = 'email_sent'", params[:id]]).to_d / session[:items_per_page].to_d).ceil

    @actions = Action.find(:all,
                           :conditions => ["data2 = ? AND action = 'email_sent'", params[:id]],
                           :offset => (@page-1)*session[:items_per_page],
                           :limit => session[:items_per_page])
  end

=begin
 In before filter : @email
=end

  def destroy
    @email.destroy
    flash[:status] = _('Email_deleted')
    if session[:user_cc_agent].to_i != 1
      redirect_to :action => 'list'
    else
      redirect_to :action => 'emeils_callcenter'
    end
  end

=begin
 In before filter : @email
=end

  def send_emails
    @page_title = _('Send_email') + ": " + @email.name
    @page_icon = "email_go.png"

    default = {
        :shu => 'true',
        :sbu => 'true'
    }

    @options = (( !session[:emails_send_user_list_opt]) ? default : session[:emails_send_user_list_opt])

    default.each { |key, value| @options[key] = params[key] if params[key] }

    cond = []
    if @options[:shu].to_s == 'false'
      cond <<  'hidden = 0'
    end

    if @options[:sbu].to_s == 'false'
      cond <<  'blocked = 0'
    end

    @users = User.includes(:address).where(["owner_id = ? AND addresses.email != '' AND addresses.id > 0 AND addresses.email IS NOT NULL #{cond.size.to_i > 0 ? ' AND ' : ''} #{cond.join(' AND ' )}", session[:user_id]]).all

    session[:emails_send_user_list_opt] = @options
    @user_id_max = User.find_by_sql("SELECT MAX(id) AS result FROM users")
    # find selected users and send email to them
    @users_list = []
    to_email = params[:to_be_sent]
    if to_email
      to_email.each do |user_id, do_it|
        if do_it == "yes"
          user = User.find(user_id)
          @users_list << user
        end
      end

      #sent email to users
      send_all(@users_list, @email)
    end

    if @users_list.size > 0
      redirect_to :action => 'list'
    end
  end

  def users_for_send_email


    default = {
        :shu => 'true',
        :sbu => 'true'
    }

    @options = (( !session[:emails_send_user_list_opt]) ? default : session[:emails_send_user_list_opt])

    default.each { |key, value| @options[key] = params[key] if params[key] }

    cond = []
    if @options[:shu].to_s == 'false'
      cond <<  'hidden = 0'
    end

    if @options[:sbu].to_s == 'false'
      cond <<  'blocked = 0'
    end

    @users = User.includes(:address).where(["owner_id = ? AND addresses.email != '' AND addresses.id > 0 AND addresses.email IS NOT NULL #{cond.size.to_i > 0 ? ' AND ' : ''} #{cond.join(' AND ' )}", session[:user_id]]).all



    logger.fatal @users.size
    @user_id_max = User.find_by_sql("SELECT MAX(id) AS result FROM users")

    session[:emails_send_user_list_opt] = @options
    render :layout=>false
  end

=begin
 In before filter : @email
=end

  def send_emails_from_cc
    @page_title = _('Send_email') + ": " + @email.name.to_s
    @page_icon = "email_go.png"

    @search_agent= params[:agent]
    @agents = User.find(:all, :conditions => "call_center_agent=1")

    @clients = CcClient.whit_main_contact(@search_agent)


    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@clients.size.to_d / session[:items_per_page].to_d).ceil
    @all_clients = @clients
    @clients = []
    @a_number = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_clients.size - 1 if iend > (@all_clients.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @clients << @all_clients[i]
    end

    # find selected users and send email to them
    @clients_list = []
    # my_debug params[:to_be_sent].to_yaml
    to_email = params[:to_be_sent]
    if to_email
      to_email.each do |client_id, do_it|
        if do_it == "yes"
          client = CcClient.whit_email(client_id)
          @clients_list << client
        end
      end

      #sent email to users
      send_all(@clients_list, @email)
    end

    if @clients_list.size > 0
      redirect_to :action => 'emeils_callcenter'
    end
  end

  def send_all(users, email)
    e =[]
    status = Email.send_email(email, users, session[:usertype].to_s == "admin" ? Confline.get_value("Company_Email", 0) : Confline.get_value("Email_from", session[:user_id].to_i), 'send_all', {:owner => session[:user_id], })
    status.uniq.each { |i| e << _(i.capitalize) }
    flash[:notice] = e.join('<br>')
  end

  #send_all

  def EmailsController::send_test(id)
    user = User.find(id)
    email = Email.find(:first, :conditions => ["name = 'registration_confirmation_for_user' AND owner_id = ?", id])

    users = []
    users << user
    variables = Email.email_variables(user, nil, {:owner => id})
    send_email(email, Confline.get_value("Email_from", id), users, variables)

    # redirect_to :controller => "callc", :action => "main" and return false
  end

  def EmailsController::send_to_users_paypal_email(order)
    email = Email.find(:first, :conditions => "name = 'calling_cards_data_to_paypal' AND owner_id = #{0}")

    users = []
    users << order
    user_mail = order.email
    cards = order.cards

    admin = []
    adm = User.find(0)
    admin << adm

    admin_email = adm.email
    details = ActionView::Base.new(Rails::Configuration.new.view_path).render(:partial => 'emails/email_calling_cards_purchase', :locals => {:cards => cards})
    user = User.new({:usertype => 'user', :username => 'Card', :first_name => order.first_name, :last_name => order.last_name})
    varables = Email.email_variables(user, nil, {:cc_purchase_details => details}, {:user_email_card => order.email})
    EmailsController::send_email(email, admin_email, users, varables)
    MorLog.my_debug "_____________________________"
    MorLog.my_debug admin_email
    MorLog.my_debug user_mail
    MorLog.my_debug "_____________________________"
    EmailsController::send_email(email, user_mail, admin, {:cc_purchase_details => details})

  end

  def EmailsController::send_email(email, email_from, users, assigns = {})
    if Confline.get_value("Email_Sending_Enabled", 0).to_i == 1
      email_from.gsub!(' ', '_') #so nasty, but rails has a bug and doest send from_email if it has spaces in it
      status = Email.send_email(email, users, email_from, 'send_email', {:assigns => assigns, :owner => assigns[:owner]})
      status.uniq.each { |i| @e = _(i.capitalize) + '<br>' }
      return @e
    else
      return _('Email_disabled')
    end
  end


  def EmailsController::send_email_with_attachment(email, email_from, user, attachments, assigns = {})
    num = []
    status = Email.send_email(email, [user], email_from, 'send_email_with_attachment', {:assigns => assigns, :owner => user.owner_id.to_i, :attachments => attachments})
    status.uniq.each { |i| num[1] = _(i.capitalize) + '<br>'; num[0] = (i =~ /email[\s_]*sent/i) ? 1 : 0 }
    return num
  end

  def email_pop3_cronjob

    pop3_server = Confline.get_value("SMS_Email_pop3_Server")
    login = Confline.get_value("SMS_Email_Login")
    psw = Confline.get_value("SMS_Email_Password")

    sql = "SELECT sms_messages.*, sms_providers.*, sms_messages.id as 'sms_id' FROM sms_messages
         LEFT JOIN sms_providers on (sms_providers.id = sms_messages.provider_id)
         WHERE sms_providers.provider_type = 'sms_email' AND  sms_messages.status_code = '0'"
    res = ActiveRecord::Base.connection.select_all(sql)

    gres = []

    for r in res
      time = r['sending_date'].to_time
      min = ((Time.now - time).to_i / 60)
      @user = User.find(r['user_id'])
      @ruser = User.find(r['reseller_id'])
      if min.to_i < r['sms_email_wait_time'].to_i
        gres << r
      else
        if r['time_out_charge_user'].to_i == 1
          #       my_debug "nuskaiciau uz per ilga laika"
          @sms = SmsMessage.find(r['sms_id'])
          @user = User.find(r['user_id'])
          @ruser = User.find(r['reseller_id'])

          #       my_debug("userio_balansas : " + @user.frozen_balance)
          #       my_debug("resellerio_balansas : " + @ruser.frozen_balance)
          if @ruser.id.to_i != 0
            @user.frozen_balance = @user.frozen_balance - r['user_price'].to_d
            @user.save
          else
            @user.frozen_balance = @user.frozen_balance - r['user_price'].to_d
            @user.save
            @ruser.frozen_balance = @ruser.frozen_balance - r['reseller_price'].to_d
            @ruser.save
          end
          @sms.status_code = 5
          @sms.save
        else
          #       my_debug "grazinau uz per ilga laika"
          if @ruser.id.to_i != 0
            @user.balance = @user.balance + r['user_price'].to_d
            @user.frozen_balance = @user.frozen_balance - r['user_price'].to_d
            @user.save
          else
            @user.balance = @user.balance + r['user_price'].to_d
            @user.frozen_balance = @user.frozen_balance - r['user_price'].to_d
            @user.save
            @ruser.balance = @ruser.balance + r['reseller_price'].to_d
            @ruser.frozen_balance = @ruser.frozen_balance - r['reseller_price'].to_d
            @ruser.save
          end
          @sms = SmsMessage.find(r['sms_id'])
          @sms.status_code = 4
          @sms.user_rate = 0
          @sms.user_price = 0
          @sms.reseller_rate = 0
          @sms.reseller_price = 0
          @sms.provider_rate = 0
          @sms.provider_price = 0
          @sms.save
        end
      end

    end


    Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
    Net::POP3.start(pop3_server, Net::POP3.default_pop3s_port, login, psw) do |pop|
      if pop.mails.empty?
        a= 'No mail.'
        #     my_debug a
      else
        pop.each_mail do |email|
          msg = email.pop
          for r in gres
            #================ no keywords ===============================
            if msg.match(r['number']) and msg.match(r['sms_provider_domain']) and (r['wait_for_bad_email'].to_i == 1 or r['wait_for_good_email'].to_i == 1)
              @user = User.find(r['user_id'])
              #           my_debug("user : " + @user.username)
              @ruser = User.find(r['reseller_id'])
              #           my_debug("reseller : " + @ruser.username)
              @sms = SmsMessage.find(r['sms_id'])
              #           my_debug("user_balance : " + @user.balance.to_s)
              #           my_debug("user_frozen_balance : " + @user.frozen_balance.to_s)
              #           my_debug("resseller_balance : " + @ruser.balance.to_s)
              #           my_debug("resseller_frozen_balance : " + @ruser.frozen_balance.to_s)
              if  r['nan_keywords_charge_user'].to_i == 1
                #                my_debug "nan_keywords_charge_user"
                @user_price = r['user_price'].to_d
                @ruser_price = r['reseller_price'].to_d
                @user_price_b = 0
                @ruser_price_b = 0
                @sms.status_code = 5
              else
                #                my_debug "nan_keywords_charge_user"
                @user_price = r['user_price'].to_d
                @ruser_price = r['reseller_price'].to_d
                @user_price_b = r['user_price'].to_d
                @ruser_price_b = r['user_price'].to_d
                @sms.status_code = 4
              end

              if r['wait_for_bad_email'].to_i == 1 and msg.match(r['email_bad_keywords'])
                #                 my_debug "wait_for_bad_email"
                @user_price = r['user_price'].to_d
                @ruser_price = r['reseller_price'].to_d
                @user_price_b = r['user_price'].to_d
                @ruser_price_b = r['user_price'].to_d
                @sms.status_code = 4
              end

              if r['wait_for_good_email'].to_i == 1 and msg.match(r['email_good_keywords'])
                #                 my_debug "wait_for_good_email"
                @user_price = r['user_price'].to_d
                @ruser_price = r['reseller_price'].to_d
                @user_price_b = 0
                @ruser_price_b = 0
                @sms.status_code = 5
              end
              #            my_debug "--------------VEIKSMAI------------------"
              if @user.owner_id.to_i == 0
                #                  my_debug(@user.balance.to_s+ " + " + @user_price_b.to_s)
                @user.balance = @user.balance + @user_price_b
                #                  my_debug(@user.frozen_balance.to_s+ " - " + @user_price.to_s)
                @user.frozen_balance = @user.frozen_balance - @user_price
                @user.save
              else
                #                my_debug(@user.balance.to_s+ " + " + @user_price_b.to_s)
                @user.balance = @user.balance + @user_price_b
                #               my_debug(@user.frozen_balance.to_s+ " - " + @user_price.to_s)
                @user.frozen_balance = @user.frozen_balance - @user_price
                #               my_debug(@ruser.balance.to_s+ " + " + @ruser_price_b.to_s)
                @ruser.balance = @ruser.balance + @ruser_price_b
                #               my_debug(@ruser.frozen_balance.to_s+ " - " + @ruser_price.to_s)
                @ruser.frozen_balance = @ruser.frozen_balance - @ruser_price
                @user.save
                @ruser.save
              end
              @sms.save
              #           my_debug "---------------------------------------"
              #           my_debug "po "
              #           my_debug("user_balance : " + @user.balance.to_s)
              #           my_debug("user_frozen_balance : " + @user.frozen_balance.to_s)
              #           my_debug("resseller_balance : " + @ruser.balance.to_s)
              #           my_debug("resseller_frozen_balance : " + @ruser.frozen_balance.to_s)
              #           my_debug "*****************************************************************"
            end

          end
          email.delete
        end

      end

    end
    redirect_to :controller => "emails", :action => "list" and return false

  end


  def email_callback
    if callback_active?
      if params[:subject].to_s.downcase == 'change'
        old_callerid = params[:param1].to_s
        new_callerid = params[:param2].to_s
        Callerid.set_callback_from_emails(old_callerid, new_callerid)
      end

      if params[:subject].to_s.downcase == 'callback'
        auth_callerid = params[:param1].to_s.gsub(/[^0-9]/, "")
        first_number = params[:param2].to_s.gsub(/[^0-9]/, "")
        second_number = params[:param3].to_s.gsub(/[^0-9]/, "")

        my_debug params.to_yaml

        auth_dev_callerid = Callerid.find(:first, :conditions => "cli = '#{auth_callerid}'")
        if auth_dev_callerid and auth_dev_callerid.email_callback.to_i == 1

          MorLog.my_debug "email2callback by #{auth_callerid} authenticated."
          #Initiating callback between #{ first_number} and #{second_number}"

          if first_number.to_i > 0 and second_number.to_i > 0

            device = Device.find(:first, :conditions => "id = #{auth_dev_callerid.device_id}")

            if device

              st = originate_call(device.id, first_number, "Local/#{first_number}@mor_cb_src/n", "mor_cb_dst", second_number, device.callerid)

              if st.to_i == 0
                MorLog.my_debug "email callback - originating callback to '#{first_number}' and '#{second_number}'"
                Action.add_action2(0, "email_callback_originate", "done", "originating callback to '#{first_number}' and '#{second_number}'")
              else
                MorLog.my_debug "#{_('Cannot_connect_to_asterisk_server')} :: email callback - originating callback to '#{first_number}' and '#{second_number}'"
                Action.add_action2(0, "email_callback_originate", _('Cannot_connect_to_asterisk_server'), "originating callback to '#{first_number}' and '#{second_number}'")

              end
            else
              MorLog.my_debug "email2callback error - auth. device not found"
              Action.add_action2(0, "email_callback_originate", "error", "auth. device not found, '#{first_number}' - '#{second_number}'")
            end

          else
            MorLog.my_debug "email2callback can't be initiated because bad numbers '#{first_number}' and/or '#{second_number}'"
            Action.add_action2(0, "email_callback_originate", "error", "can't be initiated because bad numbers '#{first_number}' and/or '#{second_number}'")
          end

        else
          MorLog.my_debug "email2callback fail by auth_callerid: #{auth_callerid}"
          Action.add_action2(0, "email_callback_originate", "error", "fail by auth_callerid: #{auth_callerid}, dst: '#{second_number}'")
        end

      end


      if params[:subject].to_s.downcase != 'callback' and params[:subject].to_s.downcase != 'change'
        MorLog.my_debug "ERROR, Subject is not correct , [#{params[:subject]}]"
        Action.add_action2(0, "email_callback", "error - Unknown Action", "#{params[:subject]}")
      end
    else
      MorLog.my_debug "ERROR, Callback addon is disabled"
      Action.add_action2(0, "email_callback", "error - Callback addon is disabled", '')
    end
  end


=begin rdoc
 Sends conmirmation email for user after registration.
=end

  def EmailsController.send_user_email_after_registration(user, device, password, reg_ip, free_ext)
    if Confline.get_value("Send_Email_To_User_After_Registration") == "1"
      #send mail to user with device details
      email = Email.find(:first, :conditions => ["name = 'registration_confirmation_for_user' AND owner_id= ?", user.owner_id])
      users = [user]
      variables = Email.email_variables(user, device, {:login_password => password, :user_ip => reg_ip})
      num = EmailsController.send_email(email, Confline.get_value("Email_from", user.owner_id), users, variables)
      #      if num
      #        #flash[:notice] = _('EMAIL_SENDING_ERROR')
      #        action = Action.new
      #        action.user_id = user.id
      #        action.action = "error"
      #        action.date = Time.now
      #        action.data = 'Cant_send_email'
      #        action.data2 = num.to_s
      #        action.save
      #      end
      return 1
    end
    return 0
  end


=begin rdoc
 Send mail to admin with registered user details
=end

  def EmailsController.send_admin_email_after_registration(user, device, password, reg_ip, free_ext, owner_id = 0)
    if Confline.get_value("Send_Email_To_Admin_After_Registration") == "1"
      #
      email = Email.find(:first, :conditions => ["name = 'registration_confirmation_for_admin' AND owner_id= ?", owner_id])
      users = [User.find_by_id(owner_id)]
      variables = Email.email_variables(user, device, {:user_ip => reg_ip, :password => password, :free_ext => free_ext})
      num = EmailsController.send_email(email, Confline.get_value("Email_from", owner_id), users, variables)

      #      if num
      #        #flash[:notice] = _('EMAIL_SENDING_ERROR')
      #        action = Action.new
      #        action.user_id = user.id
      #        action.action = "error"
      #        action.date = Time.now
      #        action.data = 'Cant_send_email'
      #        action.data2 = num.to_s
      #        action.save
      #      end
    end
  end


  private

  def find_email
    @email = Email.find_by_id(params[:id])
    unless @email
      flash[:notice] = _('Email_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    check_user_for_email(@email)
  end

  def find_session_user
    @user = User.find_by_id(session[:user_id])
    unless @user
      flash[:notice] = _('User_was_not_found')
      render :controller => "callc", :action => 'main'
    end
  end

  def check_user_for_email(email)
    if email.class.to_s =="Fixnum"
      email = Email.find(:first, :conditions => ["id = ? ", email])
    end
    if email.owner_id != session[:user_id]
      dont_be_so_smart
      redirect_to :controller => "emails", :action => "list" and return false
    end
    return true
  end

end
