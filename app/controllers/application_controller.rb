# -*- encoding : utf-8 -*-
class ApplicationController < ActionController::Base

  require 'builder/xmlbase'


  if !Rails.env.development?
    rescue_from Exception do |exc|
      #log_exception_handler(exc) and return false
      logger.fatal exc.to_yaml
      logger.fatal exc.backtrace.collect { |t| t.to_s }.join("\n")
      if params[:controller].to_s == 'api'
        doc = Builder::XmlMarkup.new(:target => out_string4 = "", :indent => 2)
        doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
        doc = API.return_error(my_rescue_action_in_public(exc).to_s, doc)
        if params[:test].to_i == 1
          render :text => out_string4 and return false
        else
          if confline("XML_API_Extension").to_i == 1
            send_data(out_string4, :type => "text/xml", :filename => "mor_api_response.xml")    and return false
          else
            send_data(out_string4, :type => "text/html", :filename => "mor_api_response.html")  and return false
          end
        end
      else
      if !params[:this_is_fake_exception] and session
        if session[:flash_not_redirect].to_i == 0
          my_rescue_action_in_public(exc)
          redirect_to :controller => :callc, :action => :main and return false
        else
          my_rescue_action_in_public(exc)
          render(:layout => "layouts/mor_min") and return false
        end
      else
        render :text => my_rescue_action_in_public(exc)
      end
      end
    end
  end

  rescue_from ActiveRecord::RecordNotFound, :with => :action_missing
  rescue_from AbstractController::ActionNotFound, :with => :action_missing
  rescue_from ActionController::RoutingError, :with => :action_missing
  rescue_from ActionController::UnknownController, :with => :action_missing
  rescue_from ActionView::MissingTemplate, :with => :template_missing
  #rescue_from ActionController::UnknownAction, :with => :action_missing

  protect_from_forgery

  include SqlExport
  include UniversalHelpers

  require 'digest/sha1'
  require 'localization.rb'
  require 'net/smtp'
  require 'enumerator'
  require 'smtp_tls'
  #require 'ruby_extensions'
  require "net/http"


  Localization.load

  # Pick a unique cookie name to distinguish our session data from others'
  # session :session_key => '_mor_session_id'

  helper_method :convert_curr, :see_providers_in_dids?, :allow_manage_providers?, :allow_manage_dids?, :allow_manage_providers_tariffs?, :correct_owner_id, :pagination_array, :invoice_state, :nice_invoice_number, :nice_invoice_number_digits, :current_user, :can_see_finances?, :hide_finances, :render_email, :session_from_datetime_array, :session_till_datetime_array, :accountant_can_write?, :accountant_can_read?, :nice_date, :nice_date_time, :monitoring_enabled_for, :rs_active?, :rec_active?, :cc_active?, :ad_active?, :ccl_active?, :is_number?, :is_numeric?

  # addons
  helper_method :callback_active?, :call_shop_active?, :reseller_active?, :payment_gateway_active?, :calling_cards_active?, :sms_active?, :recordings_addon_active?, :monitorings_addon_active?, :skp_active?
  helper_method :erp_active?, :admin?, :reseller?, :user?, :accountant?, :reseller_pro_active?, :show_recordings?, :ast_18?, :provider_billing_active?, :providers_enabled_for_reseller?, :web_phone_active?, :res_campaigns?
  before_filter :log_session_size, :set_charset
  before_filter :set_current_user, :set_timezone
  before_filter :redirect_callshop_manager
  # before_filter :set_timezone

  def redirect_callshop_manager
    if current_user and current_user.is_callshop_manager?
      redirect_to :controller => "callshop", :action => "show", :id => current_user.callshop_manager_group.group_id
      return false
    end
  end

  def action_missing(m, *args, &block)
    MorLog.my_debug("Authorization failed:\n   User_type: "+session[:usertype_id].to_s+"\n   Requested: " + "#{params[:controller]}::#{params[:action]}")
    MorLog.my_debug("   Session(#{params[:controller]}_#{params[:action]}):"+ session["#{params[:controller]}_#{params[:action]}".intern].to_s)
    flash[:notice] = _('You_are_not_authorized_to_view_this_page')
    Rails.logger.error(m)
    redirect_to :controller => :callc, :action => :main
    # or render/redirect_to somewhere else
  end

  def template_missing
    redirect_to :controller => :callc, :action => :main
  end

  def log_session_size
    MorLog.log_session_size(params.inspect.to_s, request.session_options[:id]) if params[:controller].to_s != 'api' and session_log_active?
  end

  def item_pages(total_items)
    #parameters:
    #  total_items - positive integer, number of items that are going to be displayed per all pages
    #returns:
    #  items_per_page - how many items should be displayed in one page, positive integer, depends on user settings
    #  total_pages - how many pages will be needes to display items when divided per pages
    #if there's no items per session set we should save it in session for future use. after we validate id
    items_per_page = session[:items_per_page] ? session[:items_per_page].to_i : Confline.get_value("Items_Per_Page", 0).to_i
    items_per_page = items_per_page.to_i < 1 ? 1 : items_per_page.to_i
    session[:items_per_page] = items_per_page
    #currently "items per page" default value is 1, user can only set it to at least 1
    #so there's code duplication, 1 should be refactored and set as some sort of global constant
    total_pages = (total_items.to_d / items_per_page.to_d).ceil
    return items_per_page, total_pages
  end

  def valid_page_number(page_no, total_pages)
    #parameters:
    #  page_no - current page number, expected to be positive integer or 0 if total_pages is 0
    #  total_pages - expected to be not negative integer.
    #returns:
    #  page_no - validated page number, iteger, at least 1 or 0 if total pages is 0
    first_page = 1
    page_no = page_no.to_i
    page_no = page_no < first_page ? first_page : page_no
    total_pages = total_pages.to_i
    page_no = total_pages < page_no ? total_pages : page_no
  end

  def query_limit(total_items, items_per_group, item_group_number)
    #parameters:s
    #  total_items - total items returned be query, extected to be not negative integer
    #  items_per_group - items that should be returned be query count, expected to be positive integer
    #  items_group_number - eg page number, expected to be at least 1 or 0 if total items 0
    #returns:
    #  offset - not negative integer, at least 1 or 0 if total items 0
    #  limit - not negative integer
    items_per_group = items_per_group.to_i
    offset = total_items < 1 ? 0 : items_per_group * (item_group_number -1)
    limit = items_per_group
    return offset, limit
  end

  def pages_validator(options, total, page = 1)
    options[:page] = options[:page].to_i < 1 ? 1 : options[:page].to_i
    total_pages = (total.to_d / session[:items_per_page].to_d).ceil
    options[:page] = total_pages if options[:page].to_i > total_pages.to_i and total_pages.to_i > 0
    fpage = ((options[:page] -1) * session[:items_per_page]).to_i
    return fpage, total_pages, options
  end

  def convert_curr(price)
    current_user.convert_curr(price)
  end

  def set_current_user
    User.current = current_user
    User.system_time_offset = session[:time_zone_offset].to_i
  end

  def set_timezone
    Time.zone = current_user.time_zone if current_user
  end

  def set_charset
    headers["Content-Type"] = "text/html; charset=utf-8"
    session[:flash_not_redirect] = 0 if session
  end

  #def adjust_json_formatting
  #  ActiveSupport::JSON.unquote_hash_key_identifiers = false
  #  true
  #end

  def mobile_standard
    if request.env["HTTP_X_MOBILE_GATEWAY"]
      out = nil
    else

      #  request.env["HTTP_USER_AGENT"].match("iPhone") ? "mobile" : "callc"
      if session[:layout_t]
        if session[:layout_t].to_s == "mini"

          if request.env["HTTP_USER_AGENT"].to_s.match("iPhone")
            out = "iphone"
          end
        end
        if session[:layout_t].to_s == "full" or session[:layout_t].to_s == nil
          out = "callc"
        end
        if session[:layout_t].to_s == "callcenter"
          out = "callcenter"
        end
      else
        if !(request.env["HTTP_USER_AGENT"].to_s.match("iPhone") or request.env["HTTP_USER_AGENT"].to_s.match("iPod"))
          out = "callc"
        end
        if  request.env["HTTP_USER_AGENT"].to_s.match("iPhone")
          out = "iphone"
        end
      end
    end
    return out
  end

  def invoice_params_for_user
    @i1=params[:i1]
    @i2=params[:i2]
    @i3=params[:i3]
    @i4=params[:i4]
    @i5=params[:i5]
    @i6=params[:i6]
    @i7=params[:i7]
    @i8=params[:i8]
    invoice = @i1.to_i+@i2.to_i+@i3.to_i+@i4.to_i+@i5.to_i+@i6.to_i+@i7.to_i+@i8.to_i
    return invoice
  end

  # this function exchanges calls table fields user_price with reseller_price to fix major flaw in MORs' database design prior MOR 0.8
  # this function should NEVER be used! it is made just for testing purposes!
  def exchange_user_to_reseller_calls_table_values
    if Confline.get_value2("Calls_table_fixed", 0).to_i == 0

      sql = "UPDATE calls SET partner_price = user_price;"
      ActiveRecord::Base.connection.update(sql)
      sql = "UPDATE calls SET user_price = reseller_price;"
      ActiveRecord::Base.connection.update(sql)
      sql = "UPDATE calls SET reseller_price = partner_price;"
      ActiveRecord::Base.connection.update(sql)
      sql = "UPDATE calls SET partner_price = NULL"
      ActiveRecord::Base.connection.update(sql)

      Confline.set_value2("Calls_table_fixed", 1, 0)
    else
      flash[:notice] = "Calls table already fixed. Not fixing again."
    end
  end

  def show_agent_progress
    if session[:user_id]
      if !session[:user_cc_agent]
        agent = User.where(:id => session[:user_id]).first
        session[:user_cc_agent] = agent.call_center_agent
      end
      if session[:user_cc_agent].to_i == 1
        count = CcTask.get_calls_count(session[:user_id])
        @total_expected = count["total_calls"].to_i
        @day_expected = count["calls_per_day"].to_i
        calls = CcTask.get_good_calls_count(session[:user_id])
        @total_made = calls["god_calls"].to_i
        calls2 = CcTask.get_good_calls_count(session[:user_id], true)

        @day_made = calls2["god_calls"].to_i
        @total_expected==0 ? @total_percent = 0 : @total_percent = (@total_made*100/@total_expected).to_i
        @day_expected == 0 ? @today_percent = 0 : @today_percent = (@day_made*100/@day_expected).to_i
        @Callscenter_graph = _('total_calls') + " #{@total_made} / #{@total_expected} " +";" + @total_percent.to_s + "\\n"
        @Callscenter_graph += _('calls_per_day') + " #{@day_made} / #{@day_expected} " + ";" + @today_percent.to_s + "\\n"
      end
    end
  end

  # puts correct language
  def check_localization
    # ---- language ------
    if params[:lang] && Localization.l10s.has_key?(params[:lang]) # check wether such translation is present in lang/* translation files.
      Localization.lang = params[:lang]
      session[:lang] = params[:lang]
      ActiveProcessor.configuration.language = params[:lang]
                                                                  #           flash[:notice] = _('Your_language_changed_to')
    else
      if session[:lang]
        Localization.lang = session[:lang]
        ActiveProcessor.configuration.language = session[:lang]
      else
        if current_user
          translation = current_user.default_translation
        else
          user_tr = UserTranslation.where(:active => 1, :user_id => 0).includes(:translation).order("position ASC").first
          translation = user_tr.translation if user_tr
        end

        df = (translation ? translation.short_name : "en")
        Localization.lang = df #Default_Language #default language
        session[:lang] = df
        ActiveProcessor.configuration.language = df
      end
    end

    flags_to_session if !session[:tr_arr]

    # ---- currency ------
    if params[:currency]
      if curr = Currency.where(:name => params[:currency].gsub(/[^A-Za-z]/, '')).first
        session[:show_currency] = curr.name
      end
    end

    t = test_machine_active? ? (Time.now - 3.year) : Time.now

    # ---- items per page -----
    session[:items_per_page] = 1 if session[:items_per_page].to_i < 1

    if current_user
      session[:year_from] = current_user.user_time(t).year if session[:year_from].to_i == 0
      session[:month_from] = current_user.user_time(t).month if session[:month_from].to_i == 0
      session[:day_from] = current_user.user_time(t).day if session[:day_from].to_i == 0

      session[:year_till] = current_user.user_time(t).year if session[:year_till].to_i == 0
      session[:month_till] = current_user.user_time(t).month if session[:month_till].to_i == 0
      session[:day_till] = current_user.user_time(t).day if session[:day_till].to_i == 0
    else
      session[:year_from] = t.year if session[:year_from].to_i == 0
      session[:month_from] = t.month if session[:month_from].to_i == 0
      session[:day_from] = t.day if session[:day_from].to_i == 0

      session[:year_till] = t.year if session[:year_till].to_i == 0
      session[:month_till] = t.month if session[:month_till].to_i == 0
      session[:day_till] = t.day if session[:day_till].to_i == 0
    end
  end

  #not working - why?
  def disable_get
    if request.get?
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  # Method to store all HangupCauseCodes in session. Possible uses : before massive hangupcausecodes analysis or on session start
  def store_codes_in_session
    codes = Hangupcausecode.all
    for code in codes do
      session["hangup#{code.code.to_i}".intern] = code.description
    end
  end

  def authorize
    if session[:usertype].to_s != "admin" 
      c = controller_name.to_s.gsub(/"|'|\\/, '')
      a = action_name.to_s.gsub(/"|'|\\/, '')
      if !session["#{c}_#{a}".intern] or
          session["#{c}_#{a}".intern].class != Fixnum or
          session["#{c}_#{a}".intern].to_i != 1
        # handle guests
        if !session[:usertype_id] or session[:usertype] == "guest" or session[:usertype].to_s == ""
          session[:usertype_id] = Role.where(:name => 'guest').first.id
          session[:usertype] = "guest"
        end
        roleright = RoleRight.get_authorization(session[:usertype_id], c, a).to_i
        session["#{c}_#{a}".intern] = roleright
      end
      if session["#{c}_#{a}".intern].to_i != 1
        MorLog.my_debug("Authorization failed:\n   User_type: "+session[:usertype_id].to_s+"\n   Requested: " + "#{c}::#{a}")
        MorLog.my_debug("   Session(#{c}_#{a}):"+ session["#{c}_#{a}".intern].to_s)
        if params[:lang]  and  !params[:lang].blank?
        Localization.lang = params[:lang]
        end
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
        if session[:user_id] != nil
          redirect_to :controller => "callc", :action => "main" and return false
        else
          redirect_to :controller => "callc", :action => "login" and return false
        end
      end
    end
  end

  def check_calingcards_enabled
    unless cc_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :controller => "callc", :action => "login" and return false
    end
  end

  def check_read_write_permission(view = [], edit = [], options= {})
    options[:ignore] ||= false
    if session[:usertype] == options[:role]
      action = params[:action].to_sym
      problem = 0
      problem = 1 if (edit.include?(action) and session[options[:right]].to_i != 2)
      problem = 2 if (view.include?(action) and session[options[:right]].to_i == 0)
      problem = 3 if (!(view+edit).include?(action) and !options[:ignore])
      if problem > 0
        MorLog.my_debug("  >> Problems? #{problem}")
        flash[:notice] = [nil, _('You_have_no_editing_permission'), _('You_have_no_view_permission'), _('You_have_no_permission')][problem]
        redirect_to :controller => :callc, :action => :main
        return false, false
      end
      return session[options[:right]].to_i > 0, session[options[:right]].to_i == 2
    else
      return true, true
    end
  end

  def authorize_admin
    if session[:usertype] != "admin"
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      if session[:user_id] != nil
        redirect_to :controller => "callc", :action => "main" and return false
      else
        redirect_to :controller => "callc", :action => "login" and return false
      end
    end
  end

  def authorize_reseller
    if session[:usertype] != "admin" and session[:usertype] != "reseller"
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :controller => "callc", :action => "login" and return false
    end
  end

  def today
    current_user.user_time(Time.now).strftime("%Y-%m-%d")
  end

  def add_action (user_id, action, data, action_cache = nil)
    if user_id
      if action_cache
        action_cache.add("NULL, '#{data}', NULL, NULL, '#{action}', '#{Time.now.to_s(:db)}', 0, #{user_id}, NULL, ''")
      else
        Action.new(:date => Time.now, :user_id => user_id, :action => action, :data => data).save
      end
    end
  end

  def add_action2 (user_id, action, data, data2)
    if user_id
      act = Action.new
      act.date = Time.now
      act.user_id = user_id
      act.action = action
      act.data = data
      if data2
        act.data2 = data2
      end
      act.save
    end
  end

  def change_date_to_present
    t = current_user.user_time(Time.now)
    session[:year_from], session[:month_from], session[:day_from], session[:hour_from], session[:minute_from] = t.year, t.month, t.day, 0, 0
    session[:year_till], session[:month_till], session[:day_till], session[:hour_till], session[:minute_till] = t.year, t.month, t.day, 23, 59
  end

  def change_date_from
    if params[:date_from]
      if params[:date_from][:year].to_i > 1000 # dirty hack to prevent ajax trashed params error
        session[:year_from] = params[:date_from][:year]
        session[:month_from] = params[:date_from][:month].to_i <= 0 ? 1 : params[:date_from][:month].to_i

        if params[:date_from][:day].to_i < 1
          params[:date_from][:day] = 1
        else
          if !Date.valid_civil?(session[:year_from].to_i, session[:month_from].to_i, params[:date_from][:day].to_i)
            params[:date_from][:day] = last_day_of_month(session[:year_from], session[:month_from])
          end
        end

        session[:day_from] = params[:date_from][:day]
        session[:hour_from] = params[:date_from][:hour] if params[:date_from][:hour]
        session[:minute_from] = params[:date_from][:minute] if params[:date_from][:minute]
      end
    end
    if not session[:year_from]
      t = current_user.user_time(Time.now)
      session[:year_from] = t.year
      session[:month_from] = t.month
      session[:day_from] = t.day
      session[:hour_from] = t.hour
      session[:minute_from] = t.min
    end
  end

  def change_date_till
    if params[:date_till]
      if params[:date_from][:year].to_i > 1000 # dirty hack to prevent ajax trashed params error
        session[:year_till] = params[:date_till][:year]
        session[:month_till] = params[:date_till][:month].to_i <= 0 ? 1 : params[:date_till][:month].to_i

        if params[:date_till][:day].to_i < 1
          params[:date_till][:day] = 1
        else
          if !Date.valid_civil?(session[:year_till].to_i, session[:month_till].to_i, params[:date_till][:day].to_i)
            params[:date_till][:day] = last_day_of_month(session[:year_till], session[:month_till])
          end
        end

        session[:day_till] = params[:date_till][:day]
        session[:hour_till] = params[:date_till][:hour] if params[:date_till][:hour]
        session[:minute_till] = params[:date_till][:minute] if params[:date_till][:minute]
      end
    end

    if not session[:year_till]
      t = current_user.user_time(Time.now)
      session[:year_till] = t.year
      session[:month_till] = t.month
      session[:day_till] = t.day
      session[:hour_till] = t.hour
      session[:minute_till] = t.min
    end
  end

  def change_date
    change_date_from
    change_date_till

    #    MorLog.my_debug "-----------------\nfromd:#{session_from_date}-tilld:#{session_till_date}"
    #    MorLog.my_debug "fromt:#{session_from_datetime}-tillt:#{session_till_datetime}"
    if Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
      flash[:notice] = _("Date_from_greater_thant_date_till")
    end
    current_user_session_time
  end

  def current_user_session_time
    cust_from = Time.mktime(session[:year_from], session[:month_from], session[:day_from], session[:hour_from], session[:minute_from])
    cust_till = Time.mktime(session[:year_till], session[:month_till], session[:day_till], session[:hour_till], session[:minute_till])

    session[:current_user_time_from]=current_user.system_time(cust_from)
    session[:current_user_time_till]=current_user.system_time(cust_till)
  end

  def change_date_no_offset
    change_date
  end

  def random_password(size = 12)
    chars = (('a'..'z').to_a + (0..9).to_a) - %w(i o 0 1 l 0)
    (1..size).collect { |a| chars[rand(chars.size)] }.join
  end

  def ApplicationController::random_password(size = 12)
    chars = (('a'..'z').to_a + (0..9).to_a) - %w(i o 0 1 l 0)
    (1..size).collect { |a| chars[rand(chars.size)] }.join
  end

  def random_digit_password(size = 8)
    chars = ((0..9).to_a)
    (1..size).collect { |a| chars[rand(chars.size)] }.join
  end

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  #put value into file for debugging
  def my_debug_time(msg)
    MorLog.my_debug(msg, true, "%Y-%m-%d %H:%M:%S")
  end

  # done once in a while to check some functions, like did releasing, invoice counting and so on
  def global_check

    #did release checking
    dids = Did.closed.all
    for did in dids
      if did.closed_till < Time.now
        did.status = "free"
        did.user_id = 0
        did.device_id = 0
        did.save
      end
    end
  end

  # enables or disables devices based on user login status
  def check_devices


  end

  # enables or disables devices based on user login status
  def check_devices2(id)

  end

  # enables or disables device based on works_not_logged status
  def check_context(device)

    dev = device

    dev
  end


  #function for configuring extensions based on passed arguments
  def configure_extensions(device_id, options = {})
    @device = Device.where(:id => device_id).first

    return if !@device || device_id == 0

    default_context = "mor_local"
    default_app = "Dial"

    busy_extension = 201
    no_answer_extension = 401
    chanunavail_extension = 301


    @user = User.where(:id => @device.user_id).first if @device.user_id.to_i > -1

    user_id = 0
    user_id = @device.user.id if @user

    timeout = @device.timeout

    if @device
      #delete old config
      #Extline.destroy_all ["device_id = ?", device_id]
      ActiveRecord::Base.connection.delete("DELETE `extlines`.* FROM `extlines` WHERE `extlines`.`device_id` = #{device_id}")

      i = 1


      #configuring for incoming calls for extension

      # set custom userfield - no use for it now
      #Extension.mcreate(default_context, i, "Set", "CDR(userfield)=" + @conn.extension, conn_type, conn_id)
      #i += 1

      # blocked numbers

      #			for bn in @device.blocked_numbers
      #				Extline.mcreate(default_context, i, "GotoIf", "$[\"${CALLERIDNUM}\" = \"" + bn.number + "\"]?"+busy_ext.to_s, device_id)
      #				i += 1
      #			end

      # Handling BUSY from DID limited calls
      Extline.mcreate(default_context, i, "NoOp", "${MOR_MAKE_BUSY}", @device.extension, device_id)
      i+=1
      Extline.mcreate(default_context, i, "GotoIf", "$[\"${MOR_MAKE_BUSY}\" = \"1\"]?201", @device.extension, device_id)
      i+=1

      # Handling transfers
      Extline.mcreate(default_context, i, "GotoIf", "$[${LEN(${CALLED_TO})} > 0]?" + (i+1).to_s + ":" + (i+3).to_s, @device.extension, device_id)
      i+=1
      #            Extline.mcreate(default_context, i, "Set", "CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}", @device.extension, device_id)
      Extline.mcreate(default_context, i, "NoOp", "CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}", @device.extension, device_id)
      i+=1
      Extline.mcreate(default_context, i, "Goto", @device.extension.to_s + "|" + (i+2).to_s, @device.extension, device_id)
      i+=1
      Extline.mcreate(default_context, i, "Set", "CALLED_TO=${EXTEN}", @device.extension, device_id)
      i+=1


      #======================  B E F O R E   C A L L  ======================
      before_call_cfs = Callflow.where("cf_type = 'before_call' AND device_id = #{@device.id}").order("priority ASC")
      for cf in before_call_cfs

        case cf.action
          when "forward"

            # --------- start forward callerid change ------------

            case cf.data3
              when 1
                forward_callerid = cid_number(@device.callerid)
              when 2
                forward_callerid = ""
              when 3
                found_did = Did.where(:id => cf.data4).first
                forward_callerid = found_did.did if found_did
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 and forward_callerid.to_s.length > 0 #callerid does not changes
              Extline.mcreate(default_context, i, "Set", "CALLERID(num)=#{forward_callerid}", @device.extension, device_id)
              i+=1
            end

            # --------- end forward callerid change ------------

            case cf.data2
              when "local"
                dev = Device.where(:id => cf.data).first
                if dev
                  Extline.mcreate(default_context, i, "Goto", "#{dev.extension}|1", @device.extension, device_id)
                  i+=1
                end
              when "external"
                Extline.mcreate(default_context, i, "Set", "CDR(ACCOUNTCODE)=#{device_id}", @device.extension, device_id)
                i+=1
                Extline.mcreate(default_context, i, "Goto", "mor|#{cf.data}|1", @device.extension, device_id)
                i+=1
            end #case cf.data2

          when "voicemail"

            Extline.mcreate(default_context, i, "Set", 'MOR_VM=', @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, "Goto", 'mor_voicemail|${EXTEN}|1', @device.extension, device_id)
            i += 1

          when "fax_detect"

            if  cf.data.to_i > 0

              from_sender = Confline.get_value("Email_Fax_From_Sender")

              Extline.mcreate(default_context, i, "Set", "FROM_SENDER=#{from_sender}", @device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, "Set", "MOR_FAX_ID=#{cf.data}", @device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, "Set", "FAXSENDER=${CALLERID(number)}", @device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, "Answer", "", @device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, "Playtones", "ring", @device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, "NVFaxDetect", "4", @device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, "StopPlaytones", "", @device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, "ResetCDR", "", @device.extension, device_id)
              i += 1
            end


        end #case cf.action

      end
      #=========================================================

      if @device.device_type != "FAX"

        # forward
        #if @device.forward_to != 0
        #if @fwd_extension = Device.find(@device.forward_to).extension
        #  Extline.mcreate(default_context, i, "Goto", @fwd_extension.to_s+"|1", @device.extension, device_id)
        # i+=1
        #end
        #end

        # recordings

        Extline.mcreate(default_context, i, "NoOp", "MOR starts", @device.extension, device_id)
        i += 1

        # Handling CALLERID NAME
        Extline.mcreate(default_context, i, "GotoIf", "$[${LEN(${CALLERID(NAME)})} > 0]?" + (i+3).to_s + ":" + (i+1).to_s, @device.extension, device_id)
        i+=1
        Extline.mcreate(default_context, i, "GotoIf", "$[${LEN(${mor_cid_name})} > 0]?" + (i+1).to_s + ":" + (i+2).to_s, @device.extension, device_id)
        i+=1
        Extline.mcreate(default_context, i, "Set", "CALLERID(NAME)=${mor_cid_name}", @device.extension, device_id)
        i+=1


        # handling CallerID by ANI (if available)
        if @device.use_ani_for_cli == true
          Extline.mcreate(default_context, i, "GotoIf", "$[${LEN(${CALLERID(ANI)})} > 0]?" + (i+1).to_s + ":" + (i+2).to_s, @device.extension, device_id)
          i+=1
          Extline.mcreate(default_context, i, "Set", "CALLERID(NUM)=${CALLERID(ANI)}", @device.extension, device_id)
          i+=1
        end


        #handling calleridpres
        if @device.calleridpres.to_s.length > 0
          if ast_18?
            Extline.mcreate(default_context, i, "Set", "CALLERID(name-pres)=#{@device.calleridpres.to_s}", @device.extension, device_id)
            Extline.mcreate(default_context, i, "Set", "CALLERID(num-pres)=#{@device.calleridpres.to_s}", @device.extension, device_id)
          else
            Extline.mcreate(default_context, i, "SetCallerPres", @device.calleridpres.to_s, @device.extension, device_id)
          end
          i+=1
        end


        # normal path

        # SIP Proxy support
        if ccl_active? and @device.device_type.to_s == "SIP" and @device.host.to_s == "dynamic"
          
          sip_proxy = Server.where('server_type = "sip_proxy"').first
          if sip_proxy
            Extline.mcreate(default_context, i, default_app, "SIP/mor_server_" + sip_proxy.server_id.to_s + "/" + @device.name + "," + @device.timeout.to_s, @device.extension, device_id)
          end
        
        else

          # normal call-flow without sip-proxy
          # Trunk support
          trunk = ""
          if @device.istrunk == 1
            Extline.mcreate(default_context, i, "GotoIf", "$[${LEN(${MOR_DID})} > 0]?" + "#{i+1}:#{i+3}", @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, default_app, @device.device_type + "/" + @device.name + "/${MOR_DID}", @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, "Goto", "#{i+2}", @device.extension, device_id)
            i += 1
            trunk = "/${EXTEN}"
          end
          # end trunk support
          Extline.mcreate(default_context, i, default_app, @device.device_type + "/" + @device.name + trunk + "|#{timeout.to_s}", @device.extension, device_id)

        end # sip proxy support
        
        
        busy_ext = 200 + i
        i += 1
        Extline.mcreate(default_context, i, "GotoIf", "$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]|$[\"${DIALSTATUS}\" = \"CONGESTION\"]]?" + chanunavail_extension.to_s, @device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, "GotoIf", "$[\"${DIALSTATUS}\" = \"BUSY\"]?" + busy_extension.to_s, @device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, "GotoIf", "$[\"${DIALSTATUS}\" = \"NOANSWER\"]?" + no_answer_extension.to_s, @device.extension, device_id)

        i += 1
        Extline.mcreate(default_context, i, "Hangup", "", @device.extension, device_id)

      else

        #fax2email

        Extline.mcreate(default_context, i, "Set", "MOR_FAX_ID=#{@device.id}", @device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, "Set", "FAXSENDER=${CALLERID(number)}", @device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, "Goto", "mor_fax2email|${EXTEN}|1", @device.extension, device_id)
        i += 1

      end

      #======================  N O   A N S W E R  ======================
      i = no_answer_extension

      Extline.mcreate(default_context, i, "NoOp", "NO ANSWER", @device.extension, device_id)
      i+=1

      no_answer_cfs = Callflow.where("cf_type = 'no_answer' AND device_id = #{@device.id}").order("priority ASC")
      for cf in no_answer_cfs

        case cf.action
          when "forward"

            # --------- start forward callerid change ------------

            case cf.data3
              when 1
                forward_callerid = cid_number(@device.callerid)
              when 2
                forward_callerid = ""
              when 3
                forward_callerid = Did.where(:id => cf.data4).first.did
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 and forward_callerid.to_s.length > 0 #callerid does not changes
              Extline.mcreate(default_context, i, "Set", "CALLERID(num)=#{forward_callerid}", @device.extension, device_id)
              i+=1
            end

            # --------- end forward callerid change ------------

            case cf.data2
              when "local"
                dev = Device.where(:id => cf.data).first
                if dev
                  Extline.mcreate(default_context, i, "Goto", "#{dev.extension}|1", @device.extension, device_id)
                  i+=1
                end
              when "external"
                Extline.mcreate(default_context, i, "Set", "CDR(ACCOUNTCODE)=#{device_id}", @device.extension, device_id)
                i+=1
                Extline.mcreate(default_context, i, "Goto", "mor|#{cf.data}|1", @device.extension, device_id)
                i+=1
              when ""
                Extline.mcreate(default_context, i, "Hangup", "", @device.extension, device_id)
            end #case cf.data2

          when "voicemail"
            #				   Extline.mcreate(default_context, i, "Voicemail", @device.extension.to_s + "|u", @device.extension, device_id)
            #                   i+=1
            #			       Extline.mcreate(default_context, i, "Hangup", "", @device.extension, device_id)

            Extline.mcreate(default_context, i, "Set", 'MOR_VM="u"', @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, "Goto", 'mor_voicemail|${EXTEN}|1', @device.extension, device_id)
            i += 1

          when "empty"
            Extline.mcreate(default_context, i, "Hangup", "", @device.extension, device_id)
        end #case cf.action

      end

      if no_answer_cfs.empty?
        Extline.mcreate(default_context, i, "Hangup", "", @device.extension, device_id)
      end
      #=========================================================


      #======================  B U S Y  ======================
      i = busy_extension

      Extline.mcreate(default_context, i, "NoOp", "BUSY", @device.extension, device_id)
      i+=1

      busy_cfs = Callflow.where(["cf_type = 'busy' AND device_id = ?", @device.id]).order("priority ASC")
      for cf in busy_cfs

        case cf.action
          when "forward"

            # --------- start forward callerid change ------------

            case cf.data3
              when 1
                forward_callerid = cid_number(@device.callerid)
              when 2
                forward_callerid = ""
              when 3
                forward_callerid = Did.where(:id => cf.data4).first.did
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 and forward_callerid.to_s.length > 0 #callerid does not changes
              Extline.mcreate(default_context, i, "Set", "CALLERID(num)=#{forward_callerid}", @device.extension, device_id)
              i+=1
            end

            # --------- end forward callerid change ------------

            case cf.data2
              when "local"
                dev = Device.where(:id => cf.data).first
                if dev
                  Extline.mcreate(default_context, i, "Goto", "#{dev.extension}|1", @device.extension, device_id)
                  i+=1
                end
              when "external"
                Extline.mcreate(default_context, i, "Set", "CDR(ACCOUNTCODE)=#{device_id}", @device.extension, device_id)
                i+=1
                Extline.mcreate(default_context, i, "Goto", "mor|#{cf.data}|1", @device.extension, device_id)
                i+=1
              when ""

                Extline.mcreate(default_context, i, "GotoIf", "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|BUSY|1", @device.extension, device_id)
                i += 1
                Extline.mcreate(default_context, i, "Busy", "10", @device.extension, device_id)
                i += 1

            end #case cf.data2

          when "voicemail"
            #				   Extline.mcreate(default_context, i, "Voicemail", @device.extension.to_s + "|b", @device.extension, device_id)
            #                   i+=1
            #			       Extline.mcreate(default_context, i, "Hangup", "", @device.extension, device_id)
            #			       i += 1

            Extline.mcreate(default_context, i, "Set", '"MOR_VM"="b"', @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, "Goto", 'mor_voicemail|${EXTEN}|1', @device.extension, device_id)
            i += 1

          when "empty"

            Extline.mcreate(default_context, i, "GotoIf", "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|BUSY|1", @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, "Busy", "10", @device.extension, device_id)
            i += 1

        end #case cf.action

      end

      if busy_cfs.empty?

        Extline.mcreate(default_context, i, "GotoIf", "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|BUSY|1", @device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, "Busy", "10", @device.extension, device_id)
        i += 1
      end
      #=========================================================


      #======================  F A I L E D  ======================
      i = chanunavail_extension

      Extline.mcreate(default_context, i, "NoOp", "FAILED", @device.extension, device_id)
      i+=1

      failed_cfs = Callflow.where(["cf_type = 'failed' AND device_id = ?",@device.id]).order("priority ASC")
      for cf in failed_cfs

        case cf.action
          when "forward"

            # --------- start forward callerid change ------------

            case cf.data3
              when 1
                forward_callerid = cid_number(@device.callerid)
              when 2
                forward_callerid = ""
              when 3
                forward_callerid = Did.where(:id => cf.data4).first.did
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 #callerid does not changes
              Extline.mcreate(default_context, i, "Set", "CALLERID(num)=#{forward_callerid}", @device.extension, device_id)
              i+=1
            end

            # --------- end forward callerid change ------------

            case cf.data2
              when "local"
                dev = Device.where(:id => cf.data).first
                if dev
                  Extline.mcreate(default_context, i, "Goto", "#{dev.extension}|1", @device.extension, device_id)
                  i+=1
                end
              when "external"
                Extline.mcreate(default_context, i, "Set", "CDR(ACCOUNTCODE)=#{device_id}", @device.extension, device_id)
                i+=1
                Extline.mcreate(default_context, i, "Goto", "mor|#{cf.data}|1", @device.extension, device_id)
                i+=1
              when ""
                Extline.mcreate(default_context, i, "GotoIf", "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|FAILED|1", @device.extension, device_id)
                i += 1
                Extline.mcreate(default_context, i, "Congestion", "4", @device.extension, device_id)
                i += 1
            end #case cf.data2

          when "voicemail"
            #				   Extline.mcreate(default_context, i, "Voicemail", @device.extension.to_s + "|u", @device.extension, device_id)
            #                   i+=1
            #			       Extline.mcreate(default_context, i, "Hangup", "", @device.extension, device_id)
            #			       i += 1

            Extline.mcreate(default_context, i, "Set", 'MOR_VM="u"', @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, "Goto", 'mor_voicemail|${EXTEN}|1', @device.extension, device_id)
            i += 1

          when "empty"

            Extline.mcreate(default_context, i, "GotoIf", "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|FAILED|1", @device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, "Congestion", "4", @device.extension, device_id)
            i += 1

        end #case cf.action

      end

      if failed_cfs.empty?
        Extline.mcreate(default_context, i, "GotoIf", "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|FAILED|1", @device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, "Congestion", "4", @device.extension, device_id)
        i += 1
      end
      #=========================================================


      # check devices login status

      dev = @device


      begin
        if dev.device_type == "SIP" or dev.device_type == "IAX2"
          exception_array = @device.prune_device_in_all_servers
          raise "Server_problems" if exception_array.size > 0
        end

        if dev.device_type == "H323"
          for server in Server.all
            server.ami_cmd('h.323 reload')
            server.ami_cmd('extensions reload')
          end
        end
        Action.add_action_hash(options[:current_user], {:action => 'Device sent to Asterisk', :target_id => @device.id, :target_type => "device", :data => @device.user_id})
      rescue Exception => e
        MorLog.my_debug _('Cannot_connect_to_asterisk_server')
        Action.add_action_hash(options[:current_user], {:action => 'error', :data2 => "Cannot_connect_to_asterisk_server", :target_id => @device.id, :target_type => "device", :data => @device.user_id, :data3 => e.class.to_s, :data4 => e.message.to_s})
        if session[:usertype] == "admin" and !options[:no_redirect]
          flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit"
          flash[:notice] = _('Cannot_connect_to_asterisk_server')
          flash[:notice] += "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>" if flash_help_link
          if options[:api].to_i == 0
            redirect_to :controller => "callc", :action => "main" and return false
          else
            return false
          end
        end

      end
    end #if device
    return true
  end

  def extlines_did_not_active(did_id)
    #if did = Did.find(did_id)
    #    Extline.mcreate(Default_Context, 1, "NoOp", did.did, did.did, 0)
    #   Extline.mcreate(Default_Context, 2, "Playback", "mor_is_curntly_unavail|noanswer", did.did, 0)
    #  Extline.mcreate(Default_Context, 3, "Hangup", "", did.did, 0)
    #end
  end

  def assign_did_to_calling_card_dp(did, answer, number_length, pin_length)
    dp = Dialplan.new
    dp.name = "CallingCard DP, answer: #{answer}, nl: #{number_length}, pl: #{pin_length}"
    dp.dptype = "callingcard"
    dp.save

    dp_ext = "dp"+dp.id.to_s

    did.dialplan_id = dp.id
    did.status = "active"
    did.save

    #delete old config
    #Extline.destroy_all ["exten = ?", did.did]
    #Extline.mcreate(Default_Context, 1, "Goto", dp_ext+"|1", did.did, 0)

    # dp extlines
    answeri = 0
    answeri = 1 if answer

    Extline.mcreate(Default_Context, 1, "Set", "MORCC_ANSWER=#{answeri}", dp_ext, 0)
    Extline.mcreate(Default_Context, 2, "Set", "MORCC_NUMBER_LENGTH=#{number_length}", dp_ext, 0)
    Extline.mcreate(Default_Context, 3, "Set", "MORCC_PIN_LENGTH=#{pin_length}", dp_ext, 0)
    Extline.mcreate(Default_Context, 4, "Set", "MORCC_DESTINATION=#{did.did}", dp_ext, 0)
    Extline.mcreate(Default_Context, 5, "Set", "MOR_TELL_TIME=1", dp_ext, 0)
    Extline.mcreate(Default_Context, 6, "Set", "MOR_TELL_BALANCE=1", dp_ext, 0)
    Extline.mcreate(Default_Context, 7, "Set", "MOR_TELL_RTIME_WHEN_LEFT=120", dp_ext, 0)
    Extline.mcreate(Default_Context, 8, "Set", "MOR_TELL_RTIME_EVERY=60", dp_ext, 0)
    Extline.mcreate(Default_Context, 9, "Set", "LIMIT_TIMEOUT_FILE=mor/morcc_credit_low", dp_ext, 0)
    Extline.mcreate(Default_Context, 10, "Set", "CHANNEL(language)=#{did.language}", dp_ext, 0)
    Extline.mcreate(Default_Context, 11, "morcc", "", dp_ext, 0)
    Extline.mcreate(Default_Context, 12, "Hangup", "", dp_ext, 0)

  end

  def assign_did_to_auth_by_pin_dp(did)

    new_pin_auth_dp

    dp = Dialplan.where(:dptype => 'authbypin').first

    dp_ext = "dp"+dp.id.to_s

    did.dialplan_id = dp.id
    did.status = "active"
    did.save

    #Extline.mcreate(Default_Context, 1, "Goto", dp_ext+"|1", did.did, 0)

  end

  def new_pin_auth_dp

    return if Dialplan.where(:dptype => 'authbypin').first

    dp = Dialplan.new
    dp.name = "Authenticate by PIN Dial-Plan"
    dp.dptype = "authbypin"
    dp.save

    dp_ext = "dp"+dp.id.to_s

    # dp extlines

    Extline.mcreate(Default_Context, 1, "Set", "STEP=0", dp_ext, 0)
    Extline.mcreate(Default_Context, 2, "Set", "MOR_AUTH_BY_PIN=1", dp_ext, 0)
    Extline.mcreate(Default_Context, 3, "Set", "MOR_AUTH_BY_PIN_TRY_TIMES=3", dp_ext, 0)
    Extline.mcreate(Default_Context, 4, "mor", "", dp_ext, 0)
    Extline.mcreate(Default_Context, 5, "Set", "STEP=$[${STEP}+1]", dp_ext, 0)
    Extline.mcreate(Default_Context, 6, "GotoIf", "$[$[\"${DIALSTATUS}\" != \"ANSWERED\"] && $[${STEP} < 3]]]?7:9  ", dp_ext, 0)
    Extline.mcreate(Default_Context, 7, "Playback", "mor/morcc_unreachable", dp_ext, 0)
    Extline.mcreate(Default_Context, 8, "Goto", "2", dp_ext, 0)
    Extline.mcreate(Default_Context, 9, "Hangup", "", dp_ext, 0)
  end


  # converting caller id like "name" <11> to name
  def nice_cid(cidn)
    if cidn
      cid = cidn.split('"')
      cid = cid[1] #if cidn.index('<')
    else
      cid = ""
    end
    cid
  end

  # converting caller id like "name" <11> to 11
  def cid_number(cid)
    if cid and cid.index('<') and cid.index('>')
      cid = cid[cid.index('<')+1, cid.index('>') - cid.index('<') - 1]
    else
      cid = ""
    end
    cid
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = "0" + dd if dd.length<2
    dd
  end

  def session_from_date
    sfd = session[:year_from].to_s + "-" + good_date(session[:month_from].to_s) + "-" + good_date(session[:day_from].to_s)
    current_user.system_time(sfd, 1)
  end

  def session_till_date
    sfd = session[:year_till].to_s + "-" + good_date(session[:month_till].to_s) + "-" + good_date(session[:day_till].to_s)
    current_user.system_time(sfd, 1)
  end

  def session_from_datetime
    sfd = session[:year_from].to_s + "-" + good_date(session[:month_from].to_s) + "-" + good_date(session[:day_from].to_s) + " " + good_date(session[:hour_from].to_s) + ":" + good_date(session[:minute_from].to_s) + ":00"
    current_user.system_time(sfd)
  end

  def session_till_datetime
    sfd = session[:year_till].to_s + "-" + good_date(session[:month_till].to_s) + "-" + good_date(session[:day_till].to_s) + " " + good_date(session[:hour_till].to_s) + ":" + good_date(session[:minute_till].to_s) + ":59"
    current_user.system_time(sfd)
  end

  def session_from_datetime_array
    [session[:year_from].to_s, session[:month_from].to_s, session[:day_from].to_s, session[:hour_from].to_s, session[:minute_from].to_s, "00"]
  end

  def session_till_datetime_array
    [session[:year_till].to_s, session[:month_till].to_s, session[:day_till].to_s, session[:hour_till].to_s, session[:minute_till].to_s, "59"]
  end

  def active_users(date)

    date_s = date.strftime("%Y-%m-%d")

    sql =
        'SELECT users.*' +
            'FROM users join devices on (users.id = devices.user_id) join calls on (calls.src_device_id = devices.id  ' +
            'AND calls.calldate BETWEEN \'' + date_s + ' 00:00:00\' AND \'' + date_s + ' 23:59:59\') '+
            'GROUP BY users.id'

    ActiveRecord::Base.connection.select_all(sql)

  end

  #================== C O D E C S =============================

  def audio_codecs
    Codec.where(:codec_type => 'audio').order("id ASC")
  end

  def video_codecs
    Codec.where(:codec_type => 'video').order("id ASC")
  end

  def image_codecs
    Codec.where(:codec_type => 'image').order("id ASC")
  end


  #============================================================

  # get last day of month
  def last_day_of_month(year, month)

    year = year.to_i
    month = month.to_i

    if (month == 1) or (month == 3) or (month == 5) or (month == 7) or (month == 8) or (month == 10) or (month == 12)
      day = "31"
    else
      if  (month == 4) or (month == 6) or (month == 9) or (month == 11)
        day = "30"
      else
        if year % 4 == 0
          day = "29"
        else
          day = "28"
        end
      end
    end
    day
  end

  #previous month
  def prev_month(date) # takes format as '2006-02'
    year = date[0..4].to_i
    month = date[5..7].to_i
    if month == 1
      month += 12
      year -= 1
    end
    month -=1
    pm = year.to_s + "-" + good_date(month.to_s)
  end

  #previous day
  def prev_day(date) # takes format as '2006-02-21'
    year = date[0..4].to_i
    month = date[5..7].to_i
    day = date[8..10].to_i


    if day == 1
      #new year
      if month==1
        month = 12
        year -= 1
        day = 31
      else
        if (month == 5) or (month == 7) or (month == 8) or (month == 10) or (month == 12)
          day = 30
          month -= 1
        else
          if (month == 2) or (month == 4) or (month == 6) or (month == 9) or (month == 11)
            day = 31
            month -= 1
          else
            if month == 3
              if year % 4 == 0
                day = "29"
              else
                day = "28"
              end
              month -= 1
            end
          end
        end
      end
    else
      day -= 1
    end

    pd = year.to_s + "-" + good_date(month.to_s) + "-" + good_date(day.to_s)
  end

  # format time from seconds
  def nice_time(time)
    time = time.to_i
    return "" if time == 0
    t = ""
    h = time / 3600
    m = (time - (3600 * h)) / 60
    s = time - (3600 * h) - (60 * m)
    t = good_date(h) + ":" + good_date(m) + ":" + good_date(s)
  end

  def nice_time2(time)
    time.strftime("%H:%M:%S") if time
  end

=begin
  Since session is turned off in api controller, not only do we need to check for Conflines
  and/or session variables to format a number, but we need to check wheter session is not nil.
  In case it is nil we set nice_number_digits to 2 and do not change decimal.
=end
  def nice_number(number)
    confline = (!session or !session[:nice_number_digits]) ? Confline.get_value("Nice_Number_Digits") : session[:nice_number_digits]
    nice_number_digits = (confline and confline.to_s.length > 0) ? confline.to_i : 2
    n = ""
    n = sprintf("%0.#{nice_number_digits}f", number.to_d) if number
    if session 
      session[:nice_number_digits] = nice_number_digits 
      n = n.gsub('.', session[:global_decimal]) if session[:change_decimal]
    end
    n
  end

  def nice_invoice_number(number, type, options = {})
    dig =  nice_invoice_number_digits(type)
    n = ""
    n = sprintf("%0.#{dig}f", number.to_d) if number
    if session[:change_decimal] and options[:no_repl].to_i == 0
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end

  def nice_invoice_number_digits(type)
    if type.to_s == 'prepaid'
      session[:nice_prepaid_invoice_number_digits] ||= Confline.get_value("Prepaid_Round_finals_to_2_decimals").to_i
      if session[:nice_prepaid_invoice_number_digits].to_i == 1
        return 2
      else
        return session[:nice_number_digits]
      end
    else
      session[:nice_invoice_number_digits] ||= Confline.get_value("Round_finals_to_2_decimals").to_i
      if session[:nice_invoice_number_digits].to_i == 1
        return 2
      else
        return session[:nice_number_digits]
      end
    end
  end

  def nice_user(user)
    nu = user.username.to_s
    nu = user.first_name.to_s + " " + user.last_name.to_s if user.first_name.to_s.length + user.last_name.to_s.length > 0
    nu
  end

  def link_nice_user(user, options={})
    link_to nice_user(user), {:controller => "users", :action => "edit", :id => user.id}.merge(options)
  end

  def nice_device(device)
    d = ""
    if device
      d = device.device_type + "/"
      d += device.name if device.device_type != "FAX"
      d += device.extension if device.device_type == "FAX" or device.name.length == 0
    end

    d
  end

  def nice_inv_name(iv_id_name)
    id_name=""
    if  iv_id_name.to_s.strip[-1..-1].to_s.strip == "-"
      name_length = iv_id_name.strip.length
      name_length = name_length.to_i - 2
      id_name = iv_id_name.strip
      id_name = id_name[0..name_length].to_s
    else
      id_name = iv_id_name.to_s.strip
    end
    id_name.to_s.strip
  end

  #looks at devices table to check next free extension, basically for self-registering users
  def free_extension
    ran_min = Confline.get_value("Device_Range_MIN").to_i
    ran_max = Confline.get_value("Device_Range_MAX").to_i

    sql = "SELECT c AS free, COUNT(v.c) AS x FROM (
              (SELECT #{ran_min} AS c)
              UNION ALL
              (SELECT data2 c FROM dialplans  WHERE (dptype = 'pbxfunction' AND data2 REGEXP '^[0-9]+$' = 1 AND data2 BETWEEN #{ran_min} AND #{ran_max}) GROUP BY c)
              UNION ALL
              (SELECT data2 + 1 AS c FROM dialplans  WHERE (dptype = 'pbxfunction' AND data2 REGEXP '^[0-9]+$' = 1 AND data2 BETWEEN #{ran_min} AND #{ran_max}) GROUP BY c)
              UNION ALL
              (SELECT extension c FROM devices  WHERE (extension REGEXP '^[0-9]+$' = 1 AND extension BETWEEN #{ran_min} AND #{ran_max}) GROUP BY c)
              UNION ALL
              (SELECT extension + 1 AS c FROM devices WHERE (extension REGEXP '^[0-9]+$' = 1 AND extension BETWEEN #{ran_min} AND #{ran_max}) GROUP BY c)
            ) AS v GROUP BY free HAVING  x < 2 AND free BETWEEN #{ran_min} AND #{ran_max} ORDER BY CONVERT(free, UNSIGNED);"
    devices = ActiveRecord::Base.connection.select_all(sql)

    if devices and devices[0]
      fe = devices[0]["free"].to_s
    else
      fe = ran_min + 1
    end
    fe
  end

  def nice_src(call, options={})
    value = Confline.get_value("Show_Full_Src")
    srt = call.clid.split(' ')
    name = srt[0..-2].join(' ').to_s.delete('"')
    number = call.src.to_s
    if options[:pdf].to_i == 0
      session[:show_full_src] ||= value
    end
    if value.to_i == 1 and name.length > 0
      return "#{number} (#{name})"
    else
      return "#{number}"
    end
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = "0" + dd if dd.length<2
    dd
  end

  def count_exchange_rate(curr1, curr2)
    Currency::count_exchange_rate(curr1, curr2)
  end

  def voucher_number(length)
    good = 0

    length = 10 if length.to_i == 0

    while good == 0
      number = random_digit_password(length)
      good = 1 if not Voucher.where(:number => number).first
    end

    number
  end


  def validate_date(year, month, day)
    good = 1
    year = year.to_i
    month = month.to_i
    day = day.to_i

    if day == 31 and (month == 4 or month == 6 or month == 9 or month == 11)
      good = 0
    end

    good = 0 if month == 2 and day > 29

    good = 0 if year.remainder(4) != 0 and month == 2 and day == 29

    good
  end

  def next_agreement_number

    sql = "SELECT agreement_number FROM users ORDER by cast(agreement_number as signed) DESC LIMIT 1"
    res = ActiveRecord::Base.connection.select_value(sql)

    #user = User.find(:first, :order => "agreement_number DESC")

    number = res.to_i + 1

    start = ""

    length = Confline.get_value("Agreement_Number_Length").to_i
    #default_value
    length = 10 if length == 0

    #      if type == 1
    zl = length - start.length - number.to_s.length
    z = ""
    for i in 1..zl
      z += "0"
    end
    num = "#{start}#{z}#{number.to_s}"
    #    end

    num.to_s
  end

  def confline(name, id = 0)
    Confline.get_value(name, id)
  end

  def confline2(name, id = 0)
    Confline.get_value2(name, id)
  end

  def renew_session(user)
    @current_user = user
    session[:username] = user.username
    session[:first_name] = user.first_name
    session[:last_name] = user.last_name
    session[:user_id] = user.id
    session[:usertype] = user.usertype
    session[:owner_id] = user.owner_id
    session[:tax] = user.get_tax
    session[:usertype_id] = Role.find_by_name(session[:usertype].to_s).id.to_i
    session[:device_id] = user.primary_device_id
    session[:tariff_id] = user.tariff_id
    session[:sms_service_active] = user.sms_service_active
    session[:help_link] = Confline.get_value("Hide_HELP_banner").to_i == 0 ? 1 : 0
    session[:callc_main_stats_options]= nil
    if Confline.where('name = "System_time_zone_offset"').first
      session[:time_zone_offset] = Confline.get_value('System_time_zone_ofset').to_i
    else
      sql = 'select HOUR(timediff(now(),convert_tz(now(),@@session.time_zone,\'+00:00\'))) as u;'
      z = ActiveRecord::Base.connection.select_all(sql)[0]['u']
      t = z.to_s.to_i
      Confline.set_value('System_time_zone_offset', t.to_i, 0)
      session[:time_zone_offset] = Confline.get_value('System_time_zone_ofset').to_i
    end

    ["Hide_Iwantto", "Hide_Manual_Link"].each { |option|
      session[option.downcase.to_sym] = Confline.get_value(option).to_i
    }

    ["Hide_Device_Passwords_For_Users"].each { |option|
      session[option.downcase.to_sym] = Confline.get_value(option, user.owner_id).to_i
    }

    c = Currency.where(:id => 1).first
    session[:default_currency] = c.name
    Currency.check_first_for_active if c.active.to_i == 0
    session[:show_currency] = user.currency.name

    session[:manager_in_groups] = user.manager_in_groups

    cookies[:mor_device_id] = user.primary_device_id.to_s

    session[:voucher_attempt] = Confline.get_value("Voucher_Attempts_to_Enter").to_i


    session[:fax_device_enabled] = Confline.get_value("Fax_Device_Enabled") == "1"

    session[:allow_own_dids] = Confline.get_value("Resellers_can_add_their_own_DIDs").to_i

    nnd = Confline.get_value("Nice_Number_Digits").to_i
    session[:nice_number_digits] = 2
    session[:nice_number_digits] = nnd if nnd > 0

    if Confline.get_value("Global_Number_Decimal").to_s.blank?
      Confline.set_value("Global_Number_Decimal", '.')
    end
    gnd = Confline.get_value("Global_Number_Decimal").to_s
    session[:change_decimal] = gnd.to_s == '.' ? false : true
    session[:global_decimal] = gnd

    ipp = Confline.get_value("Items_Per_Page").to_i
    session[:items_per_page] = 100
    session[:items_per_page] = ipp if ipp > 0
    session[:items_per_page] = 1 if session[:items_per_page].to_i < 1
    format = Confline.get_value("Date_format", user.usertype == "reseller" ? user.id : user.owner_id).to_s
    session[:date_time_format] = format.to_s.blank? ? "%Y-%m-%d %H:%M:%S" : format
    session[:date_format] = format.to_s.blank? ? "%Y-%m-%d" : format.to_s.split(' ')[0]
    session[:time_format] = format.to_s.blank? ? "%H:%M:%S" : format.to_s.split(' ')[1]

    session[:callback_active] = callback_active? ? Confline.get_value("CB_Active").to_i : 0

    set_erp_settins(user)
    #load accountant settings
    if ["accountant", "reseller"].include?(user.usertype)
      load_permissions_for(user)
    end
    #// load accountant settings
    if user.usertype == "admin"
      session[:integrity_check] = Confline.get_value("Integrity_Check", user.id).to_i
    end
    session[:frontpage_text] = Confline.get_value2("Frontpage_Text", user.owner_id).to_s
    if sms_active?
      session[:frontpage_sms_text] = Confline.get_value2("Frontpage_SMS_Text", 0).to_s
    end
    if user.usertype == "reseller"
      user.check_translation
      session[:version] = Confline.get_value("Version", user.id)
      session[:copyright_title] = Confline.get_value("Copyright_Title", user.id)
      session[:company_email] = Confline.get_value("Company_Email", user.id)
      session[:company] = Confline.get_value("Company", user.id)
      session[:admin_browser_title] = Confline.get_value("Admin_Browser_Title", user.id)
      session[:logo_picture] = Confline.get_value("Logo_Picture", user.id)
      session[:show_menu] = Confline.get_value("Show_only_main_page", user.id).to_i
      #fetching some reseller specific params
      session[:tariff_csv_import_value] = 0
      az, av = user.alow_device_types_dahdi_virt
      session[:device] = {
          :allow_dahdi => az,
          :allow_virtual => av
      }
    else
      session[:tariff_csv_import_value] = Confline.get_value("Load_CSV_From_Remote_Mysql", user.owner_id).to_i == 0 ? 1 : 0
      if  session[:tariff_csv_import_value].to_i == 1
        config = YAML::load(File.open("#{Rails.root}/config/database.yml"))
        session[:tariff_csv_import_value] = (config['production']['host'].blank? or config['production']['host'].include?('localhsot')) ? 1 : 0
      end
      session[:show_menu] = Confline.get_value("Show_only_main_page", user.owner_id).to_i
      session[:version] = Confline.get_value("Version", user.owner_id)
      session[:copyright_title] = Confline.get_value("Copyright_Title", user.owner_id)
      session[:company_email] = Confline.get_value("Company_Email", user.owner_id)
      session[:company] = Confline.get_value("Company", user.owner_id)
      session[:admin_browser_title] = Confline.get_value("Admin_Browser_Title", user.owner_id)
      session[:logo_picture] = Confline.get_value("Logo_Picture", user.owner_id)
      session[:device] = {}
    end

    session[:active_calls_refresh_interval] = Confline.get_value("Active_Calls_Refresh_Interval")
    session[:active_calls_show_server] = Confline.get_value("Active_Calls_Show_Server").to_i

    session[:show_full_src] = Confline.get_value("Show_Full_Src")

    #caching values
    session[:show_rates_for_users] = Confline.get_value('Show_rates_for_users', user.owner_id)
    # payments values
    session[:webmoney_enabled] = Confline.get_value("WebMoney_Enabled", user.owner_id).to_i
    session[:vouchers_enabled] = Confline.get_value("Vouchers_Enabled", user.owner_id).to_i
    session[:linkpoint_enabled] = user.owner_id == 0 ? Confline.get_value("Linkpoint_Enabled", user.owner_id).to_i : 0
    session[:cyberplat_enabled] = Confline.get_value("Cyberplat_Enabled", user.owner_id).to_i
    session[:ouroboros_enabled] = Confline.get_value("Ouroboros_Enabled", user.owner_id).to_i
    session[:ouroboros_name] = Confline.get_value("Ouroboros_Link_name_and_url", user.owner_id).to_s
    session[:ouroboros_url] = Confline.get_value2("Ouroboros_Link_name_and_url", user.owner_id).to_s
    if session[:usertype] == "reseller" and Confline.get_value("Paypal_Disable_For_Reseller").to_i == 1
      session[:paypal_enabled] = 0
    else
      session[:paypal_enabled] = Confline.get_value("Paypal_Enabled", user.owner_id).to_i
    end

    session[:show_active_calls_for_users] = Confline.get_value("Show_Active_Calls_for_Users", 0).to_i
    session[:lang] = nil
    flags_to_session
    check_localization
    change_date
    if user.usertype == "reseller"
      user.check_reseller_emails
    end
  end

  def set_erp_settins(user)
    cor_id = user.get_correct_owner_id
    session[:erp_domain] = Confline.get_value("ERP_domain", cor_id)
    session[:erp_login] = Confline.get_value("ERP_login", cor_id)
    session[:erp_password] = Confline.get_value("ERP_password", cor_id)
  end


  def sanitize_filename(file_name)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(file_name)
    # replace all none alphanumeric, underscore or perioids with underscore
    just_filename.gsub(/[^\w\.\_]/, '_')
  end


  # reads translations table and puts translations into session
  def flags_to_session(force_owner = nil)
    unless force_owner and force_owner.class == User
      if current_user
        @translations = current_user.active_translations
      else
        tra = UserTranslation.where(:active => 1, :user_id => 0).includes(:translation).order("position ASC")
        @translations = tra.map(&:translation)
      end
    else
      @translations = force_owner.active_translations
    end
    tr_arr = []
    @translations.each { |tr| tr_arr << tr }
    session[:tr_arr] = tr_arr
  end


  def new_device_pin
    good = 0
    pin_length = Confline.get_value("Device_PIN_Length").to_i
    pin_length = 6 if pin_length == 0

    while good == 0
      pin = random_digit_password(pin_length)
      good = 1 unless Device.where(:pin => pin).first
    end
    pin
  end

  def direction_by_dst(dst)
    sql = "SELECT directions.name AS direction_name,
                  destinationgroups.name AS destinationgroup_name
           FROM   directions
           JOIN   destinations ON directions.code = destinations.direction_code
           LEFT JOIN   destinationgroups ON destinations.destinationgroup_id = destinationgroups.id
           WHERE  destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))
           ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1"
    res = ActiveRecord::Base.connection.select_all(sql)
    array = [_('Unknown'), _('Unknown')]
    if res and res[0]
      array[0] = res[0]['direction_name'] if !res[0]['direction_name'].blank?
      array[1] = res[0]['destinationgroup_name'] if !res[0]['destinationgroup_name'].blank?
    end
    return array
  end

  #using RAMI library originates call through Asterisk AMI interface
  def originate_call(acc, src, channel, context, extension, callerid, var2 = nil, server_id = 1)

    # acc - which device is dialing (devices.id)
    # src - who receives call first (device's name/extension)
    # channel - usually == "Local/#{src}@mor_cb_src/n"
    # context - usually == "mor_cb_dst"
    # extension - who receives call second
    # callerid - what CallerID to apply to both calls
    # var2 - additional variables
    # server_id - on which server activate callback

    # --------- USING AMI ----------
    @server = Server.where(:server_id => server_id).first
    if  !@server or @server.active != 1
      connection_status = 1
    else
      ami_host = @server.server_ip
      ami_username = @server.ami_username
      ami_secret = @server.ami_secret

      server = Rami::Server.new({'host' => ami_host, 'username' => ami_username, 'secret' => ami_secret})
      server.console =1
      server.event_cache = 100
      server.run

      client = Rami::Client.new(server)
      client.timeout = 3

      accs = acc.to_s
      variable = "MOR_ACC=#{accs}"

      variable += "|" + var2 if var2 and var2.length > 0

=begin
CLI> manager show command originate
Action: Originate
Synopsis: Originate Call
Privilege: call,all
Description: Generates an outgoing call to a Extension/Context/Priority or
  Application/Data
Variables: (Names marked with * are required)
        *Channel: Channel name to call
        Exten: Extension to use (requires 'Context' and 'Priority')
        Context: Context to use (requires 'Exten' and 'Priority')
        Priority: Priority to use (requires 'Exten' and 'Context')
        Application: Application to use
        Data: Data to use (requires 'Application')
        Timeout: How long to wait for call to be answered (in ms)
        CallerID: Caller ID to be set on the outgoing channel
        Variable: Channel variable to set, multiple Variable: headers are allowed
        Account: Account code
        Async: Set to 'true' for fast origination
=end

      t = client.originate({'Channel' => channel, 'Context' => context, 'Exten' => extension, 'Priority' => "1", 'Async' => "no", 'Variable' => variable, "CallerID" => callerid, "Account" => accs, "Timeout" => "1200000"})

      client.stop

      connection_status = 0
    end
    return connection_status
  end


  # Returns HangupCauseCode message by code
  def get_hangup_cause_message(code)
    if session["hangup#{code.to_i}".intern]
      return session["hangup#{code.to_i}".intern].html_safe
    else
      line = Hangupcausecode.where(:code => code).first
      if line
        session["hangup#{code.to_i}".intern] = line.description.html_safe
      else
        session["hangup#{code.to_i}".intern] = ("<b>"+_("Unknown_Error")+"</b><br />").html_safe
      end
      return session["hangup#{code.to_i}".intern].html_safe
    end
  end

  #======== cheking file type ================

  def get_file_ext(file_string, type)
    filename = sanitize_filename(file_string)
    ext = filename.to_s.split(".").last
    if ext.downcase != type.downcase
      flash[:notice] = _('File_type_not_match')+ " : #{type.to_s}"
      return false
    else
      return true
    end
  end

  ############ MATRIX CLASS ##############


  class Matrix < Array
    def initialize (rows, columns)
      super(rows)
      self.each_index { |i|
        self[i] = Array.new(columns)
        self[i].each_index { |j| self[i][j] = rand(10) }
      }
    end


    def sort(key, order)
      key = key.to_i
      order = order.to_s

      b = Matrix.new(self.size, self[0].size)

      s_row = self[key].sort

      s_row = s_row.reverse if order == "desc"

      i=0
      zz = 0
      while i<self[0].size
        j=0
        while self[key][j] != s_row[i]
          j += 1
        end

        for zz in 0..self.size-1
          b[zz][i] = self[zz][j]
        end
        self[key][j] = "s" #mark as used

        i+=1

      end

      b
    end

    #put value into file for debugging
    def my_debug(msg)
      File.open(Debug_File, "a") { |f|
        f << msg.to_s
        f << "\n"
      }
    end
  end


  def escape_for_email(string)
    string.to_s.gsub("\'", "\\\'").to_s.gsub("\"", "\\\"").to_s.gsub("\`", "\\\`")
  end

  def important_exception(exception)
    case exception.class.to_s
      when "ActionController::RoutingError"
        if exception.to_s.scan(/no route found to match \"\/images\//).size > 0
          if exception.to_s.scan(/no route found to match \"\/images\/flags\//).size > 0
            country = exception.to_s.scan(/flags\/.*"/)[0].gsub("flags", "").gsub(/[\'\"\\\/]/, "")
            if simple_file_name?(country)
              MorLog.my_debug(" >> cp #{Rails.root}/public/images/flags/empty.jpg #{Rails.root}/public/images/flags/#{country}", true)
              MorLog.my_debug(`cp #{Rails.root}/public/images/flags/empty.jpg #{Rails.root}/public/images/flags/#{country}`)
            end
          end
        end

        return false
    end
    if exception.to_s.respond_to?(:scan) and exception.to_s.scan(/No action responded to/).size > 0
      flash[:notice] = _('Action_was_not_found')
      redirect_to :controller => "callc", :action => "main" and return false
    end
    return true
  end

  #    def rescue_action_locally(exception)
  #      rescue_action_in_public(exception)
  #    end

  def my_rescue_action_in_public(exception)
    #    MorLog.my_debug exception.to_yaml
    #    MorLog.my_debug exception.backtrace.to_yaml
    time = Time.now()
    id = time.strftime("%Y%m%d%H%M%S")
    address = 'guicrashes@kolmisoft.com'
    extra_info = ""
    swap = nil
    begin
      MorLog.my_debug("Rescuing exception: #{exception.class.to_s} controller: #{params[:controller].to_s}, action: #{params[:action].to_s}", true)
      if important_exception(exception)
        MorLog.my_debug("  >> Exception is important", true)
        MorLog.log_exception(exception, id, params[:controller].to_s, params[:action].to_s)  if params[:do_not_log_test_exception].to_i == 0

        trace = exception.backtrace.collect { |t| t.to_s }.join("\n")

        exception_class = escape_for_email(exception.class).to_s
        exception_class_previous = Confline.get_value("Last_Crash_Exception_Class", 0).to_s
        exception_send_email = Confline.get_value("Exception_Send_Email").to_i

        # Lots of duplication but this is due fact that in future there may be
        # need for separate link for every error.
        flash_help_link = nil

        if exception_class.include?("Errno::ENETUNREACH")
          flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_Errno::ENETUNREACH"
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Asterik_server_connection_error', :data2 => exception.message).save
        end

        if exception_class.include?("Errno::EACCES")
          flash_notice = _('File_permission_error')                                                                                                                                    
          flash_help_link = ''                                                                                                                                                         
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'File_permission_error', :data2 => exception.message).save          
        end           

        if exception_class.include?("Errno::EHOSTUNREACH") or (exception_class.include?("Errno::ECONNREFUSED") and trace.to_s.include?("rami.rb:380"))
          flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit"
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Asterik_server_connection_error', :data2 => exception.message).save
        end

        if exception_class.include?("SystemExit") or (exception_class.include?('RuntimeError') and (exception.message.include?('No route to host') or exception.message.include?('getaddrinfo: Name or service not known') or exception.message.include?('Connection refused')))
          flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit"
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Asterik_server_connection_error', :data2 => exception.message).save
        end

        if exception_class.include?('RuntimeError') and (exception.message.include?('Connection timed out') or exception.message.include?('Connection reset by peer') or exception.message.include?('exit'))
          flash_notice = _('Your_Asterisk_server_is_not_accessible_Please_check_if_address_entered_is_valid_and_network_is_OK')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Asterik_server_connection_error', :data2 => exception.message).save
        end

        if exception_class.include?("SocketError") and !trace.to_s.include?("smtp_tls.rb")
          flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit"
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Asterik_server_connection_error', :data2 => exception.message).save
        end
        if exception_class.include?("Errno::ETIMEDOUT")
          flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit"
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Asterik_server_connection_error', :data2 => exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?("OpenSSL::SSL::SSLError") or exception_class.include?("OpenSSL::SSL")
          flash_notice = _('Verify_mail_server_details_or_try_alternative_smtp_server')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'SMTP_connection_error', :data2 => exception.message).save
        end

        if exception_class.include?("ActiveRecord::RecordNotFound")
          flash_notice = _('Data_not_found')
          flash_help_link = ''
          exception_send_email = 1
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Data_not_found', :data2 => exception.message).save
        end

        if exception_class.include?("ActiveRecord::StatementInvalid") and exception.message.include?('Access denied for user')
          flash_notice = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'MySQL_permission_problem', :data2 => exception.message).save
        end

        if exception_class.include?("Transactions::TransactionError")
          flash_notice = _("Transaction_error")
          swap = []
          swap << %x[vmstat]
          #          swap << ActiveRecord::Base.connection.select_all("SHOW INNODB STATUS;")
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Transaction_errors', :data2 => exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?("Errno::ENOENT") and exception.message.include?('/tmp/mor_debug_backup.txt')
          flash_notice = _('Backup_file_not_found')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Backup_file_not_found', :data2 => exception.message).save
        end

        if exception_class.include?("GoogleCheckoutError") and exception.message.include?("No seller found with id")
          flash_notice = _('Internal_Error_Contact_Administrator')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Payment_Gateway_Error', :data2 => exception.message).save
        end

        # database not updated
        if exception_class.include?("NoMethodError") and !exception.message.include?("nil:NilClass") and exception.message.include?("for #<")
          flash_notice = _('Database_Error')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Database_Error', :data2 => exception.message).save
        end
        if exception_class.include? "ActiveModel::MissingAttributeError"
          flash_notice = _('Database_Error')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Database_Error', :data2 => exception.message).save
        end
        if exception_class.include?("ActiveRecord::StatementInvalid") and exception.message.include?("Unknown column")
          flash_notice = _('Database_Error')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Database_Error', :data2 => exception.message).save
        end
        #

        if exception_class.include?("GoogleCheckoutError") and exception.message.include?("The currency used in the cart must match the currency of the seller account.")
          flash_notice = _('Internal_Error_Contact_Administrator')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Payment_Gateway_Error', :data2 => exception.message).save
        end

        if exception_class.include?("Google4R") and exception.message.include?("Missing URL component: expected id:")
          flash_notice = _('Internal_Error_Contact_Administrator')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Payment_Gateway_Error', :data2 => exception.message).save
        end

        if exception_class.include?("Google4R") and exception.message.include?('expected id: (\d{10})|(\d{15})')
          flash_notice = _("Payment_Error_Contact_Administrator_enter_merchant_id")
          flash_help_link = ''
          exception_send_email = 0
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Payment_Gateway_Error', :data2 => exception.message).save
        end

        if exception_class.include?("Google4R") and exception.message.include?('Seller Account') and exception.message.include?('is not active.')
          flash_notice = _("Payment_Error_Contact_Administrator_account_not_active")
          flash_help_link = ''
          exception_send_email = 0
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Payment_Gateway_Error', :data2 => exception.message).save
        end

        if  exception.message.include?('Unexpected response code')
          flash_notice = _("Google_checkout_error") + ': ' + exception.message.to_s #.gsub('Google Unexpected response code', 'Unexpected response code')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Payment_Gateway_Error', :data2 => exception.message).save
        end

        if  exception.message.include?('An API Certificate or API Signature is required to make requests to PayPal')
          flash_notice = _('An_API_Certificate_or_API_Signature_is_required_to_make_requests_to_PayPal')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Payment_Gateway_Error', :data2 => exception.message).save
        end

        if  exception.message.include?('Temporary failure in name resolution')
          flash_notice = _('DNS_Error')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'DNS_Error', :data2 => exception.message).save
        end

        if  exception.message.include?('Ambethia::ReCaptcha::Controller::RecaptchaError')
          flash_notice = _('ReCaptcha_Error')
          flash_help_link = ''
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'ReCaptcha_Error', :data2 => exception.message).save
        end

        #if exception_class.include?("Net::SMTP") or (exception_class.include?("Errno::ECONNREFUSED") and trace.to_s.include?("smtp_tls.rb")) or (exception_class.include?("SocketError") and trace.to_s.include?("smtp_tls.rb")) or ((exception_class.include?("Timeout::Error") and trace.to_s.include?("smtp.rb"))) or trace.to_s.include?("smtp.rb")
        flash_help_link = email_exceptions(exception) if  flash_help_link.blank?  and  flash_notice.blank?
            #end

        if exception_class.include?("LoadError") and exception.message.to_s.include?('locations or via rubygems.')
          if exception.message.include?('cairo')
            flash_help_link = "http://wiki.kolmisoft.com/index.php/Cannot_generate_PDF"
          else
            flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_Ruby_Gems"
          end
          Action.new(:user_id => session[:user_id].to_i, :date => Time.now.to_s(:db), :action => "error", :data => 'Ruby_gems_not_found', :data2 => exception.message).save
          exception_send_email = 0
        end

        if exception_send_email == 1 and exception_class != exception_class_previous and !flash_help_link  or params[:this_is_fake_exception].to_s == "YES"
          MorLog.my_debug("  >> Need to send email", true)

          if exception_class.include?("NoMemoryError")
            extra_info = get_memory_info
            MorLog.my_debug(extra_info)
          end

          # Gather all exception
          rep, rev, status = get_svn_info
          rp = []
          (params.each { |k, v| rp << ["#{k} => #{v}"] })

          message = [
              "ID:         #{id.to_s}",
              "IP:         #{request.env['SERVER_ADDR']}",
              "Class:      #{exception_class}",
              "Message:    #{exception}",
              "Controller: #{params[:controller]}",
              "Action:     #{params[:action]}",
              "User ID:    #{session ? session[:user_id].to_i : 'possible_from_api'}",
              "----------------------------------------",
              "Repositority:           #{rep}",
              "Revision:               [#{rev}]",
              "Local version modified: #{status}",
              "----------------------------------------",

              "Request params:    \n#{rp.join("\n")}",
              "----------------------------------------",
              "Seesion params:    \n#{nice_session if session}",
              "----------------------------------------"
          ]
          if extra_info.length > 0
            message << "----------------------------------------"
            message << extra_info
            message << "----------------------------------------"
          end
          message << "#{trace}"

          if test_machine_active?
            if File.exists?('/var/log/mor/test_system')
              message << "----------------------------------------"
              message << %x[tail -n 50 /var/log/mor/test_system]
            end
          end

          if swap
            message << "----------------------------------------"
            message << swap.to_yaml
          end

          if exception_class.include?("Errno::EPERM")
            message << "----------------------------------------"
            message << %x[ls -la /home/mor/tmp/]
            message << "----------------------------------------"
            message << %x[ls -la /home/mor/]
          end

          Confline.set_value("Last_Crash_Exception_Class", exception_class, 0)

          if params[:this_is_fake_exception].to_s == "YES"
            MorLog.my_debug('  >> Crash email NOT sent THIS IS JUST TEST', true)
            return :text => flash_notice.to_s + flash_help_link.to_s + message.join("\n")
            #render :text => message.join("\n") and return false
          else

            subject = "#{ExceptionNotifier_email_prefix} Exception. ID: #{id.to_s}"
            time = Confline.get_value("Last_Crash_Exception_Time", 0)
            if time and !time.blank? and (Time.now - time.to_time) > 1.minute
              MorLog.my_debug("Crash email NOT sent : Time.now #{Time.now.to_s(:db)} - Last_Crash_Exception_Time #{time}")
            else
              send_crash_email(address, subject, message.join("\n")) if params[:do_not_log_test_exception].to_i == 0
              Confline.set_value("Last_Crash_Exception_Time", Time.now.to_s(:db), 0)
              MorLog.my_debug('Crash email sent')
            end
          end
        else
          MorLog.my_debug("  >> Do not send email because:", true)
          MorLog.my_debug("    >> Email should not be sent. Confline::Exception_Send_Email: #{exception_send_email.to_s}", true) if exception_send_email != 1
          MorLog.my_debug("    >> The same exception twice. Last exception: #{exception_class.to_s}", true) if exception_class == exception_class_previous
          MorLog.my_debug("    >> Contained explanation. Flash: #{ flash_help_link}", true) if flash_help_link
        end

        if !flash_help_link.blank?
          flash[:notice] = _('Something_is_wrong_please_consult_help_link')
          flash[:notice] += "<a id='exception_info_link' href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' /></a>".html_safe
        else
          flash[:notice] = flash_notice.to_s.blank? ? "INTERNAL ERROR. - ID: #{id} - #{exception_class}" : flash_notice
        end

        if session and session[:forgot_pasword] == 1
          session[:forgot_pasword] = 0
          flash[:notice_forgot]= (_('Cannot_change_password') + "<br />" + _('Email_not_sent_because_bad_system_configurations')).html_safe
        end

        if session and session[:flash_not_redirect].to_i == 0
          #redirect_to Web_Dir + "/callc/main" and return false
        else
          session[:flash_not_redirect] = 0   if session
          #render(:layout => "layouts/mor_min") and return false
        end
      end
    rescue Exception => e
      MorLog.log_exception(e, id, params[:controller].to_s, params[:action].to_s)
      `/usr/local/mor/sendEmail -f 'support@kolmisoft.com' -t '#{address}' -u '#{ExceptionNotifier_email_prefix} SERIOUS EXCEPTION' -s 'smtp.gmail.com' -xu 'crashemail1' -xp 'crashemail1999' -m 'Exception in exception at: #{escape_for_email(request.env['SERVER_ADDR'])} \n --------------------------------------------------------------- \n #{escape_for_email(%x[tail -n 50 /var/log/mor/test_system])}' -o tls='auto'`
      flash[:notice] = "INTERNAL ERROR."
      #redirect_to Web_Dir + "/callc/main" and return false
    end
  end

  def nice_session
    s = []
    [:username, :first_name, :last_name, :user_id, :usertype, :owner_id, :tax, :usertype_id, :device_id, :tariff_id, :sms_service_active, :user_cc_agent,
     :help_link, :default_currency, :show_currency, :manager_in_groups, :voucher_attempt, :fax_device_enabled, :nice_number_digits, :items_per_page,
     :callback_active, :integrity_check, :frontpage_text, :version, :copyright_title, :company_email, :company, :admin_browser_title, :logo_picture,
     :active_calls_refresh_interval, :show_full_src, :show_rates_for_users, :webmoney_enabled, :paypal_enabled,
     :vouchers_enabled, :linkpoint_enabled, :cyberplat_enabled, :ouroboros_enabled, :ouroboros_name, :ouroboros_url, :show_active_calls_for_users].each { |key|
      s << [escape_for_email("#{key} => #{session[key]}")]
    }
    out = ""
    out = s.join("\n")
    out
  end

  def email_exceptions(exception)
    flash = nil

    # http://www.emailaddressmanager.com/tips/codes.html
    # http://www.answersthatwork.com/Download_Area/ATW_Library/Networking/Network__3-SMTP_Server_Status_Codes_and_SMTP_Error_Codes.pdf

    err_link = {}
    code = ['421', '422', '431', '432', '441', '442', '446', '447', '449', '450', '451', '500', '501', '502', '503', '504', '510', '521', '530', '535', '550', '551', '552', '553', '554']

    code.each { |value| err_link[value] = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#' + value.to_s }

    err_link.each { |key, value| flash = value if exception.message.to_s.include?(key) }

    if flash.to_s.blank?
      if exception.class.to_s.include?("Net::SMTPAuthenticationError")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#535'
      end
      if exception.class.to_s.include?("SocketError") or exception.class.to_s.include?("Timeout") or exception.class.to_s.include?("Errno::ECONNREFUSED")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#Email_SMTP_server_timeout'
      end
      if exception.class.to_s.include?("Net::SMTP")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end
      if exception.class.to_s.include?("Errno::ECONNRESET")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#Connection_reset'
      end
      if exception.message.include?('SMTP-AUTH requested but missing user name')
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end
      if exception.class.to_s.include?("EOFError")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end
    end
    if session
      a_user_id = session[:user_id].to_s.blank? ? session[:reg_owner_id].to_i : session[:user_id]
    else
      a_user_id = 0
    end
    Action.new(:user_id => a_user_id, :date => Time.now.to_s(:db), :action => "error", :data => 'Cant_send_email', :data2 => exception.message.to_s).save
    flash
  end

  def load_permissions_for(user)
    short = {"accountant" => "acc", "reseller" => "res"}
    if group = user.acc_group
      group.only_view ? session[:acc_only_view] = 1 : session[:acc_only_view] = 0
      rights = AccRight.select("name, value").where(:right_type => group.group_type).joins("LEFT JOIN acc_group_rights ON (acc_group_rights.acc_right_id = acc_rights.id AND acc_group_rights.acc_group_id = #{group.id})")

      rights.each { |right|
        name = "#{short[user.usertype]}_#{right[:name].downcase}".to_sym
        if right[:value].nil?
          session[name] = 0
        else
          session[name] = ((right[:value].to_i >= 2 and group.only_view) ? 1 : right[:value].to_i)
        end
        # Uncomment to see what permissions are beeing added when user logs in.
        MorLog.my_debug("right : #{name}")
        MorLog.my_debug("value : #{session[name]}")
      }
    end
  end

  def corrected_user_id
    session[:usertype] == "accountant" ? 0 : session[:user_id]
  end

=begin rdoc
 Returns correct owner_id if usertype is accountant
=end

  def correct_owner_id
    return 0 if session[:usertype] == 'accountant' or session[:usertype] == 'admin'
    return session[:user_id] if session[:usertype] == 'reseller'
    return session[:owner_id]
  end

=begin rdoc

=end

  def months_between(date1, date2)
    years = date2.year - date1.year
    months = years * 12
    months += date2.month - date1.month
    months
  end

  def generate_invoice_number(start, length, type, number, time)
    owner_id = correct_owner_id
    type = 1 if type.to_i == 0

    #INV000000001 - prefixNR

    if type == 1
      ls = start.length
      cond_str = ["SUBSTRING(number,1,?) = ?", "users.owner_id = ?"]
      cond_var = [ls, start.to_s, owner_id]
      cond_str << ["number_type = 1"]
      invoice = Invoice.where([cond_str.join(" AND ")]+cond_var).joins("LEFT JOIN users ON (invoices.user_id = users.id)").order("CAST(SUBSTRING(number,#{ls+1},255) AS SIGNED) DESC").first

      invoice ? number = (invoice.number[ls, invoice.number.length - ls].to_i + 1) : number = 1
      zl = length - start.length - number.to_s.length
      z = ""
      1..zl.times { z += "0" }
      invnum = "#{start}#{z}#{number.to_s}"
    end
    #INV070605011 - prefixYYMMDDnr
    if type == 2
      date = time.year.to_s[-2..-1] + good_date(time.month)+good_date(time.day)
      ls = start.length + 6
      cond_str = ["SUBSTRING(number,1,?) = '#{start.to_s}#{date.to_s}' AND users.owner_id = ?"]
      cond_var = [ls, owner_id]
      cond_str << ["number_type = 2"]
      pinv = Invoice.where([cond_str.join(" AND ")]+cond_var).joins("LEFT JOIN users ON (invoices.user_id = users.id)").order("CAST(SUBSTRING(number,#{ls+1},255) AS SIGNED) DESC").first

      pinv ? nn = (pinv.number[ls, pinv.number.length - ls].to_i + 1) : nn = 1
      zl = length - start.length - nn.to_s.length - 6
      z = ""
      1..zl.times { z += "0" }
      invnum = "#{start}#{date}#{z}#{nn}"
    end
    return invnum
  end

  def flash_errors_for(message, object)
    flash[:notice] = message
    object.errors.each { |key, value|
      flash[:notice] += "<br> * #{_(value)}"
    } if object.respond_to?(:errors)
  end

  def test_sip_conectivity(ip, port)
    begin
      `rm -f /tmp/.mor_provider_check`
      return false if ip.to_s.length == 0
      if port.to_s == ""
        `sipsak -s sip:101@#{ip} -v > /tmp/.mor_provider_check`
      else
        `sipsak -s sip:101@#{ip}:#{port} -v > /tmp/.mor_provider_check`
      end
      @server = `grep 'Server\\|User-Agent\\|User-agent' /tmp/.mor_provider_check`.to_s.gsub("User-Agent:", "").to_s.gsub("User-agent:", "").to_s.gsub("Server:", "").to_s.strip
      @sip_response = `cat /tmp/.mor_provider_check`
      return @sip_response.to_s.scan(/SIP.*200/).size > 0 ? true : false
    rescue
      return false
    end
  end

  def dont_be_so_smart(user_id = session ? session[:user_id] : 0 )
    flash[:notice] = _('Dont_be_so_smart')
    Action.dont_be_so_smart(user_id, request.env, params)
  end

  def check_user_id_with_session(user_id)
    if user_id != session[:user_id]
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    else
      return true
    end
  end

  def check_owner_for_device(user, r = 1, cu = nil)
    a = true
    if user.class != User
      user = User.where(:id => user).first
    end
    if cu == nil
      if session and session[:usertype] == "accountant" and ['accountant', 'admin'].include?(user.usertype)
        dont_be_so_smart
        a = false
        if r.to_i == 1
          redirect_to :controller => :users, :action => "list" and return false
        end
      end

      unless user and (user.owner_id == corrected_user_id.to_i)
        dont_be_so_smart
        a = false
        if r.to_i == 1
          redirect_to :controller => :users, :action => "list" and return false
        end
      end
    else
      if cu.usertype == "accountant" and user.usertype == "admin"
        dont_be_so_smart
        a = false
        if r.to_i == 1
          redirect_to :controller => :users, :action => "list" and return false
        end
      end

      coi = cu.usertype == "accountant" ? 0 : cu.id
      unless user and (user.owner_id == coi.to_i)
        dont_be_so_smart
        a = false
        if r.to_i == 1
          redirect_to :controller => :users, :action => "list" and return false
        end
      end
    end
    return a
  end

  def tax_from_params
    return {
        :tax1_enabled => 1,
        :tax2_enabled => params[:tax2_enabled].to_i,
        :tax3_enabled => params[:tax3_enabled].to_i,
        :tax4_enabled => params[:tax4_enabled].to_i,
        :tax1_name => params[:tax1_name].to_s,
        :tax2_name => params[:tax2_name].to_s,
        :tax3_name => params[:tax3_name].to_s,
        :tax4_name => params[:tax4_name].to_s,
        :total_tax_name => params[:total_tax_name].to_s,
        :tax1_value => params[:tax1_value].to_d,
        :tax2_value => params[:tax2_value].to_d,
        :tax3_value => params[:tax3_value].to_d,
        :tax4_value => params[:tax4_value].to_d,
        :compound_tax => params[:compound_tax].to_i
    }
  end

  def check_request_url
    Web_URL == request.protocol + request.host
  end

  # IP validation
  def check_ip_validity(ip=nil)
   regexp = /^\b(?![0.]*$)(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)(?:\.(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)){3}\b$/
   (regexp.match(ip) ? (return true) : (return false))
  end

  # Delegatas. Suderinamumui.
  def email_variables(user, device = nil, variables = {})
    Email.email_variables(user, device, variables, {:nice_number_digits => session[:nice_number_digits], :global_decimal => session[:global_decimal], :change_decimal => session[:change_decimal]})
  end

  def invoice_total_tax_name(tax)
    tax_name = tax.total_tax_name.to_s
    tax_name += " " + nice_number(tax.tax1_value.to_d).to_s + "%" if tax.get_tax_count == 1
    return tax_name
  end

  def owned_balance_from_previous_month(invoice)
    invoice.owned_balance_from_previous_month
  end

  def current_user
    @current_user ||= User.where(:id => session[:user_id]).includes(:tax, :address, :currency).first
    User.current_user = @current_user
    @current_user
  end

  def validate_range(value, min, max, min_def = nil, max_def = nil)
    min_def = min.to_d unless min_def
    max_def = max.to_d unless max_def
    value = min_def.to_d if value.to_d < min.to_d
    value = max_def.to_d if value.to_d > max.to_d
    return value
  end

  def archive_file_if_size(filename, extension, size, path = "/tmp")
    full_name = "#{filename}.#{extension}"
    f_size = `stat -c%s #{path}/#{full_name}`
    if (f_size.to_i / 1024).to_d >= size.to_d
      `rm -rf #{path}/#{filename}.tar.gz`
      `cd #{path}; tar -czf #{filename}.tar.gz #{filename}.#{extension}`
      `rm -rf #{path}/#{full_name}.#{extension}`
      return "#{path}/#{filename}.tar.gz"
    else
      return "#{path}/#{full_name}.#{extension}"
    end
  end

  def notice_with_info_help(text, help_link)
    text.to_s + " " + "<a id='notice_info_link' href='#{help_link}' target='_blank'>#{_("Press_Here_For_More_Info")}<img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' /></a>"
  end

  def csv_import_invalid_file_notice
    help_link = "http://wiki.kolmisoft.com/index.php/I_cannot_import_CSV_file"
    notice_with_info_help(_('Please_upload_valid_CSV_file')+".", help_link)
  end

  def csv_import_invalid_prefix_notice
    help_link = "http://wiki.kolmisoft.com/index.php/I_cannot_import_CSV_file"
    notice_with_info_help(_('Please_Check_Prefix_Format_In_CSV')+".", help_link)
  end

  def hide_finances(string, can_see = nil)
    can_see_finances?(can_see) ? string : ""
  end

  def can_see_finances?(can_see = nil)
    if !can_see
      (session[:usertype] == "accountant" and session[:acc_see_financial_data].to_i == 0) ? can_see = false : can_see = true
    end
    return can_see
  end

=begin
  Check whether current user can edit users, ofcourse it depend on wheter current
  users is owner of specific user. But for instance user cannot ever edit user's
  data or accountant can edit admin user's data if ha has manage users privilege.

  *Returns*
  +boolean+ true if current user might be able to edit some users data, false if
    there is no chance, that this user could ever edit anyones data.
=end
  def can_edit_users?
    ['reseller', 'admin'].include?(session[:usertype]) or session[:acc_user_manage].to_i == 2
  end

  def check_if_can_see_finances
    unless can_see_finances?
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  # Renders email for current user

  def render_email(email_to_render, user)
    bin = binding()
    Email.email_variables(user).each { |key, value| Kernel.eval("#{key} = '#{value.gsub("'", "&#8216;")}'", bin) }
    ERB.new(email_to_render.body).result(bin).to_s
  end


  def check_csv_file_seperators(file, min_collum_size = 1, return_type = 1, opts = {})
    f = file.split("\n")
    not_words = ""
    objc = []

    5.times { |num| not_words += f[num].to_s.gsub(/[\w "']/, "").to_s.strip }

    symbols_count=[]
    symbols = not_words.split(//).uniq.sort
    symbols.delete(':') if return_type == 2
    symbols.delete('-')

    symbols.each_with_index { |symbol, index| symbols_count[index] = not_words.count(symbol) }

    max2 = 0
    max_item2 = 0
    symbols_count.each_with_index { |item, index|
      max2 = index if  max_item2 <= item
      max_item2 = item if max_item2 <= item
    }

    symbols_count[max2] = 0
    max3 = 0
    max_item3 = 0
    symbols_count.each_with_index { |item, index|
      max3 = index if  max_item3 <= item
      max_item3 = item if max_item3 <= item
    }

    sep1, dec1 = symbols[max2].to_s, symbols[max3].to_s

    action = params[:controller].to_s + "_" + params[:action].to_s
    sep, dec = session["import_csv_#{action}_options".to_sym][:sep], session["import_csv_#{action}_options".to_sym][:dec]

    5.times { |num| objc[num] = f[num].to_s.split(sep1) }

    line = 1
    line = opts[:line] if opts[:line]
    colums_size = f[line].to_s.split(params[:sepn2]) if params[:sepn2]
    colums_size = f[line].to_s.split(sep1) if !params[:sepn2]
    flash[:status] = nil
    disable_next = false
    if ((sep1 != sep or (dec1 != dec and return_type == 2)) and params[:use_suggestion].to_i != 2) or (colums_size.size.to_i < min_collum_size.to_i and !params[:sepn2].blank?)
      disable_next = true if colums_size.size.to_i < min_collum_size.to_i
      flash[:notice] = nil
      if (sep1.to_s == "\\") or (dec1.to_s == "\\")
        flash[:notice] = _('Backslash_cannot_be_separator')
      else
        flash[:status] = _('Please_confirm_column_delimiter_and_decimal_delimiter')
      end
      render :file => "layouts/_csv_import_confirm", :layout => "callc.html.erb", :locals => {:sep => sep, :dec => dec, :sep1 => sep1, :dec1 => dec1, :return_type => return_type.to_i, :action_to => params[:action].to_s, :fl => objc, :min_collum_size => min_collum_size, :disable_next => disable_next, :opts => opts} and return false
    end
    return true
  end


  def nice_action_session_csv
    action = params[:controller].to_s + "_" + params[:action].to_s
    session["import_csv_#{action}_options".to_sym] ? options = session["import_csv_#{action}_options".to_sym] : options = {}

    if params[:step].to_i > 1
      if params[:use_suggestion].to_i >= 1
        options[:sep] = params[:use_suggestion].to_i == 1 ? params[:sepn].to_s : params[:sepn2].to_s
        options[:dec] = params[:use_suggestion].to_i == 1 ? params[:decn].to_s : params[:decn2].to_s
      else
        if options[:sep].blank?
          confl_sep = Confline.get_value("CSV_Separator", correct_owner_id).to_s
          options[:sep] = confl_sep.blank? ? ',' : confl_sep.to_s
        else
          options[:sep] = options[:sep]
        end
        if options[:dec].blank?
          confl_dec = Confline.get_value("CSV_Decimal", correct_owner_id).to_s
          options[:dec] = confl_dec.blank? ? '.' : confl_dec.to_s
        else
          options[:dec] = options[:dec]
        end
      end
    else
      confl_sep = Confline.get_value("CSV_Separator", correct_owner_id).to_s
      confl_dec = Confline.get_value("CSV_Decimal", correct_owner_id).to_s
      options[:sep] = confl_sep.blank? ? ',' : confl_sep.to_s
      options[:dec] = confl_dec.blank? ? '.' : confl_dec.to_s
    end

    session["import_csv_#{action}_options".to_sym] = options
    return options[:sep].to_s, options[:dec].to_s
  end

  def nice_date_from_params(options={})
    if options.size > 0
      if options[:year].to_i > 2000
        year = options[:year].to_i
        month = options[:month].to_i #<= 0 ? 1 :  options[:month].to_i
        if options[:day].to_i < 1
          options[:day] = 1
        else
          if !Date.valid_civil?(year.to_i, month.to_i, options[:day].to_i)
            options[:day] = last_day_of_month(year, month)
          end
        end
        day = options[:day]
        t = Time.mktime(year.to_i, month, day).to_date.to_s
      end
    else
      t = Date.now().to_s
    end
  end

  def nice_date_time(time, ofset=1)
    if time
      format = (session and !session[:date_time_format].to_s.blank?) ? session[:date_time_format].to_s : "%Y-%m-%d %H:%M:%S"
      if time.respond_to?(:strftime)
        t = time
      else
        t = time.to_time
      end
      if ofset.to_i == 1
        d = (session and current_user) ? current_user.user_time(t).strftime(format.to_s) : t.strftime(format.to_s)
      else
        d = t.strftime(format.to_s)
      end
    else
      d=''
    end
    return d
  end

=begin
  Since sessions are disabled in api, controller no longer can we user session[:XXX] or current_user method.
  If session is not found time/date will be converted to string in default format %Y-%m-%d. And note no time zone
  manglig with datetime, since there is no time zones.
=end
  def nice_date(date, ofset=1)
    if date
      format = (!session or session[:date_format].to_s.blank?) ? "%Y-%m-%d" : session[:date_format].to_s
      t = date.respond_to?(:strftime) ? date : date.to_time
      t = t.class.to_s == 'Date' ? t.to_time : t
      d = (session and ofset.to_i == 1) ? current_user.user_time(t).strftime(format.to_s) : t.strftime(format.to_s)
    else
      d=''
    end
    return d
  end

=begin
  Method to check check whether current user is accountat and has specified write permission
  Note that this method shouldnt be used only if you want to check whether user has some 
  kind of permissions but youre not certain that user is accountant. for instance current user is admin
  and he has rights to see financial data, but this method would return false because current user is 
  not accountant, hence 'current user IS ACCOUNTANT and has specified write permission'.
  !!!Note that there's method defined in User class accountant_allow_edit(permission), i believe you should 
  use that method!!!
 
  *Params*
  +permission_name+ string containing permission name, note that 'acc_' is added to that string.
 
  *Returns*
  +permited+ boolean value.
=end
  def accountant_can_write?(permission)
    session[:usertype].to_s == 'accountant' and session["acc_#{permission}".to_sym].to_i == 2
  end

=begin
  Same thing as for accountant_can_write goes for this method.
  !!!Note that there is(another..?) a bug - if accountant has write permission he should automaticaly have
  read permission. WRONG, according to this method he doesn't. Note that there's method defined in User 
  class accountant_allow_read(permission), i believe you should use that method!!!
=end
  def accountant_can_read?(permission)
    session[:usertype].to_s == 'accountant' and session["acc_#{permission}".to_sym].to_i == 1
  end

  def invoice_state(invoice)
    case invoice.state
      when "full"
        _('Paid')
      when "partial"
        _('Partly_paid')
      when "unpaid"
        _('Unpaid')
    end
  end

  def correct_page_number(page, total_pages, min_pages = 1)
    page = total_pages.to_i if page.to_i > total_pages.to_i
    page = min_pages.to_i if page.to_i < min_pages.to_i
    return page
  end

  def allow_manage_providers_tariffs?
    session[:usertype] == "admin" or current_user.reseller_allow_providers_tariff? or (session[:usertype].to_s == "accountant" and session[:acc_tariff_manage].to_i > 0)
  end

  def allow_manage_providers?
    session[:usertype] == "admin" or current_user.reseller_allow_providers_tariff?
  end

  def providers_enabled_for_reseller?
    unless allow_manage_providers?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def allow_manage_dids?
    (session[:allow_own_dids].to_i == 1 and current_user.usertype == 'reseller') or ['admin', 'accountant'].include?(current_user.usertype)
  end

  def see_providers_in_dids?
    (current_user.reseller_allow_providers_tariff? and current_user.usertype == 'reseller') or ['admin', 'accountant'].include?(current_user.usertype)
  end

  private

  def store_location
    session[:return_to] = request.url
  end

  def redirect_back_or_default(default = 'callc/main')
    session[:return_to] ? redirect_to(session[:return_to]) : redirect_to(Web_Dir + default)
    session[:return_to] = nil
  end

  def get_memory_info
    begin
      info = "RAM:\n"
      info += `free`
      info += "\nDISK:\n"
      info += `df -h`
      info += "\nPS AUX:\n"
      info += `ps aux | grep 'apache\\|cgi\\|USER' | grep -v grep`
      return info
    rescue Exception
      return "Error on extracting memory and PS info."
    end
  end

  def get_svn_info
    begin
      svn_info = `svn info #{Rails.root}`
      svn_status = (`svn status #{Rails.root} 2>&1`).to_s.split("\n").collect { |l| l if (l[0..0] == "M" or l.scan("This client is too old to work with working copy").size > 0) }.compact.size > 0
      svn_data = svn_info.split("\n")
      rep = svn_data[1].to_s.split(": ")[1].to_s.strip
      rev = svn_data[4].to_s.split(": ")[1].to_s.strip
      status = svn_status ? "YES" : "NO"
    rescue Exception => e
      #for info
      status = e
      rev = rep = "SVN ERROR"
      #status = rev = rep = "SVN ERROR"
    end
    return rep, rev, status
  end

  def simple_file_name?(string)
    string.match(/^[a-zA-Z1-9]+.[a-zA-Z1-9]+/)
  end

  def testable_file_send(file, filename, mimetype)
    if params[:test]
      case mimetype
        when "application/pdf" then
          render :text => {:filename => filename, :file => "File rendered"}.to_json
        else
          render :text => {:filename => filename, :file => file}.to_json
      end
    else
      send_data(file, :type => mimetype, :filename => filename)
    end
  end

  def send_crash_email(address, subject, message)
    MorLog.my_debug("  >> Before sending message.", true)
    local_filename = "/tmp/mor_crash_email.txt"
    File.open(local_filename, 'w') { |f| f.write(message) }
    command = "/usr/local/mor/sendEmail -f 'support@kolmisoft.com' -t '#{address}' -u '#{subject}' -s 'smtp.gmail.com' -xu 'crashemail1' -xp 'crashemail1999' -o message-file='#{local_filename}' tls='auto'"
    system(command)
    MorLog.my_debug("  >> Crash email sent to #{address}", true)
    MorLog.my_debug("  >> COMMAND : #{command.inspect}", true)
    MorLog.my_debug("  >> MESSAGE  #{message.inspect}", true)
    system("rm -f #{local_filename}")
  end

  def find_provider
    @provider = current_user.providers.where(:id => params[:id]).first
    unless @provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :controller => "providers", :action => 'list' and return false
    end
  end

  def find_providerrule
    unless @provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :controller => "providers", :action => 'list' and return false
    end
    @providerrule = @provider.providerrules.where(:id => params[:providerrule_id]).first
    unless @providerrule
      flash[:notice] = _('Provider_rule_was_not_found')
      redirect_to :controller => "providers", :action => 'list' and return false
    end
  end

  def find_destination
    @destination = Destination.where(:id => params[:id]).includes([:destinationgroup]).first
    unless @destination
      flash[:notice] = _('Destination_was_not_found')
      redirect_to :controller => "directions", :action => 'list' and return false
    end
  end

  def is_number?(val=nil)
    #check if value is a number ( no decimal seperator allowed )
    (!!(val.match /^[0-9]+$/) rescue false)
  end

  def is_numeric?(val=nil)
    # Check if value is a digit ( allows decimal seperator )
    (!!(Float(val)) rescue false)
  end

  def call_shop_active?
    defined?(CS_Active) and CS_Active == 1
  end

  def reseller_active?
    defined?(RS_Active) and RS_Active == 1
  end

  def payment_gateway_active?
    defined?(PG_Active) and PG_Active == 1
  end

  def calling_cards_active?
    defined?(CC_Active) and (CC_Active == 1) and (session[:usertype] != 'reseller' or (session[:usertype] == 'reseller' and (session[:res_calling_cards].to_i == 2)))
  end

  def sms_active?
    defined?(SMS_Active) and (SMS_Active == 1)
  end

  def callback_active?
    defined?(CALLB_Active) and (CALLB_Active == 1)
  end

  def recordings_addon_active?
    defined?(REC_Active) and REC_Active.to_i == 1
  end

  def monitorings_addon_active?
    defined?(MA_Active) and MA_Active == 1
  end

  def rs_active?
    (defined?(RS_Active) and RS_Active.to_i == 1)
  end

  def cc_active?
    (defined?(CC_Active) and CC_Active.to_i == 1)
  end

  def ad_active?
    (defined?(AD_Active) and AD_Active.to_i == 1)
  end

  def res_campaigns?
    (current_user and current_user.reseller_right('autodialer').to_i == 2)
  end

  def skp_active?
    (defined?(SKP_Active) and SKP_Active.to_i == 1)
  end

  def reseller_pro_active?
    reseller_active? and defined?(RSPRO_Active) and (RSPRO_Active == 1)
  end

  def rec_active?
    recordings_addon_active?
  end

  def monitoring_enabled_for(user)
    monitorings_addon_active? and user and (user.usertype == 'admin' or (user.usertype == 'accountant' and user.accountant_right('user_manage').to_i == 2) or (user.usertype == 'reseller' and user.reseller_right('monitorings').to_i == 2))
  end

  def allow_dahdi?
    session[:usertype] != "reseller" or (session[:device] and session[:device][:allow_dahdi] == true)
  end

  def allow_virtual?
    session[:usertype] != "reseller" or (session[:device] and session[:device][:allow_virtual] == true)
  end

  def admin?
    current_user.usertype == "admin"
  end

  def reseller?
    current_user.usertype == "reseller"
  end

  def user?
    current_user.usertype == "user"
  end

  def accountant?
    current_user.usertype == "accountant"
  end

  def show_recordings?
    0 == Confline.get_value("Hide_recordings_for_all_users", 0).to_i
  end

  def test_machine_active?
    (defined?(TEST_MACHINE) and TEST_MACHINE.to_i == 1)
  end

  def session_log_active?
    (defined?(TEST_MACHINE_SESSION) and TEST_MACHINE_SESSION.to_i == 1)
  end

  def erp_active?
    (defined?(ERP_Active) and ERP_Active.to_i == 1) and admin?
  end

  def provider_billing_active?
    (defined?(PROVB_Active) and PROVB_Active.to_i == 1)
  end

  def web_phone_active?
    (defined?(WP_Active) and WP_Active.to_i == 1)
  end

  def ast_18?
    (defined?(AST_18) and AST_18.to_i == 1)
  end

  def ccl_active?
    ccl_active = Confline.get_value("CCL_Active") rescue NIL
    (!ccl_active.blank? and ccl_active.to_i == 1)
  end

  def last_day_month(date)
    year = session["year_#{date}".to_sym]
    if last_day_of_month(session["year_#{date}".to_sym], session["month_#{date}".to_sym]).to_i <= session["day_#{date}".to_sym].to_i
      day = "01"
      if session["month_#{date}".to_sym].to_i == 12
        month = '01'
        year = session["year_#{date}".to_sym].to_i + 1
      else
        month = session["month_#{date}".to_sym].to_i+1
      end
    else
      day = session["day_#{date}".to_sym].to_i+1
      month = session["month_#{date}".to_sym].to_i
    end
    return year, month, day
  end

  def split_number(number)
    number_array = []
    number = number.to_s.gsub(/\D/, "")
    number.size.times { |i| number_array << number[0..i] }
    return number_array
  end

=begin
  Check whether supplied date's day is the last day of that month.
  Maybe we should exten Date, Daytime, Time with this method, but i dont approve modifying built in classes

  *Params*
  *date* - Date, Daytime, Time instances or anything that has year, month and day methods

  *Returns*
  *boolean* - true or false depending whether day is the last day of the month of supplied date
=end
  def self.last_day_of_the_month?(date)
    next_month = Date.new(date.year, date.month) + 42 # warp into the next month
    date.day == (Date.new(next_month.year, next_month.month) - 1).day # back off one day from first of that month
  end

=begin
  Check whether supplied date's day is the last day of that month.
  Maybe we should exten Date, Daytime, Time with this method, but i dont approve modifying built in classes

  *Params*
  *date* - Date, Daytime, Time instances or anything that has day method

  *Returns*
  *boolean* - true or false depending whether day is the first day of the month of supplied date
=end
  def self.first_day_of_the_month?(date)
    date.day == 1
  end

=begin
  Return difference in 'months' between two dates.
  In MOR 'month' only counts when it is a period FROM FIRST SECOND
  OF CALENDAR MONTH TILL LAST SECOND OF CALENDAR MONTH. for example:
  period between 01.01 00:00:00 and 01.31 23:59:59 is whole 1 month
  period between 01.02 00:00:00 and 02.01 23:59:59 is NOT a whole month, althoug intervals exressed as seconds are the same
  period between 01.01 00:00:00 and 02.01 23:59:59 is whole 1 month
  period between 01.01 00:00:00 and 02.29 23:59:59 is whole 1 month
  period between 01.01 00:00:00 and 02.29 23:59:59 is whole 1 month, allthoug it may seem as allmost two months
  period between 01.02 00:00:00 and 02.29 23:59:59 is NOT a whole month, allthoug it may seem as allmost two months
  period between 01.02 00:00:00 and 03.29 23:59:59 is only 1 whole month, allthoug it may seem as allmost three months
  lets hope you'll get it, if not ask boss, he knows whats this about.
=end
  def self.month_difference(period_start, period_end)
    month_diff = period_end.month - period_start.month
    if month_diff == 0
      return ((first_day_of_the_month? period_start and last_day_of_the_month? period_end) ? 1 : 0)
    else
      month_diff = month_diff - 1
      if first_day_of_the_month? period_start
        month_diff += 1
      end
      if last_day_of_the_month? period_end
        month_diff += 1
      end
      return month_diff
    end
  end


  def check_post_method
    unless request.post?
      dont_be_so_smart
      redirect_to root_path and return false
    end
  end
end

module Enumerable
  def dups
    inject({}) { |h, v| h[v]=h[v].to_i+1; h }.reject { |k, v| v==1 }.keys
  end
end


