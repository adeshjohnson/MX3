# -*- encoding : utf-8 -*-
class UsersController < ApplicationController


  layout "callc"

  include SqlExport

  before_filter :check_post_method, :only => [:destroy, :create, :update, :update_personal_details]
  before_filter :authorize, :except => [:daily_actions]
  before_filter :check_localization, :except => [:daily_actions]
  before_filter { |c|
    view = [:list, :index, :reseller_users, :show, :edit, :device_groups, :custom_rates, :user_acustrates_full, :user_acustrates, :default_user]
    edit = [:new, :create, :update, :destroy, :hide, :device_group_edit, :device_group_update, :device_group_new, :device_group_create, :device_group_delete, :update_personal_details, :user_custom_rate_add_new, :user_delete_custom_rate, :artg_destroy, :ard_manage, :user_ard_time_edit, :user_custom_rate_update, :user_custom_rate_update, :user_custom_rate_delete, :default_user_update]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_user_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }
  before_filter :find_user, :only => [:update, :device_group_create, :device_groups, :device_group_new, :custom_rates, :user_custom_rate_add_new, :user_acustrates_full, :monitorings]
  before_filter :find_user_from_session, :only => [:update_personal_details, :personal_details]
  before_filter :find_devicegroup, :only => [:device_group_delete, :device_group_update, :device_group_edit]
  before_filter :find_customrate, :only => [:user_delete_custom_rate, :artg_destroy, :ard_manage, :user_ard_time_edit, :user_acustrates, :user_custom_rate_add]
  before_filter :find_ard, :only => [:user_custom_rate_delete, :user_custom_rate_update]
  before_filter :find_ard_all, :only => [:artg_destroy, :user_ard_time_edit, :user_acustrates]
  before_filter :check_params, :only => [:create, :update, :default_user_update]
  before_filter :check_with_integrity, :only => [:edit, :list, :new, :default_user, :users_postpaid_and_allowed_loss_calls, :default_user_errors_list]


  def index
    list
    render :action => 'list'
  end

  def list
    @page_title = _('Users')
    @page_icon = 'vcard.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Users"

    logger.fatal "fffffffffffffffffffffffffffffff"
    @default_currency = Currency.find(:first).name
    @roles = Role.find(:all, :conditions => ["name !='guest'"])

    default = {
        :items_per_page => session[:items_per_page].to_i,
        :page => "1",
        :order_by => "nice_user",
        :order_desc => 0,
        :s_username => "",
        :s_first_name => "",
        :s_last_name => "",
        :s_agr_number => "",
        :s_acc_number => "",
        :s_clientid => "",
        :sub_s => "-1",
        :user_type => "-1",
        :s_email => "",
        :s_id => ""
    }

    if params[:clean]
      @options = default
    else
      @options = ((params[:clear] || !session[:user_list_stats]) ? default : session[:user_list_stats])
    end

    default.each { |key, value| @options[key] = params[key] if params[key] }


    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc] == 1 ? " DESC" : " ASC")
    @options[:order] = User.users_order_by(params, @options)


    owner = correct_owner_id
    cond = ["users.hidden = 0 AND users.owner_id = ?"]
    joins, group_by, var = [], nil, [owner]
    select = ["users.*", "tariffs.purpose", "#{SqlExport.nice_user_sql}"]

    add_contition_and_param(@options[:user_type], @options[:user_type], "users.usertype = ?", cond, var) if @options[:user_type].to_i != -1
    add_contition_and_param(@options[:s_id], @options[:s_id], "users.id = ?", cond, var) if @options[:s_id].to_i != -1
    add_contition_and_param(@options[:s_agr_number], @options[:s_agr_number].to_s+"%", "users.agreement_number LIKE ?", cond, var) if !@options[:s_agr_number].blank?
    add_contition_and_param(@options[:s_acc_number], @options[:s_acc_number].to_s+"%", "users.accounting_number LIKE ?", cond, var) if !@options[:s_acc_number].blank?
    add_contition_and_param(@options[:s_email], @options[:s_email].to_s, "email = ?", cond, var) if !@options[:s_email].blank?

    ["first_name", "username", "last_name", "clientid"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], "%"+@options["s_#{col}".intern].to_s+"%", "users.#{col} LIKE ?", cond, var) }

    unless @options[:s_email].blank?
      joins << "LEFT JOIN addresses ON (users.address_id = addresses.id)"
    end

    if @options[:sub_s].to_i > -1
      group_by = "users.id HAVING subscriptions_count#{@options[:sub_s].to_i == 0 ? " = 0" : " > 0"}"
      select << "count(subscriptions.id) as 'subscriptions_count'"
      joins << "LEFT JOIN subscriptions ON (users.id = subscriptions.user_id)"
    end
    # ///////
    joins << "LEFT JOIN tariffs ON users.tariff_id = tariffs.id"

    # page params
    @user_size = User.find(:all, :select => select.join(","), :joins => joins.join(" "), :conditions => [cond.join(" AND "), *var], :group => group_by)
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@user_size.size.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    #we need to left join acc_groups, addreses and lcrs. When COUNTING users this data is irelevant,
    #so no need for extra joins there
    #Select addresses.county(that's right), addresses.city, lcrs.name, tariffs.name, acc_groups_name
    #so that rails wouldnt generate extra queries.
    if @options[:s_email].blank?
      joins << "LEFT JOIN addresses ON users.address_id = addresses.id"
    end
    joins << "LEFT JOIN lcrs ON users.lcr_id = lcrs.id"
    joins << "LEFT JOIN acc_groups ON users.acc_group_id = acc_groups.id"
    select << "addresses.city, addresses.county"
    select << "lcrs.name AS lcr_name"
    select << "tariffs.name AS tariff_name"
    select << "acc_groups.name AS acc_group_name"

    @users = User.find(:all, :select => select.join(","), :joins => joins.join(" "), :conditions => [cond.join(" AND "), *var], :order => @options[:order], :group => group_by, :limit => "#{fpage}, #{session[:items_per_page].to_i}")
    @search = ((cond.size > 1 or @options[:sub_s].to_i > -1) ? 1 : 0)

    session[:user_list_stats] = @options
  end


  def reseller_users
    @page_title = _('Reseller_users')
    @page_icon = 'vcard.png'

    @reseller = User.find(:first, :conditions => ["id = ?", params[:id]]) if params[:id].to_i > 0
    if not @reseller
      flash[:notice] = _("Not_found")
      redirect_to :controller => "stats", :action => "resellers" and return false
    end

    @users = @reseller.reseller_users
  end

  def hidden
    @page_title = _('Hidden_users')
    @page_icon = 'vcard.png'
    #    @user_pages, @users = paginate :users, :per_page => 40

    @default_currency = Currency.find(:first).name
    @roles = Role.find(:all, :conditions => ["name !='guest'"])

    default = {
        :items_per_page => session[:items_per_page].to_i,
        :page => "1",
        :order_by => "nice_user",
        :order_desc => 0,
        :s_username => "",
        :s_first_name => "",
        :s_last_name => "",
        :s_agr_number => "",
        :s_acc_number => "",
        :s_clientid => "",
        :sub_s => "-1",
        :user_type => "-1",
        :s_email => "",
        :s_id => ""
    }

    if params[:clean]
      @options = default
    else
      @options = ((params[:clear] || !session[:user_hiden_stats]) ? default : session[:user_hiden_stats])
    end

    default.each { |key, value| @options[key] = params[key] if params[key] }


    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc] == 1 ? " DESC" : " ASC")
    @options[:order] = User.users_order_by(params, @options)

    owner = correct_owner_id
    cond = ["users.hidden = 1 AND users.owner_id = ?"]
    joins, var = [], [owner]
    select = ["users.*", "#{SqlExport.nice_user_sql}"]
    add_contition_and_param(@options[:user_type], @options[:user_type], "users.usertype = ?", cond, var) if @options[:user_type].to_i != -1
    add_contition_and_param(@options[:s_id], @options[:s_id], "users.id = ?", cond, var) if @options[:s_id].to_i != -1
    add_contition_and_param(@options[:s_agr_number], @options[:s_agr_number].to_s+"%", "users.agreement_number LIKE ?", cond, var) if !@options[:s_agr_number].blank?
    add_contition_and_param(@options[:s_acc_number], @options[:s_acc_number].to_s+"%", "users.accounting_number LIKE ?", cond, var) if !@options[:s_acc_number].blank?
    add_contition_and_param(@options[:s_email], @options[:s_email].to_s, "email = ?", cond, var) if !@options[:s_email].blank?

    ["first_name", "username", "last_name", "clientid"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], "%"+@options["s_#{col}".intern].to_s+"%", "users.#{col} LIKE ?", cond, var) }

    unless @options[:s_email].blank?
      joins << "LEFT JOIN addresses ON (users.address_id = addresses.id)"
    end

    if @options[:sub_s].to_i > -1
      group_by = "users.id HAVING subscriptions_count#{@options[:sub_s].to_i == 0 ? " = 0" : " > 0"}"
      select << "count(subscriptions.id) as 'subscriptions_count'"
      joins << "LEFT JOIN subscriptions ON (users.id = subscriptions.user_id)"
    end
    # ///////

    joins and joins.size > 0 ? joins = joins.join(" ") : joins = nil

    # page params
    @user_size = User.find(:all, :select => select.join(","), :joins => joins, :conditions => [cond.join(" AND "), *var], :group => group_by)
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@user_size.size.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    fpage = ((@options[:page] -1) * session[:items_per_page]).to_i


    @users = User.find(:all, :select => select.join(","), :joins => joins, :conditions => [cond.join(" AND "), *var], :order => @options[:order], :group => group_by, :limit => "#{fpage}, #{session[:items_per_page].to_i}")
    @search = ((cond.size > 1 or @options[:sub_s].to_i > -1) ? 1 : 0)

    session[:user_hiden_stats] = @options
  end


  def hide
    user = User.find(:first, :conditions => ["id = ?", params[:id]])
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => 'list' and return false
    end

    if user.hidden == 1
      user.hidden = 0
      user.save
      flash[:status] = _('User_unhidden')+": "+nice_user(user)
      redirect_to :action => 'list'
    else
      user.hidden = 1
      user.save
      flash[:status] = _('User_hidden')+": "+nice_user(user)
      redirect_to :action => 'hidden'
    end

  end


  def show
    @user = User.find(:first, :conditions => ["id = ?", params[:id]])
  end

  def new
    @page_title = _('New_user')
    @page_icon = "add.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/User_Details"

    check_for_accountant_create_user
    @lcrs = current_user.load_lcrs(:all, :order => "name ASC")
    @groups = AccGroup.find(:all, :conditions => "group_type = 'accountant'")
    @groups_resellers = AccGroup.find(:all, :conditions => "group_type = 'reseller'")
    #@sms_lcrs = SmsLcr.find(:all)
    if session[:usertype] == "accountant"
      owner = User.find(session[:user_id].to_i).owner_id.to_i
    else
      owner = session[:user_id]
    end
    #@sms_tariffs = SmsTariff.find(:all, :conditions => "(tariff_type = 'user') AND owner_id = '#{owner}' ", :order => "tariff_type ASC, name ASC")
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{owner}' #{cond} ", :order => "purpose ASC, name ASC")

    @countries = Direction.find(:all, :order => "name ASC")
    @default_country_id = Confline.get_value("Default_Country_ID").to_i
    if @lcrs.empty? and allow_manage_providers?
      flash[:notice] = _('No_lcrs_found_user_not_functional')
      redirect_to :action => 'list' and return false
    end

    if @tariffs.empty?
      flash[:notice] = _('No_tariffs_found_user_not_functional')
      redirect_to :action => 'list' and return false
    end

    @user = Confline.get_default_object(User, owner)
    @user.agreement_date = Time.now().to_s(:db)
    @user.owner_id = owner
    @address = Confline.get_default_object(Address, owner)
    @tax = Confline.get_default_object(Tax, owner)
    @user.tax = @tax
    @user.address = @address
    @user.agreement_number = next_agreement_number
    if Confline.get_value("Default_User_recording_enabled").to_i == 1
      @user.recording_enabled = 1
    end

    @i = @user.get_invoices_status
  end

  def create
    #MorLog.my_debug params.to_yaml
    @page_title = _('New_user')
    @page_icon = "add.png"

    check_for_accountant_create_user
    sanitize_user_params_by_accountant_permissions

    params[:user] = params[:user].each_value(&:strip!)
    params[:address] = params[:address].each_value(&:strip!) if params[:address]

    #accountant cannot create accountant
    if session[:usertype] == 'accountant' and ['accountant'].include?(params[:user][:usertype])
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    if ["accountant", "reseller"].include?(params[:user][:usertype])
      if params[:accountant_type].to_i == 0
        dont_be_so_smart
        redirect_to :controller => "callc", :action => 'main' and return false
      else
        params[:user][:acc_group_id] = params[:accountant_type].to_i
      end
    else
      params[:user][:acc_group_id] = 0
    end

    if params[:privacy]
      if params[:privacy][:global].to_i == 1
        params[:user][:hide_destination_end] = -1
      else
        params[:user][:hide_destination_end] = params[:privacy].values.sum { |v| v.to_i }
      end
    end

    params[:cyberplat_active].to_i == 1 ? params[:user][:cyberplat_active] == 1 : params[:user][:cyberplat_active] == 0
    params[:user][:generate_invoice].to_i == 1 ? params[:user][:generate_invoice] = 1 : params[:user][:generate_invoice] = 0

    #    if  !Email.address_validation(params[:address][:email]) and params[:address][:email].to_s.length > 0
    #      flash[:notice] = _('Please_enter_correct_email')
    #      redirect_to :action => 'new' and return false
    #    end

    owner_id = correct_owner_id
    if session[:usertype] == "reseller" and params[:user][:usertype] != "user"
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    if session[:usertype] == "accountant" and params[:user][:usertype] == "admin"
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    @user = Confline.get_default_object(User, owner_id)
    @user.attributes= params[:user]
    @user.owner_id = owner_id
    @user.warning_email_balance = params[:user][:warning_email_balance].to_f
    @user.warning_email_active = params[:user][:warning_email_active].to_i
    @user.password = Digest::SHA1.hexdigest(params[:password][:password].strip)
    @user.recording_hdd_quota = (params[:user][:recording_hdd_quota].to_f * 1048576).to_i
    @user.agreement_date = params[:agr_date][:year].to_s + "-" + params[:agr_date][:month].to_s + "-" + params[:agr_date][:day].to_s

    @invoice = invoice_params_for_user
    @user.send_invoice_types = @invoice
    @user.cyberplat_active = params[:cyberplat_active].to_i

    if params[:unlimited] == "1"
      @user.credit = -1
    else
      @user.credit = params[:credit].to_f
      @user.credit = 0 if @user.credit < 0
    end

    @lcrs = current_user.load_lcrs(:all, :order => "name ASC")
    @tariffs = Tariff.find(:all, :conditions => "purpose = 'user' AND owner_id = '#{session[:user_id]}'")
    @countries = Direction.find(:all, :order => "name ASC")

    @user.block_conditional_use = params[:block_conditional_use].to_i
    @user.allow_loss_calls = params[:allow_loss_calls].to_i

    tax = Tax.create(tax_from_params)

    @user.tax_id = tax.id

    @user.warning_email_active = params[:warning_email_active].to_i
    @user.invoice_zero_calls = params[:show_zero_calls].to_i

    @user.own_providers = params[:own_providers].to_i if @user.usertype == 'reseller'

    if monitoring_enabled_for(current_user)
      @user.ignore_global_monitorings = params[:ignore_global_monitorings].to_i
    end

    #reseller support
    if @user.owner_id != 0
      reseller = User.find(@user.owner_id)
      unless reseller.can_own_providers?
        @user.lcr_id = reseller.lcr_id
      end
      #ticket #5246 
      #@user.allow_loss_calls = reseller.allow_loss_calls
    end

    if rec_active?
      @user.recording_enabled = params[:recording_enabled].to_i
      @user.recording_forced_enabled = params[:recording_forced_enabled].to_i
    else
      @user.recording_enabled = 0
      @user.recording_forced_enabled = 0
    end
    @user.balance = params[:user][:balance].to_f

    if params[:warning_email_active]
      @user.warning_email_hour = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
    end

    @address = Address.new(params[:address])
    if @address.save
      @user.address_id = @address.id
    else
      @user.tax.destroy if @user.tax
      @user.address.destroy if @user.address
      @i = @user.get_invoices_status
      flash_errors_for(_('User_was_not_created'), @address)
      render :action => 'new' and return false
    end

    if @user.postpaid? and Confline.mor_11_extended?
      @user.minimal_charge = params[:minimal_charge_value].to_i
      if params[:minimal_charge_value].to_i != 0 and params[:minimal_charge_date]
        year = params[:minimal_charge_date][:year].to_i
        month = params[:minimal_charge_date][:month].to_i
        day = 1
        @user.minimal_charge_start_at = Date.new(year, month, day)
      elsif params[:minimal_charge_value].to_i == 0
        @user.minimal_charge_start_at = nil
      end
    end


    if @user.valid? and User.create(@user.attributes)

      flash[:status] = _('user_created')
      redirect_to :action => 'list' and return false
    else
      @user.tax.destroy if @user.tax
      @user.address.destroy if @user.address
      @user.fix_when_is_rendering
      @i = @user.get_invoices_status
      @groups = AccGroup.find(:all, :conditions => "group_type = 'accountant'")
      @groups_resellers = AccGroup.find(:all, :conditions => "group_type = 'reseller'")
      flash_errors_for(_('User_was_not_created'), @user)
      render :action => 'new' and return false
    end
  end

  def edit
    @return_controller = "users"
    @return_action = "list"
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    redirect_to :action => 'list' and return false if not params[:id]
    @user = User.find(:first, :include => [:address, :tax], :conditions => ["users.id = ?", params[:id]])
    redirect_to :action => 'list' and return false if not @user

    check_owner_for_user(@user.id)

    @page_title = _('users_settings')+": "+nice_user(@user)
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/User_Details"


    @i = @user.get_invoices_status

    @lcrs = current_user.load_lcrs(:all, :order => "name ASC")

    session[:usertype] == "accountant" ? owner = 0 : owner = session[:user_id]

    #@sms_tariffs = SmsTariff.find(:all, :conditions => "(tariff_type = 'user') AND owner_id = '#{owner}' ", :order => "tariff_type ASC, name ASC")
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{owner}' #{cond} ", :order => "purpose ASC, name ASC")

    @countries = Direction.find(:all, :order => "name ASC")

    #for backwards compatibility - user had no address before, so let's give it to him
    if not @user.address
      address = Address.new
      address.save
      @user.address_id = address.id
      @user.save
    end

    if !@user.tax or @user.tax_id.to_i == 0
      @user.assign_default_tax
    end
    @total_recordings_size = Recording.find(:all, :first, :select => "SUM(size) AS 'total_size'", :conditions => ["user_id = ? AND deleted = 0", @user.id])[0]["total_size"].to_f
    @address = @user.address
    @groups = AccGroup.find(:all, :conditions => "group_type = 'accountant'")
    @groups_resellers = AccGroup.find(:all, :conditions => "group_type = 'reseller'")

    @chanspy_disabled = Confline.chanspy_disabled?
    #if @user.usertype == 'user' or @user.usertype == 'accountant'
    @devices = @user.devices(:conditions => "device_type != 'FAX'")
    #    else
    #      @devices = Device.find_all_for_select(corrected_user_id)
    #    end

    flash[:notice] = _('No_lcrs_found_user_not_functional') if @lcrs.empty?
    flash[:notice] = _('No_tariffs_found_user_not_functional') if @tariffs.empty?
  end

  # sets @user in before filter
  def update
    a = check_owner_for_user(@user.id)
    return false unless a

    notice, par = @user.validate_from_update(current_user, params, @allow_edit)
    if !notice.blank?
      flash[:notice] = notice
      redirect_to :controller => :callc, :action => :main and return false
    end

    @user.update_from_edit(par, current_user, tax_from_params, monitoring_enabled_for(current_user), rec_active?)
    @return_controller = "users"
    @return_action = "list"

    if @user.save
      if @user.usertype == "reseller"
        @user.check_default_user_conflines
      end
      # @user.address.update_attributes(params[:address])
      @user.address.save
      #my_debug @user.send_invoice_types
      flash[:status] = _('user_details_changed')+": "+nice_user(@user)
      redirect_to(:action => :edit, :id => @user.id) and return false
    else
      check_owner_for_user(@user.id)

      @i = @user.get_invoices_status

      @lcrs = current_user.load_lcrs(:all, :order => "name ASC")
      #@sms_lcrs = SmsLcr.find(:all)
      if session[:usertype] == "accountant"
        owner = User.find(session[:user_id].to_i).get_owner.id.to_i
      else
        owner = session[:user_id]
      end

      if Confline.get_value("User_Wholesale_Enabled").to_i == 0
        cond = " AND purpose = 'user' "
      else
        cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
      end
      @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{owner}' #{cond} ", :order => "purpose ASC, name ASC")

      @countries = Direction.find(:all, :order => "name ASC")

      #for backwards compatibility - user had no address before, so let's give it to him
      if not @user.address
        address = Address.new
        address.save
        @user.address_id = address.id
        @user.save
      end
      @user.fix_when_is_rendering
      @user.assign_default_tax if !@user.tax or @user.tax_id.to_i == 0
      @total_recordings_size = Recording.find(:all, :first, :select => "SUM(size) AS 'total_size'", :conditions => ["user_id = ? AND deleted = 0", @user.id])[0]["total_size"].to_f
      @address = @user.address
      @groups = AccGroup.find(:all, :conditions => "group_type = 'accountant'")
      @groups_resellers = AccGroup.find(:all, :conditions => "group_type = 'reseller'")
      #if @user.usertype == 'user' or @user.usertype == 'accountant'
      @devices = @user.devices(:conditions => "device_type != 'FAX'")
      #      else
      #        @devices = Device.find_all_for_select(corrected_user_id)
      #      end
      flash_errors_for(_('User_was_not_updated'), @user)
      render :action => 'edit'
    end
  end

  def destroy
    return_controller = "users"
    return_action = "list"
    return_controller = params[:return_to_controller] if params[:return_to_controller]
    return_action = params[:return_to_action] if params[:return_to_action]

    user = User.find(:first, :conditions => ["id = ?", params[:id]])
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => "list" and return false
    end
    error = check_owner_for_user(user)
    if !error
      dont_be_so_smart and return false
    end

    devices = user.devices
    for device in devices
      if device.has_forwarded_calls
        flash[:notice] = _('Cant_delete_user_has_forwarded_calls')
        redirect_to :controller => return_controller, :action => return_action and return false
      end
    end

    #    actions = Action.find(:all, :conditions=> "data = '#{user.id}' AND (action != 'did%' OR action ='did_reserved')")
    #    my_debug("data = '#{user.id}' AND (action != 'did%' OR action ='did_reserved')")
    #    for action in actions
    #        flash[:notice] = _('Cant_delete_user_has_actions_data')
    #        redirect_to :controller => return_controller, :action => return_action and return false
    #    end

    if user.id.to_i == session[:user_id]
      flash[:notice] = _('Cant_delete_self')
      redirect_to :controller => return_controller, :action => return_action and return false
    end

    if user.dids.size > 0
      flash[:notice] = _('Cant_delete_user_it_has_dids')
      redirect_to :controller => return_controller, :action => return_action and return false
    end

    if user.all_calls.size > 0
      flash[:notice] = _('Cant_delete_user_has_calls')
      redirect_to :controller => return_controller, :action => return_action and return false
    end


    if user.payments.size > 0
      flash[:notice] = _('Cant_delete_user_it_has_payments')
      redirect_to :controller => return_controller, :action => return_action and return false
    end

    if user.usertype == 'reseller'
      rusers = User.count(:all, :conditions => ["owner_id = ?", user.id]).to_i
      if rusers > 0
        flash[:notice] = _('Cant_delete_reseller_whit_users')
        redirect_to :controller => return_controller, :action => return_action and return false
      end
    end

    if params[:id].to_i != 0
      user.destroy_everything
      flash[:status] = _('User_deleted')
    else
      flash[:notice] = _('Cant_delete_sysadmin')
    end

    redirect_to :controller => return_controller, :action => return_action
  end


  ############# Device groups ###########
=begin
in before filter : user (:find_user)
=end
  def device_groups
    @page_title = _('Device_groups')
    @page_icon = "groups.png"

    @devicegroups = @user.devicegroups
    #for backwards compatibility - user had no device group before, so let's create one for him
    if not @user.primary_device_group
      devgroup = Devicegroup.new
      devgroup.init_primary(@user.id, "primary", @user.address_id)
    end
  end

=begin
in before filter : devicegroup (:find_devicegroup)
=end
  def device_group_edit
    @page_title = _('Device_group_edit')
    @page_icon = "edit.png"

    @user = @devicegroup.user
    @countries = Direction.find(:all, :order => "name ASC")
    @address = @devicegroup.address
  end

=begin
in before filter : devicegroup (:find_devicegroup)
=end
  def device_group_update
    @devicegroup.update_attributes(params[:devicegroup])
    @devicegroup.save

    @address = @devicegroup.address
    @address.update_attributes(params[:address])
    if @address.save

      flash[:status] = _('Dev_groups_details_changed')
      redirect_to :action => 'device_groups', :id => @devicegroup.user.id
    else
      @user = @devicegroup.user
      @countries = Direction.find(:all, :order => "name ASC")

      flash_errors_for(_('Dev_group_details_not_changed'), @address)
      render :action => :device_group_edit
    end
  end

=begin
in before filter : user (:find_user)
=end
  def device_group_new
    @page_title = _('Device_group_new')
    @page_icon = "add.png"

    @devicegroup = Devicegroup.new
    @devicegroup.added = Time.now
    @devicegroup.name = _('Please_change')

    @countries = Direction.find(:all, :order => "name ASC")
  end

=begin
in before filter : user (:find_user)
=end
  def device_group_create
    @address = Address.new(params[:address])

    @devicegroup = Devicegroup.new(:user_id => @user.id, :name => params[:devicegroup][:name], :added => Time.now().to_s(:db))
    if @address.save

      @devicegroup.address_id = @address.id

      if @devicegroup.save
        flash[:status] = _('Dev_group_created')
        redirect_to :action => 'device_groups', :id => @devicegroup.user.id and return false
      else

        @countries = Direction.find(:all, :order => "name ASC")
        flash_errors_for(_('Dev_group_not_created'), @devicegroup)
        render :action => :device_group_new
      end
    else

      @countries = Direction.find(:all, :order => "name ASC")
      flash_errors_for(_('Dev_group_not_created'), @address)
      render :action => :device_group_new
    end
  end

=begin
in before filter : devicegroup (:find_devicegroup)
=end
  def device_group_delete
    user_id = @devicegroup.user_id
    if @devicegroup.destroy_everything
      flash[:status] = _('Dev_group_deleted')
    else
      flash[:notice] = _('Dev_group_not_deleted')
    end
    redirect_to :action => 'device_groups', :id => user_id
  end

  # in before filter : user (find_user_from_session)
  def personal_details
    @page_title = _('Personal_details')
    @page_icon = "edit.png"

    @address = @user.address
    @countries = Direction.find(:all, :order => "name ASC")
    @total_recordings_size = Recording.find(:all, :first, :select => "SUM(size) AS 'total_size'", :conditions => ["user_id = ?", @user.id])[0]["total_size"].to_f
    @i = @user.get_invoices_status

    @disallow_email_editing = Confline.get_value("Disallow_Email_Editing", current_user.owner.id) == "1"

    if not @user.address
      address = Address.new
      address.save
      @user.address_id = address.id
      @user.save
    end

    if current_user.usertype == 'user' or current_user.usertype == 'accountant'
      @devices = current_user.devices(:conditions => "device_type != 'FAX'")
    else
      @devices = Device.find_all_for_select(corrected_user_id)
    end
  end

  # in before filter : user (find_user_from_session)
  def update_personal_details

    usertype = @user.usertype
    unless current_user.check_for_own_providers
      @invoice = invoice_params_for_user

      @user.send_invoice_types = @invoice
    end

    @user.update_attributes(current_user.safe_attributtes(params[:user].each_value(&:strip!), @user.id))
    @user.usertype = usertype
    @user.warning_email_active = params[:warning_email_active].to_i
    @user.password = Digest::SHA1.hexdigest(params[:password][:password]) if params[:password][:password].length > 0
    @user.warning_email_hour = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:user_warning_email_hour].to_i : params[:user][:user_warning_email_hour].to_i
    if !@user.address
      a = Address.create(params[:address].each_value(&:strip!)) if params[:address]
      @user.address_id = a.id
    else
      if Confline.get_value("Disallow_Email_Editing", current_user.owner.id) == "1" and current_user.id != @user.owner.id
        @user.address.update_attributes(params[:address].except('email').each_value(&:strip!)) if params[:address]
      else
        @user.address.update_attributes(params[:address].each_value(&:strip!)) if params[:address]
      end
    end

    if @user.save

      #renew_session(@user)

      session[:first_name] = @user.first_name
      session[:last_name] = @user.last_name
      @user.address.save
      session[:show_currency] = @user.currency.name
      flash[:status] = _('Personal_details_changed')
      redirect_to :controller => "callc", :action => 'main'
    else
      if current_user.usertype == 'user' or current_user.usertype == 'accountant'
        @devices = current_user.devices(:conditions => "device_type != 'FAX'")
      else
        @devices = Device.find_all_for_select(corrected_user_id)
      end
      @countries = Direction.find(:all, :order => "name ASC")
      @total_recordings_size = Recording.find(:all, :first, :select => "SUM(size) AS 'total_size'", :conditions => ["user_id = ?", @user.id])[0]["total_size"].to_f
      @i = @user.get_invoices_status
      @address = @user.address
      flash_errors_for(_('User_was_not_updated'), @user)
      render :action => 'personal_details'
    end
  end


  # ============== CUSTOM RATES ===============

=begin
in before filter : user (:find_user)
=end
  def custom_rates
    @page_title = _('Custom_rates')
    @page_icon = "coins.png"

    @tariff = @user.tariff
    @crates = @user.customrates
    sql = "SELECT destinationgroups.id FROM destinationgroups, users, customrates WHERE customrates.user_id = users.id AND customrates.destinationgroup_id = destinationgroups.id AND user_id = #{@user.id} ORDER BY destinationgroups.name"
    udestgroups = ActiveRecord::Base.connection.select_all(sql)
    udg = []
    for i in udestgroups
      udg << i["id"].to_i
    end

    @destgroups = []
    for dg in Destinationgroup.find(:all, :order => "name ASC")
      @destgroups << dg if not udg.include?(dg.id)
    end
  end

=begin
in before filter : user (:find_user)
=end
  def user_custom_rate_add_new
    rate = Customrate.new
    rate.user_id = @user.id
    rate.destinationgroup_id = params[:dg_new]
    rate.save

    ard = Acustratedetail.new
    ard.from = 1
    ard.duration = -1
    ard.artype = "minute"
    ard.round = 1
    ard.price = 0
    ard.customrate_id = rate.id
    ard.save
    flash[:status] = _('Custom_rate_added')
    redirect_to :action => 'custom_rates', :id => @user.id
  end

=begin
in before filter : customrate (:find_customrate)
=end
  def user_delete_custom_rate
    user_id = @customrate.user_id
    @customrate.destroy_all
    flash[:status] = _('Custom_rate_deleted')
    redirect_to :action => 'custom_rates', :id => user_id
  end

=begin
in before filter : customrate (:find_customrate) ; ards (:find_ard_all)
=end
  def artg_destroy
    dt = params[:dt] ? params[:dt] : ''

    pet = nice_time2(@ards[0].start_time - 1.second)

    @ards.eatch { |a| a.destroy }

    pards = Acustratedetail.find(:all, :conditions => ["customrate_id = ? AND end_time = ? AND daytype = ?", @customrate.id, pet, dt])

    if not pards or (pards and pards.size.to_i == 0)
      flash[:notice] = _('Acustratedetails_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end

    pards.eatch { |pa| pa.end_time = "23:59:59"; pa.save }

    flash[:status] = _('Rate_details_updated')
    redirect_to :action => 'user_acustrates_full', :id => @customrate.user_id, :dg => @customrate.destinationgroup_id
  end

=begin
in before filter : customrate (:find_customrate)
=end
  def ard_manage
    rdetails = @customrate.acustratedetails
    rdaction = params[:rdaction]

    if rdaction == "COMB_WD"
      for rd in rdetails
        if rd.daytype == "WD"
          rd.daytype = ""
          rd.save
        else
          rd.destroy
        end
      end
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == "COMB_FD"
      for rd in rdetails
        if rd.daytype == "FD"
          rd.daytype = ""
          rd.save
        else
          rd.destroy
        end
      end
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == "SPLIT"
      for rd in rdetails
        nrd = Acustratedetail.new
        nrd.start_time = rd.start_time
        nrd.end_time = rd.end_time
        nrd.from = rd.from
        nrd.duration = rd.duration
        nrd.customrate_id = rd.customrate_id
        nrd.artype = rd.artype
        nrd.round = rd.round
        nrd.price = rd.price
        nrd.daytype = "FD"
        nrd.save

        rd.daytype = "WD"
        rd.save
      end
      flash[:status] = _('Rate_details_split')
    end
    redirect_to :action => 'user_acustrates_full', :id => @customrate.user_id, :dg => @customrate.destinationgroup_id
  end

=begin
in before filter : user (:find_user)
=end
  def user_acustrates_full
    @page_title = _('Custom_rate_details')
    @page_icon = "coins.png"

    @dgroup = Destinationgroup.find(params[:dg])
    @custrate = @dgroup.custom_rate(@user.id)
    @rate = @custrate
    @ards = @custrate.acustratedetails

    if @ards[0].daytype == ""
      @WDFD = true
      sql = "SELECT start_time, end_time FROM acustratedetails WHERE daytype = '' AND customrate_id = #{@custrate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for r in res
        @st_arr << r["start_time"]
        @et_arr << r["end_time"]
      end
    else
      @WDFD = false
      sql = "SELECT start_time, end_time FROM acustratedetails WHERE daytype = 'WD' AND customrate_id = #{@custrate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Wst_arr = []
      @Wet_arr = []
      for r in res
        @Wst_arr << r["start_time"]
        @Wet_arr << r["end_time"]
      end

      sql = "SELECT start_time, end_time FROM acustratedetails WHERE daytype = 'FD' AND customrate_id = #{@custrate.id} GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Fst_arr = []
      @Fet_arr = []
      for r in res
        @Fst_arr << r["start_time"]
        @Fet_arr << r["end_time"]
      end
    end
  end

=begin
in before filter : customrate (:find_customrate); ards (:find_ard_all)
=end
  def user_ard_time_edit
    dt = params[:daytype] ? params[:daytype] : ''
    et = params[:date][:hour] + ":" + params[:date][:minute] + ":" + params[:date][:second]
    st = params[:st]

    if st.to_s > et.to_s
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'user_acustrates_full', :id => @customrate.user_id, :dg => @customrate.destinationgroup_id and return false
    end

    rdetails = @customrate.acustratedetails_by_daytype(params[:daytype])
    ard = Acustratedetail.find(:first, :conditions => ["customrate_id = ? AND start_time = ? AND daytype = ?", @customrate.id, st, dt])

    unless ard
      flash[:notice] = _('Acustratedetail_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end

    # we need to create new rd to cover all day
    if (et != "23:59:59") and ((rdetails[(rdetails.size - 1)].start_time == ard.start_time))
      nst = Time.mktime('2000', '01', '01', params[:date][:hour], params[:date][:minute], params[:date][:second]) + 1.second
      for a in @ards
        na = Acustratedetail.new
        na.from = a.from
        na.duration = a.duration
        na.artype = a.artype
        na.round = a.round
        na.price = a.price
        na.customrate_id = a.customrate_id
        na.start_time = nst
        na.end_time = "23:59:59"
        na.daytype = a.daytype
        na.save

        a.end_time = et
        a.save
      end
    end

    flash[:status] = _('Rate_details_updated')
    redirect_to :action => 'user_acustrates_full', :id => @customrate.user_id, :dg => @customrate.destinationgroup_id
  end

=begin
in before filter : customrate (:find_customrate); ards (:find_ard_all)
=end
  def user_acustrates
    @user = @customrate.user
    @page_title = _('Custom_rate_details')
    @page_icon = "coins.png"
    @dgroup = @customrate.destinationgroup

    @st = params[:st]
    @dt = params[:dt] ? params[:dt] : ''
    @et = nice_time2(@ards[0].end_time)

    @can_add = false
    lard = @ards[@ards.size - 1]
    if (lard.duration != -1 and lard.artype == "minute") or (lard.artype == "event")
      @can_add = true
      @from = lard.from + lard.duration if lard.artype == "minute"
      @from = lard.from if lard.artype == "event"
    end
  end

=begin
in before filter : ard (:find_ard)
=end
  def user_custom_rate_update

    rate = @ard.customrate
    @dgroup = rate.destinationgroup
    @user = rate.user

    artype = params[:artype]

    duration = params[:duration].to_i
    infinity = params[:infinity]
    duration = -1 if infinity == "1" and artype == "minute"
    duration = 0 if artype == "event"

    round = params[:round].to_i
    price = params[:price].to_f
    round = 1 if round < 1

    @ard.from = params[:from]
    @ard.artype = artype
    @ard.duration = duration
    @ard.round = round
    @ard.price = price
    @ard.save


    rate_id = @ard.customrate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype

    flash[:status] = _('Custom_rate_updated')
    redirect_to :action => 'user_acustrates', :id => rate_id, :st => st, :dt => dt
  end

=begin
in before filter : customrate (:find_customrate)
=end
  def user_custom_rate_add
    @ard = Acustratedetail.new
    artype = params[:artype]

    duration = params[:duration].to_i
    infinity = params[:infinity]
    duration = -1 if infinity == "1" and artype == "minute"
    duration = 0 if artype == "event"

    round = params[:round].to_i
    price = params[:price].to_f
    round = 1 if round < 1

    rate_id = @customrate.id
    st = params[:st]
    et = params[:et]
    dt = params[:dt]
    dt = "" if not params[:dt]

    @ard.from = params[:from]
    @ard.artype = artype
    @ard.duration = duration
    @ard.round = round
    @ard.price = price
    @ard.customrate_id = @customrate.id
    @ard.daytype = dt
    @ard.start_time = st
    @ard.end_time = et
    @ard.save

    flash[:status] = _('Custom_rate_updated')
    redirect_to :action => 'user_acustrates', :id => rate_id, :st => st, :dt => dt
  end

=begin
in before filter : ard (:find_ard)
=end
  def user_custom_rate_delete
    rate_id = @ard.customrate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype
    @ard.destroy
    flash[:status] = _('Custom_rate_updated')
    redirect_to :action => 'user_acustrates', :id => rate_id, :st => st, :dt => dt
  end


=begin rdoc

=end

  def default_user
    @page_title = _('Default_user')
    @page_icon = "edit.png"
    owner = correct_owner_id
    if Confline.find(:all, :conditions => ["name LIKE 'Default_Tax_%' AND owner_id = ?", owner]).size > 0
      @tax = Confline.get_default_object(Tax, owner)
    else
      @tax = Tax.new
      if session[:usertype] == "reseller"
        reseller = User.find_by_id(owner)
        @tax = reseller.get_tax.dup
      else
        @tax.assign_default_tax({}, {:save => false})
      end
    end
    @user = Confline.get_default_object(User, owner)

    @user.owner_id = owner # owner_id nera default data. taigi reikia ji papildomai nustatyt
    @address = Confline.get_default_object(Address, owner)
    @user.tax = @tax
    @user.address = @address
    @groups = AccGroup.find(:all, :conditions => "group_type = 'accountant'")
    @groups_resellers = AccGroup.find(:all, :conditions => "group_type = 'reseller'")

    @lcrs = current_user.load_lcrs(:all, :order => "name ASC")
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{owner}' #{cond} ", :order => "purpose ASC, name ASC")

    @countries = Direction.find(:all, :order => "name ASC")

    @password_length = Confline.get_value("Default_User_password_length", owner).to_i
    @password_lenght = 8 if @password_length < 1

    if @lcrs.empty? and allow_manage_providers?
      flash[:notice] = _('No_lcrs_found_user_not_functional')
      redirect_to :action => 'list' and return false
    end

    if @tariffs.empty?
      flash[:notice] = _('No_tariffs_found_user_not_functional')
      redirect_to :action => 'list' and return false
    end
    @i = @user.get_invoices_status
  end

=begin rdoc

=end

  def default_user_update
    owner = correct_owner_id

    #User.set_default_user(owner, params[:user])
    @invoice = invoice_params_for_user

    params[:user][:send_invoice_types] = @invoice
    params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i
    params[:user][:recording_enabled] = params[:recording_enabled]
    params[:user][:recording_forced_enabled] = params[:recording_forced_enabled]
    params[:user][:allow_loss_calls] = params[:allow_loss_calls].to_i
    params[:user][:block_conditional_use] = params[:block_conditional_use].to_i
    params[:user][:block_at] = params[:block_at_date][:year].to_s + "-" + params[:block_at_date][:month].to_s + "-" + params[:block_at_date][:day].to_s
    params[:user][:warning_email_active]= params[:warning_email_active].to_i
    params[:user][:invoice_zero_calls] = params[:show_zero_calls].to_i
    params[:user][:acc_group_id] = params[:accountant_type]
    params[:user][:cyberplat_active] = params[:cyberplat_active].to_i
    params[:user][:balance] = current_user.convert_curr(params[:user][:balance].to_f)
    params[:user][:recording_hdd_quota] = (params[:user][:recording_hdd_quota].to_f*1048576).to_i
    #    params[:user][:agreement_date] = params[:agr_date][:year].to_s + "-" + params[:agr_date][:month].to_s + "-" + params[:agr_date][:day].to_s
    if params[:unlimited].to_i == 1
      params[:user][:credit] = -1
    else
      params[:user][:credit] = params[:credit].to_f
      params[:user][:credit] = 0 if params[:user][:credit] < 0
    end

    if monitoring_enabled_for(current_user)
      params[:user][:ignore_global_monitorings] = params[:ignore_global_monitorings].to_i
    end

    # privacy
    if params[:privacy]
      if params[:privacy][:global].to_i == 1
        params[:user][:hide_destination_end] = -1
      else
        params[:user][:hide_destination_end] = params[:privacy].values.sum { |v| v.to_i }
      end
    end

    if  !Email.address_validation(params[:address][:email]) and params[:address][:email].to_s.length.to_i > 0
      flash[:notice] = _("Email_address_not_corect")
      redirect_to :action => :default_user and return false
    end

    if params[:warning_email_active]
      params[:user][:warning_email_hour] = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:user_warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
    end

    Confline.set_default_object(User, owner, params[:user])
    Confline.set_default_object(Address, owner, params[:address])
    tax = tax_from_params
    tax[:total_tax_name] = "TAX" if tax[:total_tax_name].blank?
    tax[:tax1_name] = params[:total_tax_name].to_s if params[:tax1_name].blank?
    Confline.set_default_object(Tax, owner, tax)

    params[:password_length] = 8 if params[:password_length].to_i < 1
    Confline.set_value("Default_User_password_length", params[:password_length].to_i, owner)
    flash[:status] = _("Default_User_Saved")
    redirect_to :action => :default_user
  end

=begin
  lets hope thats temporary hack so that we wouldnt duplicate code
  when dinamicaly generating queries. may be someday we wouldnt be
  generating them this way.
=end
  def users_sql
    joins = []
    joins << "LEFT JOIN tariffs ON users.tariff_id = tariffs.id"
    joins << "LEFT JOIN addresses ON users.address_id = addresses.id"
    joins << "LEFT JOIN lcrs ON users.lcr_id = lcrs.id"
    select = []
    select << "users.*"
    select << "addresses.city, addresses.county"
    select << "lcrs.name AS lcr_name"
    select << "tariffs.name AS tariff_name"
    return select.join(","), joins.join(" ")
  end

  def users_weak_passwords

    if current_user.usertype == 'admin'
      select, join = users_sql
      @users = User.find(:all, :select => select, :joins => join, :conditions => ["password = SHA1('') or password = SHA1(username)"])
    end

  end

  def users_postpaid_and_allowed_loss_calls
    if current_user.is_admin?
      select, join = users_sql
      @users_postpaid_and_loss_calls = User.find(:all, :select => select, :joins => join, :conditions => ["postpaid = 1 and allow_loss_calls = 1"])
    end

  end

  def default_user_errors_list
    if current_user.is_admin?
      select, join = users_sql
      ownr = Confline.get_default_user_pospaid_errors
      ids = []; ownr.each { |o| ids << o['owner_id'] }
      @users_postpaid_and_loss_calls = User.find(:all, :select => select, :joins => join, :conditions => ["users.id in (#{ids.join(',')})"])
    end
    render :action => :users_postpaid_and_allowed_loss_calls
  end

  private

  def check_owner_for_user(user)
    if user.class != User
      #user = User.find(:first, :conditions => ["id = ? ", user])
      user = User.where({:id => user}).first
    end

    if !user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => "list" and return false
    end

    if session[:usertype] == "accountant"
      owner_id = User.find(session[:user_id].to_i).get_owner.id.to_i
      if user.usertype == "admin" or user.usertype == "accountant"
        flash[:notice] = _('You_have_no_permission')
        redirect_to :action => "list" and return false
      end
    else
      owner_id = session[:user_id]
    end

    if user.owner_id != owner_id
      flash[:notice] = _('You_have_no_permission')
      redirect_to :action => "list" and return false
    end
    return true
  end

=begin rdoc
 Checks if accountant is allowed to create devices.
=end

  def check_for_accountant_create_user
    if session[:usertype] == "accountant" and session[:acc_user_create] != 2
      dont_be_so_smart
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end


=begin rdoc
 Clears values accountant is not allowed to send.
=end

  def sanitize_user_params_by_accountant_permissions(user = nil)
    if session[:usertype] == 'accountant'
      if session[:acc_user_create_opt_1] != 2
        if params[:action] != "update"
          length = Confline.get_value("Default_User_password_length", correct_owner_id).to_i
          length = 8 if length <= 0
          params[:password] = {} if params[:password].nil?
          params[:password][:password] = random_password(length)
        else
          params[:password] = nil
        end
      end
      {:acc_user_create_opt_2 => [:usertype],
       :acc_user_create_opt_3 => [:lcr_id],
       :acc_user_create_opt_4 => [:tariff_id],
       :acc_user_create_opt_5 => [:balance],
       :acc_user_create_opt_6 => [:postpaid, :hidden],
       :acc_user_create_opt_7 => [:call_limit]
      }.each { |option, fields|
        fields.each { |field| params[:user].except!(field) if session[option] != 2 }
      }
      params[:password] = nil if user and user.usertype == "admin"
    end
  end

  def check_params
    unless params[:user]
      dont_be_so_smart
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end


  def find_user

      @user = User.where({:id=>params[:id]}).first

      unless @user and @user.owner_id == current_user.get_correct_owner_id
      flash[:notice] = _('User_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end

  def find_user_from_session
    @user = User.find_by_id(session[:user_id])

    unless @user
      flash[:notice] = _('User_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end

  def find_devicegroup
    @devicegroup = Devicegroup.find_by_id(params[:id])

    unless @devicegroup
      flash[:notice] = _('Dev_group_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end

  def find_customrate
    @customrate =Customrate.find_by_id(params[:id])

    unless @customrate
      flash[:notice] = _('Customrate_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end

  def find_ard
    @ard = Acustratedetail.find_by_id(params[:id])

    unless @ard
      flash[:notice] = _('Acustratedetail_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end

  def find_ard_all
    if params[:action] == 'user_ard_time_edit'
      dt = params[:daytype] ? params[:daytype] : ''
    else
      dt = params[:dt] ? params[:dt] : ''
    end
    @ards = Acustratedetail.find(:all, :conditions => ["customrate_id = ? AND start_time = ? AND daytype = ?", @customrate.id, params[:st], dt], :order => "acustratedetails.from ASC, artype ASC")
    if not @ards or (@ards and @ards.size.to_i == 0)
      flash[:notice] = _('Acustratedetails_not_found')
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end

  def check_with_integrity
    session[:integrity_check] = current_user.integrity_recheck_user if current_user
  end
end
