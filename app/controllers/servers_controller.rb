class ServersController < ApplicationController

  layout "callc"

  before_filter :check_localization
  before_filter :authorize
  before_filter :find_server, :only=>[:server_providers, :add_provider_to_server, :show, :edit, :destroy, :server_change_status, :server_change_gateway_status, :server_test, :server_update ]
  before_filter :check_server_ip , :only=>[:server_update]

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)  
  verify :method => :post, "flash" => "note", :only => [ :destroy, :create, :update,  :server_add, :server_update, :delete],#, :server_change_gateway_status, :server_change_status
  :redirect_to => { :action => :list},
    :add_flash => { :notice => _('Dont_be_so_smart'),
    :params => {:dont_be_so_smart => true}}
  
  def index
    if session[:usertype] != "admin"
      dont_be_so_smart
      redirect_to :controller=>"callc", :action=>"main" and return false
    else
      list
      render :action => 'list'
    end

  end

  def list
    @page_title = _('Asterisk_Servers')
    @page_icon = 'server.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Multi_Server_support"
    @servers =  Server.find(:all, :order=>"id")
  end

  def server_providers
    @page_title = _('Server_providers')
    @page_icon = 'provider.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Multi_Server_support"

    @providers = Provider.find(:all, :conditions=>['hidden=?',0])
    serv_prov = Serverprovider.find(:all, :conditions=>["server_id=?", @server.server_id])
    @new_prv = []
    for prv in @providers
      if not Serverprovider.find(:first, :conditions=>["server_id=? AND provider_id=?", @server.server_id, prv.id])
        @new_prv << prv
      end
      @providers = @new_prv
    end
    session[:back] = params
  end

  def add_provider_to_server
    @provider = Provider.find_by_id(params[:provider_add])
    unless @provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :action => 'list' and return false
    end
    serv_prov = Serverprovider.find(:first, :conditions=>["server_id=? AND provider_id=?", @server.server_id, @provider.id])

    if not serv_prov
      serverprovider=Serverprovider.new
      serverprovider.server_id = @server.server_id
      serverprovider.provider_id =@provider.id
      serverprovider.save

      if @provider.register == 1
        @provider.servers.each{|server| server.reload }
      end
      flash[:status] = _('Provider_added')
    else
      flash[:notice] = _('Provider_allready_exists')
    end
    redirect_to :action => 'server_providers' , :id=>@server.id and return false
  end



  def show
  end

  def new
    @page_title = _('Server_new')
    @page_icon = "add.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Multi_Server_support"
    @server = Server.new
  end

  def edit
    @page_title = _('Server_edit')
    @page_icon = 'edit.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Multi_Server_support"
  end

  def server_add
    @servers = Server.find(:all)
    server = Server.new
    server.server_id = params[:server_id].strip
    server.hostname = params[:server_hostname].strip
    server.server_ip = params[:server_ip].strip
    server.stats_url = params[:server_url].strip
    server.comment = params[:server_comment].strip
    server.server_type = params[:server_type].strip
    server.active = 1
    server.ami_username = params[:server_ami_username].strip
    server.ami_secret = params[:server_ami_secret].strip
    server.port = params[:port].strip

    maxcalls = 1000
    maxcalls = params[:server_maxcalllimit].to_i if params[:server_maxcalllimit] and params[:server_maxcalllimit].length > 0


    if maxcalls <= 2
      server.maxcalllimit = 2
    else
      server.maxcalllimit = maxcalls
    end

    max = 0
    for serv in @servers
      if max < serv.server_id.to_i
        max = serv.server_id.to_i
      end
    end

    if server.server_id.to_i == 0
      server.server_id = 1
    end


    for serv in @servers
      if server.server_id.to_i == serv.server_id.to_i
        server.server_id = max +1
      end
    end

    if server.save
      unless server.server_device
        server.create_server_device
      end
      flash[:status] = _('Server_created')
    else
      flash_errors_for(_('Server_not_created'), server)
    end
   
    redirect_to :action => 'list'
  end


  def server_update
    @servers = Server.find(:all)
    server_old = @server.clone

    @server_providers = Serverprovider.find(:all, :conditions=>["server_id=?", @server.server_id])

    @server.hostname = params[:server_hostname].strip
    @server.server_ip = params[:server_ip].strip
    @server.stats_url = params[:server_url].strip
    @server.comment = params[:server_comment].strip
    @server.server_type = params[:server_type].strip

    @server.ami_username = params[:server_ami_username].strip
    @server.ami_secret = params[:server_ami_secret].strip
    @server.port = params[:server_port].strip

    @server.ssh_username = params[:server_ssh_username].strip
    @server.ssh_secret = params[:server_ssh_secret].strip
    @server.ssh_port = params[:server_ssh_port].strip

    if @server.server_id.to_i != params[:server_id].to_i
      dev = @server.server_device
      @server.server_id = params[:server_id].strip
      if dev
        dev.destroy
      end

      max = 0
      for serv in @servers
        if max < serv.server_id.to_i
          max = serv.server_id.to_i
        end
      end
      
      @server.server_id = max + 1 if @server.server_id.to_i == 0

      for serv in @servers
        if @server.server_id.to_i == serv.server_id.to_i
          @server.server_id = max +1
        end
      end

      for ser_prov in  @server_providers
        ser_prov.server_id =  @server.server_id
        ser_prov.save
      end
    end

    @server.maxcalllimit = (params[:server_maxcalllimit].to_i <= 2 ? 2 : params[:server_maxcalllimit])
    if @server.server_id != server_old.server_id
      Device.update_all(["server_id = ?",@server.server_id], ["server_id = ? AND username NOT LIKE 'mor_server_%'", server_old.server_id])
    end
    
    if @server.save
      #update device
      dev = @server.server_device
      if dev
        #my_debug(dev)
        #dev.name = "mor_server_" +  server.id.to_s
        dev.host = @server.hostname
        #dev.secret = random_password(10)
        #dev.context = "mor_direct"
        dev.ipaddr = @server.server_ip
        #dev.port = 5060 #make dynamic later
        dev.port = @server.port
        #dev.extension = dev.name
        #dev.username = dev.name
        #dev.user_id = 0
        #dev.allow = "alow"
        #dev.nat = "no"
        #dev.canreinvite = "no"
        dev.save
      end
      flash[:status] = _('Server_update')
    else
      flash[:notice] = _('Server_not_updated')
    end
    
    redirect_to :action => 'list'
  end



  def delete
    provider = Provider.find_by_id(params[:id])
    unless provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :action => 'list' and return false
    end
    server = Server.find_by_id(params[:sid])
    unless server
      flash[:notice] = _('Server_not_found')
      redirect_to :action => 'list' and return false
    end

    serverprovider=Serverprovider.find(:all, :conditions=>["provider_id=? and server_id=?",provider.id,server.server_id])

    for providers in serverprovider
      providers.destroy
    end
    flash[:status] = _('Providers_deleted')
    redirect_to :action => 'server_providers', :id=>server.id

  end

  def destroy
    if @server.destroy
      dev = Device.find(:first, :conditions => "name = 'mor_server_#{@server.server_id.to_s}'")
      dev.destroy if dev
      serverprovider=Serverprovider.find(:all, :conditions=>["server_id=?",@server.server_id])
      for providers in serverprovider
        providers.destroy
      end
      flash[:status] = _('Server_deleted')
    else
      flash_errors_for(_("Server_Not_Deleted"), @server)
    end
    redirect_to :action => 'list'
  end



  def server_change_status
    if @server.active == 1
      value = 0
      flash[:notice] = _('Server_disabled')
    else
      value = 1
      flash[:status] = _('Server_enabled')
    end
    sql = "UPDATE servers SET active = #{value} WHERE id = #{@server.id}"
    res = ActiveRecord::Base.connection.update(sql)
    redirect_to :action => 'list', :id => @server.id
  end


  def server_change_gateway_status
    if @server.gateway_active == 1
      @server.gateway.destroy
      value = 0
      flash[:notice] = _('Server_marked_as_not_gateway')
    else
      gtw = Gateway.new({:setid => 1, :destination => "sip:#{@server.server_ip}:#{@server.port}", :server_id => @server.id})
      gtw.save
      value = 1
      flash[:status] = _('Server_marked_as_gateway')
    end
    sql = "UPDATE servers SET gateway_active = #{value} WHERE id = #{@server.id}"
    res = ActiveRecord::Base.connection.update(sql)
    redirect_to :action => 'list', :id => @server.id
  end

  def server_test
    @help_link = "http://wiki.kolmisoft.com/index.php/Multi_Server_support"
    session[:flash_not_redirect] = 1
    session[:server_test_ok] = 0
    begin
      @server.reload(0)
    rescue Exception
      flash_help_link = "http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit"
      flash[:notice] = _('Cannot_connect_to_asterisk_server')
      flash[:notice] += "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>" if flash_help_link
      session[:server_test_ok] = 0
    else
      session[:server_test_ok] = 1
    end
    render(:layout => "layouts/mor_min")
  end
  
  private
  
  def find_server
    @server = Server.find(:first, :conditions => ["id = ?", params[:id]])
    unless @server
      flash[:notice] = _('Server_not_found')
      redirect_to :action => :list and return false
    end
  end

  def check_server_ip
    if params[:server_id] and Server.find(:first, :conditions=>["id != ? AND server_id = ?", params[:id],params[:server_id]])
      flash[:notice] = _('Server_ID_collision')
      redirect_to :action => :list and return false
    end
  end

end