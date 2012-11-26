# -*- encoding : utf-8 -*-
class ProvidersController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update, :delete]

  before_filter :check_localization
  before_filter :authorize
  before_filter :providers_enabled_for_reseller?
  before_filter :find_provider, :only => [:hide, :provider_servers, :add_server_to_provider, :show, :edit, :update, :destroy, :provider_rules, :providercodecs_sort, :provider_test,
                                          :provider_rule_change_status, :provider_rule_add, :provider_rule_destroy, :provider_rule_edit, :provider_rule_update, :unassign]
  before_filter :find_providerrule, :only => [:provider_rule_change_status, :provider_rule_destroy, :provider_rule_edit, :provider_rule_update]

  def index
    redirect_to :action => :list and return false
  end

  def list
    @page_title = _('Providers')
    @page_icon = "provider.png"

    session[:providers_list_options] ? @options = session[:providers_list_options] : @options = {}
    # search params parsing. Assign new params if they were sent, default unset params to "" and leave if param is set but not sent
    @options = clear_options(@options) if params[:clear].to_i == 1
    @options[:s_user_id] ||= current_user.id
    params[:s_hidden] = params[:s_hidden].to_i
    [:s_tech, :s_name, :s_hidden].each { |key|
      params[key] ? @options[key] = params[key].to_s : (@options[key] = "" if !@options[key])
    }
    # page number is an exception because it defaults to 1
    if params[:page] and params[:page].to_i > 0
      @options[:page] = params[:page].to_i
    else
      @options[:page] = 1 if !@options[:page] or @options[:page] <= 0
    end
    # same goes for order descending
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"
    order_by = current_user.providers.providers_order_by(@options)

    cond = []
    cond_param = []
    #conditions
    ["name"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "providers.#{col} LIKE ?", cond, cond_param) }
    ["tech", "hidden", "owner_id"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s, "providers.#{col} = ?", cond, cond_param) }

    @total_pages = (current_user.providers.count(:all, :conditions => [cond.join(" AND ")] + cond_param).to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages and @total_pages > 0

    @providers = current_user.providers.find(:all, :conditions => [cond.join(" AND ")] + cond_param, :include => [:tariff], :offset => session[:items_per_page]*(@options[:page]-1), :limit => session[:items_per_page], :order => order_by)

    @provider_used_by_resellers = Provider.find_by_sql("SELECT p.* FROM providers p LEFT JOIN lcrproviders l ON l.provider_id = p.id
     WHERE p.common_use = 1 AND (p.terminator_id IN (SELECT id FROM terminators WHERE user_id !=0) OR l.lcr_id IN (SELECT id FROM lcrs WHERE user_id !=0)) GROUP BY p.id")

    @servers = Server.find(:all)

    @search = 0
    @search = 1 if cond.size.to_i > 1

    sql = "SELECT DISTINCT tech FROM providers WHERE tech != '' ORDER BY tech"
    @provtypes = ActiveRecord::Base.connection.select_all(sql)

    @admin_providers = nil
    @admin_providers = Provider.find(:all, :conditions => "common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id})", :order => order_by) if session[:usertype] == "reseller" and params[:s_hidden].to_i == 0

    @n_class = ''
    session[:providers_list_options] = @options
    session[:back] = params
    store_location
  end

  # in before filter : provider (find_provider)
  def hide
    if @provider.hidden == 1
      @provider.hidden = 0
      @provider.save
      flash[:status] = _('Provider_unhidden')

    else
      @provider.hidden = 1
      @provider.save
      flash[:status] = _('Provider_hidden')

    end
    redirect_to :action => 'list', :s_hidden => @provider.hidden.to_i
  end

  # in before filter : provider (find_provider)
  def provider_servers
    @page_title = _('Provider_servers')
    @page_icon = "server.png"
    @servers = Server.find(:all)
  end

  # in before filter : provider (find_provider)
  def delete
    server = Server.find(params[:id])
    serverprovider=Serverprovider.find(:all, :conditions => ["provider_id=? and server_id=?", @provider.id, server.server_id])
    for providers in serverprovider
      providers.destroy
    end
    flash[:status] = _('Server_deleted')
    redirect_to :action => 'provider_servers', :id => @provider.id
  end

  # in before filter : provider (find_provider)
  def add_server_to_provider
    @server=Server.find(params[:server_add])
    serv_prov = Serverprovider.find(:first, :conditions => ["server_id=? AND provider_id=?", @server.server_id, @provider.id])

    if not serv_prov
      serverprovider=Serverprovider.new
      serverprovider.server_id = @server.server_id
      serverprovider.provider_id =@provider.id
      serverprovider.save

      flash[:status] = _('Server_added')
      redirect_to :action => 'provider_servers', :id => @provider.id

    else
      flash[:notice] = _('Server_already_exists')
      redirect_to :action => 'provider_servers', :id => @provider.id
    end
  end

  # in before filter : provider (find_provider)
  def show
  end

  def new
    @page_title = _('New_provider')
    @page_icon = "add.png"

    if current_user.usertype == 'reseller' and Confline.get_value('Create_own_providers', current_user.id).to_i != 1
      dont_be_so_smart
      redirect_to :action => :list and return false
    end

    @provider = Provider.new
    @provider.tech = "SIP"
    @providertypes = Providertype.find(:all)
    @tariffs = Tariff.find(:all, :conditions => ["purpose = 'provider' AND owner_id = ?", session[:user_id]])
    @locations = current_user.locations
    @servers= Server.find(:all, :order => "server_id")
    @serverproviders = []
    @provider.serverproviders.each { |p| @serverproviders[p.server_id] = 1 }

    unless @servers.size > 0
      flash[:notice] = _('No_servers_available')
      redirect_to :action => :list and return false
    end

    @action = "new"

    if @tariffs.size == 0
      flash[:notice] = _('No_tariffs_available')
      redirect_to :action => 'list'
    end

    @new_provider = true
  end


  def create
    params[:provider][:name]=params[:provider][:name].strip

    if current_user.usertype == 'reseller' and Confline.get_value('Create_own_providers', current_user.id).to_i != 1
      dont_be_so_smart
      redirect_to :action => :list and return false
    end

    @provider = Provider.new(params[:provider])
    @provider.user_id = session[:user_id]
    @provider.server_ip = "0.0.0.0"
    @provider.login = @provider.name.strip
    @provider.password = "please_change"

    @provider.port = "4569" if @provider.tech == "IAX2"
    @provider.port = "5060" if @provider.tech == "SIP"
    @provider.port = "1720" if @provider.tech == "H323"

    @provider.add_a = ""
    @provider.add_b = ""
    @provider.cut_a = 0
    @provider.cut_b = 0

    # Dirty not proper hack.
    @provider.channel = "" if !@provider.channel
    #    params[:server_add] = 1 if session[:usertype] == "reseller"
    #    @server = Server.find(:first, :conditions => ["id = ?", params[:server_add]])
    #    unless @server
    #      flash[:notice] = _('No_servers_available')
    #      redirect_to :action => :list and return false
    #    end

    params[:add_to_servers] = {'1' => '1'} if session[:usertype] == "reseller"

    if !params[:add_to_servers] or params[:add_to_servers].size.to_i == 0
      flash[:notice] = _('Please_select_server')
      redirect_to :action => 'new' and return false
    end

    if @provider.save

      #======= creating device for IAX2 and SIP provaiders ==========
      #if (@provider.tech == "IAX2" or @provider.tech == "SIP")
      #prov_name = @provider.name.strip#.downcase.gsub(/\s/, '') -- atrodo nereikalingas
      dev = Device.new
      dev.device_ip_authentication_record = params[:ip_authentication].to_i
      if params[:ip_authentication].to_s == "1"
        if !dev.name.include?('ipauth')
          name = dev.generate_rand_name('ipauth', 8)
          while Device.find(:first, :conditions => ['name= ? and id != ?', name, dev.id])
            name = dev.generate_rand_name('ipauth', 8)
          end
          dev.name = name
        end
      else
        dev.name = "prov_" + @provider.id.to_s #tmp
      end
      dev.host = "0.0.0.0"
      dev.ipaddr = "0.0.0.0"
      dev.secret = @provider.password.strip
      dev.context = Default_Context
      dev.callerid = "" #coming from provider
      dev.extension = random_password(10) #should be not-quesable
      dev.username = dev.name.strip
      dev.trustrpid = 'yes'
      dev.insecure = "port,invite"
      dev.device_type = @provider.tech.strip
      dev.user_id = -1 #means it's not ordinary user
                        #temp until taken from provider's table
      dev.istrunk = 1   #mark as trunk by default when call will be send to this provider, to send Destination info to it also
      dev.port = @provider.port.strip
      dev.works_not_logged = 1
      dev.nat = "no"
                        #temp
      if not dev.save
        @provider.destroy
        flash_errors_for(_('Provider_was_not_created'), dev)
        redirect_to :action => 'new' and return false
      end

      dev.accountcode = dev.id
                        #dev.name = "prov" + dev.id.to_s
      dev.save

      @provider.device_id = dev.id
      @provider.save

      @provider.create_serverproviders(params[:add_to_servers])
                        #end
                        #==============================================================

      flash[:status] = _('Provider_was_successfully_created')
      redirect_to :action => 'edit', :id => @provider.id
    else
      flash_errors_for(_('Provider_was_not_created'), @provider)
      redirect_to :action => 'new' and return false
    end
  end

  # in before filter : provider (find_provider)
  def edit
    @page_title = _('Provider_edit') + ": " + @provider.name
    @page_icon = "edit.png"
    @servers= Server.find(:all, :conditions => "server_type = 'asterisk'", :order => "server_id")
    @prules = @provider.providerrules

    @providertypes = Providertype.find(:all)
    @curr = current_user.currency

    if @provider.tech == "Skype"
      @audio_codecs = @provider.codecs_order('audio', {:skype => true})
    else
      @audio_codecs = @provider.codecs_order('audio')
    end

    @video_codecs = @provider.codecs_order('video')

    @tariffs = Tariff.find(:all, :conditions => ["purpose = 'provider' AND owner_id = ?", session[:user_id]])

    @locations = current_user.locations

    @serverproviders = []
    @provider.serverproviders.each { |p| @serverproviders[p.server_id] = 1 }

    @is_common_use_used = false
    provider_used_by_resellers_terminator = Provider.find(:all, :conditions => ["id = ? AND common_use = 1 and terminator_id IN (select id from terminators where user_id != 0)", @provider.id])
    provider_used_by_resellers_lcr = Lcrprovider.find(:all, :conditions => ["(provider_id = ? and lcr_id IN (select id from lcrs where user_id != 0))", @provider.id])
    if provider_used_by_resellers_terminator.size > 0 or provider_used_by_resellers_lcr.size > 0
      @is_common_use_used = true
    end

    @device = @provider.device
    if @device
      @cid_name = ""
      if @device.callerid
        @cid_name = nice_cid(@device.callerid)
        @cid_number = cid_number(@device.callerid)
      end

      if @device.qualify == "yes" or @device.qualify == "no"
        @qualify_time = 2000
      else
        @qualify_time = @device.qualify
      end
    else
      flash[:notice] = _('Providers_device_not_found')
      redirect_to :action => 'list' and return false #, :id => @provider.id and return false
    end

    #------ permits --------

    @ip1 = ""
    @mask1 = ""
    @ip2 = ""
    @mask2 = ""
    @ip3 = ""
    @mask3 = ""

    if @provider.device
      data = @provider.device.permit.split(';')
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
    end

    render :action => 'edit_h323' if @provider.tech == "H323"
    render :action => 'edit_skype' if @provider.tech == "Skype"

  end

  def update
    params[:provider][:name]=params[:provider][:name].to_s.strip
    params[:provider][:timeout]= params[:provider][:timeout].to_s.strip
    params[:provider][:max_timeout]= params[:provider][:max_timeout].to_s.strip

    #5618#comment:13 if timeout value is invalid(its not positive integer) we discard that value 
    params[:provider].delete(:timeout) if params[:provider][:timeout] !~ /^[0-9]+$/
    params[:provider].delete(:max_timeout) if params[:provider][:max_timeout] !~ /^[0-9]+$/

    params[:provider][:reg_extension] ||= ""
    params[:provider][:reg_line] ||= ""

    params[:provider][:call_limit] = 0 if params[:provider][:call_limit] and params[:provider][:call_limit].to_i < 0

    @provider.set_old

    unless @provider.is_dahdi?
      params[:provider][:login]= params[:provider][:login].strip if params[:provider][:login]
      params[:provider][:password]= params[:provider][:password].strip if params[:provider][:password]
      params[:provider][:server_ip]= params[:provider][:server_ip].strip if params[:provider][:server_ip]
      params[:provider][:port]= params[:provider][:port].strip if params[:provider][:port]
      params[:cid_number]= params[:cid_number].strip if params[:cid_number]
      params[:cid_name]=params[:cid_name].strip if params[:cid_name]
      params[:fromdomain]=params[:fromdomain].strip if params[:fromdomain]
      params[:fromuser]=params[:fromuser].strip if params[:fromuser]
    else
      params[:provider][:channel]= params[:provider][:channel].strip if params[:provider][:channel]
    end
    params[:provider][:hidden] = (params[:provider][:hidden] == '1' ? 1 : 0)
    @provider.attributes = params[:provider]
    @provider.network(params[:hostname_ip].to_s, params[:provider][:server_ip].to_s.strip, params[:device][:ipaddr].to_s.strip, params[:provider][:port].to_s.strip)
    unless @provider.valid?
      flash_errors_for(_('Providers_was_not_saved'), @provider)
      redirect_to :action => 'edit', :id => @provider.id and return false
    end

    if (params[:hostname_ip] == 'hostname' and params[:provider][:server_ip].blank?) or (params[:hostname_ip] == 'ip' and (params[:provider][:server_ip].blank? or params[:device][:ipaddr].blank?))
      @hostname_ip = "ip"
      flash[:notice] = _('Hostname/IP_is_blank')
      redirect_to :action => 'edit', :id => @provider.id and return false
    end

    params[:add_to_servers] = {'1' => '1'} if session[:usertype] == "reseller"
    if !params[:add_to_servers] or params[:add_to_servers].size.to_i == 0
      flash[:notice] = _('Please_select_server')
      redirect_to :action => 'edit', :id => @provider.id and return false
    end
    #========= codecs =======

    @provider.update_codecs_with_priority(params[:codec]) if params[:codec]

    @device = @provider.device
    @device.set_old_name
    @device.device_ip_authentication_record = params[:ip_authentication].to_i
    #logger.info @device.device_ip_authentication_record
    @device.update_cid(params[:cid_name], params[:cid_number])
    @device.attributes = params[:device]

    if params[:mask1]
      if !Device.validate_permits_ip([params[:ip1], params[:ip2], params[:ip3], params[:mask1], params[:mask2], params[:mask3]])
        flash[:notice] = _('Allowed_IP_is_not_valid')
        redirect_to :action => 'device_edit', :id => @provider.id and return false
      else
        @device.permit = Device.validate_perims({:ip1 => params[:ip1], :ip2 => params[:ip2], :ip3 => params[:ip3], :mask1 => params[:mask1], :mask2 => params[:mask2], :mask3 => params[:mask3]})
      end
    end

    #my_debug permits
    #------ advanced --------
    if params[:qualify] == "yes"
      @device.qualify = params[:qualify_time].strip
      @device.qualify = "1000" if @device.qualify.to_i <= 1000
    else
      @device.qualify = "no"
    end

    params[:canreinvite] = @device.canreinvite if not params[:canreinvite]
    @device.canreinvite = params[:canreinvite].strip
    @device.transfer = params[:canreinvite].strip

    @device.fromuser = params[:fromuser]
    @device.fromuser = nil if not params[:fromuser] or params[:fromuser].length < 1

    @device.fromdomain = params[:fromdomain]
    @device.fromdomain = nil if not params[:fromdomain] or params[:fromdomain].length < 1

    @device.authuser = params[:authuser].blank? ? "" : params[:authuser]
    @device.grace_time = params[:grace_time]

    @device.insecure = nil
    @device.insecure = "port" if params[:insecure_port] == "1" and params[:insecure_invite] != "1"
    @device.insecure = "port,invite" if params[:insecure_port] == "1" and params[:insecure_invite] == "1"
    @device.insecure = "invite" if params[:insecure_port] != "1" and params[:insecure_invite] == "1"

    @device.fullcontact = ""

    params[:register].to_s == "1" ? @provider.register = 1 : @provider.register = 0

    if params[:ip_authentication].to_i == 1

      @provider.login = ""
      @provider.password = ""
      @device.username = ""
      @device.secret = ""
      if !@device.name.include?('ipauth')
        name = @device.generate_rand_name('ipauth', 8)
        while Device.find(:first, :conditions => ['name= ? and id != ?', name, @device.id])
          name = @device.generate_rand_name('ipauth', 8)
        end
        @device.name = name
      else
        @device.name = "prov" + @device.id.to_s
      end
    else
#      #ticket 5055. ip auth or dynamic host must checked
#      if params[:hostname_ip].to_i != 'dynamic' and ['SIP', 'IAX2'].include?(@device.device_type)
#        flash[:notice] = _("Must_set_either_ip_auth_either_dynamic_host")
#        redirect_to :action => :edit, :id => @provider.id and return false
#      end 
      @device.name = "prov" + @device.id.to_s
      @device.username = @provider.login.strip
      @device.secret = (@provider.password).strip
    end
    #------- Network related -------
    @provider.network(params[:hostname_ip].to_s, params[:provider][:server_ip].to_s.strip, params[:device][:ipaddr].to_s.strip, params[:provider][:port].to_s.strip)

    if params[:save_call_log].to_s == "1"
      @device.save_call_log = 1
    else
      @device.save_call_log = 0
    end

    if not @provider.device.save
      flash_errors_for(_('Providers_settings_bad'), @provider.device)
      redirect_to :action => :edit, :id => @provider.id and return false
    end

    @provider.create_serverproviders(params[:add_to_servers])

    if @provider.save
      session[:flash_not_redirect] = 0
      # update asterisk configuration
      if @provider.tech == "SIP" or @provider.tech == "IAX2"
        #        if @provider.change_register_params?
        exceptions = @provider.reload
        #else
        exceptions = @device.prune_device_in_all_servers
        #end
        raise exceptions[0] if exceptions.size > 0
      end

      if @provider.tech == "H323"
        exceptions = @provider.h323_reload
        raise exceptions[0] if exceptions.size > 0
      end

      if @provider.tech == "Skype"
        exceptions = @provider.skype_reload
        raise exceptions[0] if exceptions.size > 0
      end


      flash[:status] = _('Provider_was_successfully_updated')
      redirect_to :action => 'list', :id => @provider, :s_hidden => @provider.hidden.to_i and return false
    else
      flash_errors_for(_('Providers_was_not_saved'), @provider)
      redirect_to :action => 'edit', :id => @provider.id and return false
    end
  end

  # in before filter : provider (find_provider)
  def unassign
    #unassigns provider from user based on what provider id was passed as id
    #-
    #if everything went well
    #1) if no return action and return contoller was passed
    #1.1) return back to where session[:return_to] points
    #1.2) go to callc main if session[:return_to] is not defined
    #2) else go to controller and action
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    device = @provider.device
    if device

      device.user_id = -1
      if device.save
        flash[:status] = _('Provider_unassigned')
      else
        flash[:notice] = _('Provider_not_updated')
      end

      if defined? @return_action and defined? @return_controller
        redirect_to :controller => @return_controller, :action => @return_action and return false
      else
        redirect_back_or_default
      end

    else
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

  end

  # in before filter : provider (find_provider)
  def destroy
    device = @provider.device
    if device
      if @provider.tech == "SIP" or @provider.tech == "IAX2"
        exceptions = device.prune_device_in_all_servers
        raise exceptions[0] if exceptions.size > 0
      end
      if @provider.tech == "H323"
        exceptions = @provider.h323_reload
        raise exceptions[0] if exceptions.size > 0
      end

      if @provider.tech == "Skype"
        exceptions = @provider.skype_reload
        raise exceptions[0] if exceptions.size > 0
      end


    end

    if @provider.destroy
      flash[:status] = _('Provider_deleted')
    else
      flash_errors_for(_('Provider_not_deleted'), @provider)
    end
    redirect_to :action => 'list'
  end


  #------------ Provider rules --------------
  # in before filter : provider (find_provider)
  def provider_rules
    @page_title = _('Provider_rules')
    @page_icon = 'page_white_gear.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Provider_Rules"
    @rules = @provider.providerrules
    @rules_dst = Providerrule.find(:all, :conditions => ["provider_id = ? and pr_type = ?", @provider.id, "dst"])
    @rules_src = Providerrule.find(:all, :conditions => ["provider_id = ? and pr_type = ?", @provider.id, "src"])
  end

  # in before filter @provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_change_status

    if @providerrule.enabled == 0
      @providerrule.enabled = 1
      flash[:status] = _('Rule_enabled')
    else
      @providerrule.enabled = 0
      flash[:status] = _('Rule_disabled')
    end
    @providerrule.save
    redirect_to :action => 'provider_rules', :id => @provider.id
  end

  # in before filter : provider (find_provider)
  def provider_rule_add
    if params[:name].blank? or (params[:cut].blank? and params[:add].blank?)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to :action => 'provider_rules', :id => params[:id] and return false
    end

    rule = Providerrule.new({
                                :provider_id => @provider.id,
                                :name => params[:name].strip,
                                :enabled => 1,
                                :pr_type => params[:pr_type].strip
                            })
    rule.cut = params[:cut].strip if params[:cut]
    rule.add = params[:add].strip if params[:add]
    rule.minlen = params[:minlen].strip if params[:minlen].length > 0
    rule.maxlen = params[:maxlen].strip if params[:maxlen].length > 0
    if rule.save
      flash[:status] = _('Rule_added')
    else
      if rule.cut == rule.add
        flash[:notice] = _('Add_Failed')+" : "+_('Cut_Equals_Add')
      else
        flash[:notice] = _('Add_Failed')
      end
    end
    redirect_to :action => 'provider_rules', :id => @provider.id
  end

  # in before filter : provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_destroy
    @providerrule.destroy
    flash[:status] = _('Rule_deleted')
    redirect_to :action => 'provider_rules', :id => @provider.id
  end

  # in before filter : provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_edit
    @page_title = _('Provider_rule_edit')
    @page_icon = 'edit.png'
  end

  # in before filter : provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_update
    if params[:name].length == 0 or (params[:cut].length == 0 and params[:add].length ==0)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to :action => 'provider_rule_edit', :id => params[:id], :providerrule_id => params[:providerrule_id] and return false
    end

    @providerrule.name = params[:name].strip
    @providerrule.cut = params[:cut].strip if params[:cut]
    @providerrule.add = params[:add].strip if params[:add]
    @providerrule.minlen = params[:minlen].strip if params[:minlen].length > 0
    @providerrule.maxlen = params[:maxlen].strip if params[:maxlen].length > 0
    if @providerrule.save
      flash[:status] = _('Rule_updated')
    else
      flash[:notice] = _('Update_Failed')
    end
    redirect_to :action => 'provider_rules', :id => @provider.id

  end

  #---------------------- new provider logic -----------------

  # this action is not used, because Provider is "created" by marking user as Provider
  def provider_new
    @page_title = _('New_provider')
    @page_icon = "add.png"
    @provider = Provider.new
    @provider.tech = ""
    @tariffs = Tariff.find(:all, :conditions => ["purpose = 'provider' AND owner_id = ?", session[:user_id]])
    @servers= Server.find(:all, :order => "server_id")

    if not @tariffs
      flash[:notice] = _('No_tariffs_available')
      redirect_to :action => 'list'
    end

  end

  def provider_create

    if params[:provider][:name].to_s == ""
      flash[:notice] = _('Please_enter_name')
      redirect_to :action => 'list' and return false
    end

    provider = Provider.new
    provider.name = params[:provider][:name].strip

    provider.tariff_id = params[:tariff_id]
    provider.call_limit = params[:provider][:call_limit].to_i

    provider.tech = ""
    provider.server_ip = ""
    provider.login = ""
    provider.password = ""
    provider.port = ""
    provider.priority = 100
    provider.user = current_user

    provider.save

    # server
    sp = Serverprovider.find(:first, :conditions => "server_id = #{server.server_id.to_i} AND provider_id = #{provider.id.to_i}")
    if not sp
      serverprovider=Serverprovider.new
      serverprovider.server_id = server.server_id
      serverprovider.provider_id = provider.id
      serverprovider.save
    end

    flash[:status] = _('Provider_created')
    redirect_to :action => 'list'

  end

  # in before filter : provider (find_provider)
  def providercodecs_sort
    if params[:codec_id]
      if params[:val] == 'true'
        pc = Providercodec.new({:codec_id => params[:codec_id], :provider_id => @provider.id})
        pc.save if pc
      else
        pc = Providercodec.find(:first, :conditions => ['provider_id=? AND codec_id=?', params[:id], params[:codec_id]])
        pc.destroy if pc
      end
    end

    params["#{params[:ctype]}_sortable_list".to_sym].each_with_index do |i, index|
      item = Providercodec.find(:first, :conditions => ['provider_id=? AND codec_id=?', params[:id], i])
      if item
        item.priority = index.to_i
        item.save
      end

    end
    @provider.update_device_codecs
    render :layout => false
  end

  def billing
    unless provider_billing_active?
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

    @page_title = _('Providers')
    @page_icon = "provider.png"
    @curr = current_user.currency
    session[:providers_billing_options] ? @options = session[:providers_billing_options] : @options = {}
    @options = clear_options(@options) if params[:clear].to_i == 1
    @options[:s_user_id] ||= current_user.id
    params[:s_hidden] = params[:s_hidden].to_i
    [:s_tech, :s_name, :s_hidden].each { |key|
      params[key] ? @options[key] = params[key].to_s : (@options[key] = "" if !@options[key])
    }
    # page number is an exception because it defaults to 1
    if params[:page] and params[:page].to_i > 0
      @options[:page] = params[:page].to_i
    else
      @options[:page] = 1 if !@options[:page] or @options[:page] <= 0
    end
    # same goes for order descending
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"
    order_by = current_user.providers.providers_order_by(@options)

    cond = []
    cond_param = []
    #conditions
    ["name"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "providers.#{col} LIKE ?", cond, cond_param) }
    ["tech", "hidden", "owner_id"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s, "providers.#{col} = ?", cond, cond_param) }

    @total_pages = (current_user.providers.count(:all, :conditions => [cond.join(" AND ")] + cond_param).to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages and @total_pages > 0

    @providers = current_user.providers.find(:all, :conditions => [cond.join(" AND ")] + cond_param, :include => [:tariff], :offset => session[:items_per_page]*(@options[:page]-1), :limit => session[:items_per_page], :order => order_by)

    @n_class = ''
    session[:providers_list_options] = @options
    session[:back] = params
    store_location
  end

  # in before filter : provider (find_provider)
  def provider_test
    @success = 0
    if @provider
      if @provider.server_ip != "dynamic"
        if @provider.tech == "SIP"
          if test_sip_conectivity(@provider.server_ip.to_s, @provider.port.to_s)
            @message = _('Connection_successful')
            @success = 1
          else
            @message = _('Connection_failed')
          end
        else
          @message = _("Can_only_test_SIP_providers")
        end
      else
        @message = _("Cannot_test_dynamic_IP")
      end
    else
      @message = _("Provider_not_found")
    end
    render(:layout => "layouts/mor_min")
  end

end