# -*- encoding : utf-8 -*-
class FunctionsController < ApplicationController

  require "yaml"
  layout "callc"
  before_filter :check_post_method, :only => [:callback_settings_update, :activate_callback]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_location, :only => [:location_rules, :location_devices, :location_destroy]
  before_filter :find_location_rule, :only => [:location_rule_edit, :location_rule_update, :location_rule_change_status, :location_rule_destroy]
  before_filter :find_dialplan, :only => [:pbx_function_edit, :pbx_function_update, :pbx_function_destroy]
  before_filter :callback_active?, :only => [:callback, :callback_settings, :callback_settings_update, :activate_callback]
  skip_before_filter :redirect_callshop_manager, :except => [:login_as_execute]

  @@wp_view = [:webphone_settings]
  @@wp_edit = [:webphone_settings_update]
  before_filter(:only => @@wp_view+@@wp_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@wp_view, @@wp_edit, {:role => "accountant", :right => :acc_webphone_acc, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  @@card_view_res = []
  @@card_edit_res = [:webphone_settings_update, :webphone_settings]
  before_filter(:only => @@card_view_res+@@card_edit_res) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@card_view_res, @@card_edit_res, {:role => "reseller", :right => :res_webphone_res, :ignore => true})
    c.instance_variable_set :@allow_read_res, allow_read
    c.instance_variable_set :@allow_edit_res, allow_edit
    true
  }

  $date_formats = ["%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S", "%Y,%m,%d %H:%M:%S", "%Y.%m.%d %H:%M:%S", "%d-%m-%Y %H:%M:%S", "%d/%m/%Y %H:%M:%S", "%d,%m,%Y %H:%M:%S", "%d.%m.%Y %H:%M:%S", "%m-%d-%Y %H:%M:%S", "%m/%d/%Y %H:%M:%S", "%m,%d,%Y %H:%M:%S", "%m.%d.%Y %H:%M:%S"]
  $decimal_formats = ['.', ',', ';']

  def index
    redirect_to :controller => :callc, :action => :main and return false
  end


  def skype
    @page_title = _('Skype')
    @page_icon = 'skype.png'

    @skype_providers = Provider.find(:all, :conditions => "tech = 'Skype'", :order => "name ASC")

    @default_skype_provider = Confline.get_value("Skype_Default_Provider", 0).to_i

  end

  def skype_change_default_provider

    update_confline("Skype_Default_Provider", params[:skype_provider].to_s)

    provider = Provider.where({:id => params[:skype_provider].to_i}).first

    if provider
      exceptions = provider.skype_reload
      raise exceptions[0] if exceptions.size > 0
      flash[:status] = _('Skype_Default_Provider_changed')
    else
      flash[:notice] = _('Provider_not_found')
    end


    redirect_to :action => "skype"
  end

  # ============== CALLBACK ===============

  def spy_channel


    device_id = current_user.spy_device_id

    # this code selects correct calls for admin/reseller/user
    user_sql = " activecalls.id = #{params[:id].to_i}"
    user_id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    if user_id != 0
      #reseller or user
      if session[:usertype] == "reseller"
        #reseller
        user_sql += " AND (activecalls.user_id = #{user_id} OR dst.user_id = #{user_id} OR  activecalls.owner_id = #{user_id}) "
      else
        #user
        user_sql += " AND (activecalls.user_id = #{user_id} OR dst.user_id = #{user_id} )"
      end
    end

    acall = Activecall.find(:first, :conditions => user_sql, :joins => "LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id) ")
    unless acall
      @error = _('Dont_be_so_smart')
      dont_be_so_smart
      # redirect_to :controller=>:callc, :action=>:main and return false
    else

      if device_id > 0
        @channel = params[:channel].to_s

        device = Device.find(device_id)
        src = device.extension

        #server = Confline.get_value("Web_Callback_Server").to_i
        server = device.server_id.to_i
        server = 1 if server == 0

        src_channel = "Local/#{src}@mor_cb_src/n"

        extension = @channel.split('-')[0]

        @spy_device = nice_device(device)

        st = originate_call(device_id, src, src_channel, "mor_cb_spy", extension, _('Spy_Channel'), nil, server)

        @error = _('Cannot_connect_to_asterisk_server') if st.to_i != 0
      else
        @error = _('No_Spy_device_explanation')
      end
    end
    render(:layout => false)
  end


  def callback_from_url

    @page_title = _('Callback')

    @cb_ok = 0

    @acc = ""
    @src = ""
    @dst = ""
    secret = ""

    @acc = params[:acc].to_i if params[:acc]
    @src = params[:src] if params[:src]
    @dst = params[:dst] if params[:dst]
    secret = params[:secret] if params[:secret]

    if params[:acc].length > 0 and @src.length > 0


      device= Device.find(:first, :joins => "LEFT JOIN users ON (users.id = devices.user_id)", :conditions => ["devices.id = ? AND secret = ? AND device_type != 'FAX' AND (users.owner_id = ? OR users.id = ?) AND name not like 'mor_server_%'", @acc, secret, corrected_user_id, corrected_user_id])

      unless device
        flash[:notice] = _('Device_not_found')
        redirect_to :controller => :callc, :action => :main and return false
      end

      callerid_number = Confline.get_value('WEB_Callback_CID', 0)

      if device #Device.count(@acc, :conditions => "secret = '#{secret}'") > 0

        @cb_ok = 1

        channel = "Local/#{@src}@mor_cb_src/n"
        if @dst.length > 0
          st = originate_call(@acc, @src, channel, "mor_cb_dst", @dst, callerid_number)
        else
          st = originate_call(@acc, @src, channel, "mor_cb_dst_ask", "123", callerid_number)
        end

        @error = _('Cannot_connect_to_asterisk_server') if st.to_i != 0
                #create_call_file(@acc, @src, @dst)
      end

    end

    #render(:layout => "layouts/realtime_stats")
    render(:layout => false)
  end


  def callback
    @page_title = _('Callback')
    @page_icon = 'phone_sound.png'

    @user = current_user
    @devices = @user.devices

    if @devices.count == 0
      flash[:notice] = _('No_devices_callback_not_possible')
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    if session[:callback_active].to_i == 0
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end

  end


  def activate_callback

    @src = ""
    @dst = ""

    @acc = params[:acc].to_i
    @src = params[:src].gsub(/[^\d]/, "") if params[:src]
    @dst = params[:dst].gsub(/[^\d]/, "") if params[:dst]

    device = current_user.devices.find(:first, :conditions => {:id => @acc})

    unless device
      flash[:notice] = _('Device_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    callerid_number = device.callerid_number

    if callerid_number.length == 0
      # if number not set, check what to use as caller id:
      # source or WEB_Callback_CID ?
      if Confline.get_value('Web_Callback_Send_Source_As_CID', 0).to_i == 1
        callerid_number = @src
      else
        callerid_number = Confline.get_value('WEB_Callback_CID', 0)
      end
    end

    server = Confline.get_value("Web_Callback_Server").to_i
    server = 1 if server == 0

    serv = Server.where({:id => server}).first

    if @src.length > 0

      channel = "Local/#{@src}@mor_cb_src/n"
      if @dst.length > 0
        st = originate_call(@acc, @src, channel, "mor_cb_dst", @dst, callerid_number, nil, server)
      else
        st = originate_call(@acc, @src, channel, "mor_cb_dst_ask", "123", callerid_number, nil, server)
      end


      if st.to_i != 0
        flash[:notice] = _('Cannot_connect_to_asterisk_server')
      else
        flash[:status] = _('Callback_activated')
      end


    else
      flash[:notice] = _('Source_should_be_entered_for_callback')
    end


    redirect_to :controller => "functions", :action => 'callback' and return false

  end


  #================ PBX Functions  ===============
  def pbx_functions
    @page_title = _('Pbx_functions')

    @dialplans = current_user.dialplans.find(:all, :conditions => "dptype = 'pbxfunction'", :order => "name ASC")
    if reseller?
      @pbxfunctions = Pbxfunction.find(:all, :conditions => 'allow_resellers = 1 AND name != "ringgroupid"', :order => "pf_type ASC")
    else
      @pbxfunctions = Pbxfunction.find(:all, :conditions => 'name != "ringgroupid"', :order => "pf_type ASC")
    end

  end


  # before filter
  #   find_dialplan @dialplan
  def pbx_function_edit
    @page_title = _('Pbx_function_edit')
    @page_icon = 'edit.png'

    if reseller?
      @pbxfunctions = Pbxfunction.find(:all, :conditions => 'allow_resellers = 1 AND name != "ringgroupid"', :order => "pf_type ASC")
    else
      @pbxfunctions = Pbxfunction.find(:all, :conditions => 'name != "ringgroupid"', :order => "pf_type ASC")
    end

    @currency = Currency.get_active

    @pbxfunction = @dialplan.pbxfunction

    @user = User.find_by_id(@dialplan.data5) if @dialplan.data5 != "all" and !@dialplan.data5.blank?
    @users = current_user.find_all_for_select

  end

  # before filter
  #   find_dialplan @dialplan
  def pbx_function_update

    if current_user.id != @dialplan.user_id.to_i
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    user = User.find_by_id(params[:s_user].to_i)

    if reseller?
      if user.owner_id.to_i != current_user.id and user.id.to_i != current_user.id
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    else
      if user.owner_id.to_i != current_user.id
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end

    if params[:dialplan]
      pbxfunction_id = params[:dialplan][:type_id]
      pbxfunction = Pbxfunction.find(pbxfunction_id)
      if current_user.usertype == 'reseller' and pbxfunction.allow_resellers == 0
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
      #check if extension entered
      ext = params[:dialplan][:ext]
      if not ext or ext.length == 0
        flash[:notice] = _('Enter_extension')
        redirect_to :action => 'pbx_function_edit', :id => params[:id] and return false
      end

      #delete if extension changes
      if @dialplan.data2 != params[:dialplan][:ext]
        pbx_function_delete_extline(@dialplan)
      end

      if params[:dialplan][:type_id].to_i == 8
        @dialplan.data5=params[:s_user]
      end

      if @dialplan.update_attributes(params[:dialplan].merge({:dptype => "pbxfunction"}))
        pbx_function_configure_extline(@dialplan)

        flash[:status] = _('Pbx_function_updated')
      end
    end

    redirect_to :action => 'pbx_functions'
  end

  def pbx_function_add

    pbxfunction = Pbxfunction.find(params[:type_id])

    if current_user.usertype == 'reseller' and pbxfunction.allow_resellers == 0
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

    #check if extension entered
    ext = params[:ext]
    if not ext or ext.length == 0
      flash[:notice] = _('Enter_extension')
      redirect_to :action => 'pbx_functions' and return false
    end

    # check if such extension exist
    extline = Extline.find(:first, :conditions => "exten = '#{ext}'")

    if extline
      flash[:notice] = _('Such_extension_exists')
      redirect_to :action => 'pbx_functions' and return false
    end

    dialplan = Dialplan.new({:name => params[:name], :dptype => "pbxfunction", :data1 => params[:type_id], :data2 => params[:ext]})

    if pbxfunction and pbxfunction.pf_type == "tell_balance"
      def_currency = Currency.find(1)
      dialplan.data3 = def_currency.name if def_currency
      dialplan.data4 = "en"
      dialplan.data5 = "user"
    end

    if pbxfunction and pbxfunction.pf_type == "use_voucher"
      def_currency = Currency.find(1)
      dialplan.data3 = def_currency.name if def_currency
      dialplan.data4 = "en"
    end

    if pbxfunction and pbxfunction.pf_type == "external_did"
      dialplan.data5 = current_user.id
    end

    dialplan.save

    pbx_function_configure_extline(dialplan)

    flash[:status] = _('Pbx_function_created')
    redirect_to :action => 'pbx_functions'

  end


  def pbx_function_destroy
    #    dialplan = Dialplan.find_by_id(params[:id])
    #    unless dialplan
    #      flash[:notice]=_('Dialplan_was_not_found')
    #      redirect_to :action=>:pbx_functions and return false
    #    end
    dids = Did.count(:all, :conditions => ["dialplan_id =  ?", params[:id].to_i])
    if dids.to_i == 0
      pbx_function_delete_extline(@dialplan)

      @dialplan.destroy

      flash[:status] = _('Pbx_function_deleted')
      redirect_to :action => 'pbx_functions'
    else
      flash[:notice] = _('Pbx_is_assigned_to_DID')
      redirect_to :action => 'pbx_functions'
    end
  end

  #================= CALL TRACING ==================

  def call_tracing
    @page_title = _('Call_Tracing')
    @page_icon = 'lightning.png'
    @users = current_user.find_all_for_select
  end

  def call_tracing_ajax
    if admin?
      @user = User.find_by_id(params[:id])
      render :layout => false
    else
      render :text => "" and return false
    end
  end

  def call_tracing_user
    @page_title = _('Call_Tracing')
    @page_icon = 'lightning.png'
    notice_msg = nil
    notice_msg = _('User_not_found') if not (@user = call_tracing_user_find_user)
    if @user
      notice_msg = _('Device_Was_Not_Found') if notice_msg.nil? and not (@devices = @user.devices)
      notice_msg = _('Tariff_not_found') if notice_msg.nil? and not (@u_tariff = @user.tariff)
      notice_msg = _('Lcr_was_not_found') if notice_msg.nil? and not (@lcr = @user.lcr)
      if @lcr
        notice_msg = _('Lcrprovider_was_not_found') if notice_msg.nil? and not (@lcr_providers = @lcr.providers)
        notice_msg = _('There_is_no_active_provider') if notice_msg.nil? and not (@lcr_active_providers = @lcr.active_providers)
      end
    end

    if notice_msg.nil? and admin? and @user and @user.owner_id.to_i > 0
      @reseller = @user.owner
      if @reseller and @reseller.is_reseller?
        notice_msg = _('Reseller_Tariff_not_found') if notice_msg.nil? and not (@r_tariff = @reseller.tariff)
      else
        notice_msg = _('Reseller_Was_Not_Found')
      end
    end

    unless notice_msg.nil?
      flash[:notice] = notice_msg.to_s
      redirect_to :action => 'call_tracing' and return false
    end

    @hide_lcrs_and_providers = (reseller? and !current_user.can_own_providers?)
  end

  def call_tracing_device
    change_date

    @page_title = _('Call_Tracing')
    @page_icon = 'lightning.png'

    @user = call_tracing_device_find_user

    if not @user or !params[:user]
      flash[:notice] = _('User_not_found')
      redirect_to :action => 'call_tracing' and return false
    end

    @u_tariff = @user.tariff
    @lcr = @user.lcr
    if (!@lcr or @lcr == nil) or (@lcr.user_id.to_i == current_user.owner_id.to_i and current_user.reseller_allow_providers_tariff? and current_user.id != @user.id)
      flash[:notice] = _('Check_if_your_user_is_using_your_lcr')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    @lcr_providers = @lcr.providers

    @device = Device.find(:first, :conditions => ["devices.id = ? and devices.user_id = ?", params[:device], @user.id])

    unless @device
      flash[:notice] = _('Device_not_found')
      redirect_to :action => 'call_tracing' and return false
    end

    if @device.location
      if @device.location_id <= 1 and current_user.usertype == 'reseller'
        #import admin rules as default location and use it instead of GLOBAL!
        @device.check_location_id
        #now device should have default location in db
        @device = Device.find(:first, :conditions => ["devices.id = ? and devices.user_id = ?", params[:device], @user.id])
      end
    else
      flash[:notice] = _('No_location_found.Please_change_device_location')
      redirect_to :action => 'call_tracing_user', :user => @user.id and return false
    end

    if @device.device_type == "H323" and (@device.ipaddr == "0.0.0.0" or @device.ipaddr.to_s !~ /^\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$/)
      flash[:notice] = _('H323_device_must_have_IP')
      redirect_to :action => 'call_tracing_user', :user => @user.id and return false
    end

    if @device.device_type == "H323" and @device.port.to_i != 1720
      flash[:notice] = _('H323_device_port_is_not_1720')
    end

    @dst = params[:destination].to_s.strip

    #my_debug validate_date(session_from_date[0..3], session_from_date[5..6], session_from_date[8..9])

    if validate_date(session_from_date[0..3], session_from_date[5..6], session_from_date[8..9]) == 0
      flash[:notice] = _('Bad_date')
      redirect_to :action => 'call_tracing_user', :user => @user.id and return false
    end

    if @dst.length == 0
      flash[:notice] = _('Please_enter_destination')
      redirect_to :action => 'call_tracing_user', :user => @user.id and return false
    end

    if current_user.usertype == 'reseller' and @device.user_id == current_user.id
      @user_owner = @device.user.owner
    else
      @user_owner = current_user
    end

    # get daytype and localization settings
    day = session_from_date
    if @user_owner.usertype == 'reseller'
      usable_location = 'A.location_id = locations.id AND A.location_id != 1'
    else
      if @device.location
        usable_location = 'A.location_id = locations.id'
      else
        usable_location = 'A.location_id = locations.id OR A.location_id = 1'
      end
    end
    sql = "SELECT  A.*, (SELECT IF((SELECT daytype FROM days WHERE date = '#{day}') IS NULL,
(SELECT IF(WEEKDAY('#{day}') = 5 OR WEEKDAY('#{day}') = 6, 'FD', 'WD')),
(SELECT daytype FROM days WHERE date = '#{day}')))   as 'dt' FROM devices
JOIN locations ON (locations.id = devices.location_id)
LEFT JOIN (SELECT * FROM locationrules WHERE  enabled = 1 AND lr_type = 'dst' AND LENGTH('#{@dst}')
BETWEEN minlen AND maxlen AND (SUBSTRING('#{@dst}',1,LENGTH(cut)) = cut OR LENGTH(cut) = 0 OR ISNULL(cut))
ORDER BY LENGTH(cut) DESC ) AS A ON ( #{usable_location}) WHERE devices.id = #{@device.id}"
    #my_debug "1"
    res = ActiveRecord::Base.connection.select_one(sql)
    @daytype = res['dt']
    @loc_add = res['add']
    @loc_cut = res['cut']
    @loc_rule = res['name']
    @loc_lcr_id = res['lcr_id']
    @loc_tariff_id = res['tariff_id']
    @loc_device_id = res['device_id']
    #check if reseller is changed from/to res pro and he changed LCR in location rules, lcr partial
    lcr_owner = Lcr.find_by_id(@loc_lcr_id)
    if lcr_owner and !@user_owner.is_admin?
      if lcr_owner.user_id.to_i == @user_owner.owner_id.to_i and @user_owner.reseller_allow_providers_tariff?
        flash[:notice] = _('Check_if_you_are_using_your_lcr')
        redirect_to :controller => "callc", :action => "main" and return false
      elsif lcr_owner.user_id.to_i == @user_owner.id.to_i and !@user_owner.reseller_allow_providers_tariff?
        flash[:notice] = _('Check_if_you_are_using_admins_lcr')
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end


    # lcr change from localization
    if @loc_lcr_id.to_i > 0
      @old_lcr = @lcr
      if @user_owner.is_allow_manage_providers?
        @lcr = @user_owner.lcrs.find_by_id(@loc_lcr_id)
      else
        @lcr = @user_owner.load_lcrs(:first, :conditions => "id = #{@loc_lcr_id}")
      end
      @new_lcr = @lcr
      @lcr_providers = @lcr.providers if @lcr
    end

    # tariff change from localization
    if @loc_tariff_id.to_i > 0
      @old_u_tariff = @u_tariff
      @u_tariff = Tariff.find_by_id(@loc_tariff_id)
    end
    # device change from localization
    if @loc_device_id.to_i > 0
      @old_device = @device
      @new_device = Device.find_by_id(@loc_device_id)
    end


    #localization

    @loc_dst = Location.nice_locilization(@loc_cut, @loc_add, @dst)
    if @lcr
      # read LCR Partials
      sql = "SELECT lcr_partials.prefix as 'prefix', lcrs.id as 'lcr_id', lcrs.order FROM lcr_partials JOIN lcrs ON (lcrs.id = lcr_partials.lcr_id) WHERE main_lcr_id = '#{@lcr.id}' AND prefix=SUBSTRING('#{@loc_dst}',1,LENGTH(prefix)) ORDER BY LENGTH(prefix) DESC LIMIT 1;"
      #my_debug sql
      res = ActiveRecord::Base.connection.select_one(sql)
    end
    #=begin
    if res
      @old_lcr_before_partials = @lcr
      if @user_owner.is_allow_manage_providers?
        @lcr = @user_owner.lcrs.find_by_id(res['lcr_id'].to_i)
      else
        @lcr = Lcr.find(res['lcr_id'].to_i)
        #@lcr = current_user.load_lcrs(:first, :conditions=>"id = #{res['lcr_id'].to_i}")
      end
      unless @lcr
        flash[:notice] = _('LCR_in_lcr_partial_not_found')
        redirect_to :action => 'call_tracing' and return false
      end
      @lcr_providers = @lcr.providers
      @lcr_partials_prefix = res['prefix']
    end
    #=end

    @direction_name, @destination_group_name = direction_by_dst(@loc_dst)

    time = nice_time2 Time.mktime("2000", "01", "01", session[:hour_from], session[:minute_from], "00")
    dst = @loc_dst
    tariff_id = @u_tariff.id
    daytype = @daytype
    user = @user

    # Ticket 2143
    if @u_tariff.nil?
      flash[:notice] = _('Unknown_Error')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    # user rates

    if @u_tariff.purpose == "user"

      sql = "SELECT A.prefix, aratedetails.id as 'aid', aratedetails.from as 'afrom', aratedetails.duration as 'adur', aratedetails.artype as 'atype', aratedetails.round as 'around', aratedetails.price as 'aprice', destinationgroups.id as 'dgid', aratedetails.start_time, aratedetails.end_time " +
          "FROM  rates 	JOIN aratedetails ON (aratedetails.rate_id = rates.id  AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = ''))  "+
          "JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id ) " +
          "JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix)) AND destinationgroup_id > 0 ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id) " +
          " WHERE rates.tariff_id = #{tariff_id} ORDER BY afrom ASC, atype ASC "

      #my_debug "2"
      @res_user = ActiveRecord::Base.connection.select_all(sql)
      @dgroup = Destinationgroup.find(@res_user[0]['dgid']) if @res_user[0]

      #custom rates

      sql = "SELECT A.prefix, acustratedetails.id as 'acid', acustratedetails.from as 'acfrom', acustratedetails.duration as 'acdur', acustratedetails.artype as 'actype', acustratedetails.round as 'acround', acustratedetails.price as 'acprice', destinationgroups.id as 'dgid', acustratedetails.start_time, acustratedetails.end_time "+
          "FROM  destinationgroups   " +
          "JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))  ORDER BY LENGTH(destinations.prefix) AND destinationgroup_id > 0 DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id)   " +
          "JOIN customrates ON (customrates.destinationgroup_id = destinationgroups.id AND customrates.user_id = #{user.id})  " +
          "JOIN acustratedetails ON (acustratedetails.customrate_id = customrates.id  AND '#{time}' BETWEEN acustratedetails.start_time AND acustratedetails.end_time AND (acustratedetails.daytype = 'FD' OR acustratedetails.daytype = ''))  "

      @res_cuser = ActiveRecord::Base.connection.select_all(sql)
      @cdgroup = Destinationgroup.find(@res_cuser[0]['dgid']) if @res_cuser[0]

    else
      #wholesale rates
      @res_user = []
      @res_cuser = []

      sql = "SELECT A.prefix, ratedetails.rate, ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee as 'cf', ratedetails.start_time, ratedetails.end_time FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' )  AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))) as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{tariff_id} ORDER BY LENGTH(A.prefix) DESC LIMIT 1; "
      #my_debug sql

      @res_user = ActiveRecord::Base.connection.select_all(sql)
    end

    # my_debug @res_cuser
    # my_debug "3"


    # provider's stuff

    #-------------------


    @not_disabled_prov = 0
    @active_prov = 0

    @res_prov = []
    for prov in @lcr_providers

      tariff_id = prov.tariff_id

      rr= Hash.new

      rr['prov_name'] = prov.name
      rr['providers_id'] = prov.id
      rr['tech'] = prov.tech
      rr['server_ip'] = prov.server_ip
      rr['user_id'] = prov.device.user_id 

      sql = "SELECT `add`, cut FROM providerrules WHERE provider_id = #{prov.id} AND enabled = 1 AND pr_type = 'dst' AND LENGTH('#{dst}') BETWEEN minlen AND maxlen AND (SUBSTRING('#{dst}',1,LENGTH(cut)) = cut OR LENGTH(cut) = 0 OR ISNULL(cut)) ORDER BY LENGTH(cut) DESC LIMIT 1;"
      res = ActiveRecord::Base.connection.select_one(sql)

      rr['add'] = ""
      rr['cut'] = ""
      if res
        rr['add'] = res['add']
        rr['cut'] = res['cut']
      end

      sql = "SELECT A.prefix as 'prefix', ratedetails.rate as 'rate', ratedetails.increment_s as 'increment_s', ratedetails.min_time as 'min_time', ratedetails.connection_fee as 'cf', currencies.exchange_rate AS 'e_rate' FROM  tariffs JOIN currencies ON (currencies.name = tariffs.currency) JOIN rates ON (rates.tariff_id = tariffs.id)  JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' ) AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time)  JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix)) ORDER BY LENGTH(destinations.prefix) DESC) as A ON (A.id = rates.destination_id)  WHERE tariffs.id = #{tariff_id};"
      res = ActiveRecord::Base.connection.select_one(sql)

      rr['prefix'] = nil
      rr['cf'] = nil
      rr['increment_s'] = nil
      rr['min_time'] = nil
      rr['rate'] = nil
      rr['e_rate'] = "1"

      if res
        rr['prefix'] = res['prefix']
        rr['cf'] = res['cf']
        rr['increment_s'] = res['increment_s']
        rr['min_time'] = res['min_time']
        rr['rate'] = res['rate']
        rr['e_rate'] = res['e_rate']
      end
      tariff = Tariff.find_by_id(tariff_id)
      unless tariff
        flash[:notice] = _('Tariff_not_found')
        redirect_to :action => 'call_tracing' and return false
      end
      rr['e_rate'] = tariff.exchange_rate(@user_owner.currency.name).to_d

      if @user_owner.is_reseller? and @user_owner.is_allow_manage_providers? and prov.common_use == 1
        #t=Tariff.find_by_id(current_user.tariff_id)
        data = CommonUseProvider.find(:first, :conditions => " reseller_id = #{@user_owner.id} AND provider_id = #{prov.id}", :include => [:tariff])
        t = data.tariff if data
        unless t
          flash[:notice] = _('Tariff_not_found')
          redirect_to :action => 'call_tracing' and return false
        end
        rr['e_rate'] = t.exchange_rate(@user_owner.currency.name).to_d
        if t.purpose == "user"
          sql = "SELECT aratedetails.price as 'rate',aratedetails.round as 'increment_s'  " +
              "FROM  rates 	JOIN aratedetails ON (aratedetails.rate_id = rates.id  AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = ''))  "+
              "JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id ) " +
              "JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))  ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id) " +
              " WHERE rates.tariff_id = #{t.id} "
        else
          sql = "SELECT ratedetails.rate , ratedetails.increment_s as 'increment_s'
                FROM rates
                JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' )
                 AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time)
                 JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))) as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{t.id} ORDER BY LENGTH(A.prefix) DESC LIMIT 1; "
        end
        rate = ActiveRecord::Base.connection.select_one(sql)
        if rate
          rr['rate'] = rate['rate']
          rr['increment_s'] = rate['increment_s']
        else
          rr['rate'] = nil
        end
      elsif @user_owner.is_reseller? and !@user_owner.is_allow_manage_providers?
        t = @user_owner.tariff
        unless t
          flash[:notice] = _('Tariff_not_found')
          redirect_to :action => 'call_tracing' and return false
        end
        rr['e_rate'] = t.exchange_rate(@user_owner.currency.name).to_d
        if t.purpose == "user"
          sql = "SELECT aratedetails.price as 'rate',aratedetails.round as 'increment_s'  " +
              "FROM  rates 	JOIN aratedetails ON (aratedetails.rate_id = rates.id  AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = ''))  "+
              "JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id ) " +
              "JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))  ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id) " +
              " WHERE rates.tariff_id = #{t.id} "
        else
          sql = "SELECT ratedetails.rate as 'rate', ratedetails.increment_s as 'increment_s'
                FROM rates
                JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' )
                 AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time)
                 JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))) as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{t.id} ORDER BY LENGTH(A.prefix) DESC LIMIT 1; "
        end
        rate = ActiveRecord::Base.connection.select_one(sql)
        if rate
          rr['rate'] = rate['rate']
          rr['increment_s'] = rate['increment_s']
        else
          rr['rate'] = nil
        end
      end

      @res_prov << rr
      @not_disabled_prov += 1 if prov.active?(@lcr.id) == 1
      @active_prov += 1 if rr['rate'] and rr['prefix'] and prov.active?(@lcr.id) == 1 and (prov.device.user_id.to_i != @user.id.to_i) 

    end

    if admin? and @user.owner_id.to_i > 0
      @reseller = @user.owner
      unless @reseller and @reseller.is_reseller?
        flash[:notice] = _('Reseller_Was_Not_Found')
        redirect_to :action => 'call_tracing' and return false
      end
    elsif reseller?
      @reseller = current_user
    end

    if @reseller
      @r_tariff = @reseller.tariff
      @r_lcr = @reseller.lcr
      @r_lcr_providers = @lcr.providers if @lcr

      if @r_tariff.purpose == "user"

        sql = "
         SELECT A.prefix, aratedetails.id as 'aid', aratedetails.from as 'afrom', aratedetails.duration as 'adur', aratedetails.artype as 'atype', aratedetails.round as 'around', aratedetails.price as 'aprice', destinationgroups.id as 'dgid', aratedetails.start_time, aratedetails.end_time
         FROM  rates
           JOIN aratedetails ON (aratedetails.rate_id = rates.id)
           JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id )
           JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))  ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id)
         WHERE rates.tariff_id = #{@r_tariff.id} AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = '')
         ORDER BY afrom ASC, atype ASC "

        #my_debug "2"
        @res_reseller = ActiveRecord::Base.connection.select_all(sql)

        @dgroup_reseller = Destinationgroup.find(@res_reseller[0]['dgid']) if @res_reseller[0]

        #custom rates

        sql = "
          SELECT A.prefix, acustratedetails.id as 'acid', acustratedetails.from as 'acfrom', acustratedetails.duration as 'acdur', acustratedetails.artype as 'actype', acustratedetails.round as 'acround', acustratedetails.price as 'acprice', destinationgroups.id as 'dgid', acustratedetails.start_time, acustratedetails.end_time
          FROM  destinationgroups
            JOIN customrates ON (customrates.destinationgroup_id = destinationgroups.id)
            JOIN acustratedetails ON (acustratedetails.customrate_id = customrates.id)
            JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))  ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id)
          WHERE  '#{time}' BETWEEN acustratedetails.start_time AND acustratedetails.end_time AND (acustratedetails.daytype = 'FD' OR acustratedetails.daytype = '') AND customrates.user_id = #{@reseller.id}"


        @res_creseller = ActiveRecord::Base.connection.select_all(sql)
        @cdgroup_reseller = Destinationgroup.find(@res_creseller[0]['dgid']) if @res_creseller[0]
      else
        #wholesale rates
        @res_reseller = []
        @res_creseller= []
        sql = "SELECT A.prefix, ratedetails.rate, ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee as 'cf', ratedetails.start_time, ratedetails.end_time FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' )  AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))) as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{@r_tariff.id} ORDER BY LENGTH(A.prefix) DESC LIMIT 1; "
        @res_reseller = ActiveRecord::Base.connection.select_all(sql)
      end
    end
    @hide_lcrs_and_providers = (reseller? and !current_user.can_own_providers?)
    @hide_locations = (reseller? and @device.user_id == current_user.id)
  end


  #================= LOGIN AS ==================

  def login_as
    @page_title = _('Login_as')
    @page_icon = 'key.png'


    @users = User.find(:all, :select => "*, #{SqlExport.nice_user_sql}", :conditions => "hidden = 0", :order => "nice_user ASC")

  end


  def login_as_execute
    @user = User.find_by_id(params[:user])
    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => :index and return false
    end

    if @user.owner_id.to_i != session[:user_id].to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    @login_ok = true

    renew_session(@user)

    flash[:status] = _('Logged_as') + ": " + nice_user(@user)

    if defined?(CS_Active) && CS_Active == 1 && group = @user.usergroups.includes(:group).where("usergroups.gusertype = 'manager' and groups.grouptype = 'callshop'").first
      session[:cs_group] = group
      session[:lang] = Translation.find_by_id(group.group.translation_id).short_name
      redirect_to :controller => "callshop", :action => "show", :id => group.group_id and return false
    else
      redirect_to :controller => "callc", :action => 'main' and return false
    end

  end


  def settings
    @page_title = _('Settings')
    @page_icon = 'cog.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Configuration_from_GUI'

    @countries = Direction.find(:all, :order => "name ASC")
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{session[:user_id]}' #{cond} ", :order => "purpose ASC, name ASC")
    @lcrs = current_user.lcrs.find(:all, :order => "name ASC")
    @currencies = Currency.get_active
    @servers = Server.find(:all, :order => "server_id ASC")
    @all_ivrs = Ivr.find(:all)

    style(Confline.get_value("Usual_text_font_style").to_i)
    @style1 = @ar[2]
    @style2 = @ar[1]
    @style3 = @ar[0]
    style(Confline.get_value("Usual_text_highlighted_text_style").to_i)
    @style4 = @ar[2]
    @style5 = @ar[1]
    @style6 = @ar[0]
    style(Confline.get_value("Header_footer_font_style").to_i)
    @style7 = @ar[2]
    @style8 = @ar[1]
    @style9 = @ar[0]

    @invoice_postpaid = Confline.get_value("Invoice_default").to_i
    @i_postpaid = []
    max = 128
    i= 6
    6.times do
      max = max / 2
      if @invoice_postpaid.to_i >= max.to_i
        @i_postpaid[i] = max
        @invoice_postpaid = @invoice_postpaid.to_i - max.to_i
      end
      i = i -1
    end

    @invoice_prepaid = Confline.get_value("Prepaid_Invoice_default").to_i
    @i_prepaid = []
    max = 128
    i= 6
    6.times do
      max = max / 2
      if @invoice_prepaid.to_i >= max.to_i
        @i_prepaid[i] = max
        @invoice_prepaid = @invoice_prepaid.to_i - max.to_i
      end
      i = i -1
    end

    @agreement = Confline.get("Registration_Agreement", session[:user_id])

  end

  def send_test_email
    @emails = Email.find(:all, :conditions => ["owner_id= ? AND (callcenter='0' OR callcenter IS NULL)", session[:user_id]])
    if @emails.size.to_i == 0 and session[:usertype] == "reseller"
      user=User.find(session[:user_id])
      user.create_reseller_emails
    end
    @num = EmailsController.send_test(session[:user_id])
    @num == "#{_('Email_sent')}<br>" ? flash[:status] = @num : flash[:notice] = @num

    if session[:usertype] == "admin"
      redirect_to :action => "settings"
    else
      redirect_to :action => "reseller_settings"
    end
  end

  def settings_change
    if params[:company].to_s.length == 0
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    if invalid_api_params? params[:allow_api], params[:api_secret_key]
      flash[:notice] = _("invalid_api_secret_key")
      redirect_to :action => 'settings' and return false
    end

    params[:email_from] = params[:email_from].to_s.downcase.strip
    if (params[:email_sending_enabled].to_i == 1 and params[:email_from].to_s.blank?) or (not params[:email_from].to_s.blank? and not params[:email_from].to_s =~ /^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$/ )
      flash[:notice] = _("Invalid_email_format_in_emails_from")
      redirect_to :action => 'settings' and return false
    end
=begin
    if (!Email.address_validation(params[:email_fax_from_sender]) and params[:fax_device_enabled].to_i == 1)  or !Email.address_validation(params[:company_email])
      flash[:notice] = _("Email_address_not_correct")
      redirect_to :action => 'settings' and return false
    end
=end
    #reset  /stats/subscriptions_stats  session
    session[:subscriptions_stats_options] = {}

    error = 0
    #Globals
    update_confline("Company", params[:company])
    update_confline("Company_Email", params[:company_email])
    update_confline("Version", params[:version])
    update_confline("Copyright_Title", params[:copyright_title])
    update_confline("Admin_Browser_Title", params[:admin_browser_title])
    Confline.set_value2("Frontpage_Text", params[:frontpage_text].to_s, session[:user_id])
    Confline.set_value2("Login_page_Text", params[:login_page_text].to_s, session[:user_id])
    #Registration

    update_confline("Registration_enabled", params[:registration_enabled])
    Confline.set_value("Hide_registration_link", params[:hide_registration_link])
    update_confline("Tariff_for_registered_users", params[:tariff_for_registered_users])
    update_confline("LCR_for_registered_users", params[:lcr_for_registered_users])
    update_confline("Default_Country_ID", params[:default_country_id])
    update_confline("Asterisk_Server_IP", params[:asterisk_server_ip])
    update_confline("Default_CID_Name", params[:default_cid_name])
    update_confline("Default_CID_Number", params[:default_cid_number])
    update_confline("Send_Email_To_User_After_Registration", params[:send_email_to_user_after_registration])
    update_confline("Send_Email_To_Admin_After_Registration", params[:send_email_to_admin_after_registration])
    Confline.set_value("Default_Balance_for_new_user", params[:default_balance_for_new_user].to_d)
    if params[:enable_recaptcha].to_i == 0 or (params[:enable_recaptcha].to_i == 1 and !params[:recaptcha_public_key].to_s.blank? and !params[:recaptcha_private_key].to_s.blank?)
      Confline.set_value("reCAPTCHA_enabled", params[:enable_recaptcha].to_i)
      Confline.set_value("ReCAPTCHA_public_key", params[:recaptcha_public_key].to_s.strip)
      Confline.set_value("ReCAPTCHA_private_key", params[:recaptcha_private_key].to_s.strip)
      Recaptcha.configuration.send("public_key=", Confline.get_value("reCAPTCHA_public_key"))
      Recaptcha.configuration.send("private_key=", Confline.get_value("reCAPTCHA_private_key"))
      Recaptcha.configuration.public_key = Confline.get_value("reCAPTCHA_public_key")
      Recaptcha.configuration.private_key = Confline.get_value("reCAPTCHA_private_key")
    end
    Confline.set_value("Allow_registration_username_passwords_in_devices", params[:allow_registration_username_passwords_in_devices].to_i)
    Confline.set_value("Active_calls_show_did", params[:active_calls_show_did].to_i)
    Confline.set_value("Registration_Enable_VAT_checking", params[:enable_vat_checking].to_i)
    Confline.set_value("Registration_allow_vat_blank", params[:allow_vat_blank].to_i)

    #Invoices
    #postpaid
    update_confline("Invoice_Number_Start", params[:invoice_number_start])
    params[:invoice_number_length] = validate_range(params[:invoice_number_length], 1, 20, 5).to_i
    update_confline("Invoice_Number_Length", params[:invoice_number_length])
    update_confline("Invoice_Number_Type", params[:invoice_number_type])
    update_confline("Invoice_Period_Start_Day", params[:invoice_period_start_day])
    update_confline("Invoice_Show_Calls_In_Detailed", params[:invoice_show_calls_in_detailed])
    format = params[:invoice_address_format].to_i == 0 ? 1 : params[:invoice_address_format]
    update_confline("Invoice_Address_Format", format)
    update_confline("Invoice_Address1", params[:invoice_address1])
    update_confline("Invoice_Address2", params[:invoice_address2])
    update_confline("Invoice_Address3", params[:invoice_address3])
    update_confline("Invoice_Address4", params[:invoice_address4])
    update_confline("Invoice_Bank_Details_Line1", params[:invoice_bank_details_line1])
    update_confline("Invoice_Bank_Details_Line2", params[:invoice_bank_details_line2])
    update_confline("Invoice_Bank_Details_Line3", params[:invoice_bank_details_line3])
    update_confline("Invoice_Bank_Details_Line4", params[:invoice_bank_details_line4])
    update_confline("Invoice_Bank_Details_Line5", params[:invoice_bank_details_line5])
    update_confline("Invoice_Balance_Line", params[:invoice_balance_line], session[:user_id])
    update_confline("Invoice_To_Pay_Line", params[:invoice_to_pay_line], session[:user_id])
    update_confline("Invoice_End_Title", params[:invoice_end_title])
    Confline.set_value("Invoice_Show_Balance_Line", params[:invoice_show_balance_line])
    Confline.set_value("Invoice_Add_Average_rate", params[:invoice_add_average_rate].to_i)
    Confline.set_value("Invoice_Show_Time_in_Minutes", params[:invoice_show_time_in_minutes].to_i)
    Confline.set_value('Show_recordings_with_zero_billsec', params[:show_recordings_with_zero_billsec].to_i)
    @invoice = (params[:i1]).to_i + (params[:i2]).to_i + (params[:i3]).to_i + (params[:i4]).to_i + (params[:i5]).to_i + (params[:i6]).to_i
    update_confline("Invoice_default", @invoice)
    Confline.set_value("Round_finals_to_2_decimals", params[:invoice_number_digits].to_i)
    Confline.set_value("Invoice_Short_File_Name", params[:invoice_short_file_name].to_i)
    session[:nice_invoice_number_digits] = params[:invoice_number_digits].to_i
    Confline.set_value("Invoice_user_billsec_show", params[:invoice_user_billsec_show].to_i)
    Confline.set_value("Invoice_show_additional_details_on_separate_page", params[:show_additional_details_on_separate_page_check].to_i)
    Confline.set_value2("Invoice_show_additional_details_on_separate_page", params[:show_additional_details_on_separate_page_details].to_s)
    set_valid_page_limit("Invoice_page_limit", params[:invoice_page_limit].to_i, 0) #"magic number" 0 means administrator id

    # Prepaid
    Confline.set_value("Prepaid_Invoice_Number_Start", params[:prepaid_invoice_number_start])
    params[:prepaid_invoice_number_length] = validate_range(params[:prepaid_invoice_number_length], 1, 20, 5).to_i
    Confline.set_value("Prepaid_Invoice_Number_Length", params[:prepaid_invoice_number_length])
    Confline.set_value("Prepaid_Invoice_Number_Type", params[:prepaid_invoice_number_type])
    Confline.set_value("Prepaid_Invoice_Period_Start_Day", params[:prepaid_invoice_period_start_day])
    Confline.set_value("Prepaid_Invoice_Show_Calls_In_Detailed", params[:prepaid_invoice_show_calls_in_detailed])
    Confline.set_value("Prepaid_Invoice_Address_Format", params[:prepaid_invoice_address_format])
    Confline.set_value("Prepaid_Invoice_Address1", params[:prepaid_invoice_address1])
    Confline.set_value("Prepaid_Invoice_Address2", params[:prepaid_invoice_address2])
    Confline.set_value("Prepaid_Invoice_Address3", params[:prepaid_invoice_address3])
    Confline.set_value("Prepaid_Invoice_Address4", params[:prepaid_invoice_address4])
    Confline.set_value("Prepaid_Invoice_Bank_Details_Line1", params[:prepaid_invoice_bank_details_line1])
    Confline.set_value("Prepaid_Invoice_Bank_Details_Line2", params[:prepaid_invoice_bank_details_line2])
    Confline.set_value("Prepaid_Invoice_Bank_Details_Line3", params[:prepaid_invoice_bank_details_line3])
    Confline.set_value("Prepaid_Invoice_Bank_Details_Line4", params[:prepaid_invoice_bank_details_line4])
    Confline.set_value("Prepaid_Invoice_Bank_Details_Line5", params[:prepaid_invoice_bank_details_line5])
    Confline.set_value("Prepaid_Invoice_Balance_Line", params[:prepaid_invoice_balance_line], session[:user_id])
    Confline.set_value("Prepaid_Invoice_To_Pay_Line", params[:prepaid_invoice_to_pay_line], session[:user_id])
    Confline.set_value("Prepaid_Invoice_End_Title", params[:prepaid_invoice_end_title])
    Confline.set_value("Prepaid_Invoice_Add_Average_rate", params[:prepaid_invoice_add_average_rate].to_i)
    Confline.set_value("Prepaid_Invoice_Show_Time_in_Minutes", params[:prepaid_invoice_show_time_in_minutes].to_i)
    Confline.set_value("Prepaid_Invoice_Show_Balance_Line", params[:prepaid_invoice_show_balance_line])
    @invoice_prepaid = (params[:i1_prepaid]).to_i + (params[:i2_prepaid]).to_i + (params[:i3_prepaid]).to_i + (params[:i4_prepaid]).to_i + (params[:i5_prepaid]).to_i + (params[:i6_prepaid]).to_i
    Confline.set_value("Prepaid_Invoice_default", @invoice_prepaid)
    Confline.set_value("Prepaid_Round_finals_to_2_decimals", params[:prepaid_invoice_number_digits].to_i)
    Confline.set_value("Prepaid_Invoice_Short_File_Name", params[:prepaid_invoice_short_file_name].to_i)
    session[:nice_prepaid_invoice_number_digits] = params[:prepaid_invoice_number_digits].to_i
    Confline.set_value("Prepaid_Invoice_user_billsec_show", params[:prepaid_invoice_user_billsec_show].to_i)
    Confline.set_value("Prepaid_Invoice_show_additional_details_on_separate_page", params[:prepaid_show_additional_details_on_separate_page_check].to_i)
    Confline.set_value2("Prepaid_Invoice_show_additional_details_on_separate_page", params[:prepaid_show_additional_details_on_separate_page_details].to_s)
    set_valid_page_limit("Prepaid_Invoice_page_limit", params[:prepaid_invoice_page_limit].to_i, 0) #"magic number" 0 means administrator id

    Confline.set_value("Invoice_allow_recalculate_after_send", params[:invoice_allow_recalculate_after_send].to_i, 0)

    #Emails

    update_confline("Email_Sending_Enabled", params[:email_sending_enabled])
    update_confline("Email_Smtp_Server", params[:email_smtp_server])
    # set default param in model
    #update_confline("Email_Domain", params[:email_domain])

    update_confline("Email_Batch_Size", params[:email_batch_size])
    update_confline("Email_from", params[:email_from])
    update_confline("Email_port", params[:email_port])


    if callback_active?
      if Confline.get_value("Email_Callback_Login", 0).to_s != params[:email_login] or Confline.get_value("Email_Callback_Pop3_Server", 0).to_s != params[:email_pop3_server]
        update_confline("Email_Pop3_Server", params[:email_pop3_server])
        update_confline("Email_Login", params[:email_login])
        update_confline("Email_Password", params[:email_password])
      else
        error =1
        flash[:notice] = _('Cannot_duplicate_email_callback_server')
      end
    else
      update_confline("Email_Login", params[:email_login])
      update_confline("Email_Password", params[:email_password])
    end

    #Realtime
    if (params[:time]).to_i < 15
      update_confline("Realtime_reload_time", '15')
    else
      update_confline("Realtime_reload_time", params[:time])
    end

    update_confline("Usual_text_font_color", params[:colorfield1])
    update_confline("Usual_text_font_size", params[:usual_text_font_size])
    @usual_text_font_style = (params[:style1]).to_i + (params[:style2]).to_i + (params[:style3]).to_i
    update_confline("Usual_text_font_style", @usual_text_font_style.to_s)
    update_confline("Usual_text_highlighted_text_color", params[:colorfield2])
    @usual_text_highlighted_text_style = (params[:style4]).to_i + (params[:style5]).to_i + (params[:style6]).to_i
    update_confline("Usual_text_highlighted_text_style", @usual_text_highlighted_text_style.to_s)
    update_confline("Usual_text_highlighted_text_size", params[:usual_text_highlighted_text_size])
    update_confline("Header_footer_font_color", params[:colorfield3])
    update_confline("Header_footer_font_size", params[:h_f_font_size])
    @h_f_font_style = (params[:style7]).to_i + (params[:style8]).to_i + (params[:style9]).to_i
    update_confline("Header_footer_font_style", @h_f_font_style.to_s)
    update_confline("Background_color", params[:colorfield4])
    update_confline("Row1_color", params[:colorfield5])
    update_confline("Row2_color", params[:colorfield6])
    update_confline("3_first_rows_color", params[:colorfield7])

    #Tax
    params[:total_tax] = "TAX" if params[:total_tax].blank?
    params[:tax1name] = params[:total_tax].to_s if params[:tax1name].blank?

    Confline.set_value("Tax_1", params[:tax1name])
    Confline.set_value("Tax_2", params[:tax2name])
    Confline.set_value("Tax_3", params[:tax3name])
    Confline.set_value("Tax_4", params[:tax4name])
    Confline.set_value("Tax_1_Value", params[:tax1value].to_d)
    Confline.set_value("Tax_2_Value", params[:tax2value].to_d)
    Confline.set_value("Tax_3_Value", params[:tax3value].to_d)
    Confline.set_value("Tax_4_Value", params[:tax4value].to_d)
    Confline.set_value("Total_tax_name", params[:total_tax])
    Confline.set_value("Tax_compound", params[:compound_tax].to_i, session[:user_id])

    Confline.set_value2("Tax_1", "1") # for consistency.
    Confline.set_value2("Tax_2", params[:tax2active].to_i)
    Confline.set_value2("Tax_3", params[:tax3active].to_i)
    Confline.set_value2("Tax_4", params[:tax4active].to_i)
    #/Tax
    Confline.set_value("User_Wholesale_Enabled", params[:user_wholesale_enabled])
    if params[:days_for_did_close].to_i > 1000
      Confline.set_value("Days_for_did_close", 1000)
    else
      if params[:days_for_did_close].to_i < 0
        Confline.set_value("Days_for_did_close", 0)
      else
        Confline.set_value("Days_for_did_close", params[:days_for_did_close])
      end
    end
    Confline.set_value("Agreement_Number_Length", params[:agreement_number_length])
    Confline.set_value("Nice_Number_Digits", params[:nice_number_digits])
    if params[:items_per_page].to_i < 1
      flash[:notice] = _('Items_Per_Page_mus_be_greater_than_0')
      error = 1
    else
      Confline.set_value("Items_Per_Page", params[:items_per_page].to_i)
    end

    Confline.set_value("Date_format", params[:date_format])
    Confline.set_value("Device_PIN_Length", params[:device_pin_length])
    Confline.set_value("Fax_Device_Enabled", params[:fax_device_enabled])
    Confline.set_value("Email_Fax_From_Sender", params[:email_fax_from_sender])
    Confline.set_value("Fax2Email_Folder", params[:fax2email_folder]) if params[:fax2email_folder].to_s.length > 0
    Confline.set_value("Change_dahdi", params[:change_dahdi])
    Confline.set_value("Change_dahdi_to", params[:change_dahdi_to])
    if params[:device_range_min].to_i < params[:device_range_max].to_i
      Confline.set_value("Device_Range_MIN", params[:device_range_min])
      Confline.set_value("Device_Range_MAX", params[:device_range_max])
    else
      flash[:notice] = _('Device_Range_interval_is_not_valid')
      error = 1
    end
    Confline.set_value("Disalow_Duplicate_Device_Usernames", params[:disalow_duplicate_device_usernames])
    update_confline("Disallow_prepaid_user_balance_drop_below_zero", params[:disallow_prepaid_user_balance_drop_below_zero].to_i)
    Confline.set_value("Hide_non_completed_payments_for_user", params[:hide_non_completed_payments_for_user].to_i)
    Confline.set_value("Disallow_Email_Editing", params[:disallow_email_editing], current_user.id)
    Confline.set_value('System_time_zone_daylight_savings', params[:system_time_zone_daylight_savings].to_i)


    Confline.set_value("AD_Sounds_Folder", params[:ad_sound_folder])
    Confline.set_value("Logout_link", params[:logout_link])
    # FUNCTIONALITY
    Confline.set_value("Devices_Check_Ballance", params[:devices_check_ballance])
    Confline.set_value("Devices_Check_Rate", params[:devices_check_rate])
    Confline.set_value("Allow_short_passwords_in_devices", params[:allow_short_passwords_in_devices].to_i)
    Confline.set_value("Show_zero_rates_in_LCR_tariff_export", params[:show_zero_rates_in_LCR_tariff_export].to_i)

    # FUNCTIONALITY
    Confline.set_value("Show_Rates_Without_Tax", params[:show_rates_without_tax], session[:user_id])
    ## Check if decimal separator and CSV separator are not equal.
    if params[:csv_separator] != params[:csv_decimal]
      Confline.set_value("CSV_Separator", params[:csv_separator])
      Confline.set_value("CSV_Decimal", params[:csv_decimal])
    end
    Confline.set_value("XML_API_Extension", params[:xml_api_extension].to_i)
    if  not params[:XML_API_Extension]
      Confline.set_value("Show_Full_Src", params[:show_full_src])
    end
    Confline.set_value("Google_Key", params[:gm_key])

    Confline.set_value("Active_Calls_Maximum_Calls", params[:active_calls_max])
    Confline.set_value("Active_Calls_Refresh_Interval", (params[:active_calls_interval].to_i < 3 ? 3 : params[:active_calls_interval].to_i))
    Confline.set_value("Show_Active_Calls_for_Users", params[:show_active_calls_for_users])
    Confline.set_value("Active_Calls_Show_Server", params[:active_calls_show_server])

    Confline.set_value("Banned_CLIs_default_IVR_id", params[:banned_clis_default_ivr_id])
    if params[:show_logo_on_register_page]
      Confline.set_value("Show_logo_on_register_page", params[:show_logo_on_register_page])
    else
      Confline.set_value("Show_logo_on_register_page", 0)
    end
    Confline.set_value("Show_rates_for_users", params[:show_rates_for_users].to_i, session[:user_id])
    Confline.set_value("Show_Advanced_Rates_For_Users", params[:show_advanced_rates_for_users].to_i, session[:user_id])

    Confline.set_value("Show_advanced_Provider_settings", params[:provider_settings].to_i, session[:user_id])
    Confline.set_value("Show_advanced_Device_settings", params[:device_settings].to_i, session[:user_id])
    Confline.set_value("Hide_payment_options_for_postpaid_users", params[:hide_payment_options_for_postpaid_users].to_i, session[:user_id])
    Confline.set_value("Hide_quick_stats", params[:hide_quick_stats].to_i, session[:user_id])
    Confline.set_value("Hide_HELP_banner", params[:hide_help_banner].to_i, session[:user_id])
    Confline.set_value("Hide_Iwantto", params[:hide_iwantto].to_i)
    Confline.set_value("Hide_Manual_Link", params[:hide_manual_link].to_i)
    Confline.set_value("Hide_Device_Passwords_For_Users", params[:hide_device_passwords_for_users].to_i, 0)
    Confline.set_value("Show_only_main_page", params[:show_only_main_page].to_i, 0)
    Confline.set_value("Show_forgot_password", params[:show_forgot_password].to_i, 0)
    Confline.set_value("Hide_recordings_for_all_users", params[:hide_recordings_for_all_users].to_i, 0)

    # GoogleMaps
    Confline.set_value("Google_Fullscreen", params[:gm_fullscreen])
    Confline.set_value("Google_ReloadTime", params[:gm_reload_time])
    Confline.set_value("Google_Width", params[:gm_width])
    Confline.set_value("Google_Height", params[:gm_height])
    Confline.set_value("Google_Key", params[:gm_key])

    # Backups Confline.set_value
    #Confline.set_value('Backup_Folder', params[:backup_storage_directory])
    if  params[:backup_number].to_i >= 3 and params[:backup_number].to_i <= 50
      Confline.set_value('Backup_number', params[:backup_number].to_i)
    else
      Confline.set_value('Backup_number', 3)
    end

    if  params[:backup_disk_space].to_i >= 10 and params[:backup_disk_space].to_i <= 100
      Confline.set_value('Backup_disk_space', params[:backup_disk_space].to_i)
    else
      Confline.set_value('Backup_disk_space', 10)
    end

    Confline.set_value('Backup_shedule', params[:shedule])
    Confline.set_value('Backup_month', params[:backup_month])
    if (((params[:backup_month].to_i % 2 == 1) and (params[:backup_month].to_i > 8)) or ((params[:backup_month].to_i % 2 == 0) and (params[:backup_month].to_i < 7))) and params[:backup_month_day].to_i >= 29
      params[:backup_month_day] = 30 if params[:backup_month_day].to_i >= 30
      if params[:backup_month].to_i == 2
        params[:backup_month_day] = 28
      end
    end
    Confline.set_value('Backup_month_day', params[:backup_month_day])
    Confline.set_value('Backup_week_day', params[:backup_week_day])
    Confline.set_value('Backup_hour', params[:hour])

    # API settings
    Confline.set_value('Allow_API', params[:allow_api].to_i)
    Confline.set_value('Allow_GET_API', params[:allow_get_api].to_i)
    Confline.set_value('API_Secret_Key', params[:api_secret_key])
    Confline.set_value('API_Login_Redirect_to_Main', params[:api_login_redirect_to_main].to_i)
    Confline.set_value('API_Allow_registration_ower_API', params[:api_allow_registration].to_i)
    Confline.set_value('API_Disable_hash_checking', params[:api_disable_hash_checking].to_i)
    # /API settings

    Confline.set_value("CSV_File_size", params[:csv_file_size].to_i)
    Confline.set_value('Play_IVR_for_200_HGC', params[:play_ivr_for_200_hgc].to_i)
    Confline.set_value('IVR_for_200_HGC', params[:ivr_for_200_hgc].to_i)

    # terms and conditions
    cl = Confline.find_or_create_by_name_and_owner_id("Registration_Agreement", session[:user_id])
    if params[:use_terms_and_conditions]
      cl.update_attributes({:value2 => params[:terms_and_conditions], :value => "1"})
    else
      cl.update_attribute(:value, "0")
    end

    Confline.set_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users', params[:change_if_hgc_not_equal_to_16_for_users].to_i)
    Confline.set_value('Global_Number_Decimal', params[:global_number_decimal].to_s)

    tb = Confline.get_value('Tell_Balance').to_i
    tt = Confline.get_value('Tell_Time').to_i
    Confline.set_value('Tell_Balance', params[:tell_balance].to_i)
    Confline.set_value('Tell_Time', params[:tell_time].to_i)
    Confline.set_value('API_Allow_payments_ower_API', params[:api_allow_payments].to_i)
    Confline.set_value('API_payment_confirmation', params[:api_payment_confirmation].to_i)
    Dialplan.change_tell_balance_value(params[:tell_balance].to_i) if tb != params[:tell_balance].to_i
    Dialplan.change_tell_time_value(params[:tell_time].to_i) if tt != params[:tell_time].to_i

    sip_port = params[:default_sip_device_port].to_i == 0 ? 5060 : params[:default_sip_device_port].to_i                                                                                                            
    iax2_port = params[:default_iax2_device_port].to_i == 0 ? 4569 : params[:default_iax2_device_port].to_i                                                                                                         
    h323_port = params[:default_h323_device_port].to_i == 0 ? 1720 : params[:default_h323_device_port].to_i                                                                                                         
    Confline.set_value('Default_SIP_device_port', sip_port, current_user.get_corrected_owner_id)                                                                                                                    
    Confline.set_value('Default_IAX2_device_port', iax2_port, current_user.get_corrected_owner_id)                                                                                                                  
    Confline.set_value('Default_H323_device_port', h323_port, current_user.get_corrected_owner_id)   
      
    # PRIVACY settings
    Confline.set_value("Hide_Destination_End", params[:hide_destination_ends_gui].to_i + params[:hide_destination_ends_csv].to_i + params[:hide_destination_ends_pdf].to_i)
    # /PRIVACY settings
    user = User.find_by_id(session[:user_id])
    unless user
      flash[:notice] = _("User_not_found")
      redirect_to :controller => :callc, :action => :main and return false
    end
    renew_session(user)
    if params[:enable_recaptcha].to_i == 1 and (params[:recaptcha_public_key].to_s.blank? or params[:recaptcha_private_key].to_s.blank?)
      flash[:notice] = _("reCAPTCHA_keys_cannot_be_empty")
      redirect_to :action => 'settings' and return false
    end
    if error.to_i == 0
      flash[:status] = _('Settings_saved')
    end
    redirect_to :action => 'settings' and return false

  end

=begin rdoc
Sets default tax values for users or cardgroups

*Params*

<tt>u</tt> - 1 : set default taxes for users, 2 : set default taxes for cardgroups

*Flash*

<tt>notice</tt> - _('User_taxes_set_successfully') for users or _('Cardgroup_taxes_set_successfully') for cardgroups

*Redirects*

<tt>settings</tt> - after this action settings form is reopened.
=end

  def tax_change
    owner = correct_owner_id
    tax ={
        :tax1_enabled => 1,
        :tax2_enabled => Confline.get_value2("Tax_2", owner).to_i,
        :tax3_enabled => Confline.get_value2("Tax_3", owner).to_i,
        :tax4_enabled => Confline.get_value2("Tax_4", owner).to_i,
        :tax1_name => Confline.get_value("Tax_1", owner),
        :tax2_name => Confline.get_value("Tax_2", owner),
        :tax3_name => Confline.get_value("Tax_3", owner),
        :tax4_name => Confline.get_value("Tax_4", owner),
        :total_tax_name => Confline.get_value("Total_tax_name", owner),
        :tax1_value => Confline.get_value("Tax_1_Value", owner).to_d,
        :tax2_value => Confline.get_value("Tax_2_Value", owner).to_d,
        :tax3_value => Confline.get_value("Tax_3_Value", owner).to_d,
        :tax4_value => Confline.get_value("Tax_4_Value", owner).to_d,
        :compound_tax => Confline.get_value("Tax_compound", owner).to_i
    }

    tax[:total_tax_name] = "TAX" if tax[:total_tax_name].blank?
    tax[:tax1_name] = tax[:total_tax_name].to_s if tax[:tax1_name].blank?

    case params[:u].to_i
      when 1
        users = User.find(:all, :include => [:tax], :conditions => ["owner_id = ?", owner])
        for user in users do
          user.assign_default_tax(tax, {:save => true})
        end
        Confline.set_default_object(Tax, owner, tax)
        flash[:status] = _('User_taxes_set_successfully')
      when 2
        Cardgroup.set_tax(tax, session[:user_id])
        flash[:status] = _('Cardgroup_taxes_set_successfully')
      when 3
        Voucher.set_tax(tax)
        flash[:status] = _('voucher_taxes_set_successfully')
      else
        dont_be_so_smart
    end

    if owner == 0
      redirect_to :action => 'settings' and return false
    else
      redirect_to :action => 'reseller_settings' and return false
    end
  end

  def settings_vm
    @page_title = _('VoiceMail_Settings')
    @page_icon = 'voicemail.png'

    @help_link = "http://wiki.kolmisoft.com/index.php/Voicemail"

    @devices = Device.find(:all, :conditions => "user_id >= 0 AND name not like 'mor_server_%'", :order => "username ASC")
  end


  def style(stile)
    @ar = []
    if stile >= 8
      @ar[0]=8
    else
      @ar[0]=0
    end
    stile = stile - @ar[0]

    if stile >= 6
      @ar[1]=4
    else
      @ar[1]=0
    end
    stile = stile - @ar[1]

    if stile >= 2
      @ar[2]=2
    else
      @ar[2]=0
    end

    return @ar

  end


  def settings_vm_change

    if params[:vm_retrieve_extension].length == 0
      flash[:notice] = _('Please_enter_extension')
      redirect_to :action => 'settings_vm' and return false
    end

    if params[:vm_server_active].to_i == 1 and params[:vm_server_device_id].length == 0
      flash[:notice] = _('Please_select_device')
      redirect_to :action => 'settings_vm' and return false
    end

    if params[:vm_server_retrieve_extension].length == 0
      flash[:notice] = _('Please_enter_extension')
      redirect_to :action => 'settings_vm' and return false
    end

    old_local_ext = Confline.get_value("VM_Retrieve_Extension", 0)
    new_local_ext = params[:vm_retrieve_extension]

    old_server_ext = Confline.get_value("VM_Server_Retrieve_Extension", 0)
    new_server_ext = params[:vm_server_retrieve_extension]
    device_id = params[:vm_server_device_id]

    update_confline("VM_Retrieve_Extension", new_local_ext)

    update_confline("VM_Server_Active", params[:vm_server_active])
    update_confline("VM_Server_Device_ID", device_id)
    update_confline("VM_Server_Retrieve_Extension", new_server_ext)


    reconfigure_voicemail(params[:vm_server_active].to_i, old_server_ext, new_server_ext, old_local_ext, new_local_ext, device_id)


    flash[:status] = _('Settings_saved')

    redirect_to :action => 'settings_vm' and return false

  end


  def settings_payments
    @page_title = _('Payment_Settings')
    @page_icon = 'cog.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Payments_configuration'

    @countries = Direction.find(:all, :order => "name ASC")
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{session[:user_id]}' #{cond} ", :order => "purpose ASC, name ASC")

    @lcrs = current_user.lcrs.find(:all, :order => "name ASC")
    @currencies = Currency.get_active
    @ppcurr = Confline.get_value("Paypal_Default_Currency")
    @wppcurr = Confline.get_value("WebMoney_Default_Currency")
    @lppcurr = Confline.get_value("Linkpoint_Default_Currency")
    @cpcurr = Confline.get_value("Cyberplat_Default_Currency")
    @selected_mode = Confline.get_value('WebMoney_SIM_MODE').to_i

  end

  def settings_payments_change
    @page_title = _('Payment_Settings')
    @page_icon = 'cog.png'
    default_amount = (params[:paypal_default_amount].to_d > params[:paypal_max_amount].to_d) ? params[:paypal_max_amount] : params[:paypal_default_amount]
    default_amount = (params[:paypal_default_amount].to_d < params[:paypal_min_amount].to_d) ? params[:paypal_min_amount] : default_amount

    #Vouchers
    Confline.set_value("Vouchers_Enabled", params[:vouchers_enabled].to_i, session[:user_id])
    if params[:vouchers_enabled].to_i == 0
      ActiveRecord::Base.connection.update("UPDATE conflines SET value = 0 WHERE name = 'Vouchers_Enabled'")
    end
    Confline.set_value("Voucher_Number_Length", params[:voucher_number_length])
    Confline.set_value("Voucher_Disable_Time", params[:voucher_disable_time])
    Confline.set_value("Voucher_Attempts_to_Enter", params[:voucher_attempts_to_enter])
    Confline.set_value("Voucher_Card_Disable", params[:voucher_card_disable].to_i)
    # /Vouchers

    #PayPal
    if (!Email.address_validation(params[:paypal_email]) and (params[:paypal_enabled].to_i == 1 or params[:paypal_test].to_i ==1))
      flash[:notice] = _("Email_address_not_correct")
      redirect_to :action => 'settings_payments' and return false
    end
    Confline.set_value("Paypal_Enabled", params[:paypal_enabled].to_i)
    Confline.set_value("Paypal_Disable_For_Reseller", params[:paypal_disable_for_reseller].to_i)
    Confline.set_value("PayPal_Email", params[:paypal_email])
    Confline.set_value("PayPal_Default_Currency", params[:paypal_default_currency])
    Confline.set_value("PayPal_User_Pays_Transfer_Fee", params[:paypal_user_pays_transfer_fee])
    Confline.set_value("PayPal_Default_Amount", default_amount)
    Confline.set_value("PayPal_Min_Amount", params[:paypal_min_amount])
    Confline.set_value("PayPal_Max_Amount", params[:paypal_max_amount])
    Confline.set_value("PayPal_Email_Notification", params[:paypal_email_notification])
    Confline.set_value("PayPal_Test", params[:paypal_test])
    Confline.set_value("PayPal_Payment_Confirmation", params[:paypal_payment_confirmation])
    Confline.set_value('PayPal_Custom_redirect', params[:paypal_custom_redirect])
    Confline.set_value('Paypal_return_url', params[:paypal_return_url])
    Confline.set_value('Paypal_cancel_url', params[:paypal_cancel_url])
    # /PayPal

    #WebMoney
    Confline.set_value("WebMoney_Enabled ", params[:webmoney_enabled].to_i)
    Confline.set_value("WebMoney_Gateway ", params[:webmoney_gateway].to_i)
    Confline.set_value("WebMoney_Test", params[:webmoney_test])
    Confline.set_value("WebMoney_Default_Currency", params[:webmoney_default_currency])
    Confline.set_value("WebMoney_Min_Amount", params[:webmoney_min_amount])
    Confline.set_value("WebMoney_Default_Amount", params[:webmoney_default_amount])
    Confline.set_value("WebMoney_Purse", params[:webmoney_purse])
    Confline.set_value("WebMoney_SIM_MODE", params[:webmoney_sim_mode])
    Confline.set_value("WebMoney_Secret_key", params[:webmoney_secret_key])
    Confline.set_value("Webmoney_skip_prerequest", params[:webmoney_skip_prerequest])
    # /Webmoney

    # CyberPlat
    Confline.set_value("Cyberplat_Enabled", params[:cyberplat_enabled].to_i)
    Confline.set_value("Cyberplat_Test", params[:cyberplat_test])
    Confline.set_value("Cyberplat_Default_Currency", params[:cyberplat_default_currency])
    Confline.set_value("Cyberplat_Default_Amount", params[:cyberplat_default_amount])
    Confline.set_value("Cyberplat_Min_Amount", params[:cyberplat_min_amount])
    Confline.set_value("Cyberplat_ShopIP", params[:cyberplat_shopip])
    Confline.set_value("Cyberplat_Transaction_Fee", params[:cyberplat_transaction_fee])
    Confline.set_value2("Cyberplat_Crap", params[:cyberplat_crap])
    Confline.set_value2("Cyberplat_Disabled_Info", params[:cyberplat_disabled_info])
    # /Cyberplat

    # Linkpoint
    Confline.set_value("Linkpoint_Enabled ", params[:linkpoint_enabled].to_i)
    Confline.set_value("Linkpoint_Test", params[:linkpoint_test].to_i)
    Confline.set_value("Linkpoint_Allow_HTTP", params[:linkpoint_allow_http].to_i)
    Confline.set_value("Linkpoint_Default_Currency", params[:linkpoint_default_currency])
    Confline.set_value("Linkpoint_Min_Amount", params[:linkpoint_min_amount])
    Confline.set_value("Linkpoint_Default_Amount", params[:linkpoint_default_amount])
    Confline.set_value("Linkpoint_StoreID", params[:linkpoint_storeid])
    # /Linkpoint

    # Ouroboros
    Confline.set_value("Ouroboros_Enabled", params[:ouroboros_enabled].to_i, session[:user_id])
    Confline.set_value("Ouroboros_Min_Amount", params[:ouroboros_min_amount].to_i, session[:user_id])
    Confline.set_value("Ouroboros_Max_Amount", params[:ouroboros_max_amount].to_i, session[:user_id])
    Confline.set_value("Ouroboros_Default_Amount", params[:ouroboros_default_amount].to_i, session[:user_id])
    Confline.set_value("Ouroboros_Language", params[:ouroboros_language], session[:user_id])
    Confline.set_value("Ouroboros_Default_Currency", params[:ouroboros_default_currency], session[:user_id])
    Confline.set_value("Ouroboros_Secret_key", params[:ouroboros_secret_key].to_s.strip, session[:user_id])
    Confline.set_value("Ouroboros_Merchant_Code", params[:ouroboros_merchant_code], session[:user_id])
    Confline.set_value("Ouroboros_Completion", 0, session[:user_id])
    Confline.set_value("Ouroboros_Completion_Over", params[:ouroboros_max_amount].to_i, session[:user_id])
    Confline.set_value("Ouroboros_Retry_Count", 3, session[:user_id])
    Confline.set_value("Ouroboros_Link_name_and_url", params[:ouroboros_link_name], session[:user_id])
    Confline.set_value2("Ouroboros_Link_name_and_url", params[:ouroboros_link_url], session[:user_id])
    # /Ouroboros

    user = User.find(session[:user_id])
    renew_session(user)

    flash[:status] = _('Settings_saved')
    redirect_to :action => 'settings_payments' and return false

  end

=begin rdoc

=end

  def settings_addons
    @page_title = _('Addons_Settings')
    @page_icon = 'cog.png'
    if recordings_addon_active?
      @total_recordings_size = Recording.find(:all, :first, :select => "SUM(size) AS 'total_size'", :conditions => "deleted = 0")[0]["total_size"].to_d
    end
  end

=begin rdoc

=end

  def settings_addons_change
    errors = []

    # === Recordings ===============================================================

    if recordings_addon_active?
      sum = params[:ra_ip].to_s.strip+params[:ra_port].to_s.strip+params[:ra_login].to_s.strip+params[:ra_password].to_s.strip
      if params[:ra_use_external_server].to_i == 1 and sum.length == 0
        flash[:notice]= _('Set_external_Server_options')
        redirect_to :action => 'settings_addons' and return false
      end
      Confline.set_value("Recordings_addon_Use_External_Server", params[:ra_use_external_server], session[:user_id])
      if Device.validate_ip(params[:ra_ip])
        Confline.set_value("Recordings_addon_IP", params[:ra_ip], session[:user_id])
      else
        errors << _('Recordings_addon_IP_is_not_valid')
        #redirect_to :action => 'settings_addons' and return false
      end
      if params[:ra_port].gsub(/[0-9]/, "").to_s.length == 0
        Confline.set_value("Recordings_addon_Port", params[:ra_port], session[:user_id])
      else
        errors << _('Recordings_addon_Port_is_not_valid')
        #redirect_to :action => 'settings_addons' and return false
      end

      Confline.set_value("Recordings_addon_Login", params[:ra_login], session[:user_id])
      Confline.set_value("Recordings_addon_Password", params[:ra_password], session[:user_id])
      Confline.set_value("Recordings_addon_Max_Space", (params[:ra_max_space].to_d*1048576).to_i, session[:user_id])
    end
    # /=== Recordings ==============================================================
    # === Click To Call ============================================================
    if calling_cards_active?
      Confline.set_value("CCShop_show_values_without_VAT_for_user", params[:CCShop_show_values_without_VAT_for_user].to_i, session[:user_id])
    end
    # === SMS ======================================================================
    if sms_active?
      Confline.set_value("SMS_Email_Pop3_Server", params[:email_pop3_server].to_s, session[:user_id])
      Confline.set_value("SMS_Email_Login", params[:email_login], session[:user_id])
      Confline.set_value("SMS_Email_Password", params[:email_password], session[:user_id])
      Confline.set_value("Send_SMS_from_Front_page", params[:send_sms_from_front_page].to_i, session[:user_id])
      Confline.set_value2("Frontpage_SMS_Text", params[:frontpage_sms_text].to_s, session[:user_id])
    end
    # /=== SMS =====================================================================

    # Monitoring
    if (defined?(MA_Active) and MA_Active == 1)

      Confline.set_value("Spy_Device", params[:spy_device], session[:user_id])

    end


    renew_session(current_user)

    if errors.size > 0
      flash[:notice] = " * " + errors.join("<br> * ")
    else
      flash[:status]= _('Settings_saved')
    end

    redirect_to :action => 'settings_addons' and return false
  end


  #================= LOGO UPLOAD ==================

  def settings_logo
    @page_title = _('Logo_settings')
    @logo = Confline.get_value("Logo_Picture")
  end

  def settings_logo_save
    if params[:logo]
      @file = params[:logo]
      if @file.size > 0
        if @file.size < 102400
          @filename = sanitize_filename(@file.original_filename)
          @ext = @filename.split(".").last.downcase
          if @ext == 'jpg' or @ext == 'jpeg' or @ext == 'png' or @ext == 'gif'
            File.open(Actual_Dir + '/app/assets/images/logo/' + @filename, "wb") do |f|
              f.write(params[:logo].read)
            end
            update_confline("Logo_Picture", 'logo/' + @filename)
            flash[:status] = _('Logo_uploaded')
            user = User.find(session[:user_id])
            renew_session(user)
          else
            flash[:notice] = _('Not_a_picture')
          end
        else
          flash[:notice] = _('Logo_to_big_max_size_100kb')
        end
      else
        flash[:notice] = _('Zero_size_file')
      end
    else
      flash[:notice] = _('Select_a_file')
    end
    redirect_to :action => 'settings_logo' and return false
  end

  def update_confline(cline, value, id = 0)
    Confline.set_value(cline, value, id)
  end

  def update_confline2(cline, value, id = 0)
    Confline.set_value2(cline, value, id)
  end

  def translations
    @page_title = _('Translations')
    @items = current_user.load_user_translations
  end


  def translations_sort
    params[:sortable_list].each_index do |i|
      item = UserTranslation.find(params[:sortable_list][i])
      item.update_attributes(:position => i)
    end
    @items = current_user.load_user_translations
    render :layout => false, :action => :translations
  end


  def translations_change_status
    tr = UserTranslation.find(params[:id])
    active = UserTranslation.get_active.size
    tr.active = (tr.active == 1 ? 0 : 1)
    if (tr.active == 0 and active != 1) or tr.active == 1
      tr.save
    end
    @items = current_user.load_user_translations
    render :layout => false, :action => :translations
  end

  def translations_refresh
    flags_to_session
    redirect_to :action => 'translations' and return false
  end

  #============== Reseller options ===============================================

  def reseller_settings
    @page_title = _('Settings')
    @page_icon = 'cog.png'

    @countries = Direction.find(:all, :order => "name ASC")
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{session[:user_id]}' #{cond} ", :order => "purpose ASC, name ASC")

    @currencies =Currency.get_active
    @user_id = session[:user_id]
    @user = current_user
    User.exists_resellers_confline_settings(session[:user_id])
    @agreement = Confline.get("Registration_Agreement", session[:user_id])

  end

  def reseller_settings_change


    if invalid_api_params? Confline.get_value('Allow_API').to_i == 1 , params[:api_secret_key]
      flash[:notice] = _("invalid_api_secret_key")
      redirect_to :action => :reseller_settings and return false
    end


    #Confline.set_value(cline, value, id)
    Confline.set_value("Company", params[:reseller_company], session[:user_id])
    Confline.set_value("Company_Email", params[:reseller_company_email], session[:user_id])
    Confline.set_value("Version", params[:reseller_version], session[:user_id])
    Confline.set_value("Copyright_Title", params[:reseller_copyright_title], session[:user_id])
    Confline.set_value("Admin_Browser_Title", params[:reseller_admin_browser_title], session[:user_id])
    Confline.set_value2("Frontpage_Text", params[:frontpage_text].to_s, session[:user_id])
    Confline.set_value("Show_advanced_Provider_settings", params[:provider_settings].to_i, session[:user_id])
    Confline.set_value("Show_advanced_Device_settings", params[:device_settings].to_i, session[:user_id])

    #boolean values

    {"Registration_enabled" => :registration_enabled, "Hide_registration_link" => :hide_registration_link, "Show_logo_on_register_page" => :show_logo_on_register_page, "Registration_Enable_VAT_checking" => :enable_vat_checking, "Registration_allow_vat_blank" => :allow_vat_blank}.each { |key, value|
      Confline.set_value(key, params[value].to_i, session[:user_id])
    }

    # INVOICES

    Confline.set_value("Invoice_Number_Start", params[:invoice_number_start], session[:user_id])
    params[:invoice_number_length] = validate_range(params[:invoice_number_length], 1, 20, 5).to_i
    Confline.set_value("Invoice_Number_Length", params[:invoice_number_length], session[:user_id])
    Confline.set_value("Invoice_Number_Type", params[:invoice_number_type], session[:user_id])
    Confline.set_value("Invoice_Period_Start_Day", params[:invoice_period_start_day], session[:user_id])
    Confline.set_value("Invoice_Show_Calls_In_Detailed", params[:invoice_show_calls_in_detailed], session[:user_id])
    format = params[:invoice_address_format].to_i == 0 ? Confline.get_value("Invoice_Address_Format", 0).to_i : params[:invoice_address_format]
    Confline.set_value("Invoice_Address_Format", format, session[:user_id])
    Confline.set_value("Invoice_Address1", params[:invoice_address1], session[:user_id])
    Confline.set_value("Invoice_Address2", params[:invoice_address2], session[:user_id])
    Confline.set_value("Invoice_Address3", params[:invoice_address3], session[:user_id])
    Confline.set_value("Invoice_Address4", params[:invoice_address4], session[:user_id])
    Confline.set_value("Invoice_Bank_Details_Line1", params[:invoice_bank_details_line1], session[:user_id])
    Confline.set_value("Invoice_Bank_Details_Line2", params[:invoice_bank_details_line2], session[:user_id])
    Confline.set_value("Invoice_Bank_Details_Line3", params[:invoice_bank_details_line3], session[:user_id])
    Confline.set_value("Invoice_Bank_Details_Line4", params[:invoice_bank_details_line4], session[:user_id])
    Confline.set_value("Invoice_Bank_Details_Line5", params[:invoice_bank_details_line5], session[:user_id])
    Confline.set_value("Invoice_Balance_Line", params[:invoice_balance_line], session[:user_id])
    Confline.set_value("Invoice_End_Title", params[:invoice_end_title], session[:user_id])
    Confline.set_value("Invoice_Show_Balance_Line", params[:invoice_show_balance_line], session[:user_id])
    Confline.set_value("Invoice_Short_File_Name", params[:invoice_short_file_name].to_i, session[:user_id])
    Confline.set_value("Date_format", params[:date_format], session[:user_id])
    Confline.set_value("Invoice_show_additional_details_on_separate_page", params[:show_additional_details_on_separate_page_check].to_i, session[:user_id])
    Confline.set_value2("Invoice_show_additional_details_on_separate_page", params[:show_additional_details_on_separate_page_details].to_s, session[:user_id])
    set_valid_page_limit("Invoice_page_limit", params[:invoice_page_limit].to_i, session[:user_id])
    unless current_user.reseller_allow_providers_tariff?
      # PRIVACY settings
      Confline.set_value("Hide_Destination_End", params[:hide_destination_ends_gui].to_i + params[:hide_destination_ends_csv].to_i + params[:hide_destination_ends_pdf].to_i, session[:user_id])
      # /PRIVACY settings
    end

    if params[:csv_separator] != params[:csv_decimal]
      update_confline("CSV_Separator", params[:csv_separator], session[:user_id])
      update_confline("CSV_Decimal", params[:csv_decimal], session[:user_id])
    end
    Confline.set_value("Show_Rates_Without_Tax", params[:show_rates_without_tax], session[:user_id])
    Confline.set_value("Show_rates_for_users", params[:show_rates_for_users].to_i, session[:user_id])
    Confline.set_value("Show_Advanced_Rates_For_Users", params[:show_advanced_rates_for_users].to_i, session[:user_id])
    update_confline("Disallow_prepaid_user_balance_drop_below_zero", params[:disallow_prepaid_user_balance_drop_below_zero].to_i, session[:user_id])
    Confline.set_value("Logout_link", params[:logout_link], session[:user_id])
    Confline.set_value("Show_only_main_page", params[:show_only_main_page].to_i, session[:user_id])
    Confline.set_value("Show_forgot_password", params[:show_forgot_password].to_i, session[:user_id])

    #Tax
    params[:total_tax] = "TAX" if params[:total_tax].blank?
    params[:tax1name] = params[:total_tax].to_s if params[:tax1name].blank?

    Confline.set_value("Tax_1", params[:tax1name], session[:user_id])
    Confline.set_value("Tax_2", params[:tax2name], session[:user_id])
    Confline.set_value("Tax_3", params[:tax3name], session[:user_id])
    Confline.set_value("Tax_4", params[:tax4name], session[:user_id])
    Confline.set_value("Tax_1_Value", params[:tax1value].to_d, session[:user_id])
    Confline.set_value("Tax_2_Value", params[:tax2value].to_d, session[:user_id])
    Confline.set_value("Tax_3_Value", params[:tax3value].to_d, session[:user_id])
    Confline.set_value("Tax_4_Value", params[:tax4value].to_d, session[:user_id])
    Confline.set_value("Total_tax_name", params[:total_tax], session[:user_id])

    Confline.set_value2("Tax_1", "1", session[:user_id]) # for consistency.
    Confline.set_value2("Tax_2", params[:tax2active].to_i, session[:user_id])
    Confline.set_value2("Tax_3", params[:tax3active].to_i, session[:user_id])
    Confline.set_value2("Tax_4", params[:tax4active].to_i, session[:user_id])
    Confline.set_value("Tax_compound", params[:compound_tax].to_i, session[:user_id])
    #/Tax

    # EMAILS

    params[:email_from] = params[:email_from].to_s.downcase.strip
    if (params[:email_sending_enabled].to_i == 1 and params[:email_from].to_s.blank?) or (not params[:email_from].to_s.blank? and not params[:email_from].to_s =~ /^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$/ )
      flash[:notice] = _("Invalid_email_format_in_emails_from")
      redirect_to :action => 'reseller_settings' and return false
    end

    Confline.set_value("Email_Sending_Enabled", params[:email_sending_enabled], session[:user_id])
    Confline.set_value("Email_Smtp_Server", params[:email_smtp_server], session[:user_id])
    # set default param in model
    #Confline.set_value("Email_Domain", params[:email_domain], session[:user_id])
    Confline.set_value("Email_Batch_Size", params[:email_batch_size], session[:user_id])
    Confline.set_value("Email_from", params[:email_from], session[:user_id])
    Confline.set_value("Email_port", params[:email_port], session[:user_id])
    Confline.set_value("Email_Login", params[:email_login], session[:user_id])
    Confline.set_value("Email_Password", params[:email_password], session[:user_id])
    i = 0
    if params[:email_login].blank?
      i = 1
      Confline.set_value("Email_Login", Confline.get_value("Email_Login", 0), session[:user_id])
      Confline.set_value("Email_Password", Confline.get_value("Email_Password", 0), session[:user_id])
    end
    Confline.set_value2("Email_Login", i, session[:user_id])
    Confline.set_value2("Email_Password", i, session[:user_id])
    Confline.set_value("Hide_Device_Passwords_For_Users", params[:hide_device_passwords_for_users].to_i, session[:user_id])

    # terms and conditions

    cl = Confline.find_or_create_by_name_and_owner_id("Registration_Agreement", session[:user_id])
    if params[:use_terms_and_conditions]

      cl.update_attributes({:value2 => params[:terms_and_conditions], :value => "1"})
    else

      cl.update_attribute(:value, "0")
    end
    Confline.set_value("Disallow_Email_Editing", params[:disallow_email_editing], current_user.id)

    # EMAILS
    #

    #API
    Confline.set_value('API_Secret_Key', params[:api_secret_key], current_user.id)
    Confline.set_value('API_Disable_hash_checking', params[:api_disable_hash_checking].to_i, current_user.id)

    #DEVICE 
    sip_port = params[:default_sip_device_port].to_i == 0 ? 5060 : params[:default_sip_device_port].to_i                                                                                                            
    iax2_port = params[:default_iax2_device_port].to_i == 0 ? 4569 : params[:default_iax2_device_port].to_i                                                                                                         
    h323_port = params[:default_h323_device_port].to_i == 0 ? 1720 : params[:default_h323_device_port].to_i                                                                                                         
    Confline.set_value('Default_SIP_device_port', sip_port, current_user.get_corrected_owner_id)                                                                                                                    
    Confline.set_value('Default_IAX2_device_port', iax2_port, current_user.get_corrected_owner_id)                                                                                                                  
    Confline.set_value('Default_H323_device_port', h323_port, current_user.get_corrected_owner_id)                 


    renew_session(current_user)

    flash[:status] = _('Settings_saved')
    redirect_to :action => 'reseller_settings' and return false
  end

  # -------------- Reseller logo options -----------------------------------------
  def reseller_settings_logo
    @page_title = _('Logo_settings')
    @logo = Confline.get_value("Logo_Picture", session[:user_id])
  end

  def reseller_settings_logo_save
    if params[:logo]
      @file = params[:logo]
      if @file.size > 0
        if @file.size < 102400
          @filename = sanitize_filename(@file.original_filename)
          @ext = @filename.split(".").last.downcase
          if @ext == 'jpg' or @ext == 'jpeg' or @ext == 'png' or @ext == 'gif'
            @filename = "logo_"+session[:user_id].to_s+"."+@ext
            File.open(Actual_Dir + '/app/assets/images/logo/' + @filename, "wb") do |f|
              f.write(params[:logo].read)
            end
            update_confline("Logo_Picture", 'logo/' + @filename.to_s, session[:user_id])
            flash[:status] = _('Logo_uploaded')
            user = User.find(session[:user_id])
            renew_session(user)
          else
            flash[:notice] = _('Not_a_picture')
          end
        else
          flash[:notice] = _('Logo_to_big_max_size_100kb')
        end
      else
        flash[:notice] = _('Zero_size_file')
      end
    else
      flash[:notice] = _('Select_a_file')
    end
    redirect_to :action => 'reseller_settings_logo' and return false
  end

  # -------------- RESELLER payment settings--------------------------------------
  def reseller_settings_payments
=begin
  2 eilutes resellerio setingu resetui
    #@user = User.find(session[:user_id])
    #@user.create_reseller_conflines
=end
    @page_title = _('Payment_Settings')
    @page_icon = 'cog.png'
    @currencies = Currency.get_active
    @ppcurr = Confline.get_value("Paypal_Default_Currency", session[:user_id])
    @wppcurr = Confline.get_value("WebMoney_Default_Currency", session[:user_id])
    @selected_mode = Confline.get_value('WebMoney_SIM_MODE', session[:user_id]).to_i
  end

  def reseller_settings_payments_change

    if (!Email.address_validation(params[:reseller_paypal_email]) and (params[:reseller_paypal_enabled].to_i == 1 or params[:reseller_paypal_test].to_i ==1))
      flash[:notice] = _("Email_address_not_correct")
      redirect_to :action => 'reseller_settings_payments' and return false
    end

    Confline.set_value("Paypal_Enabled", params[:reseller_paypal_enabled].to_i, session[:user_id])
    Confline.set_value("PayPal_Email", params[:reseller_paypal_email], session[:user_id])
    Confline.set_value("PayPal_Default_Currency", params[:reseller_paypal_default_currency], session[:user_id])
    Confline.set_value("PayPal_Default_Amount", params[:reseller_paypal_default_amount], session[:user_id])
    Confline.set_value("PayPal_User_Pays_Transfer_Fee", params[:paypal_user_pays_transfer_fee], session[:user_id])
    Confline.set_value("PayPal_Min_Amount", params[:reseller_paypal_min_amount], session[:user_id])
    Confline.set_value("PayPal_Test", params[:reseller_paypal_test], session[:user_id])
    Confline.set_value("PayPal_Email_Notification", params[:reseller_paypal_email_notification], session[:user_id])
    Confline.set_value("PayPal_Payment_Confirmation", params[:reseller_paypal_payment_confirmation], session[:user_id])
    Confline.set_value('PayPal_Custom_redirect', params[:paypal_custom_redirect], session[:user_id])
    Confline.set_value('Paypal_return_url', params[:paypal_return_url], session[:user_id])
    Confline.set_value('Paypal_cancel_url', params[:paypal_cancel_url], session[:user_id])

    #WebMoney
    if params[:reseller_webmoney_enabled]
      Confline.set_value("WebMoney_Enabled ", '1', session[:user_id])
    else
      Confline.set_value("WebMoney_Enabled ", '0', session[:user_id])
    end
    if params[:reseller_webmoney_test]
      Confline.set_value("WebMoney_Test", '1', session[:user_id])
    else
      Confline.set_value("WebMoney_Test", '0', session[:user_id])
    end
    Confline.set_value("WebMoney_Gateway ", params[:webmoney_gateway].to_i, session[:user_id])
    Confline.set_value("WebMoney_Default_Currency", params[:reseller_webmoney_default_currency], session[:user_id])
    Confline.set_value("WebMoney_Min_Amount", params[:reseller_webmoney_min_amount], session[:user_id])
    Confline.set_value("WebMoney_Default_Amount", params[:reseller_webmoney_default_amount], session[:user_id])

    Confline.set_value("WebMoney_Purse", params[:reseller_webmoney_purse], session[:user_id])
    Confline.set_value("WebMoney_SIM_MODE", params[:reseller_webmoney_sim_mode], session[:user_id])

    #Vouchers
    Confline.set_value("Vouchers_Enabled", params[:vouchers_enabled].to_i, session[:user_id])
    Confline.set_value("Voucher_Card_Disable", params[:voucher_card_disable].to_i, session[:user_id])

    user = User.find(session[:user_id])
    renew_session(user)

    flash[:status] = _('Settings_saved')
    redirect_to :action => 'reseller_settings_payments' and return false
  end

  #============= INTEGRITY CHECK ===============

  def integrity_check
    @page_title = _('Integrity_check')
    @page_icon = 'lightning.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Integrity_Check"
    @default_user_warning = false

    @destinations_without_dg = Destination.find(:all, :conditions => "destinationgroup_id = 0", :order => "direction_code ASC")
    @dialplans = Dialplan.find(:all, :conditions => "dptype = 'ivr' and data8 = 1")
    @actions = Action.find(:all, :joins => " JOIN users ON (actions.user_id = users.id) ", :conditions => "action = 'error' AND processed = '0' ")
    @devices = Device.find(:all, :conditions => "LENGTH(secret) < 8 AND LENGTH(username) > 0 AND device_type != 'H323' AND username NOT LIKE 'mor_server_%' AND user_id != -1")
    @users = User.find(:all, :conditions => ["password = SHA1('') or password = SHA1(username)"])
    @default_users_erors = Confline.get_default_user_pospaid_errors
    if  @default_users_erors and @default_users_erors.size.to_i > 0
      @default_user_warning = true
    end
    @users_postpaid_and_loss_calls = User.find(:all, :conditions => ["postpaid = 1 and allow_loss_calls = 1"])
    @insecure_devices = Device.find(:all, :conditions => "host='dynamic' and insecure like '%invite%'  and insecure != 'invite'")

    if @actions.size.to_i > 0
      @action = Action.find(:first, :joins => " JOIN users ON (actions.user_id = users.id) ", :conditions => "action = 'error' AND processed = '0' ", :order => "date ASC")
      date = @action.date.to_time - 1.day
      session[:year_from] = date.year
      session[:month_from] = date.month
      session[:day_from] = date.day
      change_date
    end

  end

  # called from anywhere to check if everything is still ok/not_ok
  def FunctionsController::integrity_recheck

    @destinations_without_dg = Destination.where(:destinationgroup_id => 0).order("direction_code ASC").all

    if @destinations_without_dg.size > 0
      return 1
    else
      Confline.set_value("Integrity_Check", 0)
      return 0
    end
  end

  def FunctionsController::integrity_recheck_user(user_id = 0)
    @default_user_warning = false

    @default_user_warning = true if Confline.get_value('Default_User_allow_loss_calls', user_id).to_i == 1 and Confline.get_value('Default_User_postpaid', user_id).to_i == 1

    @users_postpaid_and_loss_calls = User.where(:postpaid => 1, :allow_loss_calls => 1).all

    if @users_postpaid_and_loss_calls.size > 0 or @default_user_warning
      return 1
    else
      Confline.set_value("Integrity_Check", 0)
      return 0
    end
  end

  ######### PERMISSIONS ##########################################################
  def permissions
    @page_title = _('Permissions')
    @page_icon = 'cog.png'
    @roles = Role.order(:name).all

    @rights = Right.includes([:role_rights]).order("saved DESC ,controller ASC , action ASC").all
    #@permissions = RoleRight.get_auth_list
    @roles_count = @roles.size
  end

  def permissions_save
    @roles = Role.order(:name).all
    @rights = Right.includes([:role_rights]).order("saved DESC ,controller ASC , action ASC").all


    RoleRight.transaction do

      @rights.each { |right|
        MorLog.my_debug("OH SNAP #{right.role_rights.size}") if right.role_rights.size != 5
        right.role_rights.each { |rr|

          MorLog.my_debug(rr.to_yaml) if right.id == 75
          MorLog.my_debug(params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i) if right.id == 75
          if rr.permission != params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i
            rr.permission = params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i
            rr.save
            MorLog.my_debug("SAVE Setting_#{rr.role_id}_#{right.id} - #{params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i}")
          end

        }
        if right.saved == 1
          right.saved = 0
          right.save
        end
      }
    end
    flash[:status] = _("Settings_saved")
    redirect_to :action => 'permissions'
  end

  def role_new
    @page_title = _('New_Role')
    @page_icon = "add.png"
    @role = Role.new()
  end

  def role_create
    @role = Role.new(params[:role])
    if Role.where(:name => @role.name).first
      flash[:notice] = _('Cannot_Create_Role_already_exists')
      redirect_to :action => 'permissions' and return false
    end

    if @role.save
      rights = Right.all
      for right in rights do
        role_right = RoleRight.new()
        role_right.role_id = @role.id
        role_right.right_id = right.id
        if @role.name.downcase == 'admin'
          role_right.permission = 1
        else
          role_right.permission = 0
        end

        role_right.save
      end
      flash[:status] = _('Role_Created')
      redirect_to :action => 'role_new'
    else
      render :action => 'role_new'
    end
  end

  def role_destroy
    @role = Role.find(params[:id])
    if User.where(:usertype => @role.name).first
      flash[:notice] = _("Cannot_delete_role_users_exist")
      redirect_to :action => 'permissions' and return false
    end

    @role.destroy
    flash[:status] = _("Role_Destroyed")
    redirect_to :action => 'permissions' and return false
  end

  def right_new
    @page_title = _('New_Right')
    @page_icon = "add.png"
    @right = Right.new()
  end

  def right_create
    temp = params[:right]
    RoleRight.new_right(temp["controller"], temp["action"], temp["description"])
    flash[:status] = _('Right_Created')
    redirect_to :action => 'right_new'
  end

  def right_destroy
    @right = Right.find(params[:id])
    @right.destroy
    flash[:status] = _("Right_Destroyed")
    redirect_to :action => 'permissions' and return false
  end

  def action_finder
    @controllers = Dir.new("#{Rails.root}/app/controllers").entries
  end

  def action_syncronise
    @roles = Role.find(:all, :order => "name")
    @rights = Right.find(:all, :order => "controller, action")
    @permissions = RoleRight.get_auth_list
    @roles_count =Role.count

    @controllers = Dir.new("#{Rails.root}/app/controllers").entries
    @controllers.each do |controller|
      if controller =~ /_controller/
        cont = controller.camelize.gsub(".rb", "")
        cont_short = cont.gsub("Controller", "").downcase
        (eval("#{cont}.new.methods") -
            ApplicationController.methods -
            Object.methods -
            ApplicationController.new.methods).sort.each { |met|
          RoleRight.new_right(cont_short, met.to_s, cont_short.to_s.capitalize + "_"+met.to_s)
        }
      end
    end

    redirect_to :action => 'permissions'
  end

  def dump_permissions
    h = YAML.load_file(Actual_Dir+"/config/database.yml")
    `rm #{Actual_Dir.to_s}/doc/permissions.sql`
    `mysqldump --compact --add-drop-table -u #{h["development"]["username"]} -p#{h["development"]["password"]} mor roles rights role_rights >> #{Actual_Dir.to_s}/doc/permissions.sql`
    MorLog.my_debug("rm " + Actual_Dir.to_s + "/doc/permissions.sql")
    MorLog.my_debug("mysqldump --compact --add-drop-table -u #{h["development"]["username"]} -p#{h["development"]["password"]} mor roles rights role_rights >> " + Actual_Dir.to_s + "/doc/permissions.sql")
    redirect_to :action => 'permissions'
  end

  ######### /PERMISSIONS #########################################################
  ######### Get Not translated words #############################################

  def get_not_translated
    language = "en"
    language = params[:language] if params[:language]
    lang = []
    @files = {}
    @new_lang = []
    File.read("#{Rails.root}/lang/#{language}.rb").scan(/l.store\s?[\'\"][^\'\"]+[\'\"]/) do |st|
      st.scan(/[\'\"][^\'\"]+[\'\"]/) do |st2|
        lang << st2.gsub(/[\'\"]/, "")
      end
    end

    @files_list = Dir.glob("#{Rails.root}/app/controllers/*.rb").collect
    @files_list += Dir.glob("#{Rails.root}/app/views/**/*.rhtml").collect
    @files_list += Dir.glob("#{Rails.root}/app/models/*.rb").collect
    @files_list += Dir.glob("#{Rails.root}/app/helpers/*.rb").collect
    @files_list += Dir.glob("#{Rails.root}/lib/**/*.rb").collect
    for file in @files_list
      File.read(file).scan(/[^\w\d]\_\([\'\"][^\'\"]+[\'\"]\)/) do |st|
        st = st.gsub(/.?\_\(/, "").gsub(/[\s\'\"\)\(]/, "")
        @new_lang << st
        @files[st] = file
      end
    end

    @new_lang -= lang
    @new_lang = @new_lang.uniq.flatten
  end

  ######### /Get Not translated words #############################################

  ######### IMPORT USER DATA FROM CSV ############################################

  def import_user_data
    @page_title = _('Import_user_data')
    @page_icon = 'excel.png'
    @users = User.find(:all, :conditions => "temporary_id >= 0")
    @devices = Device.find(:all, :conditions => "temporary_id >= 0 AND name not like 'mor_server_%'")
  end

  def import_user_data_clis
    @step = 1
    @step = params[:step].to_i if params[:step]

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Import_CLIs') if @step == 3

    @sep, @dec = nice_action_session_csv
    store_location
    @page_title = _('import_user_data_clis') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
    @page_icon = 'excel.png'
    session[:imp_cli_include] and session[:imp_cli_include]==1 ? @include = 1 : @include = 0

    if @step == 2
      if params[:include].to_i == 1
        session[:imp_cli_include] = 1
      else
        session[:imp_cli_include] = 0
      end
      if params[:file] or session[:file]
        if params[:file]
          if params[:file] == ""
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_user_data_clis", :step => "1" and return false
          else
            @file = params[:file]
            if get_file_ext(@file.original_filename, "csv") == false
              redirect_to :action => "import_user_data_clis", :step => "1" and return false
            end
            session[:file] = @file.read
          end
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_user_data_clis", :step => "1" and return false
        end

        @file = session[:file]
        check_csv_file_seperators(@file, 2)
        arr = @file.split("\n")
        @fl = arr[0].split(@sep)
        flash[:status] = _('File_uploaded')
      end
    end

    if @step == 3
      if session[:file]
        @file = session[:file]
        session[:imp_cli_device_id] = params[:device_id].to_i if params[:device_id]
        session[:imp_cli_cli] = params[:cli].to_i if params[:cli]
        session[:imp_cli_device_id_type] = params[:device_id_type].to_i if params[:device_id_type]

        flash[:status] = _('Columns_assigned')
      end
    end

    if @step == 4
      inc = 1 - @include.to_i
      @error_array = []
      @msg_array = []
      if session[:file]
        array = []
        @file = session[:file]
        array = @file.split("\n")
        for arr in array
          if inc == 0
            row = []
            row = arr.split(@sep)
            r_arr = row
            err = ""

            device_id = clean_value_all(r_arr[session[:imp_cli_device_id]].to_s)
            cli = clean_value_all(r_arr[session[:imp_cli_cli]].to_s)

            if device_id.length == 0
              err += _("Device_ID_Cant_Be_Empty") + "<br />"
            else
              if session[:imp_cli_device_id_type] == 0
                device = Device.where("id = #{device_id.to_i}").first
              else
                device = Device.where("temporary_id = #{device_id.to_i}").first
              end

              if !device
                err += _("Device_not_found") + "<br />"
              end
            end

            if cli.length == 0
              err += _("CLI_Cant_Be_Empty") + "<br />"
            else
              callerid = Callerid.where("cli = '#{cli}'").first

              if callerid
                err += _("Such_CLI_exists") + "<br />"
              end
            end


            if err == ""
              my_debug("ADDING")
              logger.fatal params.to_yaml

              new_cli = Callerid.new(params[:cli])
              new_cli.cli = cli
              new_cli.device_id = device.id
              new_cli.description = ''
              new_cli.added_at = Time.now
              new_cli.banned = 0
              new_cli.created_at = Time.now
              new_cli.updated_at = Time.now
              new_cli.ivr_id = 0
              new_cli.comment = ''
              new_cli.email_callback = 0



              if new_cli.save

              else
                @error_array << arr
                msq = ''
                new_cli.errors.each { |key, value|
                  msq += "<br> * #{_(value)}"
                } if new_cli.respond_to?(:errors)
                @msg_array << msq
              end
            else
              @error_array << arr
              @msg_array << err
            end
          else
            inc = 0
          end
        end
      end
      if @error_array.blank?
        flash[:status] = _('CLIs_were_successfully_imported')
        redirect_to :action => :import_user_data
      else
        flash[:notice] = _("There_were_errors")
      end
    end

  end



  def import_user_data_users
    @step = 1
    @step = params[:step].to_i if params[:step]

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Import_Users') if @step == 3

    @sep, @dec = nice_action_session_csv
    store_location
    @page_title = _('Import_user_data_users') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
    @page_icon = 'excel.png'
    session[:imp_user_include] and session[:imp_user_include]==1 ? @include = 1 : @include = 0

    if @step == 2
      if params[:include].to_i == 1
        session[:imp_user_include] = 1
      else
        session[:imp_user_include] = 0
      end
      if params[:file] or session[:file]
        if params[:file]
          if params[:file] == ""
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_user_data_users", :step => "1" and return false
          else
            @file = params[:file]
            if get_file_ext(@file.original_filename, "csv") == false
              redirect_to :action => "import_user_data_users", :step => "1" and return false
            end
            session[:file] = @file.read
          end
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_user_data_users", :step => "1" and return false
        end

        @file = session[:file]
        check_csv_file_seperators(@file, 6)
        arr = @file.split("\n")
        @fl = arr[0].split(@sep)
        flash[:status] = _('File_uploaded')
      end
    end

    if @step == 3
      if session[:file]
        @file = session[:file]
        session[:imp_user_temp_id] = params[:temp_id].to_i if params[:temp_id]
        session[:imp_user_username] = params[:username].to_i if params[:username]
        session[:imp_user_password] = params[:password].to_i if params[:password]
        session[:imp_user_first_name] = params[:first_name].to_i if params[:first_name]
        session[:imp_user_last_name] = params[:last_name].to_i if params[:last_name]
        session[:imp_user_payment_type] = params[:payment_type].to_i if params[:payment_type]
        session[:imp_user_personal_id] = params[:personal_id].to_i if params[:personal_id]
        session[:imp_user_vat_reg_number] = params[:vat_reg_number].to_i if params[:vat_reg_number]
        session[:imp_user_balance] = params[:balance].to_d if params[:balance]
        session[:imp_user_credit] = params[:credit].to_d if params[:credit]
        session[:imp_user_credit_unlimited] = params[:credit_unlimited].to_d if params[:credit_unlimited]
        session[:imp_user_address] = params[:address].to_i if params[:address]
        session[:imp_user_postcode] = params[:postcode].to_i if params[:postcode]
        session[:imp_user_city] = params[:city].to_i if params[:city]
        session[:imp_user_country] = params[:country].to_i if params[:country]
        session[:imp_user_state] = params[:state].to_i if params[:state]
        session[:imp_user_phone] = params[:phone].to_i if params[:phone]
        session[:imp_user_mob_phone] = params[:mob_phone].to_i if params[:mob_phone]
        session[:imp_user_fax] = params[:fax].to_i if params[:fax]
        session[:imp_user_email] = params[:email].to_i if params[:email]
        session[:imp_user_lcr] = params[:lcr].to_i if params[:lcr]
        session[:imp_user_tariff] = params[:tariff].to_i if params[:tariff]

        flash[:status] = _('Columns_assigned')
      end
    end
    if @step == 4
      inc = 1 - @include.to_i
      @error_array = []
      @msg_array = []
      @warn_array=[]
      @warn_msg=[]
      if session[:file]
        array = []
        @file = session[:file].force_encoding("UTF-8")
        array = @file.split("\n")
        for arr in array
          if inc == 0
            row = []
            row = arr.split(@sep)
            r_arr = row
            err = ""
            warn = ""
            username = r_arr[session[:imp_user_username]].to_s.gsub("\"", "")

            if clean_value_all(r_arr[session[:imp_user_temp_id]]).to_i == ""
              err += _('Temp_User_ID_Cant_Be_Empty')+"<br />"
            end

            if username.length == 0
              err += _('Please_enter_username')+"<br />"
            end
            if User.where(:username => username).first
              err += _('Such_username_is_already_taken')+"<br />"
            end
            if clean_value_all(r_arr[session[:imp_user_password]].to_s).length < 5
              err += _('Password_is_too_short') +"<br />"
            end
            if clean_value_all(r_arr[session[:imp_user_first_name]].to_s).length == 0
              err +=_('Please_enter_first_name') +"<br />"
            end
            if clean_value_all(r_arr[session[:imp_user_last_name]].to_s).length == 0
              err +=_('Please_enter_last_name') +"<br />"
            end
            if clean_value_all(r_arr[session[:imp_user_email]].to_s).to_s.strip.length == 0
              err +=_('Please_enter_email') +"<br />"
            end

            unless Email.address_validation(clean_value_all(r_arr[session[:imp_user_email]].to_s).to_s.strip)
              err +=_('Please_enter_valid_email') +"<br />"
            end

            if err == ""
              address = Address.new
              address.direction_id = Direction.get_direction_by_country(clean_value_all(r_arr[session[:imp_user_country]]))
              address.state = clean_value_all r_arr[session[:imp_user_state]].to_s if session[:imp_user_state] >= 0
              address.county =clean_value_all r_arr[session[:imp_user_country]].to_s
              address.city =clean_value_all r_arr[session[:imp_user_city]].to_s if session[:imp_user_city] >=0
              address.postcode =clean_value_all r_arr[session[:imp_user_postcode]].to_s if session[:imp_user_postcode] >=0
              address.address =clean_value_all r_arr[session[:imp_user_address]].to_s if session[:imp_user_address] >=0
              address.phone =clean_value_all r_arr[session[:imp_user_phone]].to_s if session[:imp_user_phone] >=0
              address.mob_phone =clean_value_all r_arr[session[:imp_user_mob_phone]] if session[:imp_user_mob_phone] >=0
              address.fax =clean_value_all r_arr[session[:imp_user_fax]].to_s if session[:imp_user_fax] >=0
              address.email =(clean_value_all r_arr[session[:imp_user_email]]).to_s.strip

              address.save

              user = User.new
              user.imported_user = true
              user.temporary_id = clean_value_all(r_arr[session[:imp_user_temp_id]]).to_i
              user.username =clean_value_all r_arr[session[:imp_user_username]].to_s
              user.password = Digest::SHA1.hexdigest(clean_value_all(r_arr[session[:imp_user_password]].to_s))
              my_debug("Password:")
              my_debug(clean_value_all(r_arr[session[:imp_user_password]].to_s))

              user.usertype = "user"
              if session[:imp_user_payment_type]
                user.postpaid = clean_value_all(r_arr[session[:imp_user_payment_type]]).to_i
              else
                user.postpaid = 0
              end
              user.balance = clean_value_all(r_arr[session[:imp_user_balance]].to_s) if session[:imp_user_balance] >= 0
              user.credit = clean_value_all(r_arr[session[:imp_user_credit]].to_s) if session[:imp_user_credit] >= 0
              user.credit = clean_value_all(r_arr[session[:imp_user_credit_unlimited]].to_s) if session[:imp_user_credit_unlimited] >= 0
              user.first_name =clean_value_all r_arr[session[:imp_user_first_name]].to_s
              user.last_name =clean_value_all r_arr[session[:imp_user_last_name]].to_s

              if session[:imp_user_lcr] >= 0
                lcr_id = clean_value_all(r_arr[session[:imp_user_lcr]].to_s).to_i
                if current_user.lcrs.find(:first, :conditions => "id = #{lcr_id}")
                  user.lcr_id = lcr_id
                else
                  warn += _("LCR_Was_Not_Found_Default_Assigned")+"<br />"
                  user.lcr_id = Confline.get_value("LCR_for_registered_users").to_i
                end
              else
                user.lcr_id = Confline.get_value("LCR_for_registered_users").to_i
              end

              if session[:imp_user_tariff] >= 0
                tariff_id = clean_value_all(r_arr[session[:imp_user_tariff]].to_s).to_i
                if Tariff.where(:id => tariff_id).first
                  user.tariff_id = tariff_id
                else
                  warn += _("Tariff_Was_Not_Found_Default_Assigned")+"<br />"
                  user.tariff_id = Confline.get_value("Tariff_for_registered_users").to_i
                end
              else
                user.tariff_id = Confline.get_value("Tariff_for_registered_users").to_i
              end


              user.clientid =clean_value_all r_arr[session[:imp_user_personal_id]].to_s if session[:imp_user_personal_id] > 0
              user.agreement_date = Time.now
              user.agreement_number = next_agreement_number
              user.taxation_country = Direction.get_direction_by_country(clean_value_all(r_arr[session[:imp_user_country]]))
              user.vat_number = clean_value_all r_arr[session[:imp_user_vat_reg_number]].to_s if session[:imp_user_vat_reg_number] >=0

              user.address_id = address.id
              user.owner_id = 0
              unless user.save
                user.errors.each { |key, value|
                  MorLog.my_debug("#{key} - #{value}")
                }

              end

              user.assign_default_tax
              if warn != ""
                @warn_array << arr
                @warn_msg << warn
                my_debug(@warn_msg)
                my_debug(@warn_array)
              end
            else
              @error_array << arr
              @msg_array << err
            end
          else
            inc = 0
          end
        end
      end
      if @error_array.blank?
        flash[:status] = _('Users_were_successfully_imported')
        redirect_to :action => :import_user_data
      else
        flash[:notice] = _("There_were_errors")
      end
    end

  end

  def import_user_data_devices
    @step = 1
    @step = params[:step].to_i if params[:step]

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Import_Devices') if @step == 4

    @sep, @dec = nice_action_session_csv
    store_location
    @page_title = _('Import_user_data_devices') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
    @page_icon = 'excel.png'
    session[:imp_device_include] and session[:imp_device_include]==1 ? @include = 1 : @include = 0
    if @step == 2
      if params[:include].to_i == 1
        session[:imp_device_include] = 1
      else
        session[:imp_device_include] = 0
      end
      if params[:file] or session[:file]
        if params[:file]
          if params[:file] == ""
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_user_data_devices", :step => "1" and return false
          else
            @file = params[:file]
            if get_file_ext(@file.original_filename, "csv") == false
              redirect_to :action => "import_user_data_devices", :step => "1" and return false
            end
            session[:file] = @file.read
          end
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_user_data_devices", :step => "1" and return false
        end

        @file = session[:file]
        check_csv_file_seperators(@file, 8)
        arr = @file.split("\n")
        @fl = arr[0].split(@sep)
        flash[:status] = _('File_uploaded')
      end
    end
    if @step == 3
      if session[:file]
        @file = session[:file]
        session[:imp_device_temp_device_id] = params[:temp_device_id].to_i if params[:temp_device_id]
        session[:imp_device_temp_user_id] = params[:temp_user_id].to_i if params[:temp_user_id]
        session[:imp_device_username] = params[:username].to_i if params[:username]
        session[:imp_device_password] = params[:password].to_i if params[:password]
        session[:imp_device_host] = params[:host].to_i if params[:host]
        session[:imp_device_cli_name] = params[:cli_name].to_i if params[:cli_name]
        session[:imp_device_cli_number] = params[:cli_number].to_i if params[:cli_number]
        session[:imp_device_type] = params[:device_type].to_i if params[:device_type]
        session[:imp_device_extension] = params[:extension].to_i if params[:extension]

        session[:imp_device_pin] = params[:pin].to_i if params[:pin]
        session[:imp_device_location] = params[:location].to_i if params[:location]

        flash[:status] = _('Columns_assigned')
      end
    end
    if @step == 4
      inc = 1 - @include.to_i
      @error_array = []
      @msg_array = []
      if session[:file]
        array = []
        @file = session[:file]
        array = @file.split("\n")
        for arr in array
          if inc == 0
            row = []
            row = arr.split(@sep)
            r_arr = row
            err = ""

            device_type = clean_value_all(r_arr[session[:imp_device_type]].to_s)
            device_temp_id = clean_value_all(r_arr[session[:imp_device_temp_device_id]].to_s)
            user_temp_id = clean_value_all(r_arr[session[:imp_device_temp_user_id]].to_s)
            cli_name = clean_value_all(r_arr[session[:imp_device_cli_name]].to_s)
            cli_number = clean_value_all(r_arr[session[:imp_device_cli_number]].to_s)
            device_extension = clean_value_all(r_arr[session[:imp_device_extension]].to_s)
            location = clean_value_all(r_arr[session[:imp_device_location]].to_s)
            pin = clean_value_all(r_arr[session[:imp_device_pin]].to_s)

            if device_temp_id.length == 0
              err += _("Temp_Device_ID_Cant_Be_Empty") + "<br />"
            else
              device = Device.where("temporary_id = #{device_temp_id.to_i}").first
              if device
                err += _("Temp_Device_ID_Already_Taken") + "<br />"
              end
            end

            if user_temp_id.length == 0
              err += _("Temp_User_ID_Cant_Be_Empty") + "<br />"
            else
              user = User.where("temporary_id = #{user_temp_id.to_i}").first
              if !user
                err += _("User_Was_Not_Found") + "<br />"
              end
            end

            if device_type.upcase != "SIP" and device_type.upcase != "IAX2" and device_type.downcase != "dahdi" and device_type.upcase != "FAX" and device_type.upcase != "H323" and device_type.capitalize != "Virtual"
              err += _("Invalid_Device_type") + "<br />"
            else
              if device_type.upcase == "SIP"
                port = 5060
              elsif device_type.upcase == "IAX2"
                port = 4569
              elsif device_type.upcase == "H323"
                port = 1720
              else
                port = 0
              end
            end

            if device_extension.length == 0
              err += _("Device_Extension_Cant_Be_Empty") + "<br />"
            else
              if nil != Device.where(:extension => device_extension).first
                err += _("Device_Extension_Must_Be_Unique") + "<br />"
              end
            end

            if clean_value_all(r_arr[session[:imp_device_password]].to_s).length == 0
              err += _("Password_cant_be_empty") + "<br />"
            end

            if clean_value_all(r_arr[session[:imp_device_username]].to_s).length == 0
              err += _("Username_Cant_Be_Empty") + "<br />"
            end

            if clean_value_all(r_arr[session[:imp_device_host]].to_s).length == 0
              err += _("Host_Cant_Be_Empty") + "<br />"
            end

            if cli_name.length == 0
              err += _("CLI_Name_Cant_Be_Empty") + "<br />"
            end
            if cli_number.length == 0
              err += _("CLI_Number_Cant_Be_Empty") + "<br />"
            end

            if err == ""
              my_debug("ADDING")
              device = Device.new(params[:device])

              if location != ""
                loc = Location.where(:name => location).first
                if not loc
                  loc = Location.new
                  loc.name = location
                  loc.save
                end
              else
                #if reseller , importin device with no location , find default location
                #if no default location, create it and use
                if reseller?
                  loc = Location.where(:name => 'Default location', :user_id => current_user.id).all
                  if not loc
                    current_user.create_reseller_localization
                    loc = Location.where(:name => 'Default location').first
                  end
                else
                  loc = Location.where(:name => 'Global').first
                end
              end

              device.location = loc
              device.user_id = user.id
              device.temporary_id = device_temp_id
              device.context = "mor_local"
              device.extension = clean_value_all(r_arr[session[:imp_device_extension]].to_s)
              device.name = clean_value_all(r_arr[session[:imp_device_username]].to_s)
              device.username = clean_value_all(r_arr[session[:imp_device_username]].to_s)
              device.secret = clean_value_all(r_arr[session[:imp_device_password]].to_s)
              device.pin = pin if pin != ""
              device.device_type = ['SIP', 'IAX2', 'H323', 'FAX'].include?(device_type.upcase) ? device_type.upcase : (['dahdi'].include?(device_type.downcase) ? device_type.downcase : device_type.capitalize)
              device.permit = "0.0.0.0/0.0.0.0"
              device.host = clean_value_all(r_arr[session[:imp_device_host]].to_s)
              device.port = port
              device.istrunk = 0
              device.ani = 0
              device.callgroup = nil
              device.pickupgroup = nil
              device.fromuser = nil
              device.fromdomain = nil
              device.insecure = nil
              device.callerid = "\"#{cli_name}\"<#{cli_number}>"
              device.save
              device.accountcode = device.id
              if device.save
                a=configure_extensions(device.id, :current_user => current_user)
                return false if !a
              else
                @error_array << arr
                msq = ''
                device.errors.each { |key, value|
                  msq += "<br> * #{_(value)}"
                } if device.respond_to?(:errors)
                @msg_array << msq
              end
            else
              @error_array << arr
              @msg_array << err
            end
          else
            inc = 0
          end
        end
      end
      if @error_array.blank?
        flash[:status] = _('Devices_were_successfully_imported')
        redirect_to :action => :import_user_data
      else
        flash[:notice] = _("There_were_errors")
      end
    end
  end

  def import_user_data_dids
    @step = 1
    @step = params[:step].to_i if params[:step]

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Import_DIDs') if @step == 4

    @sep, @dec = nice_action_session_csv
    store_location
    @page_title = _('Import_user_data_DIDs') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
    @page_icon = 'excel.png'
    session[:imp_device_include] and session[:imp_device_include]==1 ? @include = 1 : @include = 0

    if @step == 2
      @providers = Provider.where(:hidden => 0).all

      if params[:include].to_i == 1
        session[:imp_dids_include] = 1
      else
        session[:imp_dids_include] = 0
      end
      if params[:file] or session[:file]
        if params[:file]
          if params[:file] == ""
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_user_data_dids", :step => "1" and return false
          else
            @file = params[:file]
            if get_file_ext(@file.original_filename, "csv") == false
              redirect_to :action => "import_user_data_dids", :step => "1" and return false
            end
            session[:file] = @file.read
          end
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_user_data_dids", :step => "1" and return false
        end

        @file = session[:file]
        check_csv_file_seperators(@file, 3)
        arr = @file.split("\n")
        @fl = arr[0].split(@sep)
        flash[:status] = _('File_uploaded')
      end
    end
    if @step == 3
      session[:imp_did_provider] = -1
      if session[:file]
        @file = session[:file]
        session[:imp_did_temp_user_id] = params[:temp_user_id].to_i if params[:temp_user_id]
        session[:imp_did_device_id] = params[:temp_device_id].to_i if params[:temp_device_id]
        session[:imp_did_did] = params[:did].to_i if params[:did]
        session[:imp_did_provider] = params[:provider].to_i if params[:provider]
        flash[:status] = _('Columns_assigned')
      end
    end
    if @step == 4
      inc = 1 - @include.to_i
      @error_array = []
      @msg_array = []
      if session[:file]
        array = []
        @file = session[:file]
        array = @file.split("\n")
        for arr in array
          if inc == 0
            row = []
            row = arr.split(@sep)
            r_arr = row
            err = ""
            user_id = clean_value_all(r_arr[session[:imp_did_temp_user_id]].to_s)
            device_id = clean_value_all(r_arr[session[:imp_did_device_id]].to_s)
            did_tx = clean_value_all(r_arr[session[:imp_did_did]].to_s)

            if user_id.length == 0
              err += _("Temp_User_ID_Cant_Be_Empty") + "<br />"
            else
              user = User.find(:first, :conditions => "temporary_id = #{user_id.to_i}")
              if !user
                err += _("User_Was_Not_Found") + "<br />"
              end
            end

            if device_id.length == 0
              err += _("Temp_Device_ID_Cant_Be_Empty") + "<br />"
            else
              device = Device.find(:first, :conditions => "temporary_id = #{device_id.to_i}")
              if !device
                err += _("Device_Was_Not_Found") + "<br />"
              end
            end

            if did_tx.length == 0
              err += _("DID_Cant_Be_Empty") + "<br />"
            else
              if did_tx.to_s[0, 1] == "0"
                err += _("DID_Cant_Start_With_Zero") + "<br />"
              else
                if Did.find(:first, :conditions => ["did = ?", did_tx])
                  err += _("DID_Must_Be_Unique") + "<br />"
                end
              end
            end

            if err == ""
              did = Did.new()
              did.did = did_tx
              did.user_id = user.id
              did.device_id = device.id
              did.provider_id = session[:imp_did_provider].to_i
              did.status = "active"
              did.save
              device.primary_did_id = did.id
              device.save
            else
              @error_array << arr
              @msg_array << err
            end
          else
            inc = 0
          end
        end
      end
      if @error_array == []
        flash[:status] = _('DIDs_were_successfully_imported')
        redirect_to :action => :import_user_data
      else
        flash[:notice] = _("There_were_errors")
      end
    end
  end

  def clean_value(value)
    cv = value
    cv = cv[1..cv.length] if cv[0, 1] == "\""
    cv = cv[0..cv.length-2] if cv[cv.length-1, 1] == "\""
    cv
  end

  def import_user_data_clear
    database = ActiveRecord::Base.connection();

    sql = "UPDATE users SET temporary_id = NULL"
    sql2 = "UPDATE devices SET temporary_id = NULL"
    database.execute(sql)
    database.execute(sql2)
    flash[:status] = _('Temporary_information_cleared')
    redirect_to :action => 'import_user_data' and return false
  end

  def clean_value_all(value)
    cv = value.to_s
    while cv[0, 1] == "\"" or cv[0] == "'" do
      cv = cv[1..cv.length]
    end
    while cv[cv.length-1, 1] == "\"" or cv[cv.length-1, 1] == "'" do
      cv = cv[0..cv.length-2]
    end
    cv
  end


  #=============== Click2Call from web ===========

  def call_to
    @number = params[:number]
    user_id = session[:user_id]
    user = User.find(user_id)

    @error = ""
    device = user.primary_device

    if device
      # originate callback
      src = device.extension
      dst = @number
      #var2 = "__MOR_CALLC_ACTION_ID=#{action.id.to_s}"

      server = Confline.get_value("Web_Callback_Server").to_i
      server = 1 if server == 0

      channel = "Local/#{src}@mor_cb_src/n"
      st = originate_call(device.id, src, channel, "mor_cb_dst", dst, device.callerid_number, nil, server)
      @error = _('Cannot_connect_to_asterisk_server') if st.to_i != 0
    else
      @error = _('No_device')
    end

    render(:layout => false)
  end


  def test_text

    @text = params[:text]
  end


  def test_file_upload
    @page_title = "Test file upload"
    @page_icon = 'lightning.png'

    @step = 1
    @step = params[:step].to_i if params[:step]

    @sep, @dec = nice_action_session_csv
    store_location

    if @step == 2
      if params[:include].to_i == 1
        session[:imp_user_include] = 1
      else
        session[:imp_user_include] = 0
      end
      if params[:file] or session[:file]
        if params[:file]
          if params[:file] == ""
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_user_data_users", :step => "1" and return false
          else
            @file = params[:file]
            if get_file_ext(@file.original_filename, "csv") == false
              redirect_to :action => "import_user_data_users", :step => "1" and return false
            end
            session[:file] = @file.read
          end
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_user_data_users", :step => "1" and return false
        end

        @file = session[:file]
        check_csv_file_seperators(@file)
        arr = @file.split("\n")
        @fl = arr[0].split(@sep)
        flash[:status] = _('File_uploaded')
      end
    end

    if @step == 3
      `rm -rf /tmp/mor/*`
      @step = 1
      flash[:status] = _('Files_deleted')
    end

  end


  def check_separator
    if session[:file] == nil
      flash[:notice] = _('Please_select_file')
      redirect_back_or_default('/callc/main') and return false
    else
      file = session[:file]
      sep = params[:custom].to_i > 0 ? (!params[:sepn].to_s.blank? ? params[:sepn].to_s : ";") : params[:sepn2].to_s
      arr = file.split("\n")
      @fl = []
      5.times { |num| @fl[num] = arr[num].to_s.split(sep) }
      if  @fl[1].size.to_i < params[:min_collum_size].to_i
        @notice = _('Not_enough_columns_check_csv_separators')
      end
      render :layout => false
    end
  end

  def callback_settings
    @page_title = _('Callback_settings')
    @servers = Server.order("server_id ASC").all
  end

  def callback_settings_update
    #WEB Callback

    Confline.set_value("CB_Active", params[:cb_active].to_i)
    #      update_confline("CB_Temp_Dir", params[:cb_temp_dir])
    #      update_confline("CB_Spool_Dir", params[:cb_spool_dir])
    Confline.set_value("CB_MaxRetries", params[:cb_maxretries])
    Confline.set_value("CB_RetryTime", params[:cb_retrytime])
    Confline.set_value("CB_WaitTime", params[:cb_waittime])

    Confline.set_value("Web_Callback_Server", params[:web_callback_server])
    Confline.set_value("Web_Callback_Send_Source_As_CID", params[:web_callback_send_source])
    cid = params[:web_callback_send_source].to_i == 1 ? '' :  params[:web_callback_cid]
    Confline.set_value("WEB_Callback_CID", cid)

    if (params[:email_callback_pop3_server] or params[:email_callback_login])
      if params[:email_callback_pop3_server] != params[:email_pop3_server]
        Confline.set_value("Email_Callback_Pop3_Server", params[:email_callback_pop3_server])
        Confline.set_value("Email_Callback_Login", params[:email_callback_login])
        Confline.set_value("Email_Callback_Password", params[:email_callback_password])
      else
        if params[:email_callback_login] != params[:email_login]
          Confline.set_value("Email_Callback_Pop3_Server", params[:email_callback_pop3_server])
          Confline.set_value("Email_Callback_Login", params[:email_callback_login])
          Confline.set_value("Email_Callback_Password", params[:email_callback_password])
        else
          error=1
          flash[:notice] = _('Cannot_duplicate_email_callback_server')
        end
      end
    end

    renew_session(current_user)
    if error.to_i == 0
      flash[:status] = _('Settings_saved')
    end
    redirect_to :action => 'callback_settings' and return false
  end

  def generate_hash
    @page_title = _('Generate_hash')
    if current_user.is_admin?
      @api_link = params[:link].to_s
      if not @api_link.blank?
        @query_values = Hash.new
        begin
          CGI::parse(URI.parse(@api_link).query).each { |key, value| @query_values[key.to_sym] = value[0] }
          flash[:notice] = nil
        rescue
          flash[:notice] = _("failed_to_parse_uri") + ' ' + @api_link
        end
        dummy, ret, @hash_param_order = MorApi.check_params_with_all_keys(@query_values, dummy)
        @system_hash = ret[:system_hash]
      end
    else
      dont_be_so_smart
      redirect_to :controller => 'callc', :action => 'main'
    end
  end

  def webphone_settings
    @page_title = _('Webphone_settings')
    @page_icon = 'cog.png'
  end

  def webphone_settings_update
    Confline.set_value2("Webphone_hash", params[:webphone_hash], current_user.get_corrected_owner_id) if !current_user.is_reseller?
    Confline.set_value("Webphone_page_url", params[:webphone_page_url], current_user.get_corrected_owner_id)
    Confline.set_value("Webphone_title", params[:webphone_title], current_user.get_corrected_owner_id)
    Confline.set_value("Webphone_text", params[:webphone_text], current_user.get_corrected_owner_id)

    flash[:status] = _('Settings_saved')
    redirect_to :action => :webphone_settings and return false

  end

  def ccl_settings
    if !ccl_active?
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end

    @page_title = _('CCL_Settings')
    @page_icon = 'cog.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/"

    if !current_user.is_admin?
      redirect_to :action => :main and return false
    end    
 
    @servers = Server.where(:server_type=> "asterisk")
 
  end

  def ccl_settings_update
    if !ccl_active?
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    if params[:indirect].to_i == 1 
      if !params[:s_id].blank? 
        Confline.set_value("Default_asterisk_server", params[:s_id], current_user.get_corrected_owner_id)
        flash[:status] = _('Settings_saved')
        redirect_to :action => :ccl_settings
      else
        flash[:notice] = _('Update_failed')
        redirect_to :action => :ccl_settings and return false
      end
    else
      redirect_to :action => :main and return false
    end
  end
  #================= PRIVATE ==================

  private

=begin rdoc
  if user wants to enable api key MUST enter at least 6 symbol key. if he disables api
  he may set valid api(at least 6 symbols) or not set at all

  *params*
  <tt>allow</tt> - true or false depending on what user wants
  <tt>key</tt> - secret api key
  *return*
  true if invalid or false if valid
=end
  def invalid_api_params?(allow_api, key)
    if allow_api
      key.to_s.length < 6
    else
      (1...6).include?(key.to_s.length)
    end
  end

  def check_callback_addon
    unless callback_active?
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def pbx_function_delete_extline(dialplan)
    Extline.where(["exten = ?", dialplan.data2]).delete_all
  end

  def pbx_function_configure_extline(dialplan)
    pbx_function_delete_extline(dialplan)
    Extline.mcreate("mor_local", 1, "Set", "MOR_DP_ID=#{dialplan.id}", dialplan.data2, 0)
    Extline.mcreate("mor_local", 2, "Goto", dialplan.pbxfunction.context.to_s + "|" + dialplan.pbxfunction.extension.to_s + "|" + dialplan.pbxfunction.priority.to_s, dialplan.data2, 0)
  end


  def sanitize_filename(file_name)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(file_name)
    # replace all none alphanumeric, underscore or perioids with underscore
    just_filename.gsub(/[^\w\.\_]/, '_')
  end


  def create_call_file(acc, src, dst)

    if Confline.get_value("CB_Active") == "0"
      flash[:notice] = _('Callback_is_disabled')
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    cb_max_retries = Confline.get_value("CB_MaxRetries")
    cb_retry_time = Confline.get_value("CB_RetryTime")
    cb_wait_time = Confline.get_value("CB_WaitTime")

    if dst.length > 0
      #call directly
      cf = "Channel: Local/#{src}@mor_cb_src/n\nMaxRetries: #{cb_max_retries}\nRetryTime: #{cb_retry_time}\nWaitTime: #{cb_wait_time}\nAccount: #{acc}\nContext: mor_cb_dst\nExtension: #{dst}\nPriority: 1\n"
    else
      #ask destination
      cf = "Channel: Local/#{src}@mor_cb_src/n\nMaxRetries: #{cb_max_retries}\nRetryTime: #{cb_retry_time}\nWaitTime: #{cb_wait_time}\nAccount: #{acc}\nContext: mor_cb_dst_ask\nExtension: 123\nPriority: 1\n"
    end

    file_name = "mor_cf_" + acc.to_s + "-" + src.to_s + "-" + dst.to_s
    tmp_file = Confline.get_value("CB_Temp_Dir") + "/" + file_name
    spool_file = Confline.get_value("CB_Spool_Dir") + "/" + file_name

    #create file
    fout = File.open(tmp_file, "w")
    fout.puts cf
    fout.close

    #activate filep
    File.rename(tmp_file, spool_file)

    #if rename fails on cross-filesystem link - we need to catch this and copy the file

  end


  def reconfigure_voicemail(action, old_server_ext, new_server_ext, old_local_ext, new_local_ext, device_id)

    # --------------------------- VM Put ------------------------------

    # extensions_mor.conf
    # [mor_voicemail]
    # switch => Realtime/mor_voicemail@realtime_ext

    # delete old configuration for mor_voicemail context
    Extline.where(["context = ?", "mor_voicemail"]).delete_all

    default_context = "mor_voicemail"

    if action == 1
      # VM is on separate server
      device = Device.find(device_id) if device_id

      mor_ext = '#${EXTEN}'
      Extline.mcreate(default_context, 1, "Dial", "#{device.device_type}/#{device.name}/#{new_server_ext}" + mor_ext, "_X.", 0)
      Extline.mcreate(default_context, 2, "Hangup", "", "_X.", 0)
    else
      # VM is on local Asterisk server server
      Extline.mcreate(default_context, 1, "VoiceMail", "${EXTEN}|${MOR_VM}", "_X.", 0)
      Extline.mcreate(default_context, 2, "Hangup", "", "_X.", 0)
    end

    # --------------------------- VM Retrieve ------------------------------

    # delete old configuration
    Extline.delete_all(["exten = ?", old_local_ext])


    default_context = "mor_local"

    if action == 1
      # VM is on separate server
      device = Device.find(device_id) if device_id

      Extline.mcreate(default_context, 1, "AGI", "mor_acc2user", new_local_ext, 0)
      mor_ext = '#${MOR_EXT}'
      Extline.mcreate(default_context, 2, "Dial", "#{device.device_type}/#{device.name}/#{new_server_ext}" + mor_ext, new_local_ext, 0)
      Extline.mcreate(default_context, 3, "Hangup", "", new_local_ext, 0)
    else
      # VM is on local Asterisk server server
      Extline.mcreate(default_context, 1, "AGI", "mor_acc2user", new_local_ext, 0)
      Extline.mcreate(default_context, 2, "VoiceMailMain", "s${MOR_EXT}", new_local_ext, 0)
      Extline.mcreate(default_context, 3, "Hangup", "", new_local_ext, 0)
    end

  end


=begin rdoc
 Updates tax for all users. If cardgroups has no tax - new tax is created.

 *Params*

 <tt>tax</tt> - hash containing tax values, names and enabled/disabled flag.
 <tt>owner</tt> - users owner_id
=end


=begin rdoc
 Updates tax for all cardgroups. If cardgroups has no tax - new tax is created.

 *Params*

 <tt>tax</tt> - hash containing tax values, names and enabled/disabled flag.
=end

  def find_location_rule
    @rule = Locationrule.find_by_id(params[:id])
    unless @rule
      flash[:notice]=_('Location_rule_was_not_found')
      redirect_to :action => :localization and return false
    end
    check_location_rule_owner
  end

  def find_dialplan
    @dialplan = Dialplan.find_by_id(params[:id])

    unless @dialplan
      flash[:notice]=_('Dialplan_was_not_found')
      redirect_to :action => :pbx_functions and return false
    end

    unless @dialplan.user_id.to_i == current_user.id.to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def find_location
    @location = Location.find_by_id(params[:id])
    unless @location
      flash[:notice]=_('Location_was_not_found')
      redirect_to :action => :localization and return false
    end
    check_location_owner
  end

  def check_location_owner
    unless @location.user_id == correct_owner_id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
  end

  def check_location_rule_owner
    unless @rule.location and @rule.location.user_id == correct_owner_id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
  end

  def call_tracing_user_find_user
    return false unless params[:reseller_user].to_i > 0 or params[:user]
    if admin?
      if params[:reseller_user] and params[:reseller_user].to_i > 0
        User.find(:first, :include => [:tariff, :devices, :lcr], :conditions => ["users.id = ? ", params[:reseller_user].to_i])
      else
        User.find(:first, :include => [:tariff, :devices, :lcr], :conditions => ["users.id = ?", params[:user]])
      end
    else
      if current_user.id == params[:user].to_i
        User.find(:first, :include => [:tariff, :devices, :lcr], :conditions => ["users.id = ?", params[:user]])
      else
        User.find(:first, :include => [:tariff, :devices, :lcr], :conditions => ["users.id = ? and users.owner_id = ?", params[:user], current_user.id])
      end
    end
  end

  def call_tracing_device_find_user
    return false if params[:user].blank?
    if admin?
      User.find(:first, :include => [:tariff, :devices, :lcr], :conditions => ["users.id = ?", params[:user]])
    else
      if current_user.id == params[:user].to_i
        User.find(:first, :include => [:tariff, :devices, :lcr], :conditions => ["users.id = ?", params[:user]])
      else
        User.find(:first, :include => [:tariff, :devices, :lcr], :conditions => ["users.id = ? and users.owner_id = ?", params[:user], current_user.id])
      end
    end
  end

  def set_valid_page_limit(field, limit, user)
    #required parameters:
    #field - expected values "Prepaid_Invoice_page_limit", "Invoice_page_limit".
    #limit - page limit. gots to be integer at least as smal as default page limit. if to small or smth else was passed set to default page limit
    #user - user id, gots to be integer. 0 for admin, 1 or more for others. theres no way to pretend that user id might be default in case it isn't valid
    default_page_limit = 1
    limit = limit.to_i < default_page_limit ? default_page_limit : limit.to_i
    Confline.set_value(field, limit, user)
  end

end
