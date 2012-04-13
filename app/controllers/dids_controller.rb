# -*- encoding : utf-8 -*-
class DidsController < ApplicationController
  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  #before_filter :authorize_admin, :except => [:quickforwarddids, :quickforwarddid_edit, :quickforwarddid_update, :quickforwarddid_destroy]
  before_filter :authorize

  before_filter :check_user_for_dids, :except => [:personal_dids, :quickforwarddids, :quickforwarddid_edit, :quickforwarddid_update, :quickforwarddid_destroy]
  before_filter { |c|
    view = [:index, :list, :show, :did_rates, :dids_export_to_csv]
    edit = [:new, :create, :edit, :update, :destroy, :edit_rate, :bulk_management, :confirm_did, :assign_to_dp]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_manage_dids_opt_1, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :check_device_presence, :only => [:update]
  before_filter :find_dids, :only => [:dids_interval_edit, :dids_interval_trunk, :dids_interval_add_to_trunk, :dids_interval_rates, :dids_interval_add_to_user, :dids_interval_delete, :delete, :dids_interval_assign_dialplan]
  before_filter :find_provider, :only => [:create]
  before_filter :check_dids_creation, :only => [:new, :create, :confirm_did]
  before_filter :check_did_params, :only => [:update]

  def index
    list
    render :action => 'list'
  end

=begin
  if language was not passed as search parameter, set it to default value 'all'.
  keep in mind we should refactor, cause 'all' is duplicated in controler and view.
=end
  def list
    @page_title = _('DIDs')
    @page_icon = "did.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/MOR_Manual#DIDs"
    @iwantto_links = [
        ['Learn_more_about_DIDs', "http://wiki.kolmisoft.com/index.php/MOR_Manual#DIDs"],
        ['Understand_DID_billing', "http://wiki.kolmisoft.com/index.php/DID_Billing"],
        ['Check_DIDs_assigned_to_me', "http://wiki.kolmisoft.com/index.php/Personal_DIDs"],
        ['Configure_DID_to_ring_some_Device', "http://wiki.kolmisoft.com/index.php/Personal_DIDs"],
        ['Forward_DID_to_external_number', "http://wiki.kolmisoft.com/index.php/Forward_DID_to_External_Number"],
        ['Charge_DID_on_a_monthly_basis', 'http://wiki.kolmisoft.com/index.php/How_to_charge_DID_on_a_monthly_basis'],
        ['Block_DID', "http://wiki.kolmisoft.com/index.php/DID_Blocking"]]
    unless current_user.usertype == 'reseller'
      @providers = current_user.load_providers(:all, {})
    end

    sql = "SELECT DISTINCT language FROM dids ORDER by language"
    @languages = ActiveRecord::Base.connection.select_all(sql)

    #seach

    params[:search_on] ? @search = 1 : @search = 0
    params[:page] ? @page = params[:page].to_i : @page = 1

    [:search_did, :search_provider, :search_language, :search_status, :search_user, :search_device].each do |param|
      set_search_param(param)
    end

    @search_language = 'all' if !params[:s_language]

    @search_device = "" if !@search_device.match(/^\d+$/)
    @users = current_user.load_users(:all, {})

    if @search_user and @search_user.to_i.to_s == @search_user
      @devices = Device.find(:all, :select => "id, device_type, extension, name, username", :conditions => ["devices.user_id = ? AND name not like 'mor_server_%'", @search_user.to_i], :order => "devices.name ASC")
    else
      @devices = current_user.load_users_devices(:all, {})
    end
    cond = ["dids.id > 0"]
    var = []
    cond << "did like ?" and var << @search_did.to_str.strip if @search_did.to_s.strip.length > 0
    cond << "dids.provider_id = ?" and var << @search_provider if @search_provider.to_s.length > 0
    cond << "dids.language = ? " and var << @search_language.to_s if @search_language.to_s != 'all'
    if @search_status.length > 0
      if  ['free', 'active'].include?(@search_status) and admin?
        cond << "dids.status = ? AND reseller_id = 0" and var << @search_status
      elsif @search_status == 'reserved' and admin?
        cond << "dids.status = ? OR  reseller_id > 0" and var << @search_status
      else
        cond << "dids.status = ?" and var << @search_status
      end
    end
    cond << "dids.user_id = ?" and var << @search_user if @search_user.to_s.length > 0
    cond << "dids.device_id = ?" and var << @search_device if @search_device.to_s.length > 0
    cond << "dids.reseller_id = ?" and var << current_user.id if current_user.usertype == 'reseller'


    total_dids = Did.count(:all, :conditions => [cond.join(" AND ")].concat(var)).to_f
    @total_pages = (total_dids / session[:items_per_page].to_f).ceil
    @page = @total_pages if @page > @total_pages
    @page = 1 if @page < 1

    @show_did_rates = !(session[:usertype] == "accountant" and session[:acc_manage_dids_opt_1] == 0 or reseller?)

    iend = session[:items_per_page] * (@page-1)
    @dids = Did.includes([:user, :device, :provider, :dialplan]).where([cond.join(" AND ")].concat(var)).order("dids.did ASC").limit(session[:items_per_page]).offset(iend).all
    @search = (var.size > 0 ? 1 : 0)
  end

  def show
    @did = Did.find_by_id(params[:id])
    unless @did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :action => :index and return false
    end
  end

  def new
    @did = Did.new
    @page_title = _('New_did')
    @page_icon = 'add.png'
    if current_user.usertype == 'reseller'
      @providers = current_user.providers.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")
    else
      @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")
    end
  end

  def create_did_rates(did, cache = nil)
    if cache
      values = ["'2000-01-01 23:59:59', 1, 'provider', 0.0, 0, 0.0, #{did.id}, '2000-01-01 00:00:00'",
                "'2000-01-01 23:59:59', 1, 'owner', 0.0, 0, 0.0, #{did.id}, '2000-01-01 00:00:00'",
                "'2000-01-01 23:59:59', 1, 'incoming', 0.0, 0, 0.0, #{did.id}, '2000-01-01 00:00:00'"
      ]
      cache.add(values, true)
    else
      #create didrate for provider
      Didrate.new(:did_id => did.id, :rate_type => 'provider').save
      #create didrate for owner
      Didrate.new(:did_id => did.id, :rate_type => 'owner').save
      #create didrate for incoming
      Didrate.new(:did_id => did.id, :rate_type => 'incoming').save
    end
  end

=begin
 @provider is set in before_filter
=end

  def create
    if params[:amount] == "one" # Create just one did
      pr = (current_user.usertype == 'reseller' and current_user.own_providers.to_i == 0) ? Confline.get_value("DID_default_provider_to_resellers").to_i.to_s : params[:provider]
      @did = Did.new(:did => params[:did].to_s.strip, :provider_id => pr, :reseller_id => current_user.id)
      if @did.save
        create_did_rates(@did)
        add_action(session[:user_id], 'did_created', @did.id)
        flash[:status] = _('Did_was_successfully_created')
        redirect_to :action => 'list'
      else
        flash_errors_for(_('Did_was_not_created'), @did)
        redirect_to :action => 'new'
      end
    else #creating did interval


      int_start = params[:did_start].to_s.strip
      int_end = params[:did_end].to_s.strip
      if int_end <= int_start
        flash[:notice] = _('Bad_interval_start_and_end')
        redirect_to :action => 'new'
      else
        pr = (current_user.usertype == 'reseller' and current_user.own_providers.to_i == 0) ? Confline.get_value("DID_default_provider_to_resellers").to_i.to_s : params[:provider]
        did_rate_cache = SQLCache.new("didrates", "`end_time`, `increment_s`, `rate_type`, `rate`, `min_time`, `connection_fee`, `did_id`, `start_time`")
        action_cache = SQLCache.new("actions", "`data3`, `data`, `data4`, `target_id`, `action`, `date`, `processed`, `user_id`, `data2`, `target_type`")
        for d in int_start..int_end
          did = Did.new(
              :did => d,
              :status => "free",
              :user_id => 0,
              :device_id => 0,
              :subscription_id => 0,
              :reseller_id => current_user.id,
              :provider_id => pr.strip)
          if did.save
            create_did_rates(did, did_rate_cache)
            add_action(session[:user_id], 'did_created', did.id, action_cache)
          end
        end
        did_rate_cache.flush
        action_cache.flush
        flash[:status] = _('Did_interval_was_successfully_created')
        redirect_to :action => 'list'
      end
    end
  end

  def confirm_did
    @page_title = _('New_did')
    @page_icon = 'add.png'
    @provider = nil
    if current_user.usertype == 'reseller'
      p = params[:did] ? params[:did][:provider_id] : nil
      pr_id = allow_manage_providers_tariffs? ? p : Confline.get_value("DID_default_provider_to_resellers").to_i.to_s
      @provider = Provider.find(:first, :conditions => ["id=?", pr_id])
    else
      @provider = Provider.find(:first, :conditions => ["id=?", params[:did][:provider_id]]) if params[:did] and params[:did][:provider_id]
    end
    if !@provider or (current_user.usertype == 'reseller' and @provider and !current_user.providers.find(:first, :conditions => ['hidden=? AND id = ?', 0, @provider.id]) and @provider.id != Confline.get_value("DID_default_provider_to_resellers").to_i)
      flash[:notice]=_('Provider_was_not_found')
      redirect_to :action => :list and return false
    end
    @amount = params[:amount]
    if @amount == "one"
      @did = params[:did][:did]
      if @did.length < 10 or @did[0..0].to_i == 0
        @notice = _('DID_not_e164_compatible')
      end
    else
      @start=params[:did_start]
      @end=params[:did_end]
      if @start.length != @end.length
        flash[:notice]=_('DIDs_has_to_be_equal_in_length')
        redirect_to :action => :new and return false
      end
      if (@start[0..0].to_i == 0 or @start.length < 10) or (@end[0..0].to_i == 0 or @end.length < 10)
        @notice = _('DID_not_e164_compatible')
      end
    end
  end


  def edit
    if reseller?
      @did = Did.find(:first, :include => [:user, :dialplan], :conditions => ["dids.id = ? AND dids.reseller_id = ?", params[:id], current_user.id])
    else
      @did = Did.find(:first, :include => [:user, :dialplan], :conditions => ["dids.id = ?", params[:id]])
    end

    unless @did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :action => :index and return false
    end
    @page_title = _('Edit')+ ": " + @did.did
    @page_icon = 'edit.png'

    if current_user.usertype == 'reseller'
      @providers = current_user.providers.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")
    else
      @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")
    end
    @back_controller = "dids"
    @back_action = "list"
    @back_controller = params[:back_controller] if params[:back_controller]
    @back_action = params[:back_action] if params[:back_action]
    #users
    @free_users = User.find(:all, :order => "users.first_name ASC, users.last_name ASC",
                            :conditions => (reseller? ? ["hidden = 0 AND owner_id = ?", current_user.id] : "hidden = 0")
    )

    #devices
    @free_devices = []
    if (@did.user)
      @free_devices = @did.user.devices
    end

    #trunks
    sql = "SELECT devices.* FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{session[:user_id]}'"

    @available_trunks = Device.find_by_sql(sql)

    #assign possible choices what to do with did
    @choice_free = @did.reseller ? (reseller? ? false : true) : false
    @choice_reserved = false
    @choice_active = false
    @choice_closed = false
    @choice_terminated = false

    #DialPlan variables (DID's for dialplan)
    @choice_free_dp = false
    @choice_active_dp = false

    if @did.status == "free"
      if @did.reseller and !reseller?
        @choice_reserved = false
        @choice_terminated = false
        @choice_free_dp = false
      else
        @choice_reserved = true
        @choice_terminated = true
        @choice_free_dp = true
      end
    end

    if @did.status == "reserved"
      @choice_free = true
      @choice_active = true
    end

    if @did.status == "active"
      @choice_active = true
      @choice_closed = true
      @choice_active_dp = true if @did.dialplan or @did.dialplan_id.to_i > 0
      @reseller_can_assing_to_trunk = Confline.get_value('Resellers_Allow_Assign_DID_To_Trunk').to_i == 1
    end

    if @did.status == "closed"
      @choice_free = true
      @choice_active = true
      @choice_terminated = true
    end

    if @did.status == "terminated"
      @choice_free = true
    end

    if @choice_free_dp
      @ccdps = current_user.dialplans.find(:all, :conditions => "dptype = 'callingcard'", :order => "name ASC")
      @abpdps = current_user.dialplans.find(:all, :conditions => "dptype = 'authbypin'", :order => "name ASC")


      @cbdps = current_user.dialplans.find(:all, :conditions => "dptype = 'callback' AND data1 != #{@did.id}", :order => "name ASC") if callback_active?

      if mor_11_extend?
        @qfddps = current_user.dialplans.find(:all, :conditions => "dptype = 'quickforwarddids' AND id != 1", :order => "name ASC")
      else
        @qfddps = current_user.dialplans.find(:all, :conditions => "dptype = 'quickforwarddids'", :order => "name ASC")
      end

      @pbxfdps = current_user.dialplans.find(:all, :conditions => "dptype = 'pbxfunction'", :order => "name ASC")
      @ivrs = current_user.dialplans.find(:all, :conditions => "dptype = 'ivr'", :order => "name ASC")

      @vm_extension = Confline.get_value("VM_Retrieve_Extension", 0)

      @ringdps = current_user.dialplans.find(:all, :conditions => "dptype = 'ringgroup'", :order => "name ASC")
    end

  end

  def update
    if params[:id]
      status = params[:status].to_s.strip
      if reseller?
        did = Did.find(:first, :conditions => ["dids.id = ? AND dids.reseller_id = ?", params[:id], current_user.id])
      else
        did = Did.find(:first, :conditions => ["dids.id = ?", params[:id]])
      end
      unless did
        flash[:notice]=_('DID_was_not_found')
        redirect_to :action => :index and return false
      end
      did.sound_file_id = params[:did][:sound_file_id] if params[:did] and params[:did].has_key?(:sound_file_id)

      ["t_digit", "t_response", "grace_time"].each do |key|
        did[key] = params[:did][key] if params[:did] and params[:did].has_key?(key)
      end
      update_did(did, status, 1)
      add_action(session[:user_id], 'did_edited', did.id)
    else
      find_dids # finds @dids ant sets @opts (additional request params)
      status = params[:status].to_s.strip
      for did in @dids
        update_did(did, status, 0)
        add_action(session[:user_id], 'did_edited', did.id)
      end
      if params[:status].to_s == 'free'
        params[:user_id] = ""
      end
      @opts[:user] = params[:user_id] if params[:user_id]
    end

    if params[:id]
      redirect_to :action => 'edit', :id => params[:id] and return false
    else
      # @opts is beeing set in find_dids method
      if params[:back]
        redirect_to({:action => 'dids_interval_add_to_trunk'}.merge(@opts)) and return false
      else
        redirect_to({:action => 'dids_interval_edit'}.merge(@opts)) and return false
      end
    end
  end


  def update_did(did, status, comment)
    if status == "provider"
      did.language = params[:did][:language].to_s.strip
      did.provider_id = params[:did][:provider_id].to_s.strip if params[:did][:provider_id]
      unless current_user.usertype == 'reseller'
        old_did_number = did.did
        if params[:did][:did] and params[:did][:did]!= did.did
          did.did = params[:did][:did].to_i
        end
        did.call_limit = params[:did][:call_limit].to_i
        did.call_limit = 0 if did.call_limit < 0
        did.comment = params[:did][:comment].to_s.strip if comment.to_i == 1
        did.user_id = params[:user_id] if params[:user_id]
        did.device_id = params[:device_id] if params[:device_id]
      else
        did.reseller_comment = params[:did][:reseller_comment].to_s.strip if comment.to_i == 1
      end
      did.cid_name_prefix = params[:did][:cid_name_prefix]
      if did.save
        if params[:did][:did] != old_did_number
          add_action2(session[:user_id], 'did_changed_did_number', did.id, "From: "+old_did_number.to_s)
        end
        Action.add_action_hash(session[:user_id], {:target_type => 'provider', :target_id => params[:did][:provider_id], :action => 'did_edit_provider', :data => did.id})
        flash[:status] = _('Details_changed')
      else
        flash[:notice] = _("DID_must_be_unique")
      end
    end

    if status == "free"
      if reseller?
        did.make_free_for_reseller
      else
        did.make_free
      end

      extlines_did_not_active(did.id)
      add_action(session[:user_id], 'did_made_available', did.id)
      flash[:status] = _('DID_made_available')
      #  redirect_to :action => 'edit', :id => did.id and return false
    end

    if status == "active"
      old_dev_id = did.device_id
      did.assign(params[:device_id])
      a=configure_extensions(did.device_id, {:no_redirect => true, :current_user => current_user})
      return false if !a

      if old_dev_id.to_i > 0
        dev = Device.where({:id => old_dev_id}).first
        if dev
          dev.primary_did_id = 0
          a= configure_extensions(old_dev_id, {:no_redirect => true, :current_user => current_user})
          return false if !a
        end
      end
      Action.add_action_hash(current_user.id, {:target_type => 'device', :target_id => old_dev_id, :action => 'did_assigned', :data => did.id})
      flash[:status] = _('DID_assigned')
    end

    if status == "closed"
      did.close
      a=configure_extensions(did.device_id, {:no_redirect => true, :current_user => current_user})
      return false if !a
      extlines_did_not_active(did.id)
      add_action(session[:user_id], 'did_closed', did.id)
      flash[:status] = _('DID_closed')
    end

    #check if not assigned to reseller and user not reseller or user is reseller and did assigned to reseller
    if status == "reserved" and ((did.reseller_id == 0 and !reseller?) or (reseller? and did.reseller_id != 0))
      did.reserve(params[:user_id])
      extlines_did_not_active(did.id)
      add_action2(session[:user_id], 'did_reserved', did.id, params[:user_id])
      flash[:status] = _('DID_reserved')
    end

    if status == "terminated"
      if did.device_id != 0
        a=configure_extensions(did.device_id, {:no_redirect => true, :current_user => current_user})
        return false if !a
      end
      did.terminate
      extlines_did_not_active(did.id)
      add_action(session[:user_id], 'did_terminated', did.id)
      flash[:status] = _('DID_terminated')
    end

  end


  def assign_to_dp
    if params[:id]
      @page_title = _('Assign_to_dialplan')
      did = Did.find_by_id(params[:id])
      unless did
        flash[:notice]=_('DID_was_not_found')
        redirect_to :action => :index and return false
      end
      if params[:dp_id].to_i > 0
        dp = Dialplan.find_by_id(params[:dp_id])
        unless dp
          flash[:notice]=_('Dialplan_was_not_found')
          redirect_to :action => :index and return false
        end
        did.dialplan_id = dp.id
      else
        if params[:dp_id] == "voicemail"

        end
      end

      flash[:status] = _('Did_assigned_to_dp') + ": " + dp.name

      did.status = "active"
      did.save
      add_action2(session[:user_id], 'did_assigned_to_dp', did.id, dp.id)
      redirect_to :action => 'edit', :id => did.id

    else
      find_dids # finds @dids ant sets @opts (additional request params)
      if params[:dp_id].to_i > 0
        dp = Dialplan.find_by_id(params[:dp_id])
        unless dp
          flash[:notice]=_('Dialplan_was_not_found')
          redirect_to({:action => 'dids_interval_assign_dialplan'}.merge(@opts)) and return false
        end
      end
      for di in @dids
        if dp
          di.dialplan_id = dp.id
        end
        di.status = "active"
        di.save
        add_action2(session[:user_id], 'did_assigned_to_dp', di.id, dp.id)
      end
      flash[:status]=_('Dids_interval_assigned_to_dialplan')
      redirect_to({:action => 'dids_interval_assign_dialplan'}.merge(@opts)) and return false
    end

  end


  def assign_to_dp_old_disabled
    #take array of cg depending of number/pin length
    sql = "SELECT number_length, pin_length FROM cardgroups GROUP BY number_length, pin_length ORDER BY number_length ASC"
    res = ActiveRecord::Base.connection.select_all(sql)

    @ccg = []
    for r in res
      cg = []
      cg[0] = r["number_length"]
      cg[1] = r["pin_length"]

      sql = "SELECT name FROM cardgroups WHERE number_length = #{cg[0]} AND pin_length = #{cg[1]} ORDER BY name ASC"
      res2 = ActiveRecord::Base.connection.select_all(sql)

      c = []
      for r2 in res2
        c << r2["name"]
      end
      cg << c

      @ccg << cg
    end
  end


  def assign_dp
    assign_type = params[:assign_type].strip
    @did = Did.find_by_id(params[:id])
    unless @did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :action => :index and return false
    end

    if assign_type == "callingcard"

      number_length = params[:number_length].strip
      pin_length = params[:pin_length].strip
      answer = params[:answer].strip

      #assign dp to did
      assign_did_to_calling_card_dp(@did, answer, number_length, pin_length)
      add_action2(session[:user_id], 'did_assign_did_to_calling_card_dp', @did.id)
      flash[:status] = _('Did_assigned_to_dp') + ": " + @did.did
    end


    if assign_type == "authbypin"
      assign_did_to_auth_by_pin_dp(@did)
      add_action2(session[:user_id], 'did_assign_did_to_auth_by_pin_dp', @did.id)
      flash[:status] = _('Did_assigned_to_dp') + ": " + @did.did
    end


    redirect_to :action => 'list'
  end


  def destroy
    did = Did.find_by_id(params[:id])
    unless did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :action => :index and return false
    end
    didrates = did.didrates
    id = did.id
    if did.destroy
      didrates.each { |dr| dr.destroy }
      flash[:status] = _('Did_deleted')
      add_action(session[:user_id], 'did_deleted', id)
    else
      flash[:notice] = _('Did_can_not_delete')
    end

    redirect_to :action => 'list'
  end

  def quickforwarddids
    @page_title = _('Quick_Forwards')

    default = {
        :items_per_page => session[:items_per_page].to_i,
        :page => "1",
        :order_by => "did",
        :order_desc => 0,
    }
    @options = ((params[:clear] || !session[:quickforwarddids_stats]) ? default : session[:quickforwarddids_stats])
    default.each { |key, value| @options[key] = params[key] if params[key] }


    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc].to_i == 1 ? " DESC" : " ASC")

    @qfd_dialplan = Dialplan.find(:first, :conditions => "dptype = 'quickforwarddids'", :order => "name ASC")

    user_id = session[:user_id]
    #select admins set rules
    user = current_user.owner_id != 0 ? current_user.owner : current_user
    if user.quickforwards_rule
      if user.quickforwards_rule.rule_regexp.blank?
        regexp = '$'
      else
        regexp = user.quickforwards_rule.rule_regexp.delete('%')
      end
    end
    #if no rule set or blank - no dids for user
    cond = user.quickforwards_rule ? "AND dids.did REGEXP('^(#{regexp})')" : "AND dids.did REGEXP('^$')"
    sql = "SELECT quickforwarddids.*, dids.did FROM quickforwarddids
JOIN dids ON (dids.id = quickforwarddids.did_id)
JOIN dialplans ON (dids.dialplan_id = dialplans.id)
WHERE dialplans.dptype = 'quickforwarddids'  #{cond} AND quickforwarddids.user_id = '#{user_id}'
GROUP BY quickforwarddids.id
ORDER BY dids.did ASC"
    #  sql = "SELECT dids.id as 'dids_id', dids.did, quickforwarddids.* FROM dids JOIN dialplans ON (dids.dialplan_id = dialplans.id AND dialplans.dptype = 'quickforwarddids') LEFT JOIN quickforwarddids ON (quickforwarddids.did_id = dids.id AND quickforwarddids.user_id = '#{user_id}') ORDER BY dids.did ASC"
    #@dids = []
    @dids2 = ActiveRecord::Base.connection.select_all(sql)
    did_id = []
    @dids2.each { |p| did_id << p['did_id'] } if @dids2
    did_cond = @dids2.size.to_i > 0 ? " AND dids.id NOT IN (#{did_id.join(',')}) " : ''
    sql = "SELECT * FROM (SELECT 0 AS qid, dids.did, 1 as not_edit, dids.id as did_id, '' as number, '' as description FROM dids
    JOIN dialplans ON (dids.dialplan_id = dialplans.id)
    WHERE dialplans.dptype = 'quickforwarddids'  #{cond}  #{did_cond}
    GROUP BY dids.did
    UNION
    SELECT quickforwarddids.id as qid, dids.did, 0 as not_edit, dids.id as did_id, number, description FROM quickforwarddids
    JOIN dids ON (dids.id = quickforwarddids.did_id)
    JOIN dialplans ON (dids.dialplan_id = dialplans.id)
     WHERE dialplans.dptype = 'quickforwarddids'  #{cond} AND quickforwarddids.user_id = '#{user_id}'
    GROUP BY quickforwarddids.id) AS v
    ORDER BY  #{@options[:order_by_full]}"

    #if resellers user - select dids according to admins rule to reseller, then resellers rule to user
    if current_user.owner.usertype == "reseller"
      resellers_user = current_user
      if !resellers_user.quickforwards_rule or resellers_user.quickforwards_rule.rule_regexp.blank?
        regexp_second = '$'
      else
        regexp_second = resellers_user.quickforwards_rule.rule_regexp.delete('%')
      end
      sql2 = "SELECT * FROM (#{sql}) AS c WHERE did REGEXP('^(#{regexp_second})') ORDER BY  #{@options[:order_by_full]}"
      @dids = ActiveRecord::Base.connection.select_all(sql2)
    else
      @dids = ActiveRecord::Base.connection.select_all(sql)
    end

  end


  def quickforwarddid_edit
    @page_title = _('Quick_Forwards')
    @page_icon = "edit.png"

    user_id = session[:user_id]

    @qfdid = Quickforwarddid.find(:first, :conditions => ["did_id =? AND user_id = ?", params[:id], user_id])
    if not @qfdid
      @qfdid = Quickforwarddid.new
      @qfdid.did_id = params[:id]
      @qfdid.user_id = user_id
    end
    @did = @qfdid.did

  end


  def quickforwarddid_update

    if  params[:number].length == 0
      flash[:notice] = _('Enter_number')
      redirect_to :action => 'quickforwarddid_edit', :id => params[:did_id] and return false
    end

    if params[:id]
      qfdid = Quickforwarddid.find_by_id(params[:id])
      unless qfdid
        flash[:notice]=_('Quickforwarddid_was_not_found')
        redirect_to :action => :index and return false
      end
    else
      qfdid = Quickforwarddid.new
      qfdid.did_id = params[:did_id]
      qfdid.user_id = session[:user_id]
    end

    qfdid.did_id = params[:did_id]
    qfdid.user_id = session[:user_id]
    qfdid.number = params[:number]
    qfdid.description = params[:description]
    qfdid.save
    add_action2(session[:user_id], 'quickforwarddid_edit', qfdid.did_id, qfdid.id)
    redirect_to :action => 'quickforwarddids'

  end

  def quickforwarddid_destroy
    q = Quickforwarddid.find_by_id(params[:id])
    unless q
      flash[:notice]=_('Quickforwarddid_was_not_found')
      redirect_to :action => :index and return false
    end
    q.destroy
    add_action(session[:user_id], 'quickforwarddid_deletedt', params[:id])
    flash[:status] = _('Number_deleted')
    redirect_to :action => 'quickforwarddids'
  end


  def bulk_management
    @page_title = _('Bulk_management')
    @page_icon = "edit.png"

    @from=params[:from] if params[:from]
    @till=params[:till] if params[:till]

    unless reseller?
      @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")
      sql = "SELECT count(devices.id)  FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{session[:user_id]}'"

      @trunk = Device.count_by_sql(sql)
    end
    @users = User.find(:all, :select => "id, username, first_name, last_name, #{SqlExport.nice_user_sql}", :conditions => ["hidden = 0 AND owner_id = ?", current_user.id], :order => "nice_user ASC")

    @devices = current_user.load_users_devices(:all, {})

    !params[:did_action].blank? and (1..4).include?(params[:did_action].to_i) ? @did_action = params[:did_action].to_i : @did_action = 1
    @did_action = 1 if @trunk.to_i == 0 and @did_action == 4
  end

  def confirm_did_action
    params[:did_action] = 0 if reseller? and ![1, 3, 5].include?(params[:did_action].to_i)
    opts = {:from => params[:did_start], :till => params[:did_end]}
    if opts[:from].blank? or opts[:till].blank?
      flash[:notice] = _('Enter_DID_interval')
      redirect_to :action => :bulk_management and return false
    end

    if opts[:from].to_i > opts[:till].to_i
      flash[:notice] = _('Bad_interval_start_and_end')
      redirect_to :action => :bulk_management and return false
    end

    opts[:user] = params[:user].to_i if params[:user] and !params[:user].strip.blank?
    opts[:device] = params[:device].to_i if params[:device] and !params[:device].strip.blank?
    opts[:active] = params[:active].to_i
    case params[:did_action].to_i
      when 1 then
        opts[:action] = :dids_interval_edit
      when 2 then
        opts[:action] = :dids_interval_delete
      when 3 then
        opts[:action] = :dids_interval_rates
      when 4 then
        opts[:action] = :dids_interval_trunk
      when 5 then
        opts[:action] = :dids_interval_add_to_user
      when 6 then
        opts[:action] = :dids_interval_assign_dialplan
      else
        flash[:notice] = _("Action_was_not_correct")
        opts = {:action => :bulk_management}
    end
    redirect_to opts and return false
  end

  def dids_interval_add_to_user
    @page_title = _('Dids_interval_add_to_user')
    @page_icon = "edit.png"
    #accountant can manage as admin
    if accountant?
      user_id = 0
    else
      user_id = current_user.id
    end

    @users = User.find(:all,
                       :select => "users.id, users.username, users.first_name, users.last_name, #{SqlExport.nice_user_sql}",
                       :conditions => ["hidden = 0 AND owner_id = ?", user_id],
                       :order => "nice_user ASC")
    user = @users.first
    @devices = (user ? user.devices : [])
  end

  def add_to_user
    @from = params[:from].to_i
    @till = params[:till].to_i
    @opts = {:from => @from, :till => @till}
    var = [@from, @till]
    cond = ["dids.did BETWEEN ? AND ?"]
    num = 0
    if reseller?
      cond << "reseller_id = ?"
      var << current_user.id
    end
    if params[:user] and !params[:user].strip.blank?
      @user = User.find(:first, :conditions => {:id => params[:user].strip})
      if @user and @user.owner_id == correct_owner_id
        cond << "dids.user_id = ?"
        var << @user.id
        @opts[:user] = @user.id
        if params[:device] and !params[:device].strip.blank?
          @device = current_user.load_users_devices(:first, :conditions => "devices.id = '#{params[:device]}'")
          if @device
            cond << "dids.device_id = ?"
            var << @device.id
            @opts[:device] = @device.id
          else
            flash[:notice] = _("Device_not_found")
            redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts)) and return false
          end
        end
      else
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end

    @s_user = User.find(:first, :conditions => ["users.id = ?", params[:s_user]])
    if @s_user and @s_user.owner_id == correct_owner_id

      if params[:s_device] and !params[:s_device].strip.blank?
        @s_device = current_user.load_users_devices(:first, :conditions => "devices.id = '#{params[:s_device]}'")
        unless @s_device
          flash[:notice] = _("Device_not_found")
          redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts)) and return false
        end
      end
      if @s_device
        num = Did.update_all("user_id = #{@s_user.id}, device_id = #{@s_device.id}, status = 'active'", [cond.join(" AND "), *var])
      else
        if @s_user.usertype=='reseller'
          num = Did.update_all("reseller_id = #{@s_user.id}, user_id = 0, device_id = 0, status = 'free'", [cond.join(" AND "), *var])
        else
          num = Did.update_all("user_id = #{@s_user.id}, device_id = 0, status = 'reserved'", [cond.join(" AND "), *var])
        end

      end
      flash[:status] = [num.to_s, _('DIDs_were_updated')].join(" ")
      redirect_to({:action => 'list'}) and return false
    else
      flash[:notice] = _('User_Was_Not_Found')
    end
    redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts))
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_add_to_trunk
    @page_title = _('Dids_interval_add_to_Trunk')
    @page_icon = "trunk.png"
    sql = "SELECT devices.* FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{session[:user_id]}'"

    @available_trunks = Device.find_by_sql(sql)
    if  @available_trunks.size.to_i == 0
      flash[:notice] = _('No_available_trunks')
      redirect_to :controller => "dids", :action => "list"
    end
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_trunk
    @page_title = _('Dids_interval_add_to_Trunk')
    @page_icon = "trunk.png"

    sql = "SELECT count(devices.id)  FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{session[:user_id]}'"

    @available_trunks = Device.count_by_sql(sql)
    if  @available_trunks.to_i == 0
      flash[:notice] = _('No_available_trunks')
      redirect_to :controller => "dids", :action => "list"
    end
    @free_users = User.find(:all, :conditions => "hidden = 0")
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_edit
    @page_title = _('Dids_interval_update')
    @page_icon = "edit.png"
    if reseller?
      @free_users = User.find(:all, :conditions => ["hidden = 0 AND owner_id = ?", current_user.id])
    else
      @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")
      @free_users = User.find(:all, :conditions => "hidden = 0")
    end
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_rates
    @page_title = _('Dids_interval_rates')
    @page_icon = "edit.png"

    for did in @dids
      did.did_prov_rates
      did.did_incoming_rates
      did.did_owner_rates
    end
  end

  def edit_rate


    if params[:till]

      if params[:user]
        if reseller?
          add_condition = "and user_id = #{params[:user].to_i}"
        else
          add_condition = "and (reseller_id = #{params[:user].to_i} or user_id = #{params[:user].to_i})"
        end
      else
        add_condition = ""
      end

      if reseller?
        @dids = Did.find(:all, :conditions => ["did >= ? AND did <= ? AND dids.reseller_id = ? #{add_condition}", params[:from], params[:till], current_user.id])
      else
        @dids = Did.find(:all, :conditions => ["did >= ? AND did <= ? #{add_condition}", params[:from], params[:till]])
      end


      for did in @dids

        if params[:provider]
          for rate in did.did_prov_rates
            update_rate(rate.id, params[:rate], params[:con_fee], params[:inc], params[:min_time])
          end
        end

        if params[:incoming]
          for rate in did.did_incoming_rates
            update_rate(rate.id, params[:rate], params[:con_fee], params[:inc], params[:min_time])
          end
        end

        if params[:owner]
          for rate in did.did_owner_rates
            update_rate(rate.id, params[:rate], params[:con_fee], params[:inc], params[:min_time])
          end
        end

        if params[:interval]
          for rate in did.did_incoming_rates
            update_rate(rate.id, params[:irate], params[:icon_fee], params[:iinc], params[:imin_time])
          end

          unless reseller?
            for rate in did.did_prov_rates
              update_rate(rate.id, params[:prate], params[:pcon_fee], params[:pinc], params[:pmin_time])
            end
            for rate in did.did_owner_rates
              update_rate(rate.id, params[:orate], params[:ocon_fee], params[:oinc], params[:omin_time])
            end
          end
        end
        flash[:status] = _('Did_interval_rate_edited')
      end

      redirect_to :action => 'dids_interval_rates', :from => params[:from], :till => params[:till], :user => params[:user]

    else
      update_rate(params[:id], params[:rate], params[:con_fee], params[:inc], params[:min_time])

      redirect_back_or_default("/dids/list")
    end
  end

  def update_rate(id, rate, fee, increments, min_time)
    didrates_conditions = {:readonly => false, :select => "didrates.*"}
    if current_user.usertype == 'reseller'
      didrates_conditions[:conditions] = ["didrates.id = ? AND dids.reseller_id = ?", id, current_user.id]
      didrates_conditions[:joins] = "LEFT JOIN dids ON (didrates.did_id = dids.id)"
    else
      didrates_conditions[:conditions] = ["didrates.id = ?", id]
    end

    dr = Didrate.find(:first, didrates_conditions)
    if dr
      dr.rate = rate
      dr.connection_fee = fee
      dr.increment_s = increments
      dr.min_time = min_time
      dr.save
      add_action2(session[:user_id], 'did_rate_edited', dr.did_id, dr.id)
      flash[:status] = _('Did_rate_edited')
    else
      flash[:notice] = _('Rate_was_not_found')
    end
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_delete
    @page_title = _('Dids_interval_delete')
    @page_icon = "edit.png"
    @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_assign_dialplan
    @page_title = _('Dids_interval_assign_to_dialplan')
    @page_icon = "edit.png"

    @ccdps = Dialplan.find(:all, :conditions => "dptype = 'callingcard'", :order => "name ASC")
    @abpdps = Dialplan.find(:all, :conditions => "dptype = 'authbypin'", :order => "name ASC")

    @cbdps = Dialplan.find(:all, :conditions => "dptype = 'callback' AND data1 NOT IN ('#{@dids.map { |d| d.id }.join("','")}')", :order => "name ASC")

    @qfddps = Dialplan.find(:all, :conditions => "dptype = 'quickforwarddids'", :order => "name ASC")

    @pbxfdps = Dialplan.find(:all, :conditions => "dptype = 'pbxfunction'", :order => "name ASC")
    @ivrs = Dialplan.find(:all, :conditions => "dptype = 'ivr'", :order => "name ASC")

    @vm_extension = Confline.get_value("VM_Retrieve_Extension", 0)

  end


  # @dids, @from, @till, (@user, @device) in before filter
  def delete
    status = params[:status].to_s.strip
    if status == 'provider'
      for did in @dids
        update_did(did, "free", 0)
        update_did(did, "terminated", 0)
        did.didrates.each { |dr| dr.destroy }
        add_action(session[:user_id], 'did_deleted', did.id)
        flash[:status] = _('Did_deleted')
        did.destroy
      end
    end

    if status != 'provider'
      status = [nil, 'free', 'terminated', nil, 'closed'][params[:dids_action].to_i]
      for did in @dids
        if did.device_id.to_i != 0 and status == 'closed'
          update_did(did, status, 0)
          add_action(session[:user_id], 'did_edited', did.id)
        end
        if status != 'closed'
          update_did(did, status, 0)
          add_action(session[:user_id], 'did_edited', did.id)
        end
      end
    end

    if params[:id]
      redirect_to :action => 'edit', :id => params[:id]
    else
      redirect_to({:action => 'dids_interval_delete'}.merge(@opts))
    end
  end

  def dids_export_to_csv
    @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => "name ASC")

    sql = "SELECT DISTINCT language FROM dids ORDER by language"
    @languages = ActiveRecord::Base.connection.select_all(sql)

    @users = User.find(:all, :conditions => "hidden = 0", :order => "first_name ASC")

    @devices = Device.find(:all, :conditions => "user_id > 0 AND name not like 'mor_server_%'", :order => "name ASC")

    #seach
    @search = 0
    @search = 1 if params[:search_on]

    @search_did = ""
    @search_did = params[:s_did] if params[:s_did]

    @search_provider = ""
    @search_provider = params[:s_provider] if params[:s_provider]

    @search_language = ""
    @search_language = params[:s_language] if params[:s_language]

    @search_status= ""
    @search_status = params[:s_status] if params[:s_status]

    @search_user = ""
    @search_user = params[:s_user] if params[:s_user]

    @search_device = ""
    @search_device = params[:s_device] if params[:s_device]

    cond = ""
    cond += " AND did like '#{@search_did}' " if @search_did.length > 0

    cond += " AND provider_id = '#{@search_provider}' " if @search_provider.length > 0

    cond += " AND language = '#{@search_language}' " if @search_language.length > 0

    if @search_status.length > 0
      if  ['free', 'active'].include?(@search_status)
        cond += " AND status = '#{@search_status}' AND reseller_id = 0"
      elsif @search_status == 'reserved'
        cond += " AND status = '#{@search_status}' OR  reseller_id > 0"
      else
        cond += " AND status = '#{@search_status}'"
      end
    end

    cond += " AND user_id = '#{@search_user}' " if @search_user.length > 0

    cond += " AND device_id = '#{@search_device}' " if @search_device.length > 0

    #@dids = Did.find(:all, :order => "did ASC")
    sql = "SELECT dids.* FROM dids WHERE id > 0  #{cond} ORDER BY did ASC"
    @dids = Did.find_by_sql(sql)

    sep, dec = current_user.csv_params

    csv_string = "DID#{sep}Provider#{sep}Language#{sep}Status#{sep}User/Dial_Plan#{sep}Device#{sep}Call_limit#{sep}Comment\n"
    for did in @dids

      if did.user_id != 0
        user_d_plan= did.user.first_name + " " + did.user.last_name
      else
        if did.dialplan_id == 0 and did.status != "free"
          user_d_plan = did.user.first_name + " " + did.user.last_name
        else
          user_d_plan = did.dialplan.name if did.dialplan
        end
      end
      csv_string += "#{did.did.to_s}#{sep}#{did.provider.name}#{sep}#{did.language}#{sep}#{did.status.capitalize}#{sep}#{user_d_plan}#{sep}#{nice_device(did.device)}#{sep}#{did.call_limit}#{sep}#{did.comment}\n"
      user_d_plan = ''
    end

    filename = "DIDs.csv"


    send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => filename)

  end

  def regenerate_dialplan
    dialplan = Dialplan.find(:first, :conditions => ["id = ? ", params[:id]])
    unless dialplan
      flash[:notice]=_('Quickforwarddid_was_not_found')
      redirect_to :action => :index and return false
    end
    dialplan.regenerate_ivr_dialplan
    dialplan.data8 = 0
    dialplan.save

    #session[:integrity_check] = FunctionsController.integrity_recheck
    redirect_to :controller => "dialplans", :action => "dialplans"
  end

  def reformat_dialplans
    @dialplans = Dialplan.find(:all, :conditions => "dptype = 'ivr' and data8 = 1")
    for dialplan in @dialplans
      dialplan.regenerate_ivr_dialplan
      dialplan.data8 = 0
      dialplan.save
    end

    #session[:integrity_check] = FunctionsController.integrity_recheck
    redirect_to :controller => "functions", :action => "integrity_check"
  end

  def DidsController::reformat_dialplans
    @dialplans = Dialplan.find(:all, :conditions => "dptype = 'ivr' and data8 = 1")
    for dialplan in @dialplans
      dialplan.regenerate_ivr_dialplan
      dialplan.data8 = 0
      dialplan.save
    end
  end

  #FunctionsController.integrity_recheck


  def personal_dids
    @page_title = _('DIDs')
    @page_icon = "did.png"
    user = User.find(:first, :conditions => ["id = ?", session[:user_id].to_i])
    params[:page] ? @page = params[:page].to_i : @page = 1
    @total_pages = (Did.count(:all, :conditions => ["user_id = ?", user.id])/session[:items_per_page].to_f).ceil
    @dids = Did.find(:all,
                     :conditions => ["user_id = ?", user.id],
                     :offset => session[:items_per_page]*(@page-1),
                     :limit => session[:items_per_page])
  end

  private

  def check_user_for_dids
    if current_user.usertype == 'user'
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :controller => "callc", :action => "login" and return false
    end
  end

  def set_search_param(param)
    session[:did_search_options] ||= {}
    key = param.to_s.gsub(/search/, 's')

    result = if params.has_key?(key)
               params.fetch(key)
             elsif session[:did_search_options].has_key?(key)
               session[:did_search_options].fetch(key)
             else
               ""
             end
    session[:did_search_options][key] = result.to_s
    instance_variable_set "@#{param}", result.to_s
  end

  def check_device_presence
    if params[:status] && params[:status] == "active" && params[:device_id]
      device = Device.find_by_id(params[:device_id])

      unless device
        flash[:notice] = _('Device_not_found')
        redirect_to :action => "list"
      end
    end
  end

  def find_provider
    @provider = Provider.find(:first, :conditions => {:id => params[:provider]})
    unless @provider
      flash[:notice] = _('Provider_was_not_found')
      redirect_to :action => 'new'
    end
  end

  def find_dids
    @from = params[:from].to_i
    @till =params[:till].to_i
    active = params[:active].to_i
    @opts = {:from => @from, :till => @till, :active => active.to_i}

    var = [@from, @till]
    cond = ["dids.did BETWEEN ? AND ?"]
    if params[:did] and params[:did][:provider_id] and !params[:did][:provider_id].strip.blank?
      @provider = Provider.find(:first, :conditions => {:id => params[:did][:provider_id]})
      var << params[:did][:provider_id].to_i
      cond << "dids.provider_id = ?"
    end
    if reseller?
      cond << "dids.reseller_id = ?"
      var << current_user.id
    end
    if params[:user] and !params[:user].strip.blank?
      @user = User.find(:first, :conditions => {:id => params[:user].strip})
      if @user
        # find dids that assigned to user or reseller
        if @user.usertype == 'reseller'
          cond << "dids.reseller_id = ?"
        else
          cond << "dids.user_id = ?"
        end
        var << params[:user].strip
        @opts[:user] = @user.id
        if params[:device] and !params[:device].strip.blank?
          @device = Device.find(:first, :conditions => {:id => params[:device].strip, :user_id => @user.id})
          if @device
            cond << "dids.device_id = ?"
            var << params[:device].strip
            @opts[:device] = @device.id
          end
        end
      end
    end
    if active.to_i == 1
      cond << 'dids.status = ?'; var << 'active'
    end
    @dids = Did.find(:all, :conditions => [cond.join(" AND "), *var])
  end

  def check_dids_creation
    if !allow_manage_dids? and !['admin', 'accountant'].include?(current_user.usertype)
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    if current_user.usertype == 'reseller' and params[:provider] and current_user.own_providers.to_i == 1 and !current_user.providers.find(:first, :conditions => "providers.id = #{params[:provider]}") and params[:provider] != Confline.get_value("DID_default_provider_to_resellers").to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    if current_user.usertype == 'reseller' and params[:provider] and current_user.own_providers.to_i == 0 and params[:provider].to_i != Confline.get_value("DID_default_provider_to_resellers").to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end

  end

  def check_did_params
    if !['reserved', "terminated", "free", "closed", "active"].include?(params[:status]) and (!params[:did] or !params[:status])
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    if params[:status] == 'reserved'
      u = User.find(:first, :conditions => ["id = ?", params[:user_id]])
      if current_user.usertype == 'reseller' and (!params[:user_id] or !u or u.owner_id != correct_owner_id)
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end
    if params[:status] == "active"
      device = Device.find(:first, :conditions => ["id = ?", params[:device_id]])
      if current_user.usertype == 'reseller' and (!device or !Device.find(:first, :joins => "LEFT JOIN users ON (devices.user_id = users.id)", :conditions => "devices.id = #{device.id} and (users.owner_id = #{current_user.id} or users.id = #{current_user.id})"))
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end
    if params[:did] and params[:did][:provider_id]
      if current_user.usertype == 'reseller' and params[:did][:provider_id] and current_user.own_providers.to_i == 1 and !current_user.providers.find(:first, :conditions => "providers.id = #{params[:did][:provider_id]}") and params[:did][:provider_id] != Confline.get_value("DID_default_provider_to_resellers").to_i
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main' and return false
      end

      if current_user.usertype == 'reseller' and params[:did][:provider_id] and current_user.own_providers.to_i == 0 and params[:did][:provider_id].to_i != Confline.get_value("DID_default_provider_to_resellers").to_i
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main' and return false
      end
    end

  end
end
