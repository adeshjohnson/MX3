# -*- encoding : utf-8 -*-
class DidsController < ApplicationController
  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  #before_filter :authorize_admin, :except => [:quickforwarddids, :quickforwarddid_edit, :quickforwarddid_update, :quickforwarddid_destroy]
  before_filter :authorize

  before_filter :check_user_for_dids, :except => [:personal_dids, :quickforwarddids, :quickforwarddid_edit, :quickforwarddid_update, :quickforwarddid_destroy]
  before_filter { |c|
    view = [:index, :list, :show, :did_rates]
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
    redirect_to :action => :list and return false
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

    #seach

    params[:search_on] ? @search = 1 : @search = 0
    params[:page] ? @page = params[:page].to_i : @page = 1

    if params[:clean].to_i == 1 or !session[:did_search_options]
      session[:did_search_options] = {:s_language => 'all'}
      params[:s_language] = 'all' if !params[:s_language]
    end
    [:search_did, :search_provider, :search_dialplan, :search_language, :search_status, :search_user, :search_device].each do |param|
      set_search_param(param)
    end

    #@search_language = 'all' if !params[:s_language]

    #@search_device = "" if !@search_device.match(/^\d+$/)

    cond = ["dids.id > 0"]
    var = []
    cond << "did like ?" and var << @search_did.to_str.strip if @search_did.to_s.strip.length > 0
    cond << "dids.provider_id = ?" and var << @search_provider if @search_provider.to_s.length > 0
    cond << "dids.dialplan_id = ?" and var << @search_dialplan if @search_dialplan.to_s.length > 0
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
    cond << "dids.device_id = ?" and var << @search_device if @search_device.to_s.length > 0  and  @search_device.to_s != 'all'
    cond << "dids.reseller_id = ?" and var << current_user.id if current_user.usertype == 'reseller'

    @search = (var.size > 0 ? 1 : 0)


    if params[:csv].to_i == 0
      unless current_user.usertype == 'reseller'
        @providers = current_user.load_providers(:all, {})
      end

      @dialplans = Dialplan.where(:user_id => current_user.id) 

      sql = "SELECT DISTINCT language FROM dids ORDER by language"
      @languages = ActiveRecord::Base.connection.select_all(sql)

      @users = current_user.load_users(:all, {})

      if @search_user and @search_user.to_i.to_s == @search_user
        @devices = Device.find(:all, :select => "id, device_type, extension, name, username", :conditions => ["devices.user_id = ? AND name not like 'mor_server_%'", @search_user.to_i], :order => "devices.name ASC")
      else
        @devices = current_user.load_users_devices(:all, {})
      end

      total_dids = Did.count(:all, :conditions => [cond.join(" AND ")].concat(var)).to_d
      @total_pages = (total_dids / session[:items_per_page].to_d).ceil
      @page = @total_pages if @page > @total_pages
      @page = 1 if @page < 1

      @show_did_rates = !(session[:usertype] == "accountant" and session[:acc_manage_dids_opt_1] == 0 or reseller?)

      iend = session[:items_per_page] * (@page-1)
      @dids = Did.includes([:user, :device, :provider, :dialplan]).where([cond.join(" AND ")].concat(var)).order("dids.did ASC").limit(session[:items_per_page]).offset(iend).all

    else

      @dids = Did.includes([:user, :device, :provider, :dialplan]).where([cond.join(" AND ")].concat(var)).order("dids.did ASC").all
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

      if params[:test].to_i == 0
        send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      else
        render :text => csv_string
      end
    end
  end

  def show
    @did = Did.where(:id => params[:id]).first
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

      status = Hash.new(0)
      status[:messages] =[]
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
            status[:good_dids] += 1
          else
            status[:messages] << did.errors.first[1]
            status[:bad_dids] += 1
          end
        end
        
        if status[:bad_dids] > 0
          status_out = status[:bad_dids].to_s + " " + _("DIDs_were_not_created") + ":<br/>"
          status[:messages].uniq.each do |error|
            status_out << "&nbsp; * #{error}<br/>"
          end
        end
        did_rate_cache.flush
        action_cache.flush
        if status[:bad_dids].size == 0
          flash[:status] = _('Did_interval_was_successfully_created')
        else
          flash[:notice] = status_out
          flash[:status] = "1 " + _("Did_was_successfully_created") if status[:good_dids].to_i == 1
          flash[:status] = "#{status[:good_dids]} " + _("Dids_were_successfully_created") if status[:good_dids].to_i > 1
        end
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
    @did.dialplan_id > 0 ? dp_cond = " AND usertype != 'reseller'" : dp_cond = ""
    @free_users = User.select("id, username, first_name, last_name, #{SqlExport.nice_user_sql}").where((reseller? ? ["hidden = 0 AND owner_id = ?", current_user.id] : "hidden = 0" + dp_cond)).order("nice_user ASC")

    #devices
    @free_devices = []
    if (@did.user)
      @free_devices = @did.user.devices.where(:istrunk => 0)
    end

    #trunks
    sql = "SELECT devices.*, #{SqlExport.nice_user_sql} FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{session[:user_id]}' ORDER BY nice_user"

    @available_trunks = Device.find_by_sql(sql)

    #assign possible choices what to do with did
    @choice_free = @did.reseller ? (reseller? ? false : true) : false
    @choice_reserved = false
    @choice_active = false
    @choice_closed = false
    @choice_terminated = false

    # QF Rule default values
    @qf_rule_collisions = false
    @rs_rules = false

    @is_reseller = current_user.is_reseller?

    if @is_reseller
      res_scope_rules = QuickforwardsRule.where("#{@did.did} REGEXP(concat('^',replace(replace(rule_regexp, '%', ''),'|','|^'))) and user_id in (0,#{current_user.id})")
      @rs_rules = true if res_scope_rules.collect(&:user_id).include?(current_user.id) and res_scope_rules.collect(&:id).include?(current_user.quickforwards_rule_id)
      @qf_rule_collisions = true if res_scope_rules.size.to_i > 0
    else
      @qf_rule_collisions = true if @did.find_qf_rules.to_i > 0
    end

    #DialPlan variables (DID's for dialplan)
    @choice_free_dp = false
    @choice_active_dp = false
    @reseller_can_assing_to_trunk = Confline.get_value('Resellers_Allow_Assign_DID_To_Trunk').to_i == 1

    if @did.status == "free"
      if @did.reseller and !reseller?
        @choice_reserved = false
        @choice_terminated = false
        @choice_free_dp = false
      else
        @choice_reserved = true unless @qf_rule_collisions
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
      current_user.is_accountant? ? @dialplan_source = Dialplan.where(:user_id => 0) : @dialplan_source = current_user.dialplans

      @qfddps = @dialplan_source.where("dptype = 'quickforwarddids' AND id != 1").order("name ASC")

      unless @qf_rule_collisions 
        @ccdps = @dialplan_source.where(:dptype => 'callingcard').order("name ASC")
        @abpdps = @dialplan_source.where(:dptype => 'authbypin').order("name ASC")

        @cbdps = @dialplan_source.where(["dptype = 'callback' AND data1 != ?", @did.id]).order("name ASC") if callback_active?

        @pbxfdps = @dialplan_source.where(:dptype => 'pbxfunction').order("name ASC")
        @ivrs = @dialplan_source.where(:dptype => 'ivr').order("name ASC")
        @vm_extension = Confline.get_value("VM_Retrieve_Extension", 0)
        @ringdps = @dialplan_source.where(:dptype => 'ringgroup').order("name ASC")
      end
    end

    @tone_zones = ['at', 'au', 'be', 'br', 'ch', 'cl', 'cn', 'cz', 'de', 'dk', 'ee', 'es', 'fi', 'fr', 'gr', 'hu', 'it', 'lt', 'mx', 'ml', 'no', 'nz', 'pl', 'pt', 'ru', 'se', 'sg', 'uk', 'us', 'us-old', 'tw', 've', 'za', 'il'].sort
    @cc_tariffs = Tariff.where(["purpose != 'provider' and owner_id = ?", correct_owner_id])

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
      did.tonezone = params[:did][:tonezone] if params[:did] and params[:did][:tonezone]
      did.sound_file_id = params[:did][:sound_file_id] if params[:did] and params[:did].has_key?(:sound_file_id)
      did.cc_tariff_id = params[:did][:cc_tariff_id] if params[:did] and params[:did][:cc_tariff_id]

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
      if status == 'reserved'
        user = User.where(:id => params[:user_id].to_i).first
        if user.usertype.to_s == 'reseller'
          num = Did.where("status = 'free' AND reseller_id = #{params[:user_id].to_i} AND did BETWEEN #{params[:from].to_i} AND #{params[:till].to_i}").count
          bad_num = Did.where("(status != 'free' OR reseller_id != #{params[:user_id].to_i}) AND did BETWEEN #{params[:from].to_i} AND #{params[:till].to_i}").count
        else
          num = Did.where("status = 'reserved' AND user_id = #{params[:user_id].to_i} AND did BETWEEN #{params[:from].to_i} AND #{params[:till].to_i}").count
          bad_num = Did.where("(status != 'reserved' OR user_id != #{params[:user_id].to_i}) AND did BETWEEN #{params[:from].to_i} AND #{params[:till].to_i}").count
        end
        flash[:notice] = [bad_num.to_s, _('DIDs_were_not_updated')].join(" ") if bad_num.to_i > 0
        flash[:status] = [num.to_s, _('DIDs_were_updated')].join(" ") if num.to_i > 0
      elsif status == 'free'
        flash[:status] = [@dids.size, _('DID_made_available')].join(" ") if @dids.size.to_i > 0
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
        redirect_to(:action => 'list') and return false
        #ticket #5946 
        #redirect_to({:action => 'dids_interval_edit'}.merge(@opts)) and return false
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
      flash[:status] = _('one_DID_made_available')
      #  redirect_to :action => 'edit', :id => did.id and return false
    end

    if status == "active"
      old_dev_id = did.device_id
      if did.assign(params[:device_id])
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
      else
        flash_errors_for(_("Could_not_assign_did"), did)
      end
    end

    if status == "closed"
      did.close
      a=configure_extensions(did.device_id, {:no_redirect => true, :current_user => current_user})
      return false if !a
      extlines_did_not_active(did.id)
      add_action(session[:user_id], 'did_closed', did.id)
      flash[:status] = _('DID_closed')
    end
    if did.dialplan_id > 0
      if did.errors.size > 0
        flash_errors_for(_('Did_was_not_updated'), did)
      end
    end

    #check if not assigned to reseller and user not reseller or user is reseller and did assigned to reseller
    if status == "reserved" and ((did.reseller_id == 0 and !reseller?) or (reseller? and did.reseller_id != 0))
      if did.reserve(params[:user_id])
      extlines_did_not_active(did.id)
      add_action2(session[:user_id], 'did_reserved', did.id, params[:user_id])
      flash[:status] = _('DID_reserved')
      else
        flash_errors_for(_('Did_was_not_updated'), did)
      end
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
      did = Did.where(:id => params[:id]).first
      unless did
        flash[:notice]=_('DID_was_not_found')
        redirect_to :action => :index and return false
      end
      if params[:dp_id].to_i > 0
        dp = Dialplan.where(:id => params[:dp_id]).first
        unless dp
          flash[:notice]=_('Dialplan_was_not_found')
          redirect_to :action => :index and return false
        end
        did.dialplan_id = dp.id
      else
        if params[:dp_id] == "voicemail"

        end
      end



      did.status = "active"
      if did.save
        flash[:status] = _('Did_assigned_to_dp') + ": " + dp.name
        add_action2(session[:user_id], 'did_assigned_to_dp', did.id, dp.id)
      else
        flash_errors_for(_('Did_was_not_updated'), did)
      end
      redirect_to :action => 'edit', :id => did.id

    else
      bad_num = 0
      find_dids # finds @dids ant sets @opts (additional request params)
      if params[:dp_id].to_i > 0
        dp = Dialplan.where(:id => params[:dp_id]).first
        unless dp
          flash[:notice]=_('Dialplan_was_not_found')
          redirect_to({:action => 'dids_interval_assign_dialplan'}.merge(@opts)) and return false
        end
      end
      for di in @dids
        if di.status.downcase == "reserved"
          bad_num += 1
          next
        end
        if dp
          di.dialplan_id = dp.id
        end
        di.status = "active"
         if di.save
        add_action2(session[:user_id], 'did_assigned_to_dp', di.id, dp.id)
         else
           bad_num += 1
        end
      end
      flash[:notice] = [bad_num.to_s, _('DIDs_were_not_updated')].join(" ") if  bad_num.to_i > 0
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
    @did = Did.where(:id => params[:id]).first
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
    did = Did.where(:id => params[:id]).first
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
      qfdid = Quickforwarddid.where(:id => params[:id]).first
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
    q = Quickforwarddid.where(:id => params[:id]).first
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
      @dps_created = (not Dialplan.find(:all, :conditions => "id != 1", :order => "name ASC").empty?)
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

    @users = User.select("users.id, users.username, users.first_name, users.last_name, #{SqlExport.nice_user_sql}").where(:hidden => 0, :owner_id => user_id).order("nice_user ASC").all

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
        if params[:device] and not (params[:device].strip.blank? or params[:device].strip.downcase == 'all')
          @device = current_user.load_users_devices(:first, :conditions => ["devices.id = #{params[:device]}"])
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

      if params[:s_device] and not (params[:s_device].strip.blank? or params[:s_device].strip.downcase == 'all')
        @s_device = current_user.load_users_devices(:first, :conditions => ["devices.id = #{params[:s_device]}"])
        unless @s_device
          flash[:notice] = _("Device_not_found")
          redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts)) and return false
        end
      end

      num = ActiveRecord::Base.connection.select_value("select COUNT(dids.id) from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null AND #{ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
      bad_num = ActiveRecord::Base.connection.select_value("select COUNT(dids.id) from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is NOT null AND #{ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
      if @s_device

        ActiveRecord::Base.connection.execute("UPDATE dids, ( select dids.id from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null) as v SET dids.user_id = #{@s_user.id}, device_id = #{@s_device.id}, status = 'active' where dids.id = v.id AND #{ ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
      else
        if @s_user.usertype=='reseller'
         # num = ActiveRecord::Base.connection.select_value("select COUNT(dids.id) from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null AND #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ;")
          ActiveRecord::Base.connection.execute("UPDATE dids, ( select dids.id from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null) as v SET reseller_id = #{@s_user.id}, dids.user_id = 0, device_id = 0, status = 'free' where dids.id = v.id AND #{ ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
       #   num = Did.update_all("reseller_id = #{@s_user.id}, user_id = 0, device_id = 0, status = 'free'", [cond.join(" AND "), *var])
        else
         # num = ActiveRecord::Base.connection.select_value("select COUNT(dids.id) from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null AND #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ;")
          ActiveRecord::Base.connection.execute("UPDATE dids, ( select dids.id from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null) as v SET dids.user_id = #{@s_user.id}, device_id = 0, status = 'reserved' where dids.id = v.id AND #{ ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
         # num = Did.update_all("user_id = #{@s_user.id}, device_id = 0, status = 'reserved'", [cond.join(" AND "), *var])
        end

      end
      flash[:notice] = [bad_num.to_s, _('DIDs_were_not_updated')].join(" ") if bad_num.to_i > 0
      flash[:status] = [num.to_s, _('DIDs_were_updated')].join(" ") if num.to_i > 0
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

    @qfddps = Dialplan.find(:all, :conditions => "id != 1 and dptype = 'quickforwarddids'", :order => "name ASC")

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
    @total_pages = (Did.count(:all, :conditions => ["user_id = ?", user.id])/session[:items_per_page].to_d).ceil
    @dids = Did.find(:all,
                     :conditions => ["user_id = ?", user.id],
                     :offset => session[:items_per_page]*(@page-1),
                     :limit => session[:items_per_page])
  end


  def summary
    @page_title = _('DIDs_report')

    if current_user.is_accountant? and !current_user.accountant_allow_edit('See_Financial_Data')
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    change_date

    @options = ((params[:clean] || !session[:dids_summary_list_options]) ? {} : session[:dids_summary_list_options])

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])


    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])

    params[:order_by] ? @options[:order_by_name] = params[:order_by].to_s : (@options[:order_by_name] = "" if !@options[:order_by_name])

    @options[:dids_grouping] = params[:dids_grouping].to_i == 0 ? (@options[:dids_grouping].to_i == 0 ? 1 : @options[:dids_grouping].to_i) :  params[:dids_grouping].to_i
    @options[:d_search] = params[:d_search].to_i == 0 ? (@options[:d_search].to_i == 0 ? 1 : @options[:d_search].to_i) :  params[:d_search].to_i
    @options[:from] = session_from_datetime
    @options[:till] = session_till_datetime
    (params[:provider_id] and params[:provider_id].to_s != "") ? @options[:provider] = params[:provider_id] : @options[:provider] = "any"
    (params[:did_number] and params[:did_number].to_s != "") ? @options[:did] = params[:did_number] : @options[:did] = ""
    (params[:user_id] and params[:user_id].to_s != "") ? @options[:user_id] = params[:user_id] : @options[:user_id] = "any"
    (params[:s_device] and params[:s_device].to_s != "") ? @options[:device_id] = params[:s_device] : @options[:device_id] = "all"
    (params[:s_days] and params[:s_days].to_s != "") ? @options[:sdays] = params[:s_days] : @options[:sdays] = "all"
    (params[:period] and params[:period].to_s != "") ? @options[:period] = params[:period] : @options[:period] = "-1"
    (params[:did_search_from] and params[:did_search_from].to_s != "") ? @options[:did_search_from] = params[:did_search_from] : @options[:did_search_from] = ""
    (params[:did_search_till] and params[:did_search_till].to_s != "") ? @options[:did_search_till] = params[:did_search_till] : @options[:did_search_till] = ""

    @options[:order_by], order_by = summary_order_by(params, @options)

    @dids_lines_full = Call.summary_by_dids(current_user, order_by, @options)

    @total = {:calls => 0, :min => 0, :inc => 0, :own => 0, :prov => 0}
    @dids_lines_full.each { |row|
      @total[:calls] += row.total_calls.to_i
      @total[:min] += row.dids_billsec.to_d
      #@total[:inc] += row.inc_price.to_d
      @total[:own] += row.own_price.to_d
      @total[:prov] += row.d_prov_price.to_d
    }

    # fetch required number of items.
    @dids_lines = []
    @total_items =  @dids_lines_full.size.to_i
    @total_pages = (@total_items.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page] > @total_pages
    start = session[:items_per_page]*(@options[:page]-1)
    (start..(start+session[:items_per_page])-1).each { |i|
      @dids_lines << @dids_lines_full[i] if @dids_lines_full[i]
    }

    @nice_days =  @options[:sdays].to_s == 'all' ? _('All') :   (@options[:sdays].to_s == 'wd' ?  _('Work_days') :   _('Free_days')    )
    d = Didrate.where({:id=>@options[:period]}).first
    @nice_period = d.start_time.strftime("%H:%M:%S").to_s + '-' + d.end_time.strftime("%H:%M:%S").to_s if d


    #@dids = Did.all
    @users = User.find_all_for_select
    if @options[:user_id] == 'any'
    @devices =   Device.where('user_id != -1').all
    else
      @user = User.find(params[:user_id])
      if @user and (["admin", "accountant"].include?(session[:usertype]) or @user.owner_id = corrected_user_id)
        @devices = @user.devices(:conditions => "device_type != 'FAX'").select('devices.*').joins('JOIN dids ON (dids.device_id = devices.id)').group('devices.id').all
      else
        @devices = []
      end
      end
    @providers = Provider.all
   # @days = [_('All'),_('Work_days'), _('Free_Days')]
    @periods = Didrate.find_hours_for_select({:day=> @options[:sdays], :did=>@options[:did], :d_search=>@options[:d_search].to_i == 1 ? 'true' : 'flase', :did_from=>@options[:did_search_from], :did_till=>@options[:did_search_till]})

    session[:dids_summary_list_options] = @options

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
      device = Device.where(:id => params[:device_id]).first

      unless device
        flash[:notice] = _('Device_not_found')
        redirect_to :action => "list"
      end
    end
  end

  def find_provider
    @provider = Provider.where(:id => params[:provider]).first
    unless @provider
      flash[:notice] = _('Provider_was_not_found')
      redirect_to :action => 'new'
    end
  end

  def find_dids
    @from = params[:from].to_i
    @till = params[:till].to_i
    active = params[:active].to_i
    
    @opts = {:from => @from, :till => @till, :active => active.to_i}

    var = [@from, @till]
    cond = ["dids.did BETWEEN ? AND ?"]
    if params[:did] and params[:did][:provider_id] and !params[:did][:provider_id].strip.blank?
      @provider = Provider.where(:id => params[:did][:provider_id]).first
      var << params[:did][:provider_id].to_i
      cond << "dids.provider_id = ?"
    end
    if reseller?
      cond << "dids.reseller_id = ?"
      var << current_user.id
    end
    if params[:user] and !params[:user].strip.blank?
      @user = User.where(:id => params[:user].strip).first
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
          @device = Device.where(:id => params[:device].strip, :user_id => @user.id).first
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
   
    @dids = Did.where([cond.join(" AND "), *var]).all
  end

  def check_dids_creation
    if !allow_manage_dids? and !['admin', 'accountant'].include?(current_user.usertype)
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    if current_user.usertype == 'reseller' and params[:provider] and current_user.own_providers.to_i == 1 and !current_user.providers.find(:first, :conditions => ["providers.id = ? ", params[:provider]]) and params[:provider] != Confline.get_value("DID_default_provider_to_resellers").to_i
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
      u = User.where(:id => params[:user_id]).first
      if current_user.usertype == 'reseller' and (!params[:user_id] or !u or u.owner_id != correct_owner_id)
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end
    if params[:status] == "active"
      device = Device.where(:id => params[:device_id]).first
      if current_user.usertype == 'reseller' and (!device or !Device.find(:first, :joins => "LEFT JOIN users ON (devices.user_id = users.id)", :conditions => "devices.id = #{device.id} and (users.owner_id = #{current_user.id} or users.id = #{current_user.id})"))
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end
    if params[:did] and params[:did][:provider_id]
      if current_user.usertype == 'reseller' and params[:did][:provider_id] and current_user.own_providers.to_i == 1 and !current_user.providers.find(:first, :conditions => ["providers.id = ?", params[:did][:provider_id]]) and params[:did][:provider_id] != Confline.get_value("DID_default_provider_to_resellers").to_i
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main' and return false
      end

      if current_user.usertype == 'reseller' and params[:did][:provider_id] and current_user.own_providers.to_i == 0 and params[:did][:provider_id].to_i != Confline.get_value("DID_default_provider_to_resellers").to_i
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main' and return false
      end
    end

  end

=begin rdoc
  Transaltes order_by param to database fields for summary report.
=end

  def summary_order_by(params, options)
    case params[:order_by].to_s
      when "nice_user" then
        order_by = "nice_user"
      when "did" then
        order_by = "did"
      when "provider" then
        order_by = "providers.name"
      when "comment" then
        order_by = "dids.comment"
      when "calls" then
        order_by = "total_calls"
      when "billed_duration" then
        order_by = "dids_billsec"
      when "owner_price" then
        order_by = "own_price"
      when "provider_price" then
        order_by = "d_prov_price"
      else
        options[:order_by] ? order_by = options[:order_by] : order_by = ""
    end

    without = order_by
    order_by += " ASC" if options[:order_desc] == 0 and order_by != ""
    order_by += " DESC" if options[:order_desc] == 1 and order_by != ""
    return without, order_by
  end
end
