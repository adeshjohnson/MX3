# -*- encoding : utf-8 -*-
class SmsController < ApplicationController
  # include SMSFu

  layout :mobile_standard

  before_filter :check_post_method, :only => [:destroy, :create, :update, :lcr_destroy, :lcr_create, :lcr_update, :provider_update, :provider_create, :provider_destroy, :tariff_create, :tariff_destroy, :tariff_update, :rate_update, :rate_create, :rate_destroy]
  #before_filter :cdr2calls, :check_localization
  before_filter :check_localization, :except => [:sms_result]
  #before_filter :authorize_admin, :except => [:quickforwarddids, :quickforwarddid_edit, :quickforwarddid_update, :quickforwarddid_destroy]
  before_filter :authorize
  before_filter :check_sms_addon, :except => [:sms_result]
  before_filter :find_session_user, :only => [:send_sms, :user_rates, :sms, :tariffs]
  before_filter :find_user, :only => [:lcr_edit_user, :lcr_update_user]
  before_filter :find_lcr, :only => [:send_sms, :sms]
  before_filter :find_provider, :only => [:send_sms, :sms]
  before_filter :find_user_tariff, :only => [:send_sms, :user_rates, :sms]
  before_filter :find_number, :only => [:send_sms]
  before_filter :find_lcr_from_id, :only => [:lcr_providers, :try_to_add_provider, :lcr_edit, :lcr_update, :lcr_destroy, :lcr_details, :remove_lcr_provider, :lcr_provider_change_status, :lcr_providers_sort, :providers_sort_save]
  before_filter :find_provider_from_id, :only => [:provider_edit, :provider_update, :provider_destroy]
  before_filter :find_tariff_from_id, :only => [:tariff_edit, :delete_all_rates, :rates_update, :rate_try_to_add, :rate_new, :rates, :tariff_destroy, :tariff_update, :tariff_edit]

  @@callshop_view = []
  @@callshop_edit = [:users, :user_subscribe_to_sms, :lcrs, :lcr_new, :lcr_create, :lcr_providers, :try_to_add_provider, :lcr_edit, :lcr_update, :lcr_destroy, :lcr_details, :remove_lcr_provider,
                     :lcr_provider_change_status, :lcr_providers_sort, :providers_sort_save, :lcr_edit_user, :lcr_update_user, :providers, :provider_new, :provider_create, :provider_edit, :provider_update, :provider_destroy,
                     :tariffs, :tariff_new, :tariff_create, :tariff_edit, :tariff_update, :tariff_destroy, :rates, :rate_new, :rate_try_to_add, :rates_update, :rate_destroy, :delete_all_rates]
  before_filter(:only => @@callshop_view+@@callshop_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@callshop_view, @@callshop_edit, {:role => "reseller", :right => :res_sms_addon, :ignore => true})
    c.instance_variable_set :@callshop, allow_read
    c.instance_variable_set :@callshop, allow_edit
    true
  }


  def index
    sms_list
    render :action => 'sms_list'
  end

  def users
    @page_title = _('Users_subscribed_to_sms')
    @page_icon = "user.png"

    @active_users = User.find(:all, :select => "*, #{SqlExport.nice_user_sql}", :conditions => ["sms_service_active = 1 AND owner_id = ? AND hidden = 0", session[:user_id]], :order => "nice_user ASC")

    @not_active_users = User.find(:all, :select => "*, #{SqlExport.nice_user_sql}", :conditions => ["sms_service_active = 0 AND owner_id = ? AND hidden = 0", session[:user_id]], :order => "nice_user ASC")
  end

  def user_subscribe_to_sms
    @user = User.find(params[:user_id])
    @lcr = SmsLcr.find(:first)

    if not @lcr
      if reseller?
        flash[:notice] = _('No_available_SMS_LCR_reseller')
      else
        flash[:notice] = _('No_available_SMS_LCR')
      end

      redirect_to :action => 'users' and return false
    end

    @tariff = SmsTariff.find(:first, :conditions => ["tariff_type = 'user' AND owner_id = ? ", session[:user_id]])

    if not @tariff
      flash[:notice] = _('No_available_SMS_Tariff')
      redirect_to :action => 'users' and return false
    end


    if @user.sms_service_active == 0
      @user.sms_service_active = 1
      @user.sms_lcr_id = @lcr.id
      @user.sms_tariff_id = @tariff.id
      flash[:status] = _('User_subscribed_to_sms_service') + ": " + nice_user(@user)
    else
      @user.sms_service_active = 0
      flash[:status] = _('User_unsubscribed_from_sms_service') + ": " + nice_user(@user)
    end
    @user.save

    redirect_to :action => 'users' and return false
  end


  #--------------- lcr --------------------------
  def lcrs
    @page_title = _('Sms_lcrs')
    #@page_icon = ""
    @lcrs = SmsLcr.find(:all, :order => "name ASC")
  end

  def lcr_new
    @page_title = _('LCR_new')
    @page_icon = "add.png"
    @lcr = SmsLcr.new
  end

  def lcr_create
    @page_title = _('LCR_new')
    @page_icon = "add.png"

    @lcr = SmsLcr.new(params[:lcr].each_value(&:strip!))
    if @lcr.save
      flash[:status] = _('Lcr_was_successfully_created')
      redirect_to :action => 'lcrs'
    else
      render :action => 'lcr_new'
    end
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def lcr_providers

    @page_title = _('Providers_for_LCR') # + ": " + @lcr.name
    @page_icon = "provider.png"

    @providers = @lcr.sms_providers("asc")
    @all_providers = SmsProvider.find(:all)
    @other_providers = []
    for prov in @all_providers
      @other_providers << prov if !@providers.include?(prov)
    end
    flash[:notice] = _('No_provaiders_available') if @all_providers.empty?
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def try_to_add_provider

    prov_id = params[:select_prov]

    if prov_id != "0"
      @prov = SmsProvider.find_by_id(prov_id)
      @lcr.add_sms_provider(@prov)
      flash[:status] = _('Provider_added')
    else
      flash[:notice] = _('Please_select_provider_from_the_list')
    end

    redirect_to :action => 'lcr_providers', :id => @lcr
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def lcr_edit
    @page_title = _('LCR_edit')
    @page_icon = "edit.png"
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def lcr_update
    @page_title = _('LCR_edit')
    @page_icon = "edit.png"

    if @lcr.update_attributes(params[:lcr].each_value(&:strip!))
      flash[:status] = _('Lcr_was_successfully_updated')
      redirect_to :action => 'lcrs', :id => @lcr
    else
      render :action => 'lcr_edit'
    end
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def lcr_destroy

    #check if no users uses this lcr
    if User.find(:all, :conditions => ["sms_lcr_id = ?", @lcr.id]).size > 0
      flash[:notice] = _('Lcr_not_deleted')
    else
      flash[:status] = _('Lcr_deleted')
      @lcr.destroy
    end

    redirect_to :action => 'lcrs'
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def lcr_details
    @page_title = _('LCR_Details')
    @page_icon = "view.png"
    @user = User.find(:all, :select => "*, #{SqlExport.nice_user_sql}", :conditions => ["sms_lcr_id = ?", @lcr.id], :order => "nice_user ASC")
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def remove_lcr_provider
    prov_id = params[:prov]
    @lcr.remove_sms_provider(prov_id)
    flash[:status] = _('Provider_removed')
    redirect_to :action => 'lcr_providers', :id => @lcr
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def lcr_provider_change_status
    prov_id = params[:prov]

    if @lcr.sms_provider_active(prov_id)
      value = 0
      flash[:status] = _('Provider_disabled')
    else
      value = 1
      flash[:status] = _('Provider_enabled')
    end

    sql = "UPDATE sms_lcrproviders SET active = #{value} WHERE sms_lcr_id = #{@lcr.id} AND sms_provider_id = #{prov_id}"
    res = ActiveRecord::Base.connection.update(sql)

    redirect_to :action => 'lcr_providers', :id => @lcr.id
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def lcr_providers_sort

    if (@lcr.order.to_s != 'priority')
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main'
    end
    @page_title = _('Change_Order') + ": " + @lcr.name
    @page_icon = "arrow_switch.png"
    @items = @lcr.sms_providers("asc")
  end

=begin
in before filter : lcr (:find_lcr_from_id)
=end
  def providers_sort_save
    params[:sortable_list].each_index do |i|
      item = SmsLcrprovider.find(:first, :conditions => "sms_provider_id = #{params[:sortable_list][i]} AND sms_lcr_id = #{params[:id]}")
      item.priority = i
      item.save
    end
    @page_title = _('Change_Order') + ": " + @lcr.name
    @items = @lcr.sms_providers("asc")
    render :layout => false, :action => :providers_sort
  end

  def lcr_edit_user
    @page_title = _('Sms_lcr_user')
    @page_icon = "edit.png"
    @sms_lcrs = SmsLcr.find(:all, :order => "name ASC")
    @sms_tariffs = SmsTariff.find(:all, :conditions => "(tariff_type = 'user') AND owner_id = '#{session[:user_id]}' ", :order => "tariff_type ASC, name ASC")
  end

=begin
in before filter : user (:find_user)
=end
  def lcr_update_user
    @user.sms_lcr_id = params[:lcr_id] if session[:usertype] == 'admin'
    @user.sms_tariff_id = params[:tariff_id]
    @user.save
    flash[:status] = _('User_updated')
    redirect_to :action => 'lcr_edit_user', :id => @user.id
  end


  #--------------- providers --------------------------
  def providers
    @page_title = _('Sms_providers')
    @page_icon = "provider.png"
    @providers = SmsProvider.find(:all)
  end

  def provider_new
    @page_title = _('New_provider')
    @page_icon = "add.png"
    @provider = SmsProvider.new
    @tariffs = current_user.sms_provider_tariffs


    @action = "new"

    if @tariffs.size == 0
      flash[:notice] = _('No_SMS_tariffs_available')
      redirect_to :action => 'providers'
    end

    @new_provider = true
  end

  def provider_create
    sms_prov = SmsProvider.new(params[:provider].each_value(&:strip!))
    if sms_prov.api? and mor_11_extend?
      sms_prov.login = params[:api_string].to_s
      sms_prov.email_good_keywords = params[:api_good_keywords].to_s
    end
    sms_prov.priority = 1
    if sms_prov.save
      flash[:status] = _('Sms_provider_created')
      redirect_to :action => 'providers' and return false
    else
      flash_errors_for(_('Sms_provider_not_created'), sms_prov)
      @api_string = sms_prov.login
      @api_keywords = sms_prov.email_good_keywords
      @provider = sms_prov
      @tariffs = current_user.sms_provider_tariffs
      render :action => :provider_new and return false
    end

  end

=begin
in before filter : provider (:find_provider_from_id)
=end
  def provider_edit
    @page_title = _('Sms_providers_edit')
    @page_icon = "edit.png"
    @tariffs = current_user.sms_provider_tariffs
    @api_string = @provider.login.to_s
    @api_keywords = @provider.email_good_keywords

  end

=begin
in before filter : provider (:find_provider_from_id)
=end
  def provider_update
    @provider.attributes = params[:provider].each_value(&:strip!)
    if params[:provider][:wait_for_good_email]
      @provider.wait_for_good_email = params[:provider][:wait_for_good_email]
    else
      @provider.wait_for_good_email = 0
    end
    @provider.email_good_keywords = params[:provider][:email_good_keywords] if params[:provider][:email_good_keywords]
    if params[:provider][:wait_for_bad_email]
      @provider.wait_for_bad_email = params[:provider][:wait_for_bad_email]
    else
      @provider.wait_for_bad_email = 0
    end
    if @provider.api? and mor_11_extend?
      @provider.login = params[:api_string].to_s
      @provider.email_good_keywords = params[:api_good_keywords].to_s
    end
    if @provider.save
      flash[:status] = _('Sms_provider_updated')
      redirect_to :action => 'providers' and return false
    else
      flash_errors_for(_('Sms_provider_not_updated'), @provider)
      @api_string = @provider.login.to_s
      @api_keywords = @provider.email_good_keywords
      @tariffs = current_user.sms_provider_tariffs
      render :action => :provider_edit and return false
    end
  end

=begin
in before filter : provider (:find_provider_from_id)
=end
  def provider_destroy
    unless @provider
      flash[:notice] = _('Sms_provider_not_found')
      redirect_to :action => 'providers' and return false
    end
    @provider.destroy
    flash[:status] = _('Sms_provider_deleted')
    redirect_to :action => 'providers'
  end

  #---------- tariffs ----------------------

=begin
in before filter : user (:find_session_user)
=end
  def tariffs
    @page_title = _('Sms_tariffs')
    @prov_tariffs = @user.sms_provider_tariffs
    @user_tariffs = SmsTariff.find(:all, :conditions => "tariff_type = 'user' AND owner_id = '#{@user.id}'", :order => "name ASC")

    #deleting not necessary session vars - just in case after crashed csv rate import
    session[:file] = nil
    session[:status_array] = nil
    session[:update_rate_array] = nil
    session[:short_prefix_array] = nil
    session[:bad_lines_array] = nil
    session[:bad_lines_status_array] = nil
    session[:manual_connection_fee] = nil
    session[:manual_increment] = nil
    session[:manual_min_time] = nil
  end

  def tariff_new
    @page_title = _('SMS_tariff_new')
    @page_icon = "add.png"
    @tariff = SmsTariff.new
    @currs = Currency.get_active
  end

  def tariff_create
    sms_tariff = SmsTariff.new(params[:tariff].each_value(&:strip!))
    sms_tariff.owner_id = session[:user_id]
    sms_tariff.save
    flash[:status] = _('Sms_tariff_created')
    redirect_to :action => 'tariffs'
  end

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def tariff_edit
    @page_title = _('Sms_tariffs_edit')
    @page_icon = "edit.png"
    a=check_user_id_with_session(@tariff.owner_id)
    return false if !a
    @currs = Currency.get_active
    # @user_wholesale_enabled = (confline("User_Wholesale_Enabled") == "1")
  end

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def tariff_update
    @tariff.update_attributes(params[:tariff].each_value(&:strip!))
    @tariff.owner_id = session[:user_id]
    @tariff.save
    flash[:status] = _('Sms_tariff_updated')
    redirect_to :action => 'tariffs'
  end

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def tariff_destroy
    a=check_user_id_with_session(@tariff.owner_id)
    return false if !a
    if @tariff.destroy
      flash[:status] = _('Sms_tariff_deleted')
    else
      flash_errors_for(_('Sms_tariff_not_deleted'), @tariff)
    end
    redirect_to :action => 'tariffs'
  end


  #---------- Rates ----------------------

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def rates
    @page_title = _('Sms_rates')
    #@page_icon = ""

    a=check_user_id_with_session(@tariff.owner_id)
    return false if !a
    @page_title = _('SMS_Rates_for_tariff') +": " + @tariff.name

    @st = "A"
    @st = params[:st].upcase if params[:st]

    @rates = @tariff.rates_by_st(@st, 0, 10000)
    @total_pages = (@rates.size.to_f / session[:items_per_page].to_f).ceil

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page = @total_pages if @page > @total_pages

    @all_rates = @rates
    @rates = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_rates.size - 1 if iend > (@all_rates.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @rates << @all_rates[i]
    end
    @rates = @rates.compact
    #----

    @use_lata = false
    @use_lata = true if @st == "U"


    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id

    @dests = @tariff.free_destinations_by_st(@st)

  end

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def rate_new
    @page_title = _('Add_new_rate_to_tariff') +": " + @tariff.name
    @page_icon = "add.png"

    # st - from which letter starts rate's direction (usualy country)
    @st = "A"
    @st = params[:st].upcase if params[:st]

    @dests = @tariff.free_destinations_by_st(@st)

    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id
  end

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def rate_try_to_add
    st = "A"
    st = params[:st].upcase if params[:st]

    for dest in @tariff.free_destinations_by_st(st)
      #add only rates which are entered
      if params[(dest.id.to_s).intern].length > 0
        @tariff.add_new_rate(dest.prefix.to_s, params[(dest.id.to_s).intern])
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to :action => 'rates', :id => params[:id], :st => st
    #    render :action => 'debug'
  end

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def rates_update
    @st = params[:st].to_s
    if @tariff and @st.length != 1
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    a=check_user_id_with_session(@tariff.owner_id)
    return false if !a
    @rates = @tariff.rates_by_st(@st, 0, 10000)
    @rates.each { |r|
      if params[:rate] and params[:rate]["id_#{r.id}".to_sym] and params[:rate]["id_#{r.id}".to_sym][:price] and r.price.to_f != params[:rate]["id_#{r.id}".to_sym][:price].to_f
        r.price = params[:rate]["id_#{r.id}".to_sym][:price].to_f
        r.save
      end
    }
    flash[:status] = _('Sms_rate_updated')
    redirect_to :action => 'rates', :id => params[:id], :st => @st, :page => params[:page]
  end

  def rate_destroy
    sms_rate = SmsRate.find_by_id(params[:id])
    sms_rate.destroy if sms_rate
    flash[:status] = _('Sms_rate_deleted')
    redirect_to :action => 'rates', :id => params[:tariff], :st => params[:st], :page => params[:page]
  end

=begin
in before filter : tariff (:find_tariff_from_id)
=end
  def delete_all_rates
    a=check_user_id_with_session(@tariff.owner_id)
    return false if !a
    @tariff.delete_all_rates
    flash[:status] = _('All_rates_deleted')
    redirect_to :action => 'list'
  end

  #------------------ SMS sending -----------------------------
  def sms
    @page_title = _('Send_sms')
    #@page_icon = ""

    if @user.sms_service_active == 0
      flash[:notice] = session[:usertype] == "admin" ? _('User_not_subscribed_to_SMS') : dont_be_so_smart
      redirect_to :action => :index and return false
    end

    @addresses = Phonebook.find(:all, :conditions => ["user_id=?", session[:user_id]])

    if  request.env["HTTP_X_MOBILE_GATEWAY"]
      respond_to do |format|
        format.wml { render :action => 'sms.wml.builder' }
        #format.html
      end
    end

  end


  def send_sms
    require 'rubygems'
    require 'clickatell'

    sms_numbers = params[:sms_counter]
    message = params[:body]

    for number in @all_numbers

      if number.class.to_s == "Phonebook"
        number = number.number
      end

      sms = SmsMessage.new
      sms.sending_date = Time.now
      sms.user_id = @user.id
      sms.reseller_id = @user.owner_id
      sms.number = number
      sms.save
      sms.sms_send(@user, @user_tariff, number, @lcr, sms_numbers.to_f, message, params)

    end
    if sms.status_code.to_s == "0"
      flash[:status] = sms.sms_status_code_tip
    else
      flash[:notice] = sms.sms_status_code_tip
    end


    if @request.env["HTTP_X_MOBILE_GATEWAY"]
      redirect_to :controller => 'callc', :action => 'main', :sms_notice => sms.sms_status_code_tip.to_s
    else
      if @request.env["HTTP_USER_AGENT"].match("Safari")
        redirect_to :controller => 'callc', :action => "main_for_pda" and return false
      else
        redirect_to :action => 'sms_list' and return false
      end

    end
  end

  def sms_result

    @api_id = params[:api_id].to_s
    @from = params[:from].to_s
    @to = params[:to].to_s
    @text = params[:text].to_s
    @dated = params[:timestamp].to_s
    @apiMsgId = params[:apiMsgId].to_s
    @status = params[:status].to_s
    @charge = params[:charge].to_s

    @sms = SmsMessage.find(:first, :conditions => ["clickatell_message_id = ?", @apiMsgId])
    if @sms
      sms_callback_action = Action.find(:first, :conditions => ["target_id = ? AND target_type = 'SMS' AND action = 'SMS_callback' AND data3 != 0 ", @sms.id])
      @user = @sms.user
      charge = false
      # logger.info "callback : #{params.to_yaml}"
      # logger.info @charge.to_f > 0.to_f and !sms_callback_action
      if  @charge.to_f > 0.to_f and !sms_callback_action
        @sms.charge_user
        charge = true
      end
      #sms_callback_no_charge_action = Action.find(:first, :conditions=>["target_id = ? AND target_type = 'SMS' AND action = 'SMS_callback' AND data3 != 0", @sms.id])
      # logger.info @charge.to_f <= 0.to_f and !sms_callback_no_charge_action
      if @charge.to_f <= 0.to_f and !sms_callback_action
        @sms.return_sms_price_to_user
        charge = true
      end
      @sms.status_code = @status.to_s
      @sms.save
      Action.add_action_hash(@user, {:action => "SMS_callback", :data => @status, :data4 => params.inspect.to_s[0..255], :data2 => @charge.to_f, :target_id => @sms.id, :target_type => "SMS", :data3 => charge})
    else
      Action.add_error(0, "SMS_callback", {:data4 => params.inspect.to_s[0..255], :target_type => "SMS", :data2 => "SMS_not_found"})
    end

    render :nothing => true
  end


  def sms_list
    @page_title = _('Sms_list')
    #@page_icon = ""
    @page = 1
    @page = params[:page].to_i if params[:page]
    @sms = SmsMessage.find(:all, :conditions => ["user_id= ?", session[:user_id]])

    @total_pages = (@sms.size.to_f / session[:items_per_page].to_f).ceil
    @all_sms = @sms
    @sms = []
    @a_number = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_sms.size - 1 if iend > (@all_sms.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @sms << @all_sms[i]
    end

    @t_sms = 0
    @t_sms_price = 0
    for sms in @sms
      if [0, 4].include?(sms.status_code.to_i) and sms.user_rate.to_f != 0.0
        @t_sms += sms.user_price / sms.user_rate
        @t_sms_price += sms.user_price
      else
        @t_sms += 0
        @t_sms_price += 0
      end
    end

  end

  def user_rates
    # @user_tariff - in before filter
    @page_title = _('Sms_rates')
    @st = (params[:st] ? params[:st].upcase : "A")
    @page = (params[:page] ? params[:page].to_i : 1)
    ex = Currency.count_exchange_rate(@user_tariff.currency, current_user.currency.name)
    #logger.info ex
    @rates = @user_tariff.rates_by_st(@st, 0, 10000, {:exchange_rate => ex})

    @total_pages = (@rates.size.to_f / session[:items_per_page].to_f).ceil
    @all_rates = @rates
    @rates = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_rates.size - 1 if iend > (@all_rates.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @rates << @all_rates[i]
    end
    #----

    @use_lata = false
    @use_lata = true if @st == "U"


    @letter_select_header_id = @user_tariff.id
    @page_select_header_id = @user_tariff.id

    @dests = @user_tariff.free_destinations_by_st(@st)
  end

  def get_users_numbers(n)
    if n.to_s == 'All'
      number = Phonebook.find(:all, :conditions => "user_id='#{session[:user_id]}'")
    else
      number = n
    end

  end


  # Prefix Finder ################################################################
  def prefix_finder_find
    @phrase = params[:prefix].to_s.gsub(/\D/, "")
    sql = "SELECT destinations.*, directions.name as dirname FROM destinations
           Join sms_rates on (sms_rates.prefix = destinations.prefix)
           LEFT Join directions on (directions.code = destinations.direction_code)
           WHERE destinations.prefix = SUBSTRING(#{q(@phrase)}, 1, LENGTH(destinations.prefix))
           Order by LENGTH(destinations.prefix) DESC
           LIMIT 1"
    @dest = Destination.find_by_sql(sql) if @phrase != ''
    if !@dest or @dest.blank? or @phrase.blank?
      @results = _('Cant_send_SMS_no_rate_for_this_destination')
    else
      @user= User.find(session[:user_id])
      @tariff = SmsTariff.find(:first, :conditions => ["id = ?", @user.sms_tariff_id])
      @results = ""
      if @tariff
        ex = Currency.count_exchange_rate(@tariff.currency, current_user.currency.name)
        @rate = SmsMessage.sms_rate(@user.sms_tariff_id, @phrase)
        for dest in @dest
          @results = dest.dirname.to_s+" "+dest.subcode.to_s+" "+dest.name.to_s
        end
        @price = ""
        if @rate
          @price = @rate.price * ex
          @results += " / 1 SMS: "+@price.to_s+" "+ current_user.currency.name.to_s #@tariff.currency.to_s
        else
          @results += " - " +_('Cant_send_SMS_no_rate_for_this_destination')
        end
      end
    end
    render(:layout => false)
  end

  # /Prefix Finder ###############################################################

  def find_sms_price
    @phrase = request.raw_post || request.query_string
    if @phrase != ''
      @result = _('Total_sms_price') + " : " + nice_number(@phrase.to_i * params[:price].to_i)
    end
    render(:layout => false)
  end

  def form_sms
    @phrase = request.raw_post || request.query_string

    if (params[:prid].to_s != 'NaNsms_email') and (params[:prid].to_s != 'NaNclickatell')
      @provider = SmsProvider.find(params[:prid]) if params[:prid]
    end
    if (params[:prov_t].to_s == 'sms_email') or (params[:prid].to_s == 'NaNsms_email')
      if (params[:prid].to_s != 'NaNsms_email')
        @provider = SmsProvider.find(params[:prid])
      end
      render(:layout => false)
    else
      render :partial => 'clickatell_provider_form', :layout => false
    end

  end

  private

  def format_number(number)
    pre_formatted = number.gsub("-", "").strip
    formatted = (pre_formatted.length == 11 && pre_formatted[0, 1] == "1") ? pre_formatted[1..pre_formatted.length] : pre_formatted
    return is_valid?(formatted) ? formatted : (raise Exception.new("Phone number (#{number}) is not formatted correctly"))
  end

  def is_valid?(number)
    return (number.length >= 5 && number[/^.\d+$/]) ? true : false
  end

  def check_sms_addon
    if !sms_active? or ((session[:sms_service_active].to_i == 0 and session[:res_sms_addon].to_i != 2) and session[:usertype] != 'admin')
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_session_user
    @user = User.find(:first, :conditions => ["id=?", session[:user_id]])
    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_user
    @user = User.find(:first, :conditions => ["id=?", params[:id]])

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_lcr
    @lcr = @user.sms_lcr
    unless @lcr
      flash[:notice] = _('No_available_SMS_LCR')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end


  def find_lcr_from_id
    @lcr = SmsLcr.find(:first, :conditions => ["id=?", params[:id]])
    unless @lcr
      flash[:notice] = _('No_available_SMS_LCR')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end


  def find_provider
    @providers = @lcr.sms_providers
    if !@providers or @providers.size.to_i < 1
      flash[:notice] = _('No_available_SMS_Provider')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_provider_from_id
    @provider = SmsProvider.find(:first, :conditions => ["id=?", params[:id]])
    unless @provider
      flash[:notice] = _('No_available_SMS_Provider')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_user_tariff
    @user_tariff = @user.sms_tariff
    unless @user_tariff
      action = Action.new({:user_id => session[:user_id], :date => Time.now, :action => 'error', :data => _('No_sms_tariff'), :data2 => request.request_uri})
      action.save
      flash[:notice] = _('No_SMS_tariffs_available')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_tariff_from_id
    @tariff = SmsTariff.find(:first, :conditions => ["id=?", params[:id]])
    unless @tariff
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_number
    if  @request.env["HTTP_X_MOBILE_GATEWAY"]
      sms_numbers = 1
      params[:number] = params[:number1] if    params[:number1]
      if params[:number2].to_i != 0
        params[:number] = params[:number2]
      end
    end

    @all_numbers = get_users_numbers(params[:number])
    if params[:number].to_s.length == 0 or @all_numbers.size == 0
      flash[:notice] = _('Please_enter_number')
      redirect_to :controller => 'sms', :action => 'sms' and return false
    end
  end

end
