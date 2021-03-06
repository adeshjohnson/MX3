# -*- encoding : utf-8 -*-
class CallcController < ApplicationController

  #require 'rami'
  require 'digest/sha1'
  require 'net/smtp'
  #require 'enumerator'
  require 'smtp_tls'

  layout :mobile_standard

  before_filter :check_localization, :except => [:pay_subscriptions, :monthly_actions]
  before_filter :authorize, :except => [:webphone, :webphone_date_limit, :webphone_invalid,:login, :try_to_login, :pay_subscriptions, :monthly_actions, :forgot_password]
  before_filter :find_registration_owner, :only => [:signup_start, :signup_end]
  skip_before_filter :redirect_callshop_manager, :only => [:webphone, :webphone_date_limit, :webphone_invalid, :logout]

  @@monthly_action_cooldown = 2.hours
  @@daily_action_cooldown = 2.hours
  @@hourly_action_cooldown = 20.minutes

  def index
    if session[:usertype]
      redirect_to :action => "login" and return false
    else
      redirect_to :action => "logout" and return false
    end
  end

  def login
    @show_login  = params[:shl].to_i
    @u = params[:u].to_s


    if params[:id]
      @owner = User.where(:uniquehash => params[:id]).first
    end

    @owner = User.where(:id => 0).first unless @owner

    if @owner and @owner.class == User
      @owner_id = @owner.id
      @defaulthash = @owner.get_hash()
    else
      @owner_id = 0
      @defaulthash = ""
    end


    session[:login_id] = @owner_id
    #my_debug session[:layout_t]
    #reset_session

    flags_to_session(@owner)

    # do some house cleaning
    global_check

    if Confline.get_value("Show_logo_on_register_page", @owner_id).to_s == ""
      Confline.set_value("Show_logo_on_register_page", 1, @owner_id)
    end

    @page_title = _('Login')
    @page_icon = "key.png"

    #my_debug(Localization.lang)

    # ----------- RAMI server -----------

    #server = Server.new({'host' => 'localhost', 'username' => 'asterisk', 'secret' => 'secret'})
    #server.console =1
    #server.event_cache = 100
    #server.run

    # -----------------------------------


    if session[:login] == true

      redirect_to :action => "main" and return false
    end

    t = Time.now

    session[:year_from] = t.year
    session[:month_from] = t.month
    session[:day_from] = t.day
    session[:hour_from] = 0
    session[:minute_from] = 0

    session[:year_till] = t.year
    session[:month_till] = t.month
    session[:day_till] = t.day
    session[:hour_till] = 23
    session[:minute_till] = 59

    if Confline.get_value("Show_logo_on_register_page", @owner_id).to_i == 1
      session[:logo_picture] = Confline.get_value("Logo_Picture", @owner_id)
      session[:version] = Confline.get_value("Version", @owner_id)
      session[:copyright_title] = Confline.get_value("Copyright_Title", @owner_id)
    else
      session[:logo_picture] = ""
      session[:version] = ""
      session[:copyright_title] = ""
    end

    if  request.env["HTTP_X_MOBILE_GATEWAY"]
      respond_to do |format|
        format.wml { render :action => 'login.wml.builder' }
        #format.html
      end
    end

  end

  def try_to_login

    #		my_debug Digest::SHA1.hexdigest("101")
    session[:layout_t] = params[:layout_t].to_s if params[:layout_t]
    if not params["login"]
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end

    @username = params["login"]["username"].to_s
    @psw = params["login"]["psw"].to_s

    @type = "user"
    @login_ok = false

    @user = User.where(:username => @username, :password => Digest::SHA1.hexdigest(@psw)).first
    if @user and @user.owner
      @login_ok = true
      renew_session(@user)
      store_url
      #session[:ssecret] = SSecret
    end

    session[:login] = @login_ok

    #    if @login_ok == true and @type == "admin"
    #      redirect_to :action => "show_agents" and return false
    #    end

    #    my_debug  request.env.to_yaml
    #    my_debug  request.env["REMOTE_ADDR"].to_s

    if @login_ok == true
      #redirect_to :action => "select_company", :id => @user_id and return false
      add_action(session[:user_id], "login", request.env["REMOTE_ADDR"].to_s)

      @user.logged = 1
      @user.save

      check_devices()

      #	           if @user.call_center_agent.to_i == 1
      #                     session[:layout_t] = "callcenter"
      #                     redirect_to :action => "main" and return false
      #                   else

      bad_psw = (params["login"]["psw"].to_s == 'admin' and @user.id == 0) ? _('ATTENTION!_Please_change_admin_password_from_default_one_Press')+ " <a href='#{Web_Dir}/users/edit/0'> #{_('Here')} </a> " + _('to_do_this') : ''
      flash[:notice] = bad_psw if !bad_psw.blank?
      if (request.env["HTTP_USER_AGENT"]) && (request.env["HTTP_USER_AGENT"].match("iPhone") or request.env["HTTP_USER_AGENT"].match("iPod"))
        #my_debug request.env["HTTP_USER_AGENT"]
        flash[:status] = _('login_successfully')
        redirect_to :action => "main_for_pda" and return false
      else
        flash[:status] = _('login_successfully')
        if defined?(CS_Active) && CS_Active == 1 && group = current_user.usergroups.includes(:group).where("usergroups.gusertype = 'manager' AND groups.grouptype = 'callshop'").first and current_user.usertype != 'admin'
          session[:cs_group] = group
          session[:lang] = Translation.where(:id => group.group.translation_id).first.short_name
          redirect_to :controller => "callshop", :action => "show", :id => group.group_id and return false
        else
          redirect_to :action => "main" and return false
        end
      end
      #                  end
    else

      add_action2(0, "bad_login", @username.to_s + "/" + @psw.to_s, request.env["REMOTE_ADDR"].to_s)

      us = User.where(:id => session[:login_id]).first
      u_hash = us ? us.uniquehash : ''
      flash[:notice] = _('bad_login')
      show_login = Action.disable_login_check(request.env["REMOTE_ADDR"].to_s).to_i == 0 ? 1 : 0
      redirect_to :action => "login", :id=>u_hash, :shl=>show_login, :u=>@username and return false
    end
  end

  def main_for_pda
    # my_debug session[:layout_t]
    @page_title = _('Start_page')
    @user = User.where(:id => session[:user_id]).first
    if @user.first_name and @user.last_name
      @username = @user.first_name.capitalize + " " + @user.last_name.capitalize
    else
      @username = @user.username
    end
  end

  def logout
    add_action(session[:user_id], "logout", "")

    user = User.where(:id => session[:user_id]).first
    if user
      user.logged = 0
      user.save
      check_devices()
      owner = user.owner

    end
    owner = User.where({:id=>0}).first if !owner
    owner_id = owner ? owner.id : 0
    session[:login] = false

    session.clear

    flash[:notice] = _('logged_off')
    if Confline.get_value("Logout_link", owner_id).to_s.blank?
      if !owner.blank? and owner.get_hash()
        redirect_to :action => "login", :id => owner.get_hash()
      else
        redirect_to :action => "login"
      end
    elsif user and user.usertype == 'reseller'
      link = (Confline.get_value("Logout_link", user.id).to_s.include?("http") ? "" : "http://") + Confline.get_value("Logout_link", user.id).to_s
      redirect_to link
    else
      link = (Confline.get_value("Logout_link", owner_id).to_s.include?("http") ? "" : "http://") + Confline.get_value("Logout_link", owner_id).to_s
      redirect_to link
    end
  end

  def forgot_password
    @r = ''
    @st = true
    if params[:email] and !params[:email].blank?
      addresses = Address.where(:email => params[:email]).all
      if addresses and addresses.size.to_i > 0
        if addresses.size.to_i == 1
          user = User.includes(:address).where(:address_id => addresses[0].id).first
          if user and user.id != 0
            psw = random_password(12)
            email = Email.where(:name => 'password_reminder', :owner_id => user.owner_id).first
            variables = Email.email_variables(user, nil, {:owner => user.owner_id, :login_password => psw})
            session[:flash_not_redirect] = 1
            session[:forgot_pasword] = 1
            num = EmailsController::send_email(email, Confline.get_value("Email_from", user.owner_id), [user], variables)
            if num.to_s.include?(_('Email_sent')+'<br>')
              user.password = Digest::SHA1.hexdigest(psw)
              if user.save
                @r = _('Password_changed_check_email_for_new_password') + '  ' + user.email
              else
                @r = _('Cannot_change_password')
              end
            end
          else
            @r = _('Cannot_change_password')
            @st = false
          end
        else
          @r = _('Email_is_used_by_multiple_users_Cannot_reset_password')
          @st = false
        end
      else
        @r = _('Email_was_not_found')
        @st = false
      end
    else
      @r = _('Please_enter_email')
      @st = false
    end
    render :layout => false
  end


  def main

    @Show_Currency_Selector=1

    if not session[:user_id]
      redirect_to :action => "login" and return false
    end

    dont_be_so_smart if params[:dont_be_so_smart] == true

    @page_title = _('Start_page')
    session[:layout_t]="full"
    @user = User.includes(:tax).where(:id => session[:user_id]).first

    unless @user
      redirect_to :action => "logout" and return false
    end
    session[:integrity_check] = current_user.integrity_recheck_user
    session[:integrity_check] = Device.integrity_recheck_devices if session[:integrity_check].to_i == 0
    @username = nice_user(@user)

    if Confline.get_value("Hide_quick_stats").to_i == 0
      show_quick_stats
    end

    if session[:usertype] == 'reseller'
      reseller = User.where(:id => session[:user_id]).first
      reseller.check_default_user_conflines
    end

    #  my_debug @quick_stats
    # @total_profitm = @total_call_pricem - @total_call_selfpricem
    #  @total_profitd = @total_call_priced - @total_call_selfpriced
    @pp_enabled = session[:paypal_enabled]
    @wm_enabled = session[:webmoney_enabled]
    @vouch_enabled = session[:vouchers_enabled]
    @lp_enabled = session[:linkpoint_enabled]
    @cp_enabled = session[:cyberplat_enabled]

    @ob_enabled = session[:ouroboros_enabled]
    @ob_link_name = session[:ouroboros_name]
    @ob_link_url = session[:ouroboros_url]
    @ob_enabled = 0 if @user.owner_id > 0 # do not show for reseller users
    @addresses = Phonebook.where(:user_id => session[:user_id]).all
    if  request.env["HTTP_X_MOBILE_GATEWAY"]
      @notice = params[:sms_notice].to_s
      respond_to do |format|
        format.wml { render :action => 'main.wml.builder' }
        #format.html
      end
    end
  end

  def show_quick_stats
    if Confline.get_value("Hide_quick_stats").to_i == 1
      @page_title = _('Quick_stats')
    end

    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @user = User.includes(:tax).where(:id => session[:user_id]).first

    unless @user
      redirect_to :action => "logout" and return false
    end

    month_t = Time.now.year.to_s + "-" + good_date(Time.now.month.to_s)
    last_day = last_day_of_month(Time.now.year.to_s, good_date(Time.now.month.to_s))
    day_t = Time.now.year.to_s + "-" + good_date(Time.now.month.to_s) + "-" + good_date(Time.now.day.to_s)
    session[:callc_main_stats_options] ? options = session[:callc_main_stats_options] : options = {}
    show_from_db = !options[:time] || options[:time] < Time.now ? 0 : 1

    if show_from_db.to_i == 0
      @quick_stats = @user.quick_stats(month_t, last_day, day_t)
      options[:quick_stats] = @quick_stats
      options[:time] = Time.now + 2.minutes
    else
      @quick_stats = options[:quick_stats]
    end

    session[:callc_main_stats_options] = options
  end

  def user_settings
    @user = User.where(:id => session[:user_id]).first
  end


  def ranks

    #      today = Time.now.strftime("%Y-%m-%d")
    #     today = "2006-07-26" #debug

    #counting month_normative for 1 user which was counted most time ago
    user = User.order("month_plan_updated ASC").first
    user.months_normative(Time.now.strftime("%Y-%m"))

    @users = User.where(:usertype => 'user', :show_in_realtime_stats => '1').all

    @h = Hash.new

    @total_billsec = 0;
    @total_calls = 0;
    @total_missed_not_processed = 0;
    @total_new_calls = 0;

    for user in @users

      @ranks_type = params[:id]


      if @ranks_type == "duration"
        calls_billsec = 0
        #          for call in user.calls("answered",today,today)
        #            calls_billsec += call.duration #billsec
        #          end

        calls_billsec = user.total_duration("answered", today, today) + user.total_duration("answered_inc", today, today)
        @h[user.id] = calls_billsec

        @total_billsec += calls_billsec
        @ranks_title = _('most_called_users')
        @ranks_col1 = _('time')
        @ranks_col2 = _('Calls')
      end

    end

    @a = @h.sort { |a, b| b[1]<=>a[1] }

    @b = []
    @c = []
    @d = []
    @e = [] #till normative
    @f = [] #class of normative
    @g = [] #percentage of normative
    @h = [] #new calls

    for a in @a

      if @ranks_type == "duration"
        user = User.where(:id => a[0]).first

        @b[a[0]] = user.total_calls("answered", today, today) + user.total_calls("answered_inc", today, today)
        #User.find(a[0]).calls("answered",today,today).size
        @d[a[0]] = user.total_calls("missed_not_processed", "2000-01-01", today)
        #User.find(a[0]).calls("missed_not_processed","2000-01-01",today).size
        @total_missed_not_processed += @d[a[0]]
        @total_calls += @b[a[0]]
        if @b[a[0]] != 0
          @c[a[0]] = a[1] / @b[a[0]]
        else
          @c[a[0]] = 0
        end

        #my_debug session[:time_to_call_per_day].to_i * 3600 - a[1]

        #@e[a[0]] = session[:time_to_call_per_day].to_d * 3600 - a[1]
        normative = user.calltime_normative.to_d * 3600
        @e[a[0]] = normative - a[1]
        @f[a[0]] = "red"


        if normative == 0
          @g[a[0]] = 0
        else
          @g[a[0]] = ((1 - (@e[a[0]] / normative)) * 100).to_i
        end

        # user has not started
        if  a[1] == 0
          @e[a[0]] = 0
          @f[a[0]] = "black"
        end

        # user has finished
        if @e[a[0]] < 0
          @e[a[0]] = a[1] - normative
          @f[a[0]] = "black"
        end

        @h[a[0]] = user.new_calls(Time.now.strftime("%Y-%m-%d")).size
        @total_new_calls += @h[a[0]]

      end
    end

    @avg_billsec = 0
    @avg_billsec = @total_billsec / @total_calls if @total_calls > 0

    render(:layout => false)

  end

  def show_ranks
    @page_title = _('Statistics')
    render(:layout => "layouts/realtime_stats")
  end

  def realtime_stats
    @page_title = _('Realtime')

    if params[:rt]
      if params[:rt][:calltime_per_day]
        session[:time_to_call_per_day] = params[:rt][:calltime_per_day]
      end
    else
      if !session[:time_to_call_per_day]
        session[:time_to_call_per_day] = 3.0
      end
    end


    @ttcpd = session[:time_to_call_per_day]
  end

  def global_settings
    @page_title = _('global_settings')
    cond = "exten = ? AND context = ? AND priority IN (2, 3) AND appdata like ?"
    ext = Extline.where(cond, '_X.', "mor", 'TIMEOUT(response)%').first
    @timeout_response = (ext ? ext.appdata.gsub("TIMEOUT(response)=", "").to_i : 20)
    ext = Extline.where(cond, '_X.', "mor", 'TIMEOUT(digit)%').first
    @timeout_digit = (ext ? ext.appdata.gsub("TIMEOUT(digit)=", "").to_i : 10)
  end

  def global_settings_save
    Confline.set_value("Load_CSV_From_Remote_Mysql", params[:load_csv_from_remote_mysql].to_i, 0)
    redirect_to :action => "global_settings" and return false
  end

  def reconfigure_globals
    @page_title = _('global_settings')
    @type = params[:type]

    if @type == "devices"
      @devices = Device.where("user_id > 0").all
      for dev in @devices
        a = configure_extensions(dev.id, {:current_user => current_user})
        return false if !a
      end
    end

    if @type == "outgoing_extensions"
      reconfigure_outgoing_extensions
    end
  end

  def global_change_timeout
    if Extline.update_timeout(params[:timeout_response].to_i, params[:timeout_digit].to_i)
      flash[:status] = _("Updated")
    else
      flash[:notice] = _("Invalid values")
    end
    redirect_to :action => "global_settings" and return false
  end

  def global_change_fax_path_setup
    if Confline.set_value("Fax2Email_Folder", params[:fax2email_folder].to_s, 0)
      flash[:status] = _("Updated")
    else
      flash[:notice] = _("Invalid values")
    end
    redirect_to :action => "global_settings" and return false
  end

  def global_set_tz
    if Confline.get_value('System_time_zone_ofset_changed').to_i == 0
      sql = "UPDATE users SET time_zone = '#{ActiveSupport::TimeZone[Time.now.utc_offset/3600].name}';"
      ActiveRecord::Base.connection.execute(sql)
      Confline.set_value('System_time_zone_ofset_changed', 1)
      flash[:status] = _("Time_zone_for_users_set_to") + " #{ActiveSupport::TimeZone[Time.now.utc_offset/3600].name} "
    else
      flash[:notice] = _("Global_Time_zone_set_replay_is_dont_allow")
    end
    redirect_to :action => "global_settings" and return false
  end

  def set_tz_to_users
    users = User.all
    for u in users
      Time.zone = u.time_zone
      u.time_zone = ActiveSupport::TimeZone[Time.zone.now.utc_offset().hour.to_d + params[:add_time].to_d].name
      u.save
    end

    flash[:status] = _("Time_zone_for_users_add_value") + " + #{params[:add_time].to_d} "
    redirect_to :action => "global_settings" and return false
  end

  def debug
  end

  def signup_start
    @page_title = _('Sign_up')
    @page_icon = "signup.png"
    @countries = Direction.order("name ASC").all

    @agreement = Confline.get("Registration_Agreement", @owner.id)

    Confline.load_recaptcha_settings

    if Confline.get_value("Show_logo_on_register_page", @owner.id).to_i == 1
      session[:logo_picture] = Confline.get_value("Logo_Picture", @owner.id)
      session[:version] = Confline.get_value("Version", @owner.id)
      session[:copyright_title] = Confline.get_value("Copyright_Title", @owner.id)
    end
    @vat_necessary = Confline.get_value("Registration_Enable_VAT_checking").to_i == 1 && Confline.get_value("Registration_allow_vat_blank").to_i == 0
  end

  def signup_end
    @page_title = _('Sign_up')
    @page_icon = "signup.png"

    #error checking
    session[:reg_username] = params[:username]
    session[:reg_password] = params[:password]
    session[:reg_password2] = params[:password2]
    session[:reg_device_type] = params[:device_type]

    session[:reg_first_name] = params[:first_name]
    session[:reg_last_name] = params[:last_name]
    session[:reg_client_id] = params[:client_id]
    session[:reg_vat_number] = params[:vat_number]

    session[:reg_address] = params[:address]
    session[:reg_postcode] = params[:postcode]
    session[:reg_city] = params[:city]
    session[:reg_county] = params[:county]
    session[:reg_state] = params[:state]
    session[:reg_country_id] = params[:country_id]
    session[:reg_phone] = params[:phone]
    session[:reg_mob_phone] = params[:mob_phone]
    session[:reg_fax] = params[:fax]
    session[:reg_email] = params[:email]
    reg_ip= request.remote_ip

    owner = User.where(:uniquehash => params[:id]).first

    if !params[:id] or !owner
      reset_session
      dont_be_so_smart
      redirect_to :action => "login" and return false
    end
    show_debug = true
    if show_debug
      File.open('/tmp/new_log.txt', 'a+') {|f| f.write("\n Start #{Time.now}") }
    end
    notice = User.validate_from_registration(params, owner.id)
    capt = true
    if Confline.get_value("reCAPTCHA_enabled").to_i == 1
      usern = User.new
      capt = verify_recaptcha(usern) ? true : (false; notice = _('Please_enter_captcha'))
    end
    if show_debug
      File.open('/tmp/new_log.txt', 'a+') {|f| f.write("\n End #{Time.now}") }
    end
    if capt and !notice or notice.blank?
      reset_session
      if Confline.get_value("Show_logo_on_register_page", @owner.id).to_i == 1
        session[:logo_picture] = Confline.get_value("Logo_Picture", @owner.id)
        session[:version] = Confline.get_value("Version", @owner.id)
        session[:copyright_title] = Confline.get_value("Copyright_Title", @owner.id)
      end
      @user, @send_email_to_user, @device, notice2 = User.create_from_registration(params, @owner, reg_ip, free_extension(), new_device_pin(), random_password(12), next_agreement_number)
      session[:reg_owner_id] = @user.owner_id
      unless notice2
        flash[:status] = _('Registration_successful')
        a = Thread.new { configure_extensions(@device.id, {:current_user => @owner}) }
        #        a=configure_extensions(@device.id)
        #        return false if !a
      else
        flash[:notice] = notice2
      end
    else
      flash[:notice] = notice
      redirect_to :action => "signup_start", :id => params[:id] and return false
    end
  end

  #cronjob runs every hour
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/hourly_actions

  def hourly_actions
    #    backups_hourly_cronjob
    if active_heartbeat_server
      periodic_action("hourly", @@hourly_action_cooldown) {
        # check/make auto backup
        #    bt = Thread.new {
        Backup.backups_hourly_cronjob(session[:user_id])
        # }
        # =========== send b warning email for users ==================================
        MorLog.my_debug("Starting checking for balance warning", 1)
        User.check_users_balance
        send_balance_warning
        MorLog.my_debug("Ended checking for balance warning", 1)

        if defined?(PG_Active) && PG_Active == 1
          if Confline.get_value("ideal_ideal_enabled").to_i == 1
            MorLog.my_debug("Starting iDeal check")
            payments = Payment.where(:paymenttype => "ideal_ideal", :completed => 0, :pending_reason => "waiting_response").all
            MorLog.my_debug("Found #{payments.size} waiting payments")
            # There m ay be possibe to do some caching if performance becomes an issue.
            if payments.size > 0
              payments.each { |payment|
                user = payment.user
                gateway = ::GatewayEngine.where(:engine => "ideal", :gateway => "ideal", :for_user => user.id).first.enabled_by(user.owner.id).query ## this is cacheable
                success, message = gateway.check_response(payment)
                MorLog.my_debug("#{success ? "Done" : "Fail"} : #{message}")
              }
            end
            MorLog.my_debug("Ended iDeal check")
          end
        end
        # bt.join
        #======================== Cron actions =====================================
        CronAction.do_jobs
        #======================== System time ofset =====================================
        #sql = 'select HOUR(timediff(now(),convert_tz(now(),@@session.time_zone,\'+00:00\'))) as u;'
        #z = ActiveRecord::Base.connection.select_all(sql)[0]['u']
        #MorLog.my_debug("GET global time => #{z.to_yaml}", 1)
        #t = z.to_s.to_i
        #old_tz= Confline.get_value('System_time_zone_ofset')
        #if t.to_i != old_tz.to_i and Confline.get_value('System_time_zone_daylight_savings').to_i == 1
          # ========================== System time ofset update users ================================
          #diff = t.to_i - old_tz.to_i
          #sql = "UPDATE users SET time_zone = ((time_zone + #{diff.to_d}) % 24);;"
          #ActiveRecord::Base.connection.execute(sql)
          #MorLog.my_debug("System time ofset update users", 1)
        #end
        #Confline.set_value('System_time_zone_ofset', t.to_i, 0)
        #MorLog.my_debug("confline => #{Confline.get_value('System_time_zone_ofset')}", 1)
        #======================== Devices  =====================================
        check_devices_for_accountcode
        # ========================== Cleaning session table ================================
        sql = "DELETE FROM sessions where sessions.updated_at < '#{(Time.now - 5.hour).to_s(:db)}'; "
        ActiveRecord::Base.connection.delete(sql)
        MorLog.my_debug("Sessions cleaned", 1)
      }
    else
      MorLog.my_debug("Backup not made because this server has different IP than Heartbeat IP from Conflines")
    end
  end


  #cronjob runs every midnight
  # 0 0 * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/daily_actions

  def daily_actions
    if active_heartbeat_server
      periodic_action("daily", @@daily_action_cooldown) {
        # ========================== Cleaning session table ================================
        @time = Time.now - 1.day
        @atime = @time.strftime("%Y-%m-%d %H:%M:%S")
        sql = "DELETE FROM sessions where sessions.updated_at < '#{@atime}'; "
        ActiveRecord::Base.connection.delete(sql)
        my_debug("Sessions cleaned")

        # =========== get Currency rates from yahoo.com =====================================
        update_currencies

        #delete file
        delete_files_after_csv_import
        system("rm -f /tmp/get_tariff_*") #delete tariff export zip files
        # =========== block users if necessary =====================================
        block_users
        block_users_conditional
        pay_subscriptions(@time.year.to_i, @time.month.to_i, @time.day.to_i, "is_a_day")
      }
    end
  end

  #cronjob runs every 1st day of month
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/monthly_actions

  def monthly_actions
    if active_heartbeat_server
      periodic_action("monthly", @@monthly_action_cooldown) {
        # --------- count/deduct subscriptions --------
        year = Time.now.year.to_i
        month = Time.now.month.to_i - 1

        if month == 0
          year -= 1
          month = 12
        end

        my_debug("Saving balances for users for: " +year.to_s + " " + month.to_s)
        save_user_balances(year, month)

        my_debug("Counting subscriptions for: " +year.to_s + " " + month.to_s)
        pay_subscriptions(year, month)
        # ----- end count/deduct subscriptions --------
      }
    end
  end

  def periodic_action(type, cooldown)
    MorLog.my_debug "#{Time.now.to_s(:db)} - #{type} actions starting sleep"
    sleep(rand * 10)
    MorLog.my_debug "#{Time.now.to_s(:db)} - #{type} actions starting sleep end"
    begin
      time_set = Time.parse(Confline.get_value("#{type}_actions_cooldown_time"))
    rescue ArgumentError
      time_set = Time.now - 1.year
    end
    unless time_set and time_set + cooldown > Time.now
      Confline.set_value("#{type}_actions_cooldown_time", Time.now.to_s(:db))
      MorLog.my_debug "#{type} actions starting"
      yield
      MorLog.my_debug "#{type} actions finished"
    else
      MorLog.my_debug("#{cooldown} has not passed since last run of #{type.upcase}_ACTIONS")
      render :text => "To fast."
    end
  end

  def pay_subscriptions_test
    if session[:usertype] == "admin" and !params[:year].blank? and !params[:month].blank?
      a = pay_subscriptions(params[:year], params[:month])
      return false if !a
    else
      render :text => "NO!"
    end
  end


  def test_pdf_generation
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    # ---------- Company details ----------

    pdf.text(session[:company], {:left => 40, :size => 23})
    pdf.text(Confline.get_value("Invoice_Address1"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address2"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address3"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address4"), {:left => 40, :size => 12})

    # ----------- Invoice details ----------

    pdf.fill_color('DCDCDC')
    pdf.draw_text(_('INVOICE'), {:at => [330, 700], :size => 26})
    pdf.fill_color('000000')
    pdf.draw_text(_('Date') + ": " + 'invoice.issue_date.to_s', {:at => [330, 685], :size => 12})
    pdf.draw_text(_('Invoice_number') + ": " + 'invoice.number.to_s', {:at => [330, 675], :size => 12})

    pdf.image(Actual_Dir+"/app/assets/images/rails.png")
    pdf.text("Test Text : ąčęėįšųūž_йцукенгшщз")
    pdf.render

    flash[:status] = _('Pdf_test_pass')
    redirect_to :action => :main and return false
  end

  def global_change_confline
    if params[:heartbeat_ip]
      Confline.set_value("Heartbeat_IP", params[:heartbeat_ip].to_s.strip)
      flash[:status] = "Heartbeat IP set"
    end
    redirect_to :action => :global_settings and return false
  end

  def webphone_invalid
    render(:layout => false)
  end

  def webphone_date_limit
    render(:layout => false)
  end

  def webphone
    render(:layout => false)
  end

  def additional_modules
    @page_title = _('Additional_modules')
  end

  def additional_modules_save

    ccl = params[:CCL_Active].to_i
    ccl_old = Confline.get_value("CCL_Active").to_i
    first_srv = Server.first.id
    def_asterisk = Confline.get_value("Default_asterisk_server").to_s
    reseller_server = Confline.get_value("Resellers_server_id").to_s
    @resellers_devices = Device.joins("LEFT JOIN users ON (devices.user_id = users.id)").where("(users.owner_id !=0 or usertype = 'reseller') AND users.hidden = 0").all
    if def_asterisk.to_i == 0
      def_asterisk = first_srv
    end

    if ccl.to_s != ccl_old.to_s and params[:indirect].to_i == 1
      @sd = ServerDevice.all
      @sp = Serverprovider.all

        if ccl.to_i == 0
          p_srv_id = Server.where(:server_type => "sip_proxy").first.server_id.to_s rescue nil
          if !p_srv_id.blank?
            Server.delete_all(:server_type => "sip_proxy")
            Device.delete_all(:name => "mor_server_" + p_srv_id.to_s)
          end

          # CCL off - All devices with more than 1 server (or is a sip+dynamic combo) gets assigned to default asterisk server, duplicates removed.
          dups = []
          @sd.each do |s|
            dup_count = ServerDevice.select("count(*) as how_many").where(:device_id => s.device_id.to_s).first.how_many.to_i rescue 0
            dev = Device.where(:id => s.device_id.to_s).first

            if dev.device_type.to_s == "SIP" and dev.proxy_port.to_i == 0 and dev.name.include?('ipauth')
              dev.proxy_port = Device::DefaultPort["SIP"]
              dev.save(:validate => false)
            end

            if dups.include?(s.device_id)
              s.delete
            elsif dup_count > 1 or (dev.host.to_s == "dynamic" and dev.device_type.to_s == "SIP")
              if @resellers_devices.include?(dev)
                s.server_id = reseller_server
              else
                s.server_id = def_asterisk.to_s
              end
              if s.save
                dups << s.device_id
              else
                serv_error =s.errors
              end
            end
            if (dev.server_id != s.server_id) or (dev.host.to_s == "dynamic" and dev.device_type.to_s == "SIP")
              if dev.host.to_s == "dynamic" and dev.device_type.to_s == "SIP"
                dev.insecure = 'no'
              end
              if dev.server_id != s.server_id
                dev.server_id = s.server_id
              end
              dev.save
            end
          end
          @sp.each do |p|
            prov = Provider.where("id = #{p.provider_id}").first
            prov_dev = Device.where("id = #{prov.device_id}").first
            if prov_dev.proxy_port == 0 and prov_dev.device_type == "SIP"
              prov.port = prov_dev.port
              prov_dev.proxy_port = prov_dev.port
              prov_dev.save(:validate => false)
              prov.save(:validate => false)
            end
          end

          Confline.set_value("CCL_Active", ccl.to_i)
          flash[:status] = "CCL turned off"
          redirect_to :action => :additional_modules and return true

        elsif ccl.to_i == 1

          ip = params[:ip_address]
          host = params[:host]

          if ip.blank? or !check_ip_validity(ip) or not Server.where(server_ip: ip).count.zero?
            flash[:notice] = _('Incorrect_Server_IP')
            redirect_to :action => :additional_modules and return false
          elsif host.blank? or !check_hostname_validity(host) or not Server.where(hostname: host).count.zero?
            flash[:notice] = _('Incorrect_Host')
            redirect_to :action => :additional_modules and return false
          else

            old_id = Server.select("MAX(server_id) AS last_old_id").first.last_old_id rescue 0
            new_id = old_id.to_i + 1

            created_server = Server.new(:server_id => new_id, :server_ip => ip, :hostname => host, :server_type => "sip_proxy", :comment => "SIP Proxy", :active => 1 )

            if (created_server.save rescue false) and
              Device.where(:name => "mor_server_" + new_id.to_s).update_all(:nat => "yes", :allow => "alaw;g729;ulaw;g723;g726;gsm;ilbc;lpc10;speex;adpcm;slin;g722")

              @sd.each do |d|
                 cur_dev = Device.where(:id => d.device_id.to_s).first
                 if cur_dev and cur_dev.host.to_s == "dynamic" and cur_dev.device_type.to_s == "SIP"
                   d.server_id = created_server.id
                   d.save
                   cur_dev.insecure = 'port,invite'
                   cur_dev.save
                 end
              end

              Confline.set_value("CCL_Active", ccl.to_i)

              flash[:status] = "CCL activated"
              redirect_to :action => :additional_modules and return true

            else
              flash[:notice] = created_server.errors.values.first.first
              redirect_to :action => :additional_modules and return false
            end

          end
        else
            flash[:notice] = "Failed to update"
            redirect_to :action => :additional_modules and return false
        end


    end
    redirect_to :action => :additional_modules
  end

  private

  def check_devices_for_accountcode
    ActiveRecord::Base.connection.execute("UPDATE devices set accountcode = id WHERE accountcode = 0;")
  end

  def active_heartbeat_server
    heartbeat_ip = Confline.get_value('Heartbeat_IP').to_s
    remote_ip = `/sbin/ifconfig | grep '#{heartbeat_ip} '`

    if !heartbeat_ip.blank? and remote_ip.to_s.length == 0
      render :text => "Heartbeat IP incorrect" and return false
    end

    return true
  end

  # saves users balances at the end of the month to use them in future in invoices to show users how much they owe to system owner
  def save_user_balances(year, month)

    @year = year.to_i
    @month = month.to_i

    date = "#{@year.to_s}-#{@month.to_s}"

    if months_between(Time.mktime(@year, @month, "01").to_date, Time.now.to_date) < 0
      render :text => "Date is in future" and return false
    end

    users = User.all

    # check all users for actions, if action not present - create new one and save users balance
    for user in users
      old_action = Action.where(:data => date, :user_id => user.id).first
      if not old_action
        MorLog.my_debug("Creating new action user_balance_at_month_end for user with id: #{user.id}, balance: #{user.raw_balance}")
        Action.add_action_hash(user, {action: 'user_balance_at_month_end', data: date, data2: user.raw_balance.to_s, data3: Currency.get_default.name})
      else
        MorLog.my_debug("Action user_balance_at_month_end for user with id: #{user.id} present already, balance: #{old_action.data2}")
      end
    end

  end


  def pay_subscriptions(year, month, day=nil, is_a_day=nil)
    email_body = []
    email_body_reseller = []
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    @year = year.to_i
    @month = month.to_i
    @day = day ? day.to_i : 1
    send = false

    if not day and months_between(Time.mktime(@year, @month, @day).to_date, Time.now.to_date) < 0
      render :text => "Date is in future" and return false
    end
    email_body << "Charging for subscriptions.\nDate: #{@year}-#{@month}\n"
    email_body_reseller << "========================================\nSubscriptions of Reseller's Users"

    @users = User.where('blocked != 1 AND subscriptions.id IS NOT NULL').includes(:tax, :subscriptions).order('users.owner_id ASC').all
    generation_time = Time.now
    doc.subscriptions() {
      doc.year(@year)
      doc.month(@month)
      doc.day(@day) if day
      @users.each_with_index { |user, i|
        user_time = Time.now
        subscriptions = user.pay_subscriptions(@year, @month, day, is_a_day)
        if subscriptions.size > 0
          doc.user(:username => user.username, :user_id => user.id, :first_name => user.first_name, :balance => user.balance, :user_type => user.user_type) {
            send = true
            email_body << "#{i+1} User: #{nice_user(user)}(#{user.username}):"   if user.owner_id.to_i == 0
            email_body_reseller << "#{i+1} User: #{nice_user(user)}(#{user.username}):"     if user.owner_id.to_i != 0
            doc.blocked("true") if user.blocked.to_i == 1
            email_body << "  User was blocked." if user.blocked.to_i == 1  and user.owner_id.to_i == 0
            email_body_reseller <<   "  User was blocked." if user.blocked.to_i == 1 and user.owner_id.to_i != 0
            subscriptions.each { |sub_hash|
              email_body << "  Service: #{sub_hash[:subscription].service.name} - #{nice_number(sub_hash[:price])}"
              doc.subscription {
                doc.service(sub_hash[:subscription].service.name)
                doc.price(nice_number(sub_hash[:price]))
              }
            }
            email_body << ""  if user.owner_id.to_i == 0
            email_body_reseller <<  ""  if user.owner_id.to_i != 0
            doc.balance_left(nice_number(user.balance))
          }
        end

        logger.debug "User time: #{Time.now - user_time}"
      }
    }
    logger.debug("Generation took: #{Time.now - generation_time}")
    email_body +=  email_body_reseller if email_body_reseller and email_body_reseller.size.to_i > 0
    if send
      email_time = Time.now
      email = Email.new(:body => email_body.join("\n"), :subject => "subscriptions report", :format => "plain", :id => "subscriptions report")
      EmailsController::send_email(email, Confline.get_value("Email_from", 0), [User.where(:id => 0).first], {:owner => 0})
      logger.debug("Email took: #{Time.now - email_time}")
    end
    if session[:usertype] == "admin"
      render :xml => out_string
    else
      render :text => ""
    end
  end

  def delete_files_after_csv_import
    MorLog.my_debug('delete_files_after_csv_import', 1)
    select = []
    select << "SELECT table_name"
    select << "FROM   INFORMATION_SCHEMA.TABLES"
    select << "WHERE  table_schema = 'mor' AND"
    select << "       table_name like 'import%' AND"
    select << "       create_time < ADDDATE(NOW(), INTERVAL -1 DAY);"
    tables = ActiveRecord::Base.connection.select_all(select.join(' '))
    if tables
      tables.each { |t|
        MorLog.my_debug("Found table : #{t['table_name']}", 1)
        Tariff.clean_after_import(t['table_name'])
      }
    end
  end


  def update_currencies
    begin
      Currency.transaction do
        my_debug('Trying to update currencies')
        notice = Currency.update_currency_rates
        if notice
          my_debug('Currencies updated')
        else
          my_debug("Currencies NOT updated. Yahoo closed the connection before the transaction was completed.")
        end
      end
    rescue Exception => e
      my_debug(e)
      my_debug("Currencies NOT updated")
      return false
    end
  end

  def backups_hourly_cronjob
    redirect_to :controller => 'backups', :action => 'backups_hourly_cronjob'
  end

  def block_users
    date = Time.now.strftime("%Y-%m-%d")
    #my_debug date
    users = User.where(:block_at => date).all
    #my_debug users.size if users
    for user in users
      user.blocked = 1
      user.save
    end
    my_debug('Users for blocking checked')
  end

  def block_users_conditional
    day = Time.now.day
    #my_debug day
    users = User.where("block_at_conditional = '#{day}' AND balance < 0 AND postpaid = 1 AND block_conditional_use = '1'").all
    #my_debug users.size if users
    for user in users

      invoices = Invoice.where("user_id = #{user.id} AND paid = 0").count
      #my_debug "not paid invoices: #{invoices}"

      if invoices > 0
        user.blocked = 1
        user.save
      end

    end
    my_debug('Users for conditional blocking checked')
  end

  def send_balance_warning

    enable_debug = 1

    users = User.includes(:address).where("warning_email_active = '1' AND ( (warning_email_sent = '0' AND warning_email_hour = '-1') or ( warning_email_hour = '#{Time.now().hour.to_i}')) AND balance < warning_email_balance").all
    if users.size.to_i > 0
      for user in users
        if enable_debug == 1
          MorLog.my_debug("Need to send warning_balance email to: #{user.id} #{user.username} #{user.email}")
        end
        email= Email.where(:name => 'warning_balance_email', :owner_id => user.owner_id).first
        unless email
          owner = user.owner
          if owner.usertype == "reseller"
            owner.check_reseller_emails
            email= Email.where(:name => 'warning_balance_email', :owner_id => user.owner_id).first
          end
        end
        variables = email_variables(user)
        begin
          @num = EmailsController::send_email(email, Confline.get_value("Email_from", user.owner_id), [user], variables)
          if @num.to_s == _('Email_sent')+"<br>"
            Action.add_action_hash(user.owner_id, {:action => "warning_balance_send", :data => user.id, :data2 => email.id})
            if enable_debug == 1
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username} #{user.email}")
            end
            user.update_attribute(:warning_email_sent, 1)
          end
        rescue Exception => exception
          if enable_debug == 1
            MorLog.my_debug("warning_balance email not sent to: #{user.id} #{user.username} #{user.email}, because: #{exception.message.to_s}")
          end
          Action.new(:user_id => user.owner_id, :target_id => user.id, :target_type => "user", :date => Time.now.to_s(:db), :action => "error", :data => 'Cant_send_email', :data2 => exception.message.to_s).save
        end
      end
    else
      if enable_debug == 1
        MorLog.my_debug("No users to send warning email balance")
      end
    end
    MorLog.my_debug("Sent balance warning action finished")
  end


  def find_registration_owner
    unless params[:id] and (@owner = User.where(:uniquehash => params[:id]).first)
      dont_be_so_smart
      redirect_to :action => "login" and return false
    end

    if Confline.get_value("Registration_enabled", @owner.id).to_i == 0
      dont_be_so_smart
      redirect_to :action => "login" and return false
    end
  end
end
