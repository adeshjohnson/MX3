# -*- encoding : utf-8 -*-
class DevicesController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_email, :only => [:pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy]
  before_filter :find_fax_device, :only => [:pdffaxemail_add, :pdffaxemail_new]
  before_filter :find_device, :only => [:destroy, :device_edit, :device_update, :device_extlines, :device_dids, :try_to_forward_device, :device_clis, :device_all_details, :callflow, :callflow_edit, :user_device_edit, :user_device_update]
  before_filter :find_cli, :only => [:change_email_callback_status, :change_email_callback_status_device, :cli_delete, :cli_user_delete, :cli_device_delete, :cli_edit, :cli_update, :cli_device_edit, :cli_user_edit, :cli_device_update, :cli_user_update]
  before_filter :verify_params, :only => [:create]
  before_filter :check_callback_addon, :only => [:change_email_callback_status, :change_email_callback_status_device]
  before_filter :find_provider, :only => [:user_device_edit]
  before_filter :check_with_integrity, :only=>[:create, :device_update, :device_edit, :show_devices]

  before_filter { |c|
    view = [:index, :new, :edit, :device_edit, :show_devices, :device_extlines, :device_dids, :forwards, :group_forwards, :device_clis, :clis, :clis_banned_status, :cli_user_devices, :device_all_details, :default_device, :get_user_devices, :ajax_get_user_devices]
    edit = [:create, :destroy, :device_update, :device_forward, :try_to_forward_device, :cli_add, :cli_device_add, :change_email_callback_status, :change_email_callback_status_device, :cli_delete, :cli_device_delete, :cli_edit, :cli_update, :cli_device_edit, :cli_device_update, :pdffaxemail_add, :pdffaxemail_new, :pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy, :default_device_update, :assign_provider]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_device_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    user_devices
    render :action => :user_devices
  end

  def new
    #my_debug params
    @page_title = _('New_device')
    @page_icon = "add.png"

    if session[:usertype] == 'reseller'
      reseller = User.find_by_id(session[:user_id])
      check_reseller_conflines(reseller)
    end

    @user = User.find_by_id(params[:user_id])
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :index and return false
    end
    check_owner_for_device(@user)
    check_for_accountant_create_device

    @device = Device.new
    @devicetypes = Devicetype.load_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?)

    if session[:usertype] == 'accountant' or session[:usertype] == 'admin'
      owner_id = 0
    else
      owner_id = session[:user_id]
    end

    @device.device_type = Confline.get_value("Default_device_type", owner_id)
    @device_type = Confline.get_value("Default_device_type", owner_id)
    @device_type = "SIP" if @device_type.to_s == ""

    @device.pin = new_device_pin
    #my_debug @device.pin

    @audio_codecs = audio_codecs
    @video_codecs = video_codecs

    @devgroups = @user.devicegroups
    #Not using this parameter
    #@locations = Location.find(:all, :conditions=>['user_id=? or id = 1', correct_owner_id], :order => "name ASC")
    #------ permits --------

    @ip1, @mask1, @ip2, @mask2, @ip3, @mask3 = @device.perims_split

    #------ advanced --------
    if @device.qualify == "no"
      @qualify_time = 2000
    else
      @qualify_time = @device.qualify
    end

    @new_device = true
    @fax_enabled = true if Confline.get_value("Fax_Device_Enabled").to_i == 1
  end


  def create

    sanitize_device_params_by_accountant_permissions
    user = User.find(:first, :include => [:address], :conditions => ["users.id = ?", params[:user_id]])
    unless user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :index and return false
    end

    params[:device][:pin] = session[:device][:pin] if session[:device] and session[:device][:pin]

    notice, par = Device.validate_before_create(current_user, user, params, allow_dahdi?, allow_virtual?)
    if !notice.blank?
      flash[:notice] = notice
      redirect_to :controller => :callc, :action => :main and return false
    end

    fextension = free_extension()
    device = user.create_default_device({:device_ip_authentication_record => par[:ip_authentication].to_i, :description => par[:device][:description], :device_type => par[:device][:device_type], :dev_group => par[:device][:devicegroup_id], :free_ext => fextension, :secret => random_password(12), :username => fextension, :pin => par[:device][:pin]})
    if ccl_active? and par[:device][:device_type] == "SIP"
      device.insecure = 'port,invite'
    elsif ccl_active? and par[:device][:device_type] != "SIP"
      device.insecure = 'no'
    end
    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").first
    if session[:usertype] == "reseller"
      if ccl_active? and device.device_type == "SIP" and device.host == "dynamic"
        device.server_id = @sip_proxy_server
      else
        first_srv = Server.first.id
        def_asterisk = Confline.get_value('Resellers_server_id').to_i
        if def_asterisk.to_i == 0
          def_asterisk = first_srv
        end
        device.server_id = def_asterisk
      end
    end

    #device.port = Confline.get_value("Default_IAX2_device_port", current_user.get_corrected_owner_id) if device.device_type == 'IAX2' and not Device.valid_port? device.port, device.device_type                    
    #device.port = Confline.get_value("Default_SIP_device_port", current_user.get_corrected_owner_id) if device.device_type == 'SIP' and not Device.valid_port? device.port, device.device_type                      
    #device.port = Confline.get_value("Default_H323_device_port", current_user.get_corrected_owner_id) if device.device_type == 'H323' and not Device.valid_port? params[:port], device.device_type    
    
    device.port = 4569 if device.device_type == 'IAX2' and not Device.valid_port? device.port, device.device_type                    
    device.port = 5060 if device.device_type == 'SIP' and not Device.valid_port? device.port, device.device_type                      
    device.port = 1720 if device.device_type == 'H323' and not Device.valid_port? params[:port], device.device_type    

    if device.save
      # if device type = SIP and device host = dynamic and ccl_active=1 it must be assigned to sip_proxy server
      serv_dev = ServerDevice.where("server_id=? AND device_id=?", device.server_id, device.id).first
      if device.device_type == "SIP" and device.host == "dynamic" and @sip_proxy_server and ccl_active?
        if not serv_dev
          server_device = ServerDevice.new
          server_device.server_id = @sip_proxy_server.id
          server_device.device_id = device.id
          server_device.save
        end
      else
        if not serv_dev
          server_device = ServerDevice.new
          server_device.server_id = device.server_id
          server_device.device_id = device.id
          server_device.save
        end
      end
      flash[:status] = device.check_callshop_user(_('device_created'))
      # no need to create extensions, prune peers, etc when device is created, because user goes to edit window and all these actions are done in device_update
      #a=configure_extensions(device.id, {:current_user => current_user})
      #return false if !a
    else
      flash_errors_for(_('device_not_created'), device)
      redirect_to :controller => "devices", :action => 'show_devices', :id => user.id and return false
    end

    redirect_to :controller => "devices", :action => 'device_edit', :id => device.id and return false
  end

  def edit
    @user = User.find_by_id(params[:id])
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :index and return false
    end
  end

  # in before filter : device (:find_device)
  def destroy

    @return_controller = "devices"
    @return_action = "show_devices"
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    user_id = @device.user_id
    return false unless check_owner_for_device(@device.user_id)

    notice = @device.validate_before_destroy(current_user, @allow_edit)
    if !notice.blank?
      flash[:notice] = notice
      redirect_to :controller => @return_controller, :action => @return_action, :id => @device.user_id and return false
    end
    @device.destroy_all

    flash[:status] = _('device_deleted')
    redirect_to :controller => @return_controller, :action => @return_action, :id => user_id
  end

  #--------------

  def show_devices
    @page_title = _('Devices')
    @page_icon = "device.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Devices"

    @user=User.find_by_id(params[:id], :include => [:devices], :conditions => ['owner_id = ? or users.id =?', correct_owner_id, current_user.id])
    if !@user
      flash[:notice] = _("User_not_found")
      redirect_to :controller => "callc", :action => "main" and return false
    end

    a = check_owner_for_device(@user)
    return false unless a

    @return_controller = "users"
    @return_action = "list"
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    items_per_page = session[:items_per_page].to_i
    items_per_page = items_per_page < 1 ? 1 : items_per_page
    #incase items per page wouldn't be set or set to 0? we'd get 1. user can set items per page only to positive integer.
    #but using magic numbers is a bad thing. should minimal/default items per page be defined somewhere?
    total_items = @user.devices.length
    total_pages = (total_items.to_d / items_per_page.to_d).ceil
    first_page = 1
    page_no = params[:page].to_i
    page_no = page_no < first_page ? first_page : page_no
    page_no = total_pages < page_no ? total_pages : page_no
    offset = total_pages < 1 ? 0 : items_per_page * (page_no -1)

    @devices = @user.devices.find(:all, :limit => items_per_page, :offset => offset)
    @page = page_no
    @total_pages = total_pages
    @provdevices = Device.find_by_sql("SELECT devices.* FROM devices JOIN providers ON (providers.device_id = devices.id) WHERE devices.user_id = '-1' AND providers.user_id = #{current_user.id} AND providers.hidden = 0 ORDER BY providers.name;")

    store_location
  end


  # in before filter : device (:find_device)
  def device_edit
    @page_title = _('device_settings')
    @page_icon = "edit.png"

    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    if session[:usertype] == 'reseller'
      reseller = User.find_by_id(session[:user_id])
      check_reseller_conflines(reseller)
    end

    @user = @device.user
    return false unless check_owner_for_device(@user)

    @device_type = @device.device_type

    @cid_name = ""
    if @device.callerid
      @cid_name = nice_cid(@device.callerid)
      @cid_number = cid_number(@device.callerid)
    end

    @server_devices = []
    @device.server_devices.each { |d| @server_devices[d.server_id] = 1 }

    @device_dids_numbers = @device.dids_numbers
    @device_cids = @device.cid_number
    @device_caller_id_number = @device.device_caller_id_number

    @devicetypes = @device.load_device_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?)
    @audio_codecs = @device.codecs_order('audio') #audio_codecs
    @video_codecs = @device.codecs_order('video') #video_codecs

    @devgroups = @device.user.devicegroups
    if session[:usertype] == 'reseller'
      collect_locations = 'user_id=? and id != 1'
    else
      collect_locations = 'user_id=? or id = 1'
    end
    @locations = Location.find(:all, :conditions => [collect_locations, correct_owner_id], :order => "name ASC")

    @dids = @device.dids
    @all_dids = Did.forward_dids_for_select

    #-------multi server support------

    @servers = Server.where("server_type = 'asterisk'").order("server_id ASC").all

    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").limit(1).all
    @asterisk_servers = @servers
    if ccl_active?
      @servers = @sip_proxy_server
    end

    #------ permits --------

    @ip1, @mask1, @ip2, @mask2, @ip3, @mask3 = @device.perims_split

    #------ advanced --------
    if @device.qualify == "no"
      @qualify_time = 2000
    else
      @qualify_time = @device.qualify
    end

    @extension = @device.extension
    @fax_enabled = true if Confline.get_value("Fax_Device_Enabled").to_i == 1
    @pdffaxemails = @device.pdffaxemails
    @global_tell_balance = Confline.get_value('Tell_Balance').to_i
    @global_tell_time = Confline.get_value('Tell_Time').to_i


    set_voicemail_variables(@device)

    render :action => 'device_edit_h323' if @device.device_type == "H323"
    render :action => 'device_edit_skype' if @device.device_type == "Skype"
  end

  # in before filter : device (:find_device)
  def device_update
    unless @allow_edit
      flash[:notice] = _('You_have_no_editing_permission')
      redirect_to :controller => :callc, :action => :main and return false
    end
    if not params[:device]
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    change_pin = !(session[:usertype] == "accountant" and session[:acc_device_pin].to_i != 2)
    change_opt_1 = !(session[:usertype] == "accountant" and session[:acc_device_edit_opt_1].to_i != 2)
    change_opt_2 = !(session[:usertype] == "accountant" and session[:acc_device_edit_opt_2].to_i != 2)
    change_opt_3 = !(session[:usertype] == "accountant" and session[:acc_device_edit_opt_3].to_i != 2)
    change_opt_4 = !(session[:usertype] == "accountant" and session[:acc_device_edit_opt_4].to_i != 2)

    return false unless check_owner_for_device(@device.user)
    @device_old = @device.dup

    @device.set_old_name
    params[:device][:description]=params[:device][:description].to_s.strip

    if ['SIP', 'IAX2'].include?(@device.device_type)
    if params[:ip_authentication_dynamic].to_i > 0
     params[:ip_authentication] = params[:ip_authentication_dynamic].to_i == 1 ? 1 : 0
     params[:dynamic_check]  = params[:ip_authentication_dynamic].to_i == 2 ? 1 : 0
    else
      @device.username.blank? ? params[:ip_authentication] = 1 :  params[:dynamic_check] = 1
    end
        end
    params[:ip_authentication] = 1 if @device.device_type.to_s == "H323"

    @devicetypes = @device.load_device_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?).map { |dt| dt.name }
    @devicetypes << "FAX"
    MorLog.my_debug(@devicetypes.inspect)
    unless @devicetypes.include?(params[:device][:device_type].to_s)
      MorLog.my_debug("DERP DERP DERP")
      MorLog.my_debug("DT: #{@device.device_type}")
      MorLog.my_debug("DTP: #{params[:device][:device_type]}")
      params[:device][:device_type] = @device.device_type
    end

    if params[:add_to_servers].blank? and params[:device][:server_id].blank?
      flash[:notice] = _('Please_select_server')
      redirect_to :action => 'device_edit', :id => @device.id and return false
    end

    #============multi server support===========
    @servers = Server.where("server_type = 'asterisk'").order("server_id ASC").all
    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").limit(1).all
    @asterisk_servers = @servers
    if ccl_active?
      @servers = @sip_proxy_server

      @server_devices = []
      @device.server_devices.each { |d| @server_devices[d.server_id] = 1 }
    end
    #================ Insecure =================

    if ccl_active? and params[:device][:device_type] == "SIP" and params[:device][:host] == "dynamic"
      @device.insecure = 'port,invite'
    elsif ccl_active? and params[:device][:device_type] != "SIP"
      @device.insecure = 'no'
    end
    #========= Reseller device server ==========

    if session[:usertype] == "reseller"
      if ccl_active? and params[:device][:device_type] == "SIP" and params[:device][:host] == "dynamic"
        params[:add_to_servers] = @sip_proxy_server
      else
        first_srv = Server.first.id
        def_asterisk = Confline.get_value('Resellers_server_id').to_i
        if def_asterisk.to_i == 0
          def_asterisk = first_srv
        end
        params[:device][:server_id] = def_asterisk
      end
    end
    #===========================================

    change_pin == true ? params[:device][:pin]=params[:device][:pin].to_s.strip : params[:device][:pin] = @device.pin
    unless (session[:usertype] == "accountant" and session[:acc_user_create_opt_7].to_i != 2) # can accountant change call_limit?
      if params[:call_limit]
        params[:device][:call_limit]= params[:call_limit].to_s.strip
        if params[:call_limit].to_i < 0
          params[:device][:call_limit] = 0
        end
      end
    end
    if !ccl_active?
      @device.server_id = params[:device][:server_id] if params[:device] and params[:device][:server_id]
    end
    #========================== check input ============================================

    #because block_callerid input may be disabled and it will not be sent in 
    #params and setter will not be triggered and value from enabled wouldnt be 
    #set to disabled, so i we have to set it here. you may call it a little hack
    params[:device][:block_callerid] = 0 if params[:block_callerid_enable].to_s == 'no'


    if @device.device_type != "Virtual"
      if params[:device][:extension]
        change_opt_1 == true ? params[:device][:extension]=params[:device][:extension].to_s.strip : params[:device][:extension] = @device.extension
      end
      params[:device][:timeout]=params[:device_timeout].to_s.strip
    end
    if not @new_device and @device.device_type != "Virtual"
      unless @device.is_dahdi?
        if change_opt_2 == true
          params[:device][:name]=params[:device][:name].to_s.strip
          params[:device][:secret]=params[:device][:secret].to_s.strip
        else
          params[:device][:name]= @device.name
          params[:device][:secret]=@device.secret
        end
        if @device.device_type != "FAX"
          change_opt_2 == true ? params[:device][:name]=params[:device][:name].to_s.strip : params[:device][:name]= @device.name
        end
      else
        change_opt_2 == true ? params[:device][:name]=params[:device][:name].to_s.strip : params[:device][:name]= @device.name
      end
    end

    if not @new_device and @device.device_type != "FAX"
      if change_opt_3 == true
        params[:cid_number]=params[:cid_number].to_s.strip
        params[:device_caller_id_number] = params[:device_caller_id_number].to_i
      else
        params[:device_caller_id_number] = 1
        params[:cid_number]= cid_number(@device.callerid)
      end
      change_opt_4 == true ? params[:cid_name]=params[:cid_name].to_s.strip : params[:cid_name]= nice_cid(@device.callerid)
    end

    if not @new_device and @device.device_type != "FAX" and @device.device_type != "Virtual"
      unless @device.is_dahdi?
        params[:host]=params[:host].to_s.strip
        if @device.host != "dynamic"
          params[:port]=params[:port].to_s.strip

        end
        qualify =  params[:qualify_time].to_s.strip.to_i 
 	if qualify < 500 
 	  qualify = 2000 
 	  params[:qualify] = 'no' 
 	end 
 	params[:qualify_time] = qualify 
      end
    end


    if not @new_device and @device.device_type != "FAX" and @device.device_type != "Virtual"
      params[:callgroup]=params[:callgroup].to_s.strip
      params[:pickupgroup]=params[:pickupgroup].to_s.strip
    end

    if not @new_device and @device.device_type != "FAX" and @device.device_type != "Virtual"
      if @device.voicemail_box
        params[:vm_email]=params[:vm_email].to_s.strip
        params[:vm_psw]=params[:vm_psw].to_s.strip
      end
    end

    if not @new_device and @device.device_type != "FAX" and @device.device_type != "Virtual"
      unless @device.is_dahdi?
        params[:ip1]=params[:ip1].to_s.strip
        params[:mask1]=params[:mask1].to_s.strip
        params[:ip2]=params[:ip2].to_s.strip
        params[:mask2]=params[:mask2].to_s.strip
        params[:ip3]=params[:ip3].to_s.strip
        params[:mask3]=params[:mask3].to_s.strip
        if @device.device_type == "SIP"
          params[:fromuser]=params[:fromuser].to_s.strip if params[:fromuser]
          params[:fromdomain]=params[:fromdomain].to_s.strip if params[:fromdomain]
        end
      end
    end

    if not @new_device and @device.device_type != "FAX"
      params[:device][:tell_rtime_when_left]=params[:device][:tell_rtime_when_left].to_s.strip
      params[:device][:repeat_rtime_every]=params[:device][:repeat_rtime_every].to_s.strip
      params[:device][:qf_tell_time] = params[:device][:qf_tell_time].to_i
      params[:device][:qf_tell_balance] = params[:device][:qf_tell_balance].to_i
    end

    #============================= end  ============================================================
    if params[:device][:recording_to_email].to_i == 1 and params[:device][:recording_email].to_s.length == 0
      flash[:notice] = _("Recordings_email_should_be_set_when_send_recordings_to_email_is_YES")
      redirect_to :action => :device_edit, :id => @device.id and return false
    end

    if params[:device][:name] and params[:device][:name].to_s.scan(/[^\w\.\@\$\-]/).compact.size > 0
      flash[:notice] = _('Device_username_must_consist_only_of_digits_and_letters')
      redirect_to :action => :device_edit, :id => @device.id and return false
    end

    #4816 If device uses ip authentication it cannot be dynamic and valid host must be specified
    #TODO: this validation should be coded into model, but since ip auth is such a pain and
    #needs refactoring, leave it for better times.
    if params[:ip_authentication].to_i == 1 and params[:host].blank?
      flash[:notice] = _("Must_specify_host_if_ip_authentication_enabled")
      redirect_to :action => :device_edit, :id => @device.id and return false
    end

    #ticket 5055. ip auth or dynamic host must checked
    if params[:dynamic_check].to_i != 1 and params[:ip_authentication].to_i != 1 and ['SIP', 'IAX2'].include?(@device.device_type)
      if params[:host].to_s.strip.blank?
        flash[:notice] = _("Must_set_either_ip_auth_either_dynamic_host")
        redirect_to :action => :device_edit, :id => @device.id and return false
      else
        params[:ip_authentication] = '1'
      end
    end

    if params[:device][:extension] and Device.find(:first, :conditions => ["id != ? and extension = ?", @device.id, params[:device][:extension]])
      flash[:notice] = _('Extension_is_used')
      redirect_to :action => 'device_edit', :id => @device.id and return false
    else
      #pin
      if (Device.find(:first, :conditions => ["id != ? AND pin = ?", @device.id, params[:device][:pin]]) and params[:device][:pin].to_s != "")
        flash[:notice] = _('Pin_is_already_used')
        redirect_to :action => 'device_edit', :id => @device.id and return false
      end
      if params[:device][:pin].to_s.strip.scan(/[^0-9]/).compact.size > 0
        flash[:notice] = _('Pin_must_be_numeric')
        redirect_to :action => 'device_edit', :id => @device.id and return false
      end
      @device.device_ip_authentication_record = params[:ip_authentication].to_i
      params[:device] = params[:device].reject { |key, value| ['extension'].include?(key.to_s) } if current_user.usertype == 'reseller' and Confline.get_value('Allow_resellers_to_change_extensions_for_their_user_devices').to_i == 0
      if params[:device][:pin].blank? and current_user.usertype == 'reseller'
        params[:device][:pin] = @device.pin
      end

      @device.attributes = params[:device]
      # if reseller and location id == 1, create default location and set new location id
      if @device.location_id == 1 and reseller?
        @device.location_id = Confline.get_value("Default_device_location_id", current_user.id)
        @device.save
      end

      @device.name = '' if @device.name.include?('ipauth') and params[:ip_authentication].to_i == 0
      #do not leave empty name
      if @device.name.to_s.length == 0
        if @device.host.length > 0
          @device.name = @device.extension
        else
          @device.name = random_password(10)
        end
      end

      if params[:process_sipchaninfo].to_s == "1"
        @device.process_sipchaninfo = 1
      else
        @device.process_sipchaninfo = 0
      end

      if params[:save_call_log].to_s == "1"
        @device.save_call_log = 1
      else
        @device.save_call_log = 0
      end

      if params[:ip_authentication].to_s == "1"

        @device.username = ""
        @device.secret = ""
        if !@device.name.include?('ipauth')
          name = @device.generate_rand_name('ipauth', 8)
          while Device.find(:first, :conditions => ['name= ? and id != ?', name, @device.id])
            name = @device.generate_rand_name('ipauth', 8)
          end
          @device.name = name
        end
      else
        @device.username = @device.name if !@device.virtual?
        if !@device_old.virtual? and @device.virtual?
          @device.check_device_username
        end
      end

      if @device.device_type != 'FAX'
        @device.update_cid(params[:cid_name], params[:cid_number], true)
        @device.cid_from_dids = params[:device_caller_id_number].to_i == 3 ? 1 : 0
        @device.control_callerid_by_cids = params[:device_caller_id_number].to_i == 4 ? params[:control_callerid_by_cids].to_i : 0
        @device.callerid_advanced_control = params[:device_caller_id_number].to_i == 5 ? 1 : 0
      end


      #================ codecs ===================

      @device.update_codecs_with_priority(params[:codec], false) if params[:codec]
      #============= PERMITS ===================
      if params[:mask1]
        if !Device.validate_permits_ip([params[:ip1], params[:ip2], params[:ip3], params[:mask1], params[:mask2], params[:mask3]])
          flash[:notice] = _('Allowed_IP_is_not_valid')
          redirect_to :action => 'device_edit', :id => @device.id and return false
        else
          @device.permit = Device.validate_perims({:ip1 => params[:ip1], :ip2 => params[:ip2], :ip3 => params[:ip3], :mask1 => params[:mask1], :mask2 => params[:mask2], :mask3 => params[:mask3]})
        end
      end

      #------ advanced --------

      if params[:qualify] == "yes"
        @device.qualify = params[:qualify_time]
        @device.qualify == "2000" if @device.qualify.to_i < 500
      else
        @device.qualify = "no"
      end

      #------- Network related -------
      if !@new_device and @device.device_type == 'H323' and params[:host].to_s.strip !~ /^\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$/
        flash[:notice] = _('Invalid_IP_address')
        redirect_to :action => 'device_edit', :id => @device.id and return false
      end

      @device.host = params[:host]
      @device.host = "dynamic" if params[:dynamic_check].to_i == 1

      if @device.host != "dynamic"
        @device.ipaddr = @device.host
      else
        @device.ipaddr = "0.0.0.0"
      end

      #ticket #4978, previuosly there was a validation to disallow ports lower than 100
      #we have doubts whether this made any sense. so user now can set port to any positive integer
      @device.port = ""
      @device.port = params[:port] if params[:port]
      @device.port = Device::DefaultPort["IAX2"] if @device.device_type == 'IAX2' and not Device.valid_port? params[:port], @device.device_type
      @device.port = Device::DefaultPort["SIP"] if @device.device_type == 'SIP' and not Device.valid_port? params[:port], @device.device_type
      @device.port = Device::DefaultPort["H323"] if @device.device_type == 'H323' and not Device.valid_port? params[:port], @device.device_type

      @device.canreinvite = params[:canreinvite]
      @device.transfer = params[:canreinvite]

      #asterisk 1.2.x
      #@device.notransfer = "yes"
      #@device.notransfer = "no" if params[:canreinvite] = "yes"

      #------Trunks-------
      if params[:trunk].to_i == 0
        @device.istrunk = 0
        @device.ani = 0
      end
      if params[:trunk].to_i == 1
        @device.istrunk = 1
        @device.ani = 0
      end
      if params[:trunk].to_i == 2
        @device.istrunk = 1
        @device.ani = 1
      end


      if admin? or accountant?
        #------- Groups -------
        @device.callgroup = params[:callgroup]
        @device.callgroup = nil if not params[:callgroup]

        @device.pickupgroup = params[:pickupgroup]
        @device.pickupgroup = nil if not params[:pickupgroup]
      end

      #------- Advanced -------
      @device.fromuser = params[:fromuser]
      @device.fromuser = nil if not params[:fromuser] or params[:fromuser].length < 1

      @device.fromdomain = params[:fromdomain]
      @device.fromdomain = nil if not params[:fromdomain] or params[:fromdomain].length < 1
      @device.grace_time = params[:grace_time]

      @device.insecure = nil
      @device.insecure = "port" if params[:insecure_port] == "1" and params[:insecure_invite] != "1"
      @device.insecure = "port,invite" if params[:insecure_port] == "1" and params[:insecure_invite] == "1"
      @device.insecure = "invite" if params[:insecure_port] != "1" and params[:insecure_invite] == "1"
      @device.forward_did_id = params[:forward_did]


      # check for errors
      @device.host = "dynamic" if not @device.host
      @device.transfer = "no" if not @device.transfer
      @device.canreinvite = "no" if not @device.canreinvite
      @device.port = "0" if not @device.port
      @device.ipaddr = "0.0.0.0" if not @device.ipaddr

      @device.timeout = 10 if @device.timeout.to_i < 10

      #my_debug @device.port
      #MorLog.my_debug("Before_save", true)
      #MorLog.my_debug(@device.name, true)
      if params[:vm_email].to_s != ""
        if !Email.address_validation(params[:vm_email])
          flash[:notice] = _("Email_address_not_correct")
          redirect_to :action => 'device_edit', :id => @device.id and return false
        end
      end

      @device.mailbox = @device.enable_mwi.to_i == 0 ? "" : @device.extension.to_s + "@default"
      if @device.save

        #----------server_devices table changes---------
        @device.create_server_devices(params[:add_to_servers]) if ccl_active?
        @device.create_server_devices({params[:device][:server_id].to_s => "1"}) if !ccl_active?

        # ---------------------- VM --------------------
        old_vm = (vm = @device.voicemail_box).dup

        vm.email = params[:vm_email] if params[:vm_email]
        if !(session[:usertype] == "accountant" and session[:acc_voicemail_password].to_i != 2)
          vm.password = params[:vm_psw]
        end
        sql = "UPDATE voicemail_boxes SET mailbox = '#{@device.extension}', email = '#{vm.email}', password = '#{vm.password}' WHERE uniqueid = #{vm.id}"
        ActiveRecord::Base.connection.update(sql)

        @device = check_context(@device)
        a=configure_extensions(@device.id, {:current_user => current_user})
        return false if !a
        @devices_to_reconf = Callflow.find(:all, :conditions => ["device_id = ? AND action = 'forward' AND data2 = 'local'", @device.id])
        @devices_to_reconf.each { |call_flow|
          if call_flow.data.to_i > 0
            a=configure_extensions(call_flow.data.to_i, {:current_user => current_user})
            return false if !a
          end
        }
        flash[:status] = _('phones_settings_updated')
        # actions to report who changed what in device settings.
        if @device_old.pin != @device.pin
          Action.add_action_hash(session[:user_id], {:target_id => @device.id, :target_type => "device", :action => "device_pin_changed", :data => @device_old.pin, :data2 => @device.pin})
        end
        if @device_old.secret != @device.secret
          Action.add_action_hash(session[:user_id], {:target_id => @device.id, :target_type => "device", :action => "device_secret_changed", :data => @device_old.secret, :data2 => @device.secret})
        end
        if old_vm.password != vm.password
          Action.add_action_hash(session[:user_id], {:target_id => @device.id, :target_type => "device", :action => "device_voice_mail_password_changed", :data => old_vm.password, :data2 => vm.password})
        end
        redirect_to :action => 'show_devices', :id => @device.user_id and return false
      else
        flash_errors_for(_('Device_not_updated'), @device)

        @user = @device.user
        @device_type = @device.device_type
        @all_dids = Did.forward_dids_for_select
        @cid_name = ""
        if @device.callerid
          @cid_name = nice_cid(@device.callerid)
          @cid_number = cid_number(@device.callerid)
        end
        @device_dids_numbers = @device.dids_numbers
        @device_cids = @device.cid_number
        @device_caller_id_number = @device.device_caller_id_number

        @devicetypes = @device.load_device_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?)
        @audio_codecs = audio_codecs
        @video_codecs = video_codecs

        @devgroups = @device.user.devicegroups
        if session[:usertype] == 'reseller'
          collect_locations = 'user_id=? and id != 1'
        else
          collect_locations = 'user_id=? or id = 1'
        end
        @locations = Location.find(:all, :conditions => [collect_locations, correct_owner_id], :order => "name ASC")

        @dids = @device.dids

        #------ permits --------

        @ip1, @mask1, @ip2, @mask2, @ip3, @mask3 = @device.perims_split

        #------ advanced --------
        if @device.qualify == "no"
          @qualify_time = 2000
        else
          @qualify_time = @device.qualify
        end

        @extension = @device.extension
        @fax_enabled = true if Confline.get_value("Fax_Device_Enabled").to_i == 1
        @pdffaxemails = @device.pdffaxemails

        set_voicemail_variables(@device)

        if @device.device_type == "H323"
          render :action => :device_edit_h323
        else
          render :action => :device_edit
        end
      end
    end
  end

  # in before filter : device (:find_device)
  def device_extlines
    @page_title = _('Ext_lines')
    @page_icon = "asterisk.png"

    if !@extlines = @device.extlines
      @extlines = nil
    end

    @user = @device.user

    #render(:layout => "layouts/realtime_stats")

    if params[:context] == :show
      render(:layout => false)
    end
  end

  # in before filter : device (:find_device)
  def device_dids
    @page_title = _('dids')
    @user = @device.user
    check_owner_for_device(@user)

    if !@dids = @device.dids
      @dids = nil
    end

    if params[:context] == :show
      render(:layout => false)
    end
  end

  def device_forward
    @page_title = _('Device_forward')
    @page_icon = "forward.png"

    if params[:group]
      @group = Group.find(params[:group])
      @devices = []
      for user in @group.users
        for device in user.devices
          @devices << device
        end
      end
    else
      @devices = Device.find(:all, :conditions => "name not like 'mor_server_%'", :order => "extension ASC")
    end

    @device = Device.find(params[:id])
    @user = @device.user
  end

  # in before filter : device (:find_device)
  def try_to_forward_device
    @fwd_to = params[:select_fwd]

    can_fwd = true

    if @fwd_to != "0"

      #checking can we forward
      d = Device.find(@fwd_to)
      can_fwd = false if d.forward_to == @device.id

      while !(d.forward_to == 0 or d.forward_to == @device.id)
        d = Device.find(d.forward_to)
        can_fwd = false if d.forward_to == @device.id
      end

    end


    if can_fwd

      if @fwd_to != "0"
        flash[:status] = _('device') + ' '+@device.name.to_s + ' ' +_('forwarded_to')+ ' ' + Device.find(@fwd_to).name.to_s
      else
        flash[:status] = _('device') + ' ' + @device.name.to_s + ' ' + _('forward_removed')
      end

      #my_debug @fwd_to
      #my_debug @device.id

      @device.forward_to = @fwd_to
      if @device.save
        #my_debug "device saved"
      else
        #my_debug "device not saved"
      end

      a=configure_extensions(@device.id, {:current_user => current_user})
      return false if !a
    else
      flash[:notice] = _('device') +' ' + @device.name.to_s + ' ' + _('not_forwarded_close_circle')
    end

    redirect_to :action => 'device_forward', :id => @device
  end


  def forwards
    @page_title = _('Forwards')
    @page_icon = "forward.png"
    @devices = Device.find(:all, :conditions => "user_id != 0 AND name not like 'mor_server_%'", :order => "name ASC")
  end


  def group_forwards
    @group = Group.find(params[:id])
    @page_icon = "forward.png"

    @page_title = _('Forwards')+": " + @group.name

    @devices = []
    for user in @group.users
      for device in user.devices
        @devices << device
      end
    end

    render :action => "forwards"
  end


  #============ CallerIDs ===============

  def user_device_clis
    @page_title = _('CallerIDs')
    @page_icon = "cli.png"

    @user = User.find(session[:user_id])
    @devices = @user.devices
    @clis = []

    sql = "SELECT callerids.* , devices.user_id , devices.name, devices.device_type, devices.istrunk, ivrs.name as 'ivr_name' FROM callerids
                       JOIN devices on (devices.id = callerids.device_id)
                       LEFT JOIN ivrs on (ivrs.id = callerids.ivr_id)
               WHERE devices.user_id = '#{@user.id}'"
    @clis = Callerid.find_by_sql(sql)


    @all_ivrs = Ivr.find(:all)
  end

  # in before filter : device (:find_device)
  def device_clis
    @page_title = _('CallerIDs')
    @page_icon = "cli.png"
    if !params[:id]
      dont_be_so_smart
      redirect_to :action => "devices_all" and return false
    end
    sql = "SELECT callerids.* , ivrs.name as 'ivr_name' FROM callerids
      LEFT JOIN ivrs on (ivrs.id = callerids.ivr_id)
      WHERE device_id = '#{@device.id}'"
    @clis = Callerid.find_by_sql(sql)
    @user = @device.user
    @all_ivrs = Ivr.find(:all)
    check_owner_for_device(@user.id)
  end

  def cli_add
    create_cli
    redirect_to :action => 'clis'
  end

  def cli_device_add
    create_cli
    redirect_to :action => 'device_clis', :id => params[:device_id] and return false
  end

  def cli_user_add
    create_cli
    redirect_to :action => 'user_device_clis' and return false
  end

  def change_email_callback_status
    Callerid.use_for_callback(@cli, params[:email_callback])
    redirect_to :action => 'clis' and return false
  end

  def change_email_callback_status_device
    Callerid.use_for_callback(@cli, params[:email_callback])
    redirect_to :action => 'device_clis', :id => @cli.device_id and return false
  end

  def cli_delete
    cli_cli = @cli.cli
    @cli.destroy
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to :action => 'clis' and return false

  end

  def cli_user_delete
    cli_cli = @cli.cli
    @cli.destroy
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to :action => 'user_device_clis' and return false
  end

  def cli_device_delete
    cli_cli = @cli.cli
    device_id = @cli.device_id
    if @cli.destroy
      flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    else
      flash_errors_for(_('CLI_is_not_deleted'), @cli)
    end
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to :action => 'device_clis', :id => device_id and return false
  end

  def cli_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @all_ivrs = Ivr.all
    @device = @cli.device
    #  check_owner_for_device(@device.user)
    @user = @device.user
    unless @user and @user.id == session[:user_id].to_i or @user.owner_id == session[:user_id].to_i or session[:usertype] == "admin" or session[:usertype] == "accountant" or session[:usertype] == "reseller"
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def cli_update
    @cli.cli = params[:cli]
    @cli.description = params[:description]
    @cli.comment = params[:comment]
    params[:banned].to_i == 1 ? @cli.banned = 1 : @cli.banned = 0
    @cli.ivr_id = params[:ivr] if params[:ivr]
    if @cli.save
      Callerid.use_for_callback(@cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to :action => 'clis' and return false
    else
      flash_errors_for(_("CLI_not_created"), @cli)
      redirect_to :action => :cli_edit, :id => @cli.id
    end
  end

  def cli_device_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'

    @all_ivrs = Ivr.find(:all)
    @device = @cli.device
    @user = @device.user
    unless @user and @user.id == session[:user_id].to_i or @user.owner_id == session[:user_id].to_i or session[:usertype] == "admin" or session[:usertype] == "accountant"
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def cli_user_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @all_ivrs = Ivr.find(:all)
    @device = @cli.device
    @user = @device.user
    unless @user and @user.id == session[:user_id].to_i or @user.owner_id == session[:user_id].to_i or session[:usertype] == "admin" or session[:usertype] == "accountant"
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def cli_device_update
    @cli.cli = params[:cli]
    @cli.description = params[:description]
    @cli.comment = params[:comment]
    params[:banned].to_i == 1 ? @cli.banned = 1 : @cli.banned = 0
    @cli.ivr_id = params[:ivr] if params[:ivr] and accountant_can_write?("cli_ivr")
    if @cli.save
      Callerid.use_for_callback(@cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to :action => 'device_clis', :id => @cli.device_id
    else
      flash_errors_for(_("CLI_not_created"), @cli)
      redirect_to :action => :cli_device_edit, :id => @cli.id
    end
  end

  def cli_user_update
    cli = Callerid.find_by_id(params[:id])
    unless cli
      flash[:notice]=_('Callerid_was_not_found')
      redirect_to :action => :index and return false
    end
    cli.cli = params[:cli]
    cli.description = params[:description]
    cli.comment = params[:comment]
    if params[:banned].to_i == 1
      cli.banned = 1
    else
      cli.banned = 0
    end
    cli.ivr_id = params[:ivr] if params[:ivr]
    if cli.save
      Callerid.use_for_callback(cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to :action => 'user_device_clis' and return false
    else
      flash_errors_for(_("CLI_not_created"), cli)
      redirect_to :action => :cli_user_edit, :id => cli.id
    end
  end

  def clis
    @page_title = _('CLIs')
    @page_icon = "cli.png"

    @search_cli = ""
    @search_device = -1
    @search_user = -1
    @search_banned = -1
    @search_email_callback = -1
    @search_ivr = -1
    @search_description = ""
    @search_comment = ""
    @search_user = params[:s_user] if params[:s_user]
    @search_cli = params[:s_cli] if params[:s_cli]
    @search_device = params[:device_id] if params[:device_id]
    @search_banned = params[:s_banned] if params[:s_banned]
    @search_ivr = params[:s_ivr] if params[:s_ivr]
    @search_description = params[:s_description] if params[:s_description]
    @search_comment = params[:s_comment] if params[:s_comment]
    @search_email_callback = params[:s_email_callback] if params[:s_email_callback]
    cond=""

    if @search_user.to_i != -1
      cond = "  AND devices.user_id = '#{@search_user}' "
      if @search_device.to_i != -1
        cond += " AND callerids.device_id = '#{@search_device}' "
      end
    end

    cond += " AND callerids.cli = '#{@search_cli}' " if @search_cli.length > 0

    cond += " AND callerids.banned =  '#{@search_banned}' " if @search_banned.to_i != -1

    cond += " AND callerids.ivr_id =  '#{@search_ivr}' " if @search_ivr.to_i != -1

    cond += " AND callerids.description LIKE '#{@search_description}%' " if @search_description.length > 0

    cond += " AND callerids.comment LIKE  '#{@search_comment}%' " if @search_comment.length > 0

    cond += " AND callerids.email_callback =  '#{@search_email_callback}' " if @search_email_callback.to_i != -1

    current_user.usertype == "accountant" ? @current_user_id = 0 : @current_user_id = current_user.id

      sql = "SELECT callerids.* , devices.user_id , devices.name, devices.extension, devices.device_type, devices.istrunk, ivrs.name as 'ivr_name' FROM callerids
             JOIN devices on (devices.id = callerids.device_id)
             JOIN users on (users.id = devices.user_id)
             LEFT JOIN ivrs on (ivrs.id = callerids.ivr_id)
             WHERE callerids.id > 0 #{cond} AND users.id = devices.user_id and users.owner_id = '#{@current_user_id}'"

    #MorLog.my_debug sql

    @clis = Callerid.find_by_sql(sql) #if cond.length > 0


    #MorLog.my_debug @clis.to_yaml

      @users = User.find(:all, :conditions => "owner_id = '#{@current_user_id}'" )

      sql2="SELECT DISTINCT(callerids.ivr_id), ivrs.name, ivrs.id FROM ivrs
          LEFT JOIN callerids ON (ivrs.id = callerids.ivr_id)
          WHERE ivrs.user_id = '#{@current_user_id}'"

    @ivrs = Ivr.find_by_sql(sql2)
    @all_ivrs = @ivrs

    @search = 0
    @search = 1 if cond.length > 8

    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@clis.size.to_d / session[:items_per_page].to_d).ceil
    @all_clis = @clis
    @clis = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_clis.size - 1 if iend > (@all_clis.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @clis << @all_clis[i]
    end


  end

  def clis_banned_status
    @cl = Callerid.find(params[:id])
    @cl.created_at = Time.now if not @cl.created_at
    @cl.banned.to_i == 1 ? @cl.banned = 0 : @cl.banned = 1
    @cl.save
    redirect_to :action => 'clis'
  end

  def cli_user_devices
    @num = request.raw_post.to_s.gsub("=", "")
    @num = params[:id] if params[:id]
    @include_cli = params[:cli] if params[:cli]
    #    if params[:cli]
    #      @add = 1
    #      @devices = Device.find(:all, :select=>"devices.*", :joins=>"LEFT JOIN callerids ON (callerids.device_id = devices.id)",:conditions => ["user_id = ? AND callerids.id IS NULL", @num]) if @num.to_i != -1
    #    else
    @devices = Device.find(:all, :conditions => ["user_id = ? AND name not like 'mor_server_%' AND name NOT LIKE 'prov%'", @num]) if @num.to_i != -1
    #    end

    if params[:add]
      @add =1
    end
    @did=params[:did].to_i
    render :layout => false
  end

  def devices_all
    @page_title = _('Devices')
    @page_icon = "device.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Devices"

    default_options = {}
    if params[:clean]
      @options = default_options
    else
      if session[:devices_all_options]
        @options = session[:devices_all_options]
      else
        @options = default_options
      end
    end
    #if new param was specified delete it from options,
    #else there might be leaved parameters that were saved in session
    @options.delete(:search_pinless) if params[:s_pinless]
    @options.delete(:search_pin) if params[:s_pin]

    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    @options[:order_by], order_by, default = devices_all_order_by(params, @options)

    params[:s_description] ? @options[:search_description] = params[:s_description].to_s : (@options[:search_description] = "" if !@options[:search_description])
    params[:s_extension] ? @options[:search_extension] = params[:s_extension].to_s : (@options[:search_extension] = "" if !@options[:search_extension])
    params[:s_username] ? @options[:search_username] = params[:s_username].to_s : (@options[:search_username] = "" if !@options[:search_username])
    @options[:search_cli] = params[:s_cli].to_s if params[:s_cli]

    #if pinless option is selected, than there shouldnt be pin parameter specified.
    #if pin was specified, then there shouldnt be pinless parameter.
    #so just in case we should delete options that shouldnt be there
    if params[:s_pinless]
      @options[:search_pinless] = params[:s_pinless]
      @options.delete(:search_pin)
    else
      pin = params[:s_pin].to_s.strip
      if pin.length > 0
        @options[:search_pin] = pin if pin =~ /^[0-9]+$/
      end
      @options.delete(:search_pinless)
    end

    @options[:search_description].to_s.length + @options[:search_extension].to_s.length+ @options[:search_username].to_s.length + @options[:search_cli].to_s.length > 0 ? @options[:search] = 1 : @options[:search] = 0
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page] or @options[:page] <= 0)
    join = ["LEFT OUTER JOIN users ON users.id = devices.user_id"]
    cond = ["user_id != -1 AND devices.name not like 'mor_server_%'"]
    cond_par = []

    #if at least one valid seach option was entered
    #@search should be true
    @search = false

    if @options[:search_description].to_s.length > 0
      cond << "devices.description LIKE ?"
      cond_par << "%"+ @options[:search_description].to_s+"%"
      @search = true
    end

    if @options[:search_extension].to_s.length > 0
      cond << "devices.extension LIKE ?"
      cond_par << @options[:search_extension].to_s+"%"
      @search = true
    end

    if @options[:search_username].to_s.length > 0
      cond << "devices.username LIKE ?"
      cond_par << @options[:search_username].to_s + "%"
      @search = true
    end

    if @options[:search_cli].to_s.length > 0
      join << "LEFT OUTER JOIN callerids ON devices.id = callerids.device_id"
      cond << "callerids.cli LIKE ?"
      cond_par << @options[:search_cli].to_s + "%"
      @search = true
    end

    if @options[:search_pinless]
      cond << "(devices.pin is NULL OR devices.pin = ?)"
      cond_par << ""
      @search = true
    else
      if @options[:search_pin]
        cond << "devices.pin LIKE ?"
        cond_par << @options[:search_pin].to_s + "%"
        @search = true
      end
    end

    cond << "users.hidden = 0"
    cond << "accountcode != 0"
    cond << "users.owner_id = ?"
    cond_par << session[:user_id]


    #grouping by device id is needed only when searching by cli. how to work around it withoud duplicating code?
    @total_pages = (Device.count(:all, :joins => join.join(" "), :conditions => [cond.join(" AND ")] + cond_par, :group => 'devices.id').size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages.to_i if @total_pages.to_i < @options[:page].to_i and @total_pages > 0
    @options[:page] = 1 if @options[:page].to_i < 1

    @devices = Device.find(:all,
                           :select => "devices.*, IF(LENGTH(CONCAT(users.first_name, users.last_name)) > 0,CONCAT(users.first_name, users.last_name), users.username) AS 'nice_user'",
                           :joins => join.join(" "),
                           :conditions => [cond.join(" AND ")] + cond_par,
                           :group => 'devices.id',
                           :order => order_by,
                           :offset => session[:items_per_page]*(@options[:page]-1),
                           :limit => session[:items_per_page]
    )

    if default and (session[:devices_all_options] == nil or session[:devices_all_options][:order_by] == nil)
      @options.delete(:order_by)
    end
    session[:devices_all_options] = @options
  end

  # in before filter : device (:find_device)
  def device_all_details
    @page_title = _('Device_details')
    @page_icon = "view.png"

    @user = @device.user
    check_owner_for_device(@user)

  end


  # ------------------------------- C A L L F L O W ---------------------------
  # in before filter : device (:find_device)
  def callflow
    @page_title = _('Call_Flow')
    @page_icon = "cog_go.png"

    #security
    if session[:usertype] == "user" or session[:usertype] == "accountant"
      if session[:manager_in_groups].size == 0
        #simple user
        @user = User.find(session[:user_id])
        if @device.user_id != @user.id

          dont_be_so_smart
          redirect_to :controller => "callc", :action => 'main'
        end
      else
        #group manager
        @user = @device.user

        can_check = false
        for group in session[:manager_in_groups]
          for user in group.users
            can_check = true if user.id == @user.id
          end
        end

        if not can_check
          dont_be_so_smart
          redirect_to :controller => "callc", :action => 'main'
        end
      end
    end

    if session[:usertype] == "reseller"
      @user = @device.user

      if @user.owner_id != session[:user_id] and @user.id != session[:user_id]
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main'
      end

    end

    if session[:usertype] == "admin"
      @user = @device.user
    end

    @before_call_cfs = Callflow.find(:all, :conditions => "cf_type = 'before_call' AND device_id = #{@device.id}", :order => "priority ASC")
    @no_answer_cfs = Callflow.find(:all, :conditions => "cf_type = 'no_answer' AND device_id = #{@device.id}", :order => "priority ASC")
    @busy_cfs = Callflow.find(:all, :conditions => "cf_type = 'busy' AND device_id = #{@device.id}", :order => "priority ASC")
    @failed_cfs = Callflow.find(:all, :conditions => "cf_type = 'failed' AND device_id = #{@device.id}", :order => "priority ASC")

    if @before_call_cfs.empty?
      cf = create_empty_callflow(@device.id, "before_call")
      @before_call_cfs << cf
    end

    if @no_answer_cfs.empty?
      cf = create_empty_callflow(@device.id, "no_answer")
      @no_answer_cfs << cf
    end

    if @busy_cfs.empty?
      cf = create_empty_callflow(@device.id, "busy")
      @busy_cfs << cf
    end

    if @failed_cfs.empty?
      cf = create_empty_callflow(@device.id, "failed")
      @failed_cfs << cf
    end

  end

  # in before filter : device (:find_device)
  def callflow_edit
    @page_title = _('Call_Flow')
    @page_icon = "edit.png"

    err=0

    @user = @device.user
    if  ['user', 'reseller'].include?(current_user.usertype)
      if @device.user_id != current_user.id and current_user.usertype == 'user'
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main' and return false
      end
      if current_user.usertype == 'reseller' and (@device.user_id != current_user.id and @device.user.owner_id != current_user.id)
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main' and return false
      end
    else
      check_owner_for_device(@user)
    end

    @dids = Did.find(:all, :conditions => ["device_id = ?", @device.id])
    @cf_type = params[:cft]

    @fax_enabled = Confline.get_value("Fax_Device_Enabled").to_i


    whattodo = params[:whattodo]
    cf = Callflow.find(:first, :conditions => {:id => params[:cf], :device_id => @device}) if params[:cf]
    if !cf and params[:cf]
      flash[:notice]=_('Callflow_was_not_found')
      redirect_to :action => :index and return false
    end
    #MorLog.my_debug("CF :#{cf.to_s}" )
    case whattodo
      when "change_action"
        cf.action = params[:cf_action]
        cf.data = ""
        cf.data2 = ""
        cf.data3 = 1
        cf.save
      when "change_local_device"
        if  params[:cf_data].to_i == 5
          if params[:device_id].to_s != ""
            cf.data = params[:device_id].to_i
            cf.data2 = "local"
            cf.data3=""
            cf.save if cf.data.to_i > 0
          else
            err=1
          end
        end
        if  params[:cf_data].to_i == 6
          if  params[:ext_number].to_i == @device.extension.to_i
            flash[:notice] = _('Devices_callflow_external_number_cant_match_extension')
            redirect_to :action => 'callflow_edit', :id => @device.id, :cft => @cf_type and return false
          end
          if  params[:ext_number].to_s.blank?
            flash[:notice] = _('Devices_callflow_external_number_cant_be_blank')
            redirect_to :action => 'callflow_edit', :id => @device.id, :cft => @cf_type and return false
          end
          cf.data = params[:ext_number].to_s.strip
          cf.data2 = "external"
          cf.data3=""
          cf.save
        end


        if params[:cf_data3].to_i < 5
          cf.data3 = params[:cf_data3].to_s
          if params[:cf_data3].to_i == 3
            cf.data4 = params[:did_id] if  params[:did_id]
          end
          if params[:cf_data3].to_i == 4
            cf.data4 = params[:cf_data4] if  params[:cf_data4].length > 0
          end
          if params[:cf_data3].to_i < 3
            cf.data4 = ""
          end
          cf.save #if cf
        end
      when "change_fax_device"
        cf.data = params[:device_id].to_i
        cf.data2 = "fax"
        cf.save if cf.data.to_i > 0
      when "change_device_timeout"
        value = params[:device_timeout].to_i
        if value < 10
          value = 10
        end
        @device.timeout = value
        @device.save
    end

    if err.to_i == 0
      flash[:status] = _('Callflow_updated') if params[:whattodo] and params[:whattodo].length > 0

      @cfs = Callflow.find(:all, :conditions => ["cf_type = ? AND device_id = ?", @cf_type, @device.id], :order => "priority ASC")

      if session[:usertype] != "admin" and session[:usertype] != "accountant"
        if session[:usertype] == "user" and session[:manager_in_groups].size == 0
          #simple user
          @devices = @user.devices
          @fax_devices = @user.fax_devices
        else
          #group manager or reseller can forward devices to same groups devices
          @devices = Device.find(:all, :include => [:user], :conditions => ["(users.owner_id = ? OR users.id = ? ) AND devices.accountcode > 0 AND name not like 'mor_server_%'", session[:user_id], session[:user_id]], :order => "name ASC")
          @fax_devices = Device.find(:all, :include => [:user], :conditions => ["(users.owner_id = ? OR users.id = ? ) AND devices.device_type = 'FAX' AND name not like 'mor_server_%'", session[:user_id], session[:user_id]], :order => "name ASC")
          for group in session[:manager_in_groups]
            for user in group.users
              for device in user.devices
                @devices << device if not @devices.include?(device)
              end
              for fdevice in user.fax_devices
                @fax_devices << fdevice if not @fax_devices.include?(fdevice)
              end
            end
          end
        end
      else
        #admin
        @devices = Device.find(:all, :conditions => "user_id != -1 AND accountcode > 0 AND name not like 'mor_server_%'", :order => "name ASC")
        @fax_devices = Device.find(:all, :conditions => "user_id != -1 AND device_type = 'FAX' AND name not like 'mor_server_%'", :order => "name ASC")
      end
      if params[:whattodo] and params[:whattodo].to_s.length > 0
        a=configure_extensions(@device.id, {:current_user => current_user})
        return false if !a
      end
    else
      flash[:notice]= _('Please_select_device')
      redirect_to :action => 'callflow_edit', :id => @device.id, :cft => @cf_type
    end
  end

  # ------------------------- User devices --------------

  def user_devices
    @page_title = _('Devices')
    @page_icon = "device.png"
    @devices = current_user.devices #Device.find(:all,:include => [:user, :provider], :conditions => ["devices.user_id = ?", session[:user_id]], :order => "devices.name")
  end

=begin rdoc
 Enables user to edit his device settings.

 *Params*

 +:id+ - Device_id

=end
  # in before filter : device (:find_device)

  def find_provider
    @provider = Provider.find(:first, :conditions => ["device_id = #{@device.id}"])
  end

  def user_device_edit
    if !@provider
      @page_title = _('device_settings')
    else
      @page_title = _('Provider_settings')
    end
    @page_icon = "edit.png"
    @user = User.find_by_id(session[:user_id])
    @owner = User.find_by_id(@user.owner_id)
    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => :index and return false
    end
    if @device.user_id != @user.id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    if @device.device_type == "FAX"
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    @dids = @device.dids
    @cid_name = ""
    if @device.callerid
      @cid_name = nice_cid(@device.callerid)
      @cid_number = cid_number(@device.callerid)
    end
    @curr = current_user.currency
  end

=begin rdoc
 Update device data.

 *Params*

 +:id+ - Device_id
 other params

=end
  # in before filter : device (:find_device)
  def user_device_update
    @user = User.find(session[:user_id])
    if @device.user_id != @user.id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    if @device.device_type !="FAX" and (params[:cid_name] or params[:cid_number] or (params[:cid_number_from_did] and params[:cid_number_from_did].length > 0))
      if params[:cid_number_from_did] and params[:cid_number_from_did].length > 0
        @device.update_cid(params[:cid_name], params[:cid_number_from_did])
      else
        @device.update_cid(params[:cid_name], params[:cid_number])
      end
    end
    # CID control by DIDs (CID can be only from the set if DIDs)
    if params[:cid_from_dids] == "1"
      @device.update_cid("", "")
    end
    @device.cid_from_dids = params[:cid_from_dids].to_i

    @device.description = params[:device][:description]

    @device.record = params[:device][:record].to_i
    @device.recording_to_email = params[:device][:recording_to_email].to_i
    @device.recording_email = params[:device][:recording_email]
    @device.recording_keep = params[:device][:recording_keep].to_i
    #@device.record_forced =  params[:device][:record_forced].to_i
    if @device.save
      flash[:status] = _('phones_settings_updated')
    else
      flash_errors_for(_("Update_Failed"), @device)
      #flash[:notice] = _("Update_Failed")
    end
    redirect_to :action => :user_devices and return false
  end

  # ------------------ PDF Fax Emails -----------------

  def pdffaxemail_add
    @page_title = _('Add_new_email')
    @page_icon = "add.png"

    @user = @device.user
  end

  def pdffaxemail_new
    if params[:new_pdffaxemail] and params[:new_pdffaxemail].length > 0 and Email.address_validation(params[:new_pdffaxemail])

      email = Pdffaxemail.new
      email.device_id = @device.id
      email.email = params[:new_pdffaxemail]
      email.save

      flash[:status] = _('New_email_added')
    else
      if !Email.address_validation(params[:new_pdffaxemail])
        flash[:notice] = _('Email_is_not_correct')
      else
        flash[:notice] = _('Please_fill_field')
      end
    end

    redirect_to :action => 'device_edit', :id => @device.id

  end

  def pdffaxemail_edit
    @page_title = _('Edit_email')
    @page_icon = "edit.png"

    @device = @email.device
    @user = @device.user
  end


  def pdffaxemail_update

    if params[:email] and params[:email].length > 0 and Email.address_validation(params[:email])

      @email.email = params[:email]
      @email.save

      flash[:status] = _('Email_updated')
    else
      flash[:notice] = _('Email_not_updated')
    end

    redirect_to :action => 'device_edit', :id => @email.device.id

  end

  def pdffaxemail_destroy
    email = @email.email
    device_id = @email.device_id
    @email.destroy

    flash[:status] = _('Email_deleted') + ": " + email
    redirect_to :action => 'device_edit', :id => device_id
  end

  def default_device

    @page_title = _('Default_device')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Default_device_settings"

    if session[:usertype] == 'reseller'
      reseller = User.find(session[:user_id])
      check_reseller_conflines(reseller)
      reseller.check_default_user_conflines
    end
    # @new_device = true
    #@user = User.find(session[:user_id])

    @device = Confline.get_default_object(Device, correct_owner_id)

    @devicetypes = Devicetype.load_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?)

    @device_type =Confline.get_value("Default_device_type", session[:user_id])

    @global_tell_balance = Confline.get_value('Tell_Balance').to_i 
    @global_tell_time = Confline.get_value('Tell_Time').to_i 

    if @device_type == 'FAX'
      @audio_codecs = Codec.find(:all,
                                 :select => 'codecs.*,  (conflines.value2 + 0) AS v2', :joins => "LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, 'Default_device_codec_', '') and owner_id = #{session[:user_id]})",
                                 :conditions => "conflines.name like 'Default_device_codec%' and codecs.codec_type = 'audio' and codecs.name IN ('alaw', 'ulaw')",
                                 :order => 'v2 asc')
    else
      @audio_codecs = Codec.find(:all,
                                 :select => 'codecs.*,  (conflines.value2 + 0) AS v2', :joins => 'LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, "Default_device_codec_", ""))',
                                 :conditions => ["conflines.name like 'Default_device_codec%' and codecs.codec_type = 'audio' and owner_id =?", session[:user_id]],
                                 :order => 'v2 asc')
    end
    @video_codecs = Codec.find(:all,
                               :select => 'codecs.*, (conflines.value2 + 0) AS v2', :joins => 'LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, "Default_device_codec_", ""))',
                               :conditions => ["conflines.name like 'Default_device_codec%' and codecs.codec_type = 'video' and owner_id =?", session[:user_id]],
                               :order => 'v2 asc')
    @owner = session[:user_id]
    if session[:usertype] == 'reseller'
      collect_locations = 'user_id=? and id != 1'
    else
      collect_locations = 'user_id=? or id = 1'
    end
    @locations = Location.find(:all, :conditions => [collect_locations, correct_owner_id], :order => "name ASC")
    @default = 1
    @cid_name = Confline.get_value("Default_device_cid_name", session[:user_id])
    @cid_number = Confline.get_value("Default_device_cid_number", session[:user_id])
    @qualify_time = Confline.get_value("Default_device_qualify", session[:user_id])
    ddd = Confline.get_value("Default_setting_device_caller_id_number", session[:user_id]).to_i
    @device.cid_from_dids= 1 if ddd == 3
    @device.control_callerid_by_cids= 1 if ddd == 4
    @device.callerid_advanced_control= 1 if ddd == 5

    @device_dids_numbers = @device.dids_numbers
    @device_caller_id_number = @device.device_caller_id_number

    #-------multi server support------
    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").limit(1).all
    @servers = Server.where("server_type = 'asterisk'").order("server_id ASC").all
    #@asterisk_servers = @servers
    if @sip_proxy_server.length > 0 and @device_type == "SIP"
      @servers = @sip_proxy_server
    end

    #------------ permits ------------

    @ip1 = ""
    @mask1 = ""
    @ip2 = ""
    @mask2 = ""
    @ip3 = ""
    @mask3 = ""

    data = Confline.get_value("Default_device_permits", session[:user_id]).split(';')
    if data[0]
      permit = data[0].split('/')
      @ip1 = permit[0]
      @mask1 = permit[1]
    end

    if data[1]
      permit = data[1].split('/')
      @ip2 = permit[0]
      @mask2 = permit[1]
    end

    if data[2]
      permit = data[2].split('/')
      @ip3 = permit[0]
      @mask3 = permit[1]
    end
    # @call_limit = confline("Default_device_call_limit")
    @user = User.new(:recording_enabled => 1)

    @fax_enabled = true if Confline.get_value("Fax_Device_Enabled").to_i == 1

    @device_voicemail_active = Confline.get_value("Default_device_voicemail_active", session[:user_id])
    @device_voicemail_box = Confline.get_value("Default_device_voicemail_box", session[:user_id])
    @device_voicemail_box_email = Confline.get_value("Default_device_voicemail_box_email", session[:user_id])
    @device_voicemail_box_password = Confline.get_value("Default_device_voicemail_box_password", session[:user_id])
    @fullname = ""
    @device_enable_mwi = Confline.get_value("Default_device_enable_mwi", session[:user_id])
  end

  def default_device_update
    if params[:call_limit]
      params[:call_limit]= params[:call_limit].to_s.strip.to_i
      if params[:call_limit].to_i < 0
        params[:call_limit] = 0
      end
    end

    if params[:vm_email].to_s != ""
      if !Email.address_validation(params[:vm_email])
        flash[:notice] = _("Email_address_not_correct")
        redirect_to :action => 'default_device' and return false
      end
    end

    Confline.set_value("Default_device_type", params[:device][:device_type], session[:user_id])
    Confline.set_value("Default_device_dtmfmode", params[:device][:dtmfmode], session[:user_id])
    Confline.set_value("Default_device_works_not_logged", params[:device][:works_not_logged], session[:user_id])
    Confline.set_value("Default_device_location_id", params[:device][:location_id], session[:user_id])
    Confline.set_value("Default_device_timeout", params[:device_timeout], session[:user_id])

    Confline.set_value("Default_device_call_limit", params[:call_limit].to_i, session[:user_id])
    Confline.set_value("Default_device_server_id", (session[:usertype] == 'reseller' ? Confline.get_value('Resellers_server_id').to_i : params[:device][:server_id].to_i), session[:user_id]) if params[:device] and params[:device][:server_id]
    Confline.set_value("Default_device_cid_name", params[:cid_name], session[:user_id])
    Confline.set_value("Default_device_cid_number", params[:cid_number], session[:user_id])
    Confline.set_value("Default_setting_device_caller_id_number", params[:device_caller_id_number].to_i, session[:user_id])

    Confline.set_value("Default_device_nat", params[:device][:nat], session[:user_id])

    Confline.set_value("Default_device_qualify_time", params[:qualify_time], session[:user_id])


    Confline.set_value("Default_device_voicemail_active", params[:voicemail_active], session[:user_id])
    Confline.set_value("Default_device_voicemail_box", 1, session[:user_id])
    Confline.set_value("Default_device_voicemail_box_email", params[:vm_email], session[:user_id])
    Confline.set_value("Default_device_voicemail_box_password", params[:vm_psw], session[:user_id])

    Confline.set_value("Default_device_trustrpid", params[:device][:trustrpid], session[:user_id])
    Confline.set_value("Default_device_sendrpid", params[:device][:sendrpid], session[:user_id])
    Confline.set_value("Default_device_t38pt_udptl", params[:device][:t38pt_udptl], session[:user_id])
    Confline.set_value("Default_device_promiscredir", params[:device][:promiscredir], session[:user_id])
    Confline.set_value("Default_device_progressinband", params[:device][:progressinband], session[:user_id])
    Confline.set_value("Default_device_videosupport", params[:device][:videosupport], session[:user_id])

    Confline.set_value("Default_device_allow_duplicate_calls", params[:device][:allow_duplicate_calls], session[:user_id])
    Confline.set_value("Default_device_tell_balance", params[:device][:tell_balance], session[:user_id])
    Confline.set_value("Default_device_tell_time", params[:device][:tell_time], session[:user_id])
    Confline.set_value("Default_device_tell_rtime_when_left", params[:device][:tell_rtime_when_left], session[:user_id])
    Confline.set_value("Default_device_repeat_rtime_every", params[:device][:repeat_rtime_every], session[:user_id])
    Confline.set_value("Default_device_fake_ring", params[:device][:fake_ring], session[:user_id])
    lang = params[:device][:language].to_s.blank? ? 'en' : params[:device][:language].to_s
    Confline.set_value("Default_device_language", lang, session[:user_id])
    Confline.set_value("Default_device_enable_mwi", params[:device][:enable_mwi].to_i, session[:user_id])

    Confline.set_value("Default_device_qf_tell_time", params[:device][:qf_tell_time].to_i, session[:user_id]) 
    Confline.set_value("Default_device_qf_tell_balance", params[:device][:qf_tell_balance].to_i, session[:user_id]) 

    #============= PERMITS ===================
    if params[:mask1]
      if !Device.validate_permits_ip([params[:ip1], params[:ip2], params[:ip3], params[:mask1], params[:mask2], params[:mask3]])
        flash[:notice] = _('Allowed_IP_is_not_valid')
        redirect_to :action => 'default_device' and return false
      else
        Confline.set_value("Default_device_permits", Device.validate_perims({:ip1 => params[:ip1], :ip2 => params[:ip2], :ip3 => params[:ip3], :mask1 => params[:mask1], :mask2 => params[:mask2], :mask3 => params[:mask3]}), session[:user_id])
      end
    end


    #------ advanced --------

    if params[:qualify] == "yes"
      Confline.set_value("Default_device_qualify", params[:qualify_time], session[:user_id])
      Confline.set_value("Default_device_qualify", "1000", session[:user_id]) if params[:qualify_time].to_i <= 1000
    else
      Confline.set_value("Default_device_qualify", "no", session[:user_id])
    end
    Confline.set_value("Default_device_use_ani_for_cli", params[:device][:use_ani_for_cli], session[:user_id])
    Confline.set_value("Default_device_encryption", params[:device][:encryption], session[:user_id]) if params[:device][:encryption]
    Confline.set_value("Default_device_block_callerid", params[:device][:block_callerid].to_i, session[:user_id]) 
    #------- Network related -------
    Confline.set_value("Default_device_host", params[:host], session[:user_id])
    Confline.set_value("Default_device_host", "dynamic", session[:user_id]) if params[:dynamic_check] == "1"

    if Confline.get_value("Default_device_host", session[:user_id]) != "dynamic"
      Confline.set_value("Default_device_ipaddr", Confline.get_value("Default_device_host", session[:user_id]), session[:user_id])
    else
      Confline.set_value("Default_device_ipaddr", "", session[:user_id])
    end

    Confline.set_value("Default_device_regseconds", params[:canreinvite], session[:user_id])
    Confline.set_value("Default_device_canreinvite", params[:canreinvite], session[:user_id])

    default_transport = 'udp'
    valid_transport_options = ['tcp', 'udp', 'tcp,udp', 'udp,tcp']
    device_transport = params[:device][:transport].to_s
    transport = (valid_transport_options.include?(device_transport) ? device_transport.to_s : 'udp')
    Confline.set_value("Default_device_transport", transport, session[:user_id])

    #time_limit_per_day can be positive integer or 0 by default                                                                                                        
    #it should be entered as minutes and saved as minutes(cause                                                                                                        
    #later it wil be assigned to device and device will convert to minutes..:/)                                                                                        
    time_limit_per_day = params[:device][:time_limit_per_day].to_i
    time_limit_per_day = (time_limit_per_day < 0 ? 0 : time_limit_per_day)
    Confline.set_value("Default_device_time_limit_per_day", time_limit_per_day, session[:user_id])

    #----------- Codecs ------------------
    if params[:device][:device_type] == 'FAX' and (!params[:codec] or !(params[:codec][:alaw].to_i == 1 or params[:codec][:ulaw].to_i == 1))
      flash[:notice]=_("Fax_device_has_to_have_at_least_one_codec_enabled")
      redirect_to :action => 'default_device' and return false
    end
    if params[:codec]
      for codec in Codec.find(:all)
        if params[:codec][codec.name] == "1"
          Confline.set_value("Default_device_codec_#{codec.name}", 1, session[:user_id])
        else
          #          my_debug "00000"
          #          my_debug params[:codec][codec.name]

          Confline.set_value("Default_device_codec_#{codec.name}", 0, session[:user_id])
        end

      end
    else
      for codec2 in Codec.find(:all)
        Confline.set_value("Default_device_codec_#{codec2.name}", 0, session[:user_id])

      end
    end
    #------Trunks-------
    if params[:trunk].to_i == 0
      Confline.set_value("Default_device_istrunk", 0, session[:user_id])
      Confline.set_value("Default_device_ani", 0, session[:user_id])
    end
    if params[:trunk].to_i == 1
      Confline.set_value("Default_device_istrunk", 1, session[:user_id])
      Confline.set_value("Default_device_ani", 0, session[:user_id])
    end
    if params[:trunk].to_i == 2
      Confline.set_value("Default_device_istrunk", 1, session[:user_id])
      Confline.set_value("Default_device_ani", 1, session[:user_id])
    end


    #------- Groups -------
    Confline.set_value("Default_device_callgroup", params[:callgroup], session[:user_id])
    Confline.set_value("Default_device_callgroup", nil, session[:user_id]) if not params[:callgroup]

    Confline.set_value("Default_device_pickupgroup", params[:pickupgroup], session[:user_id])
    Confline.set_value("Default_device_pickupgroup", nil, session[:user_id]) if not params[:pickupgroup]

    #------- Advanced -------


    Confline.set_value("Default_device_fromuser", params[:fromuser], session[:user_id])
    Confline.set_value("Default_device_fromuser", nil, session[:user_id]) if not params[:fromuser] or params[:fromuser].length < 1

    Confline.set_value("Default_device_fromdomain", params[:fromdomain], session[:user_id])
    Confline.set_value("Default_device_fromdomain", nil, session[:user_id]) if not params[:fromdomain] or params[:fromdomain].length < 1

    Confline.set_value("Default_device_grace_time", params[:grace_time], session[:user_id])

    Confline.set_value("Default_device_insecure", nil, session[:user_id])
    Confline.set_value("Default_device_insecure", "port", session[:user_id]) if params[:insecure_port] == "1" and params[:insecure_invite] != "1"
    Confline.set_value("Default_device_insecure", "port,invite", session[:user_id]) if params[:insecure_port] == "1" and params[:insecure_invite] == "1"
    Confline.set_value("Default_device_insecure", "invite", session[:user_id]) if params[:insecure_port] != "1" and params[:insecure_invite] == "1"
    Confline.set_value("Default_device_calleridpres", params[:device][:calleridpres].to_s, session[:user_id])
    Confline.set_value("Default_device_change_failed_code_to", params[:device][:change_failed_code_to].to_i, session[:user_id])
    Confline.set_value("Default_device_anti_resale_auto_answer", params[:device][:anti_resale_auto_answer].to_i, session[:user_id])

    #recordings
    Confline.set_value("Default_device_record", params[:device][:record].to_i, session[:user_id])
    Confline.set_value("Default_device_recording_to_email", params[:device][:recording_to_email].to_i, session[:user_id])
    Confline.set_value("Default_device_recording_keep", params[:device][:recording_keep].to_i, session[:user_id])
    Confline.set_value("Default_device_record_forced", params[:device][:record_forced].to_i, session[:user_id])
    Confline.set_value("Default_device_recording_email", params[:device][:recording_email].to_s, session[:user_id])

    Confline.set_value("Default_device_process_sipchaninfo", params[:process_sipchaninfo].to_i, session[:user_id])
    Confline.set_value("Default_device_save_call_log", params[:save_call_log].to_i, session[:user_id])
    tim_max = params[:device][:max_timeout].to_i
    Confline.set_value("Default_device_max_timeout", tim_max.to_i < 0 ? 0 : tim_max, session[:user_id])
    # http://trac.kolmisoft.com/trac/ticket/4236
    # Confline.set_value("Default_device_allow_grandstreams", params[:device][:allow_grandstreams].to_i, session[:user_id])

    flash[:status]=_("Settings_Saved")
    redirect_to :action => 'default_device' and return false
  end


  def assign_provider
    device = Device.find(:first, :include => [:provider], :conditions => ["devices.id = ? AND providers.user_id = ?", params[:provdevice], current_user.id])
    if device
      device.description = device.provider.name if device.provider
      device.user_id = params[:id]
      if device.save
        flash[:status] = _('Provider_assigned')
      else
        flash_errors_for(_('Device_not_updated'), device)
      end
    else
      flash[:notice] = _("Provider_Not_Found")
    end
    redirect_to :action => 'show_devices', :id => params[:id]
  end

=begin
 AJAX action.

 Returns list of devices.
 If post contains 'all' then all devices are returned.
 Other way it returns devices for single user.
 Fax devices are skipped.

 *Params*

 Post request with 'all' or id of the user.

 *Return*

 List of devices.
=end
  def get_user_devices
    owner_id = correct_owner_id
    @user = request.raw_post.gsub("=", "")
    if @user == "all"
      @devices = Device.find(:all, :select => "devices.*", :joins => "LEFT JOIN users ON (users.id = devices.user_id)", :conditions => ["users.owner_id = ? AND device_type != 'FAX' AND name not like 'mor_server_%'", owner_id])
    else
      @devices = Device.find(:all, :select => "devices.*", :joins => "LEFT JOIN users ON (users.id = devices.user_id)", :conditions => ["users.owner_id = ? AND device_type != 'FAX' AND user_id = ? AND name not like 'mor_server_%'", owner_id, @user])
    end
    render :layout => false
  end

  def ajax_get_user_devices
    owner_id = correct_owner_id
    @user = params[:user_id] if params[:user_id] != -1
    @default = params[:default].to_i if params[:default]
    params[:fax] ? @fax = params[:fax] : @fax = false
    params[:all] ? @add_all = params[:all] : @add_all = false
    params[:name] ? @add_name = params[:name] : @add_name = false

    cond = ["users.owner_id = ? AND name not like 'mor_server_%'"]
    var = [owner_id]
    cond << "user_id = ?" and var << @user.to_i if @user != 'all' and @user.to_i.to_s == @user
    cond << "device_type != 'FAX'" if @fax == true

    @devices = Device.find(
        :all,
        :select => "devices.*",
        :joins => "LEFT JOIN users ON (users.id = devices.user_id)",
        :conditions => [cond.join(" AND ")].concat(var))
    render :layout => false
  end

=begin
  A bit duplicate but this is the correct one (so far) implementation fo AJAX finder.
=end

  def get_devices_for_search
     options ={}
     options[:include_did] = params[:did_search].to_i
    if params[:user_id] == "all"
      if ["admin", "accountant"].include?(session[:usertype])
        @devices = Device.find_all_for_select(nil, options)
      else
        @devices = Device.find_all_for_select(corrected_user_id, options)
      end
    else
      @user = User.find(params[:user_id])
      if @user and (["admin", "accountant"].include?(session[:usertype]) or @user.owner_id = corrected_user_id)
        @devices = params[:did_search].to_i == 0 ? @user.devices(:conditions => "device_type != 'FAX'")  : @user.devices(:conditions => "device_type != 'FAX'").select('devices.*').joins('JOIN dids ON (dids.device_id = devices.id)').group('devices.id').all
      else
        @devices = []
      end
    end
    render :layout => false
  end

  def devicecodecs_sort
    if params[:id].to_i > 0
      @device = Device.find(:first, :conditions => {:id => params[:id]})
      unless @device
        flash[:notice] = _('Device_was_not_found')
        redirect_back_or_default("/callc/main")
        return false
      end
      if params[:codec_id]
        if params[:val] == 'true'
          pc = Devicecodec.new
          pc.codec_id = params[:codec_id]
          pc.device_id = @device.id
          begin
            pc.save
          rescue
            logger.fatal 'could not save codec, may be unique constraint was violated?'
          end
        else
          pc = Devicecodec.find(:first, :conditions => ['device_id=? AND codec_id=?', params[:id], params[:codec_id]])
          pc.destroy if pc
        end
      end

      params["#{params[:ctype]}_sortable_list".to_sym].each_with_index do |i, index|
        item = Devicecodec.find(:first, :conditions => ['device_id=? AND codec_id=?', params[:id], i])
        if item
          item.priority = index.to_i
          item.save
        end

      end
    else
      params["#{params[:ctype]}_sortable_list".to_sym].each_with_index do |i, index|
        codec = Codec.find(:first, :conditions => ['id=?', i])
        if codec
          val = params[:val] == 'true' ? 1 : 0
          Confline.set_value("Default_device_codec_#{codec.name}", val, session[:user_id]) if params[:val] and params[:codec_id].to_i == codec.id
          Confline.set_value2("Default_device_codec_#{codec.name}", index.to_i, session[:user_id])
        end
      end
    end
    render :layout => false
  end

  def devices_weak_passwords
    @page_title = _('Devices_with_weak_password')

    session[:devices_devices_weak_passwords_options] ? @options = session[:devices_devices_weak_passwords_options] : @options = {}
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page] or @options[:page] <= 0)

    @total_pages = (Device.count(:all, :conditions => "LENGTH(secret) < 8 AND LENGTH(username) > 0 AND device_type != 'H323' AND username NOT LIKE 'mor_server_%'").to_d/session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages.to_i if @total_pages.to_i < @options[:page].to_i and @total_pages > 0
    @devices = Device.find(:all, :conditions => "LENGTH(secret) < 8 AND LENGTH(username) > 0 AND device_type != 'H323' AND username NOT LIKE 'mor_server_%'", :offset => session[:items_per_page]*(@options[:page]-1), :limit => session[:items_per_page])

    session[:devices_devices_weak_passwords_options] = @options
  end

  def insecure_devices
    @page_title = _('Insecure_Devices')
    #@page_icon = "edit.png"
    #@help_link = "http://wiki.kolmisoft.com/index.php/Default_device_settings"
    session[:devices_insecure_devices_options] ? @options = session[:devices_insecure_devices_options] : @options = {}
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page] or @options[:page] <= 0)

    @total_pages = (Device.count(:all, :conditions =>  "host='dynamic' and insecure like '%invite%'  and insecure != 'invite'").to_d/session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages.to_i if @total_pages.to_i < @options[:page].to_i and @total_pages > 0

    @devices = Device.find(:all, :include=>[:user], :conditions => "host='dynamic' and insecure like '%invite%'  and insecure != 'invite'")
    session[:devices_insecure_devices_options] = @options
  end

  private

=begin
  ticket #5014 this logic is more suited to be in controller than in view. 
  About exception - it might occur if device(but not provider's) has no voicemail_box. 
  this would only mean that someone has corruped data. 
=end
  def set_voicemail_variables(device)
    begin
      @device_voicemail_active = device.voicemail_active
      @device_voicemail_box = device.voicemail_box
      @device_voicemail_box_email = @device_voicemail_box.email
      @device_voicemail_box_password = @device_voicemail_box.password
      @fullname = @device_voicemail_box.fullname
      @device_enable_mwi = device.enable_mwi
    rescue NoMethodError
      flash[:notice] = _('Device_voicemail_box_not_found')
      redirect_to :controller => :callc, :action => :main
    end
  end


  def check_reseller_conflines(reseller)
    if !Confline.find(:first, :conditions => "name LIKE 'Default_device_%' AND owner_id = '#{reseller.id}'")
      reseller.create_reseller_conflines
    end
  end

  def create_empty_callflow(device_id, cf_type)
    cf = Callflow.new
    cf.device_id = device_id
    cf.cf_type = cf_type
    cf.priority = 1
    cf.action = "empty"
    cf.save
    cf
  end


=begin rdoc
 Checks if accountant is allowed to create devices.
=end

  def check_for_accountant_create_device
    if session[:usertype] == "accountant" and session[:acc_device_create] != 2
      dont_be_so_smart
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end

=begin rdoc
 Clears values accountant is not allowed to send.
=end
  def sanitize_device_params_by_accountant_permissions
    if session[:usertype] == 'accountant'
      params[:device] = params[:device].except(:pin) if session[:acc_device_pin].to_i != 2 if params[:device]
      params[:device] = params[:device].except(:extension) if session[:acc_device_edit_opt_1] != 2 if params[:device]
      if session[:acc_device_edit_opt_2] != 2 and params[:device]
        params[:device] = params[:device].except(:name)
        params[:device] = params[:device].except(:secret)
      end
      params = params.except(:cid_name) if session[:acc_device_edit_opt_3] != 2 if !params.blank?
      params = params.except(:cid_number) if session[:acc_device_edit_opt_4] != 2 if !params.blank?
    end
    params
  end

  def devices_all_order_by(params, options)
    case params[:order_by].to_s
      when "user"
        order_by = "nice_user"
      when "acc"
        order_by = "devices.id"
      when "description"
        order_by = "devices.description"
      when "pin"
        order_by = "devices.pin"
      when "type"
        order_by = "devices.device_type"
      when "extension"
        order_by = "devices.extension"
      when "username"
        order_by = "devices.name"
      when "secret"
        order_by = "devices.secret"
      when "cid"
        order_by = "devices.callerid"
      else
        default = true
        options[:order_by] ? order_by = options[:order_by] : order_by = "nice_user"
    end

    without = order_by
    options[:order_desc].to_i == 1 ? order_by += " DESC" : order_by += " ASC"
    order_by += ', devices.id ASC ' if !order_by.include?('devices.id')
    return without, order_by, default
  end

  def find_fax_device
    @device = Device.find_by_id_and_device_type(params[:id], "FAX")

    unless @device
      flash[:notice] = _('Device_was_not_found')
      redirect_back_or_default("/callc/main")
    end
  end

  def find_device
    @device = Device.find(:first, :conditions => ['devices.id=?', params[:id]], :include => [:user, :dids])

    unless @device
      flash[:notice] = _('Device_was_not_found')
      redirect_back_or_default("/callc/main")
    end
  end

  def find_email
    @email = Pdffaxemail.find_by_id(params[:id])

    unless @email
      flash[:notice] = _('Email_was_not_found')
      redirect_back_or_default("/callc/main")
    end
  end

  def find_cli
    @cli = Callerid.find(:first, :include => [:device], :conditions => {:id => params[:id]})
    unless @cli
      flash[:notice]=_('Callerid_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    else
      check_cli_owner(@cli)
    end
  end

  def check_cli_owner(cli)
    device = cli.device
    user = device.user if device
    unless user and (user.owner_id == correct_owner_id or user.id == session[:user_id])
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def verify_params
    unless params[:device]
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def check_callback_addon
    unless callback_active?
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def create_cli
    if params[:device_id]
      cli = Callerid.new(:cli => params[:cli], :device_id => params[:device_id], :comment => params[:comment].to_s, :banned => params[:banned].to_i, :added_at => Time.now)
      cli.description = params[:description] if params[:description]
      cli.ivr_id = params[:ivr] if params[:ivr]

      if cli.save
        Callerid.use_for_callback(cli, params[:email_callback])
        flash[:status] = _('CLI_created')
      else
        flash_errors_for(_("CLI_not_created"), cli)
      end
    else
      flash[:notice] = _('Please_select_user')
    end
  end


  def check_with_integrity
    session[:integrity_check] = Device.integrity_recheck_devices if current_user and  current_user.usertype.to_s == 'admin'
  end

end
