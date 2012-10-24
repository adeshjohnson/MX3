# -*- encoding : utf-8 -*-
class TariffsController < ApplicationController
  require 'csv'
  # include PdfGen
  include UniversalHelpers
  #require 'rubygems'
  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update, :rate_destroy, :ratedetail_update, :ratedetail_destroy, :ratedetail_create, :artg_destroy, :user_rate_update, :user_rate_delete, :user_rates_update, :user_rate_destroy, :day_destroy, :day_update, :update_tariff_for_users]
  before_filter :check_localization
  before_filter :authorize, :except => [:destinations_csv]
  before_filter :check_if_can_see_finances, :only => [:new, :create, :list, :edit, :update, :destroy, :rates_list, :import_csv, :delete_all_rates, :make_user_tariff, :make_user_tariff_wholesale]
  before_filter :find_user_from_session, :only => [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed]
  before_filter :find_user_tariff, :only => [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed]
  before_filter :find_tariff_whith_currency, :only => [:find_tariff_whith_currency, :generate_providers_rates_csv, :generate_provider_rates_pdf, :generate_user_rates_pdf, :generate_user_rates_csv]
  before_filter :find_tariff_from_id, :only => [:check_tariff_time, :rate_new_by_direction, :edit, :update, :destroy, :tariffs_list, :rates_list, :rate_new_quick, :rate_try_to_add, :rate_new, :rate_new_by_direction_add, :delete_all_rates, :user_rates_list, :user_arates_full, :user_rates_update, :make_user_tariff, :make_user_tariff_wholesale, :make_user_tariff_status, :make_user_tariff_status_wholesale, :ghost_percent_edit, :ghost_percent_update]

  before_filter { |c|
    view = [:index, :list, :rates_list, :user_rates_list, :user_arates_full, :user_arates, :day_setup]
    edit = [:new, :create, :edit, :update, :destroy, :user_rate_update, :user_rates_update, :user_ard_time_edit, :ard_manage, :day_add, :day_edit, :day_update, :ghost_percent_edit, :ghost_percent_update]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_tariff_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    flash[:notice] = flash[:notice] if !flash[:notice].blank?
    redirect_to :action => :list and return false
  end

  def list
    user = User.find_by_id(correct_owner_id)
    unless user
      flash[:notice]=_('User_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Tariffs')
    @page_icon = "view.png"
    #@tariff_pages, @tariffs = paginate :tariffs, :per_page => 10
    if params[:s_prefix]
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/, '')
      dest = Destination.find(:all, :conditions => ["prefix LIKE ?", @s_prefix.to_s])
    end
    @des_id = []
    @des_id_d = []
    if dest and dest.size.to_i > 0
      dest.each { |d| @des_id << d.id }
      dest.each { |d| @des_id_d << d.destinationgroup_id }
      cond = " AND rates.destination_id IN (#{@des_id.join(',')})"
      con = " AND rates.destinationgroup_id IN (#{@des_id_d.join(',')}) "
      @search = 1
      incl =  [:rates]
    else
      con = ''
      cond = ''
      incl = ''
    end

    @prov_tariffs = Tariff.find(:all, :conditions => "purpose = 'provider' AND owner_id = '#{user.id}' #{cond}", :include => incl, :order => "name ASC", :group => 'tariffs.id')
    @user_tariffs = Tariff.find(:all, :conditions => "purpose = 'user' AND owner_id = '#{user.id}' #{con}", :include => incl, :order => "name ASC", :group => 'tariffs.id')
    @user_wholesale_tariffs = Tariff.find(:all, :conditions => "purpose = 'user_wholesale' AND owner_id = '#{user.id}' #{cond}", :include => incl, :order => "name ASC", :group => 'tariffs.id')
    @user_wholesale_enabled = (Confline.get_value("User_Wholesale_Enabled") == "1")

    @Show_Currency_Selector =1
    @tr = []
    tariffs_rates = Tariff.find(:all, :select => 'tariffs.id, COUNT(rates.id) as rsize', :conditions => "(purpose = 'provider' or purpose = 'user_wholesale' ) AND owner_id = '#{user.id}'", :joins => 'LEFT JOIN rates ON (rates.tariff_id = tariffs.id)', :order => "name ASC", :group => 'tariffs.id')
    tariffs_rates.each { |t| @tr[t.id] = t.rsize.to_i }
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

  def new
    @page_title = _('Tariff_new')
    @page_icon = "add.png"
    @tariff = Tariff.new
    @currs = Currency.get_active
    @user_wholesale_enabled = (confline("User_Wholesale_Enabled") == "1")
  end

  def create
    @page_title = _('Tariff_new')
    @page_icon = "add.png"
    @currs = Currency.get_active

    @tariff = Tariff.new(params[:tariff])

    user_id = get_user_id()

    @tariff.owner_id = user_id
    if @tariff.save
      flash[:status] = _('Tariff_was_successfully_created')
      redirect_to :action => 'list'
    else
      #KRISTINA: fix error layout on create
      flash_errors_for(_('Tariff_Was_Not_Created'), @tariff)
      #flash[:notice] = _('Tariff_Was_Not_Created')
      render :action => 'new'
    end
  end

  # before_filter : tariff(find_taririff_from_id)
  def edit
    check_user_for_tariff(@tariff.id)
    @page_icon = "edit.png"
    @page_title = _('Tariff_edit') #+": "+ @tariff.name
    @no_edit_purpose = true
    @currs = Currency.get_active
    @user_wholesale_enabled = (confline("User_Wholesale_Enabled") == "1")
  end

  # before_filter : tariff(find_taririff_from_id)
  def update
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @page_icon = "edit.png"
    @currs = Currency.get_active

    if @tariff.update_attributes(params[:tariff])
      flash[:status] = _('Tariff_was_successfully_updated')
      redirect_to :action => 'list', :id => @tariff
    else
      flash_errors_for(_('Tariff_Was_Not_Updated'), @tariff)
      render :action => 'edit'
    end
  end

  # before_filter : tariff(find_taririff_from_id)
  def destroy
    a=check_user_for_tariff(@tariff.id)
    return false if !a

    #check for providers
    tpc = @tariff.providers.count
    if tpc > 0
      flash[:notice] = tpc.to_s + _('providers_are_using_this_tariff_cant_delete')
      redirect_to :action => 'list' and return false
    end

    # check for cardgroups
    cardgroup = @tariff.cardgroups.count
    if cardgroup > 0
      flash[:notice] = cardgroup.to_s + " " + _('cardgroups_are_using_this_tariff_cant_delete')
      redirect_to :action => 'list' and return false
    end

    #check for users
    tuc = @tariff.users.count
    if tuc > 0
      flash[:notice] = tuc.to_s + " " + _('users_are_using_this_tariff_cant_delete')
      redirect_to :action => 'list' and return false
    end

    #check for locationrules
    lrules= Locationrule.find(:all, :conditions => "tariff_id='#{@tariff.id}'")
    if lrules.size.to_i > 0
      flash[:notice] = lrules.size.to_s + " " + _('locationrules_are_using_this_tariff_cant_delete')
      redirect_to :action => 'list' and return false
    end

    comm_use_prov_table = @tariff.common_use_providers.count
    if comm_use_prov_table > 0
      flash[:notice] = _('common_use_providers_are_using_this_tariff_cant_delete')
      redirect_to :action => 'list' and return false
    end
    @tariff.delete_all_rates
    @tariff.destroy
    #my_debug tariff.providers.count
    flash[:status] = _('Tariff_deleted')
    redirect_to :action => 'list'
  end

  # ================== TARIFFS LIST =====================

  # before_filter : tariff(find_taririff_from_id)
  def tariffs_list
    check_user_for_tariff(@tariff.id)
    @page_title = _('Tariff_list')
    @page_icon = "view.png"
    @user = User.find(:all, :conditions => ["tariff_id = ?", @tariff.id])
    @cardgroup = Cardgroup.find(:all, :conditions => ["tariff_id = ?", @tariff.id])
  end


  # =============== RATES FOR PROVIDER ==================

  # before_filter : tariff(find_taririff_from_id)
  def rates_list
    return false unless check_user_for_tariff(@tariff.id)

    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Rates_for_tariff') #+": " + @tariff.name
    @can_edit = true

    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first, :conditions => ["reseller_id = ? AND tariff_id = ?", current_user.id, @tariff.id])
      @can_edit = false
    end

    @directions_first_letters = Rate.find(:all, :select => 'directions.name', :conditions => ["rates.tariff_id=?", @tariff.id], :joins => "JOIN destinations ON destinations.id = rates.destination_id JOIN directions ON (directions.code = destinations.direction_code)", :order => "directions.name ASC", :group => "SUBSTRING(directions.name,1,1)") 
    
    @directions_first_letters.map! { |rate| rate.name[0..0] } 
    @st = (params[:st] ? params[:st].upcase : @directions_first_letters[0]) 

    @st = @st.to_s

    @st = 'A' if @st.blank?

    @directions = Direction.find(
        :all,
        :select => "directions.*, COUNT(destinations.id) AS 'dest_count', COUNT(rates.id) AS 'rate_count'",
        :conditions => ["directions.name LIKE ?", @st.to_s + "%"],
        :joins => "LEFT JOIN destinations ON (destinations.direction_code = directions.code) LEFT JOIN rates ON (rates.destination_id = destinations.id AND tariff_id = #{@tariff.id.to_i})",
        :order => "name ASC",
        :group => "directions.id")

    @page = params[:page] ? params[:page].to_i : 1
    record_offset = (@page - 1) * session[:items_per_page].to_i

    if params[:s_prefix]
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/, '')
      @des_id = Destination.find(:all, :select => 'id', :conditions => ["prefix LIKE ?", @s_prefix.to_s]).map {|destination| destination.id}
    end
    if @s_prefix
      unless @des_id.empty?
        @search = 1
        condition = ["rates.tariff_id=? AND rates.destination_id IN (#{@des_id.join(',')})", @tariff.id]
        rate_count = Rate.includes(:ratedetails).where(condition).count
        @rates = Rate.includes(:ratedetails).where(condition).offset(record_offset).limit(session[:items_per_page].to_i).all
      else
        @rates = []
      end
    else
      condition = ["rates.tariff_id=? AND directions.name like ?", @tariff.id, @st+"%"] 
      includes = [:ratedetails, {:destination => :direction}, :tariff]
      rate_count = Rate.includes(includes).where(condition).count
      @rates = Rate.includes(includes).where(condition).order("directions.name ASC, destinations.prefix ASC").offset(record_offset).limit(session[:items_per_page].to_i).all
    end

    @total_pages = (rate_count.to_f / session[:items_per_page].to_f).ceil

    @use_lata = (@st == "U")
    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id
  end

=begin rdoc
 Checks if prefix is available and has no set rates.

 *Params*:

 post data - prefix that needs to be checked.
 +tariff_id+ - Tariff id.
=end

  def check_prefix_availability
    @prefix = (params.keys.select { |parameter| parameter =~ /[0-9]+/ })[0]
    #wft was that? request.raw_post request.query_string??
    #@prefix = request.raw_post || request.query_string
    #@prefix = @prefix.gsub(/=/, "")
    @tariff = params[:tariff_id]
    @destination = Destination.find(:first,
                                    :select => "directions.name as 'dir_name', directions.code as 'dir_code', destinations.prefix AS 'des_prefix', destinations.name as 'des_name', destinations.subcode AS 'des_subcode', rates.id AS 'rate_id'",
                                    :joins => "LEFT JOIN directions ON (destinations.direction_code = directions.code) LEFT JOIN (SELECT * FROM rates WHERE tariff_id = #{@tariff.to_i}) AS rates ON (rates.destination_id = destinations.id)",
                                    :conditions => ["prefix = ?", @prefix])
    render :layout => false
  end

=begin rdoc
 Quickly adds new rate of desired price for tariff.

 *Params*:

 +id+ - Tariff id.
 +prefix+ - String with prefix
 +price+ - String with rate price
 +st+ - Direction's first letter for correct pagination
 +page+ - number of the page user should be returned to

 *Flash*:

 +Rate_already_set+ - if rate is already set
 +Prefix_was_not_found+ - desired rate was not found so it cannot be set
 +Rate_was_added+ - if rate was created successfully
 +Rate_was_not_added+ - if rate was not created successfully

 *Redirect*

 +rates_list+
=end

  # before_filter : tariff(find_taririff_from_id)
  def rate_new_quick
    params[:page].to_i > 0 ? @page = params[:page].to_i : @page = 1
    @prefix = params[:prefix]
    @price = params[:price]
    if Rate.find(:first,
                 :joins => "LEFT JOIN destinations ON (destinations.id = rates.destination_id)",
                 :conditions => ["rates.tariff_id =? AND destinations.prefix = ?", @tariff.id, @prefix])
      flash[:notice] = _("Rate_already_set")
      redirect_to(:action => :rates_list, :id => @tariff.id, :st => params[:st], :page => @page) and return false
    end
    @destination = Destination.find(:first, :conditions => ["prefix = ?", @prefix])
    mr = mor_11_extend?
    if @destination
      if @tariff.add_new_rate(@destination.id, @price, params[:increment_s], params[:min_time], params[:connection_fee], params[:ghost_percent], mr)
        flash[:status] = _("Rate_was_added")
      else
        flash[:notice] = _("Rate_was_not_added")
      end
    else
      flash[:notice] = _('Prefix_was_not_found')
    end
    redirect_to(:action => :rates_list, :id => @tariff.id, :st => params[:st], :page => @page) and return false
  end

=begin rdoc
 Shows list of free destinations for 1 direction. User can set rates for destinations.

 *Params*:

 +id+ - Tariff id
 +dir_id+ Direction id
 +st+ - Direction's first letter for correct pagination
 +page+ - list page number
=end
  # before_filter : tariff(find_taririff_from_id)
  def rate_new_by_direction
    params[:page].to_i > 0 ? @page = params[:page].to_i : @page = 1
    @st = params[:st]
    @direction = Direction.find(:first, :conditions => ['id = ?', params[:dir_id]])
    unless @direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to :action => :list and return false
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    #    MorLog.my_debug(@destinations)
    @total_items = @destinations.size
    @total_pages = (@total_items.to_d / session[:items_per_page].to_d).ceil
    istart = (@page-1)*session[:items_per_page]
    iend = (@page)*session[:items_per_page]-1
    #    MorLog.my_debug(istart)
    #    MorLog.my_debug(iend)
    @destinations = @destinations[istart..iend]
    @page_select_options = {
        :id => @tariff.id,
        :dir_id => @direction.id,
        :st => @st
    }
    @page_title = _('Rates_for_tariff') +" "+ _("Direction")+ ": " + @direction.name
    @page_icon = "money.png"
    #    MorLog.my_debug(@destinations)
  end

=begin rdoc

=end
  # before_filter : tariff(find_taririff_from_id)
  def rate_new_by_direction_add
    @st = params[:st]
    @direction = Direction.find(:first, :conditions => ['id = ?', params[:dir_id]])
    unless @direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to :action => :list and return false
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    mr = mor_11_extend?
    @destinations.each { |dest|
      if params["dest_#{dest.id}"] and params["dest_#{dest.id}"].to_s.length > 0
        @tariff.add_new_rate(dest.id, params["dest_#{dest.id}"], 1, 0,0, params[('gh_'+dest.id.to_s).intern], mr)
      end
    }
    flash[:status] = _('Rates_updated')
    redirect_to :action => 'rate_new_by_direction', :id => params[:id], :st => params[:st], :dir_id => @direction.id
  end

  # before_filter : tariff(find_taririff_from_id)
  def rate_new
    check_user_for_tariff(@tariff.id)

    if @tariff.purpose == 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller => :tariffs, :actions => :list and return false
    end

    @page_title = _('Add_new_rate_to_tariff') # +": " + @tariff.name
    @page_icon = "add.png"

    # st - from which letter starts rate's direction (usualy country)
    @st = "A"
    @st = params[:st].upcase if params[:st]
    @page = (params[:page] || 1).to_i
    offset = (@page -1) * session[:items_per_page].to_i

    @dests, total_records = @tariff.free_destinations_by_st(@st, session[:items_per_page], offset)
    @total_pages = (total_records.to_f / session[:items_per_page].to_f).ceil

    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id
  end

  # before_filter : tariff(find_taririff_from_id)
  def ghost_percent_edit
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @page_title = _('Ghost_percent')
    @rate = Rate.find(:first, :conditions => {:id => params[:rate_id]})
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @destination = @rate.destination
  end

  # before_filter : tariff(find_taririff_from_id)
  def ghost_percent_update
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @rate = Rate.find(:first, :conditions => {:id => params[:rate_id]})
    if @rate
      @rate.ghost_min_perc = params[:rate][:ghost_min_perc]
      @rate.save
    end

    flash[:status] = _('Rate_updated')
    redirect_to :action => :ghost_percent_edit, :id => @tariff.id, :rate_id => params[:rate_id]
  end

  # before_filter : tariff(find_taririff_from_id)
  def rate_try_to_add
    a=check_user_for_tariff(@tariff.id)
    return false if !a

    if @tariff.purpose == 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller => :tariffs, :actions => :list and return false
    end

    # st - from which letter starts rate's direction (usualy country)
    params[:st] ? st = params[:st].upcase : st = "A"

    mr = mor_11_extend?
    for dest in @tariff.free_destinations_by_st(st)
      #add only rates which are entered
      if params[(dest.id.to_s).intern].to_s.length > 0
        @tariff.add_new_rate(dest.id.to_s, params[(dest.id.to_s).intern], 1, 0,0, params[('gh_'+dest.id.to_s).intern], mr)
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to :action => 'rates_list', :id => params[:id], :st => st
    #    render :action => 'debug'
  end


  def rate_destroy
    rate = Rate.find(:first, :conditions => ["id = ?", params[:id]])
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    if rate
      a=check_user_for_tariff(rate.tariff_id)
      return false if !a

      st = rate.destination.direction.name[0, 1]
      rate.destroy_everything
    end

    flash[:status] = _('Rate_deleted')
    redirect_to :action => 'rates_list', :id => params[:tariff], :st => st
  end

  # =============== RATE DETAILS ==============

  def rate_details
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    rated = Ratedetail.find(:first, :conditions => ["rate_id = ?", params[:id]])

    if !rated
      rd = Ratedetail.new
      rd.start_time = "00:00:00"
      rd.end_time = "23:59:59"
      rd.rate = 0.to_d
      rd.connection_fee = 0.to_d
      rd.rate_id = params[:id].to_i
      rd.increment_s = 0.to_d
      rd.min_time = 0.to_d
      rd.daytype = "WD"
      rd.save
    end

    check_user_for_tariff(@rate.tariff_id)
    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Rate_details')
    @rate_details = @rate.ratedetails

    if @rate_details[0] and @rate_details[0].daytype == ""
      @WDFD = true
    else
      @WDFD = false

      @WDrdetails = []
      @FDrdetails = []
      for rd in @rate_details
        @WDrdetails << rd if rd.daytype == "WD"
        @FDrdetails << rd if rd.daytype == "FD"
      end

    end

    @tariff = @rate.tariff
    @destination = @rate.destination
    #every rate should have destination assigned, but since it is common to have 
    #broken relational itegrity, we should check whether destination is not nil
    unless @destination
      flash[:notice] = _('Rate_does_not_have_destination_assigned')
      redirect_to :controller => :callc, :action => :main 
    end 
    @can_edit = true

    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first, :conditions => ["reseller_id = ? AND tariff_id = ?", current_user.id, @tariff.id])
      @can_edit = false
    end
  end

  def ratedetails_manage
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a

    rdetails = @rate.ratedetails

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
        nrd = Ratedetail.new
        nrd.start_time = rd.start_time
        nrd.end_time = rd.end_time
        nrd.rate = rd.rate
        nrd.connection_fee = rd.connection_fee
        nrd.rate_id = rd.rate_id
        nrd.increment_s = rd.increment_s
        nrd.min_time = rd.min_time
        nrd.daytype = "FD"
        nrd.save

        rd.daytype = "WD"
        rd.save
      end

      flash[:status] = _('Rate_details_split')
    end


    redirect_to :action => 'rate_details', :id => @rate.id
  end


  def ratedetail_edit
    @ratedetail = Ratedetail.find_by_id(params[:id])
    unless @ratedetail
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    @page_title = _('Rate_details_edit')
    @page_icon = "edit.png"

    rate = Rate.find_by_id(@ratedetail.rate_id)
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    check_user_for_tariff(rate.tariff_id)

    rdetails = rate.ratedetails_by_daytype(@ratedetail.daytype)

    @tariff = rate.tariff
    @destination = rate.destination
    @etedit = (rdetails[(rdetails.size - 1)] == @ratedetail)

    #my_debug @etedit

  end


  def ratedetail_update
    @ratedetail = Ratedetail.find_by_id(params[:id])
    unless @ratedetail
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    rd = @ratedetail

    rate = Rate.find_by_id(@ratedetail.rate_id)
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    a=check_user_for_tariff(rate.tariff_id)
    return false if !a

    rdetails = rate.ratedetails_by_daytype(@ratedetail.daytype)

    if (params[:ratedetail] and params[:ratedetail][:end_time]) and ((nice_time2(rd.start_time) > params[:ratedetail][:end_time]) or (params[:ratedetail][:end_time] > "23:59:59"))
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id and return false
    end


    if @ratedetail.update_attributes(params[:ratedetail])

      # we need to create new rd to cover all day
      if (nice_time2(@ratedetail.end_time) != "23:59:59") and ((rdetails[(rdetails.size - 1)] == @ratedetail))
        st = @ratedetail.end_time + 1.second


        nrd = Ratedetail.new
        nrd.start_time = st.to_s
        nrd.end_time = "23:59:59"
        nrd.rate = rd.rate
        nrd.connection_fee = rd.connection_fee
        nrd.rate_id = rd.rate_id
        nrd.increment_s = rd.increment_s
        nrd.min_time = rd.min_time
        nrd.daytype = rd.daytype
        nrd.save
      end

      flash[:status] = _('Rate_details_was_successfully_updated')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id
    else
      render :action => 'ratedetail_edit'
    end
  end

  def ratedetail_new
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @page_title = _('Ratedetail_new')
    @page_icon = "add.png"
    @ratedetail = Ratedetail.new
    @ratedetail.start_time = "00:00:00"
    @ratedetail.end_time = "23:59:59"
  end

  def ratedetail_create
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @ratedetail = Ratedetail.new(params[:ratedetail])
    @ratedetail.rate_id = @rate.id
    if @ratedetail.save
      flash[:status] = _('Rate_detail_was_successfully_created')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id
    else
      render :action => 'ratedetail_new'
    end
  end

  def ratedetail_destroy
    @rate = Rate.find_by_id(params[:rate])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a

    rd = Ratedetail.find_by_id(params[:id])
    unless rd
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    rdetails = @rate.ratedetails_by_daytype(rd.daytype)


    if rdetails.size > 1

      #update previous rd
      et = nice_time2(rd.start_time - 1.second)
      daytype = rd.daytype
      prd = Ratedetail.find(:first, :conditions => ["rate_id = ? AND end_time = ? AND daytype = ?", @rate.id, et, daytype])
      if prd
        prd.end_time = "23:59:59"
        prd.save
      end
      rd.destroy
      flash[:status] = _('Rate_detail_was_successfully_deleted')
    else
      flash[:notice] = _('Cant_delete_last_rate_detail')
    end

    redirect_to :action => 'rate_details', :id => params[:rate]
  end


  # ======== XLS IMPORT =================
  def import_xls
    @step = 1
    @step = params[:step].to_i if params[:step]

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Analysis') if @step == 4
    @step_name = _('Creating_destinations') if @step == 5
    @step_name = _('Updating_rates') if @step == 6
    @step_name = _('Creating_new_rates') if @step == 7

    @page_title = (_('Import_XLS') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name).html_safe
    @page_icon = 'excel.png';

    @tariff = Tariff.find_by_id(params[:id])
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end
    a=check_user_for_tariff(@tariff.id)
    return false if !a

    if @step == 2
      if params[:file] or session[:file]
        if params[:file]
          @file = params[:file]
          session[:file] = @file.read if @file.size > 0
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_xls", :id => @tariff.id, :step => "1" and return false
        end

        file_name = '/tmp/temp_excel.xls'
        f = File.open(file_name, "wb")
        f.write(session[:file])
        f.close
        workbook = Excel.new(file_name)
        i=0
        session[:pagecount] = 0
        pages = []
        page = []
        #        MorLog.my_debug(workbook.info)
        last_sheet, count = count_data_sheets(workbook)
        if count == 1
          #          MorLog.my_debug("single")
          #          MorLog.my_debug(last_sheet.class)
          #          MorLog.my_debug(find_prefix_column(workbook, last_sheet))

        end

        #        MorLog.my_debug("++")

        flash[:status] = _('File_uploaded')
      end
    end
  end

  def find_prefix_column(workbook, sheet)
    workbook.default_sheet = sheet
    size = workbook.last_row
    midle = size/2
    midle.upto(size) do |index|
      workbook.row(index)
    end
  end

  def count_data_sheets(workbook)
    count = 0
    for sheet in workbook.sheets do
      workbook.default_sheet = sheet
      if workbook.last_row.to_i > 0 and workbook.last_column.to_i > 1
        count += 1
        last = sheet
      end
    end
    return sheet, count
  end

  # ======== CSV IMPORT =================
  def import_csv
    redirect_to :action => :import_csv2, :id => params[:id] and return false
  end

  def import_csv2

    @sep, @dec = nice_action_session_csv
    store_location

    params[:step] ? @step = params[:step].to_i : @step = 0
    @step = 0 unless (0..7).include?(@step.to_i)

    if (@step == 5) and reseller?
      @step = 6
    end

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Analysis') if @step == 4
    @step_name = _('Creating_destinations') if @step == 5
    @step_name = _('Updating_rates') if @step == 6
    @step_name = _('Creating_new_rates') if @step == 7

    if reseller?
      step = @step == 6 ? 5 : @step
      step = 6 if @step > 6
    else
      step = @step
    end
    @page_title = (_('Import_CSV') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name).html_safe
    @page_icon = 'excel.png';
    @help_link = "http://wiki.kolmisoft.com/index.php/Rate_import_from_CSV";

    @tariff = Tariff.find(:first, :conditions => ["id = ?", params[:id]])
    unless @tariff
      flash[:notice] = _("Tariff_Was_Not_Found")
      redirect_to :action => :list and return false
    end

    a=check_user_for_tariff(@tariff.id)
    return false if !a

    if @step == 0
      my_debug_time "**********import_csv2************************"
      my_debug_time "step 0"
      session["tariff_name_csv_#{@tariff.id}".to_sym] = nil
      session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
      session[:import_csv_tariffs_import_csv_options] = nil
    end

    if @step == 1
      my_debug_time "step 1"
      session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
      session["tariff_name_csv_#{@tariff.id}".to_sym] = nil
      if params[:file]
        @file = params[:file]
        if  @file.size > 0
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
          end
          if get_file_ext(@file.original_filename, "csv") == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
          end
          @file.rewind
          file = @file.read
          session[:file_size] = file.size
          session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = @tariff.save_file(file)
          flash[:status] = _('File_downloaded')
          redirect_to :action => "import_csv2", :id => @tariff.id, :step => "2" and return false
        else
          session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
        end
      else
        session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
      end
    end


    if @step == 2
      my_debug_time "step 2"
      my_debug_time "use : #{session["temp_tariff_name_csv_#{@tariff.id}".to_sym]}"
      if session["temp_tariff_name_csv_#{@tariff.id}".to_sym]
        file = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{@tariff.id}".to_sym]}.csv", 20).join("").to_s
        session[:file] = file
        a = check_csv_file_seperators(file, 2, 2)
        if a
          @fl = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{@tariff.id}".to_sym]}.csv", 1).join("").to_s.split(@sep)
          begin
            session["tariff_name_csv_#{@tariff.id}".to_sym] = @tariff.load_csv_into_db(session["temp_tariff_name_csv_#{@tariff.id}".to_sym], @sep, @dec, @fl)
            session[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session["tariff_name_csv_#{@tariff.id}".to_sym]}")
          rescue Exception => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            session[:import_csv_tariffs_import_csv_options] = {}
            session[:import_csv_tariffs_import_csv_options][:sep] = @sep
            session[:import_csv_tariffs_import_csv_options][:dec] = @dec
            session[:file] = File.open("/tmp/#{session["temp_tariff_name_csv_#{@tariff.id}".to_sym]}.csv", "rb").read
            Tariff.clean_after_import(session["temp_tariff_name_csv_#{@tariff.id}".to_sym])
            session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
            flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
            redirect_to :action => "import_csv2", :id => @tariff.id, :step => "2" and return false
          end
          flash[:status] = _('File_uploaded') if !flash[:notice]
        end
      else
        session["tariff_name_csv_#{@tariff.id}".to_sym] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv2", :id => @tariff.id, :step => "1" and return false
      end
      @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
    end

    if  @step > 2

      unless ActiveRecord::Base.connection.tables.include?(session["temp_tariff_name_csv_#{@tariff.id}".to_sym])
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
      end

      if session["tariff_name_csv_#{@tariff.id}".to_sym]

        if @step == 3
          my_debug_time "step 3"
          if params[:prefix_id] and params[:rate_id] and params[:prefix_id].to_i >= 0 and params[:rate_id].to_i >= 0
            @optins = {}
            @optins[:imp_prefix] = params[:prefix_id].to_i
            @optins[:imp_rate] = params[:rate_id].to_i
            @optins[:imp_subcode] = params[:subcode].to_i
            @optins[:imp_increment_s] = params[:increment_id].to_i
            @optins[:imp_min_time] = params[:min_time_id].to_i
            @optins[:imp_ghost_percent] = params[:ghost_percent_id].to_i
            @optins[:imp_cc] = params[:country_code_id].to_i

            @optins[:imp_city] = params[:city_id].to_i
            @optins[:imp_state] = params[:state_id].to_i
            @optins[:imp_lata] = params[:lata_id].to_i
            @optins[:imp_tier] = params[:tier_id].to_i
            @optins[:imp_ocn] = params[:ocn_id].to_i

            @optins[:imp_country] = params[:country_id].to_i
            @optins[:imp_connection_fee] = params[:connection_fee_id].to_i
            @optins[:imp_date_day_type] = params[:rate_day_type].to_s

            @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
            ##5808 not cheking any more
            #unless flash[:notice_2].blank?
            #  flash[:notice] = _('Tariff_import_incorrect_time').html_safe
            #  flash[:notice] += '<br /> * '.html_safe + _('Please_select_period_without_collisions').html_safe
            #  redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
            #end

            @optins[:imp_time_from_type] = params[:time_from][:hour].to_s + ":" + params[:time_from][:minute].to_s + ":" + params[:time_from][:second].to_s if params[:time_from]
            @optins[:imp_time_till_type] = params[:time_till][:hour].to_s + ":" + params[:time_till][:minute].to_s + ":" + params[:time_till][:second].to_s if params[:time_till]
            @optins[:imp_update_dest_names] = params[:update_dest_names].to_i if admin?
            @optins[:imp_update_subcodes] = params[:update_subcodes].to_i if admin?

            if admin? and params[:update_dest_names].to_i == 1
              if params[:destination_id] and params[:destination_id].to_i >=0
                @optins[:imp_dst] = params[:destination_id].to_i

                # Saving old Destination names before import
		check_destination_names = "select count(original_destination_name) as notnull from " + session["tariff_name_csv_#{@tariff.id}".to_sym].to_s + " where original_destination_name is not NULL"
		if (ActiveRecord::Base.connection.select(check_destination_names).first["notnull"].to_i rescue 0) == 0
	          sql = "UPDATE " + session["tariff_name_csv_#{@tariff.id}".to_sym].to_s + " JOIN destinations ON (replace(col_1, '\\r', '') = destinations.prefix) SET original_destination_name = destinations.name WHERE ned_update IN (1, 2, 3, 4)"
		  ActiveRecord::Base.connection.execute(sql)
		end

              else
                flash[:notice] = _('Please_Select_Columns_destination')
                redirect_to :action => "import_csv2", :id => @tariff.id, :step => "2" and return false
              end
            else
              @optins[:imp_dst] = params[:destination_id].to_i
            end
            @optins[:imp_update_directions] = params[:update_directions].to_i if admin?
            #priority over csv

            @optins[:manual_connection_fee] = ""
            @optins[:manual_increment] = ""
            @optins[:manual_min_time] = ""

            @optins[:manual_connection_fee] = params[:manual_connection_fee] if params[:manual_connection_fee]
            @optins[:manual_increment] = params[:manual_increment] if params[:manual_increment]
            @optins[:manual_min_time] = params[:manual_min_time] if params[:manual_min_time]
            @optins[:manual_ghost_percent] = params[:manual_ghost_percent] if params[:manual_ghost_percent]

            @optins[:sep] = @sep
            @optins[:dec] = @dec
            @optins[:file]= session[:file]
            @optins[:file_size] = session[:file].size
            @optins[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session["tariff_name_csv_#{@tariff.id}".to_sym]}")
            session["tariff_import_csv2_#{@tariff.id}".to_sym] = @optins
            flash[:status] = _('Columns_assigned')
          else
            flash[:notice] = _('Please_Select_Columns')
            redirect_to :action => "import_csv2", :id => @tariff.id, :step => "2" and return false
          end
        end


        if session["tariff_import_csv2_#{@tariff.id}".to_sym] and session["tariff_import_csv2_#{@tariff.id}".to_sym][:imp_prefix] and session["tariff_import_csv2_#{@tariff.id}".to_sym][:imp_rate]

          #check how many destinations and should we create new ones?
          if @step == 4
            my_debug_time "step 4"
            @tariff_analize = @tariff.analize_file(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym])
            session[:bad_destinations] = @tariff_analize[:bad_prefixes]
            session[:bad_lines_array] = @tariff_analize[:bad_prefixes]
            session[:bad_lines_status_array] = @tariff_analize[:bad_prefixes_status]

            flash[:status] = _('Analysis_completed')
            session["tariff_analize_csv2_#{@tariff.id}".to_sym] = @tariff_analize
          end

          # Create new destinations.
          if @step == 5
            if Confline.get_value('Destination_create', current_user.id).to_i == 1
              #redirect back
              flash[:notice] = _('Please_wait_while_first_import_is_finished')
              redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
            else
              @tariff_analize = session["tariff_analize_csv2_#{@tariff.id}".to_sym]
              my_debug_time "step 5"
              if ["admin", "accountant"].include?(session[:usertype])
                begin
                  session["tariff_analize_csv2_#{@tariff.id}".to_sym][:created_destination_from_file] = @tariff.create_deatinations(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
                  flash[:status] = _('Created_destinations') + ": #{session["tariff_analize_csv2_#{@tariff.id}".to_sym][:created_destination_from_file]}"
                  if session["tariff_import_csv2_#{@tariff.id}".to_sym][:imp_update_dest_names].to_i == 1
                    session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_destination_from_file] = @tariff.update_destinations(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
                    flash[:status] += "<br />"+ _('Destination_names_updated') + ": #{session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_destination_from_file]}"
                  end
                  if session["tariff_import_csv2_#{@tariff.id}".to_sym][:imp_update_subcodes].to_i == 1
                    session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_subcodes_from_file] = @tariff.update_subcodes(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
                    flash[:status] += "<br />"+ _('Subcodes_updated') + ": #{session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_subcodes_from_file]}"
                  end
                  if session["tariff_import_csv2_#{@tariff.id}".to_sym][:imp_update_directions].to_i == 1
                    session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_directions_from_file] = @tariff.update_directions(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
                    flash[:status] += "<br />"+ _('Directions_based_on_country_code_updated') + ": #{session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_directions_from_file]}"
                  end
                rescue Exception => e
                  my_debug_time e.to_yaml
                  flash[:notice] = _('collision_Please_start_over')
                  my_debug_time "clean start"
                  Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
                  session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
                  my_debug_time "clean done"
                  redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
                end
              else
                flash[:notice] = _('No_Destinations_Were_Created')
              end
            end
          end

          #update rates (ratedetails actually)
          if @step == 6
            begin
              @tariff_analize = session["tariff_analize_csv2_#{@tariff.id}".to_sym]
              my_debug_time "step 6"
              session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_rates_from_file] = @tariff.update_rates_from_csv(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
              @tariff.update_rates_from_csv(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
              flash[:status] = _('Rates_updated') + ": " + @tariff_analize[:rates_to_update].to_s
            rescue Exception => e
              my_debug_time e.to_yaml
              flash[:notice] = _('collision_Please_start_over')
              my_debug_time "clean start"
              Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
              session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
              my_debug_time "clean done"
              redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
            end
          end

          #create rates/ratedetails
          if @step == 7
            begin
              @tariff_analize = session["tariff_analize_csv2_#{@tariff.id}".to_sym]
              my_debug_time "step 7"
              session["tariff_analize_csv2_#{@tariff.id}".to_sym][:created_rates_from_file] = @tariff.create_rates_from_csv(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
              @tariff.insert_ratedetails(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
              my_debug_time "clean start"
              Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
              MorLog.my_debug session.to_yaml
              session[:file] = nil

              my_debug_time "clean done"
              flash[:status] = _('New_rates_created') + ": " + @tariff_analize[:new_rates_to_create].to_s
              Action.add_action(session[:user_id], "tariff_import_2", _('Tariff_was_imported_from_CSV'))
            rescue Exception => e
              my_debug_time e.to_yaml
              flash[:notice] = _('collision_Please_start_over')
              my_debug_time "clean start"
              #Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
              session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
              my_debug_time "clean done"
              redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
            end
          end

        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => "import_csv2", :id => @tariff.id, :step => "2" and return false
        end
      else
        flash[:notice] = _('Zero_file')
        redirect_to :controller => "tariffs", :action => "list" and return false
      end
    end
  end

  def bad_rows_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @rows = session[:bad_lines_array]
      @status = session[:bad_lines_status_array]
    else
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id]}".to_sym])
        @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{params[:tariff_id]}".to_sym]} WHERE f_error = 1")
      end
    end
    render(:layout => "layouts/mor_min")
  end

  def dst_to_create_from_csv
    @page_title = _('Dst_to_create_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2=0
    if !@file.blank?
      if params[:csv2].to_i == 0
       # @sep = session["import_csv_tariffs_import_csv2_options".to_sym][:sep]
       # @csv_file = CSV.new(@file, {:col_sep => @sep, :headers => false, :return_headers => false})
       # begin
       #   @csv_file.each { |row|}
       #   @csv_file.rewind
       # rescue
       #   flash[:notice] = csv_import_invalid_file_notice
       #   redirect_to :controller => "tariffs", :action => "list" and return false
       # end
        flash[:notice] = _('Zero_file_size')
        redirect_to :controller => "tariffs", :action => "list"
      else
        @csv2=1
        if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id]}".to_sym])
          @csv_file = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{params[:tariff_id]}".to_sym]} WHERE not_found_in_db = 1 AND f_error = 0")
        end
        render(:layout => "layouts/mor_min")
      end
    else
      flash[:notice] = _('Zero_file_size')
      redirect_to :controller => "tariffs", :action => "list"
    end
  end

  def dst_to_update_from_csv
    @page_title = _('Dst_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id]}".to_sym])
        @dst = ActiveRecord::Base.connection.select_all("SELECT destinations.prefix, col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_dst]} as new_name, IFNULL(original_destination_name,destinations.name) as dest_name FROM destinations JOIN #{session["tariff_name_csv_#{params[:tariff_id]}".to_sym]} ON (replace(col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]}, '\\r', '') = prefix)  WHERE ned_update IN (1, 3, 5, 7) ")
      end
    end
    render(:layout => "layouts/mor_min")
  end


  def subcode_to_update_from_csv
    @page_title = _('Destination_subcodes_update')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:subcodes_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id]}".to_sym])
        @dst = ActiveRecord::Base.connection.select_all("SELECT destinations.prefix, col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_subcode]} as new_sub, destinations.subcode as dest_sub FROM destinations JOIN #{session["tariff_name_csv_#{params[:tariff_id]}".to_sym]} ON (replace(col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]}, '\\r', '') = prefix)  WHERE ned_update IN (2, 3, 6, 7) ")
      end
    end
    render(:layout => "layouts/mor_min")
  end


  def dir_to_update_from_csv
    @page_title = _('Direction_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id]}".to_sym])
        imp_cc = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_cc]
        table_name = session["tariff_name_csv_#{params[:tariff_id]}".to_sym]
        imp_prefix = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]
        @directions = ActiveRecord::Base.connection.select_all("SELECT prefix, destinations.direction_code old_direction_code, replace(col_#{imp_cc}, '\\r', '') new_direction_code from #{table_name} join directions on (replace(col_#{imp_cc}, '\\r', '') = directions.code) join destinations on (replace(col_#{imp_prefix}, '\\r', '') = destinations.prefix) WHERE destinations.direction_code != directions.code;")
      end
    end
    render(:layout => "layouts/mor_min")
  end

  def rate_import_status
    #render(:layout => false)
  end

  def rate_import_status_view
    render(:layout => false)
  end

  # before_filter : tariff(find_taririff_from_id)
  def delete_all_rates
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @tariff.delete_all_rates
    flash[:status] = _('All_rates_deleted')
    redirect_to :action => 'list'
  end

=begin
  returns first letter of destination group name if it has any rates set, if nothing is set return 'A'
=end
  def tariff_dstgroups_with_rates(tariff_id)
    query = "SELECT destinationgroups.name   FROM destinationgroups  JOIN rates ON (rates.destinationgroup_id = destinationgroups.id )  WHERE rates.tariff_id = #{tariff_id}  GROUP BY destinationgroups.id   ORDER BY destinationgroups.name, destinationgroups.desttype ASC;"
    res = ActiveRecord::Base.connection.select_all(query) 
    res.map! { |rate| rate['name'][0..0] } 
    res.uniq
  end 

  def dstgroup_name_first_letters
    query = "SELECT destinationgroups.name  
             FROM   destinations 
             JOIN   destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id) 
             GROUP BY destinations.destinationgroup_id 
             ORDER BY destinationgroups.name, destinationgroups.desttype ASC" 
    res = ActiveRecord::Base.connection.select_all(query) 
    res.map! {|dstgroup| dstgroup['name'][0..0].upcase}
    res.uniq
  end 

  # =============== RATES FOR USER ==================
  # before_filter : tariff(find_taririff_from_id)
  def user_rates_list
    check_user_for_tariff(@tariff.id)

    if @tariff.purpose != 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller => :tariffs, :actions => :list and return false
    end


    @page_title = _('Rates_for_tariff') #+": " + @tariff.name
    @page_icon = "coins.png"
    @res =[]
    session[:tariff_user_rates_list] ? @options = session[:tariff_user_rates_list] : @options = {:page => 1}
    @options[:page] = params[:page].to_i if !params[:page].blank?
    @items_per_page = Confline.get_value("Items_Per_Page").to_i
    @letter_select_header_id = @tariff.id

    #dst groups are rendered in 'pages' according to they name's first letter
    #if no letter is specified in params, by default we show page full of 
    #dst groups
    @directions_first_letters = tariff_dstgroups_with_rates(@tariff.id)
    @st = (params[:st] ? params[:st].upcase : (@directions_first_letters[0] || 'A'))

    #needed to know whether to make link to sertain letter or not 
    #when rendering letter_select_header
    @directions_defined = dstgroup_name_first_letters()

    @page = 1
    @page = params[:page].to_i if params[:page]

    if params[:s_prefix] and !params[:s_prefix].blank?
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/, '')
      cond = "prefix LIKE '#{@s_prefix.to_s}'"
      @search =1
    else
      cond = "destinationgroups.name LIKE '#{@st}%'"
    end

    #Cia refactorintas , veikia x7 greiciau...
    sql = "SELECT * FROM (
                          SELECT destinationgroups.flag, destinationgroups.name, destinationgroups.desttype, destinationgroup_id AS dg_id, COUNT(DISTINCT destinations.id) AS destinations  FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                WHERE #{cond}
                                GROUP BY destinations.destinationgroup_id
                                ORDER BY destinationgroups.name, destinationgroups.desttype ASC
                         ) AS dest
              LEFT JOIN (SELECT rates.ghost_min_perc, rates.destinationgroup_id AS dg_id2, rates.id AS rate_id, COUNT(DISTINCT aratedetails.id) AS arates_size,  IF(art2.id IS NULL, aratedetails.price, NULL) AS price, IF(art2.id IS NULL, aratedetails.round, NULL) AS round, IF(art2.id IS NOT NULL,  NULL, 'minute') as artype FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                LEFT JOIN rates ON (rates.destinationgroup_id = destinationgroups.id )
                                LEFT JOIN aratedetails ON (aratedetails.rate_id = rates.id)
                                LEFT JOIN aratedetails AS art2 ON (art2.rate_id = rates.id and art2.artype != 'minute')
                                WHERE #{cond}  AND rates.tariff_id = #{@tariff.id}
                                GROUP BY rates.destinationgroup_id
                        ) AS rat ON (dest.dg_id = rat.dg_id2)"

    #@rates = Rate.find(:all, :conditions=>["rates.tariff_id = ? #{con}", @tariff.id], :include => [:aratedetails, :destinationgroup ], :order=>"destinationgroups.name, destinationgroups.desttype ASC" )
    @res = ActiveRecord::Base.connection.select_all(sql)
    @options[:total_pages] = (@res.size.to_d / @items_per_page.to_d).ceil
    @options[:page] = 1 if @options[:page] > @options[:total_pages]
    istart = (@options[:page]-1)*@items_per_page
    iend = (@options[:page])*@items_per_page-1
    @res = @res[istart..iend]
    session[:tariff_user_rates_list] = @options

    rids= []
    @res.each { |res| rids << res['rate_id'].to_i if !res['rate_id'].blank? }
    @rates_list = Rate.find(:all, :conditions => ["rates.id IN (#{rids.join(',')})"], :include => [:aratedetails, :tariff, :destinationgroup]) if rids.size.to_i > 0


    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first, :conditions => ["reseller_id = ? AND tariff_id = ?", current_user.id, @tariff.id])
      @can_edit = false
    end

  end

  def user_arates
    @rate = Rate.find(:first, :conditions => ["id = ?", params[:id]])
    if !@rate
      Action.add_action(session[:user_id], "error", "Rate: #{params[:id].to_s} was not found") if session[:user_id].to_i != 0
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    @tariff = @rate.tariff
    @page_title = _('Rates_for_tariff') +": " + @tariff.name
    @dgroup = @rate.destinationgroup

    @st = params[:st]
    @dt = params[:dt]
    @dt = "" if not params[:dt]

    @ards = Aratedetail.find(:all, :conditions => ["rate_id = ? AND start_time = ? AND daytype = ?", @rate.id, @st, @dt], :order => "aratedetails.from ASC, artype ASC")

    @ards and @ards.size > 0 ? @et = nice_time2(@ards[0].end_time) : @et = "23:59:59"

    @can_add = false
    #last ard
    lard = @ards[@ards.size - 1]
    if lard
      if (lard.duration != -1 and lard.artype == "minute") or (lard.artype == "event")
        @can_add = true
        @from = lard.from + lard.duration if lard.artype == "minute"
        @from = lard.from if lard.artype == "event"
      end
    end

    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first, :conditions => ["reseller_id = ? AND tariff_id = ?", current_user.id, @tariff.id])
      @can_edit = false
    end

  end

  # before_filter : tariff(find_taririff_from_id)
  def user_arates_full
    check_user_for_tariff(@tariff.id)

    @page_title = _('Rates_for_tariff') +": " + @tariff.name
    @dgroup = Destinationgroup.find_by_id(params[:dg])
    unless @dgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :list and return false
    end
    @rate = @dgroup.rate(@tariff.id)

    if not @rate
      rate = Rate.new
      rate.tariff_id = @tariff.id
      rate.destinationgroup_id = @dgroup.id
      rate.save

      ard = Aratedetail.new
      ard.from = 1
      ard.duration = -1
      ard.artype = "minute"
      ard.round = 1
      ard.price = 0
      ard.rate_id = rate.id
      ard.save

      @rate = rate
      #my_debug "creating rate and ard"
    end

    @ards = @rate.aratedetails

    if not @ards[0]

      ard = Aratedetail.new
      ard.from = 1
      ard.duration = -1
      ard.artype = "minute"
      ard.round = 1
      ard.price = 0
      ard.rate_id = @rate.id
      ard.save

      @ards = @rate.aratedetails
    end


    if @ards[0].daytype.to_s == ""
      @WDFD = true

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = '' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for r in res
        @st_arr << r["start_time"].strftime("%H:%M:%S")
        @et_arr << r["end_time"].strftime("%H:%M:%S")
      end

    else
      @WDFD = false

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = 'WD' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Wst_arr = []
      @Wet_arr = []
      for r in res
        @Wst_arr << r["start_time"].strftime("%H:%M:%S")
        @Wet_arr << r["end_time"].strftime("%H:%M:%S")
      end

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = 'FD' AND rate_id = #{@rate.id} GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Fst_arr = []
      @Fet_arr = []
      for r in res
        @Fst_arr << r["start_time"].strftime("%H:%M:%S")
        @Fet_arr << r["end_time"].strftime("%H:%M:%S")
      end

    end

    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first, :conditions => ["reseller_id = ? AND tariff_id = ?", current_user.id, @tariff.id])
      @can_edit = false
    end

  end


  def user_ard_time_edit
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a

    dt = params[:daytype]

    et = params[:date][:hour] + ":" + params[:date][:minute] + ":" + params[:date][:second]
    st = params[:st]

    if Time.parse(st) > Time.parse(et)
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id and return false
    end

    rdetails = @rate.aratedetails_by_daytype(params[:daytype])

    ard = Aratedetail.find(:first, :conditions => "rate_id = #{@rate.id} AND start_time = '#{st}'  AND daytype = '#{dt}'")

    #my_debug ard.start_time
    #my_debug rdetails[(rdetails.size - 1)].start_time

    # we need to create new rd to cover all day
    if (et != "23:59:59") and ((rdetails[(rdetails.size - 1)].start_time == ard.start_time))
      nst = Time.mktime('2000', '01', '01', params[:date][:hour], params[:date][:minute], params[:date][:second]) + 1.second
      #my_debug nst
      ards = Aratedetail.find(:all, :conditions => "rate_id = #{@rate.id} AND start_time = '#{st}'   AND daytype = '#{dt}'")

      for a in ards

        na = Aratedetail.new
        na.from = a.from
        na.duration = a.duration
        na.artype = a.artype
        na.round = a.round
        na.price = a.price
        na.rate_id = a.rate_id
        na.start_time = nst.to_s
        na.end_time = "23:59:59"
        na.daytype = a.daytype
        na.save

        a.end_time = et
        a.save

      end

    end


    flash[:status] = _('Rate_details_updated')
    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id
  end


  def artg_destroy
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    dt = params[:dt]
    dt = "" if not params[:dt]
    st = params[:st]

    ards = Aratedetail.find(:all, :conditions => "rate_id = #{@rate.id} AND start_time = '#{st}'   AND daytype = '#{dt}'")
    #my_debug ards.size
    pet = nice_time2(ards[0].start_time - 1.second)

    for a in ards
      a.destroy
    end

    pards = Aratedetail.find(:all, :conditions => "rate_id = #{@rate.id} AND end_time = '#{pet}'   AND daytype = '#{dt}'")
    for pa in pards
      pa.end_time = "23:59:59"
      pa.save
    end


    flash[:status] = _('Rate_details_updated')
    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id

  end


  def ard_manage
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a

    rdetails = @rate.aratedetails

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
        nrd = Aratedetail.new
        nrd.start_time = rd.start_time
        nrd.end_time = rd.end_time
        nrd.from = rd.from
        nrd.duration = rd.duration
        nrd.rate_id = rd.rate_id
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


    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id


  end

  #update one rate
  def user_rate_update
    @ard = Aratedetail.find_by_id(params[:id])
    unless @ard
      flash[:notice]=_('Aratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    #@dgroup = @ard.rate.destinationgroup
    #@tariff = @ard.rate.tariff

    a=check_user_for_tariff(@ard.rate.tariff_id)
    return false if !a
    if params[:infinity] == "1"
      p_duration = -1
    else
      p_duration = params[:duration].to_i
    end
    from_duration = params[:from].to_i+p_duration
    from_duration_db = @ard.from.to_i + @ard.duration.to_i
    rate_id = @ard.rate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype

    if (p_duration != -1 and from_duration < params[:round].to_i and params[:rate].to_i == 0) or (params[:rate].to_i == 1 and @ard.duration.to_i != -1 and from_duration_db < params["round_#{@ard.id}".to_sym].to_i)
      flash[:notice] = _('Round_by_is_too_big')
    else
      if params[:rate].to_i == 0
        artype = params[:artype]

        duration = params[:duration].to_i
        infinity = params[:infinity]
        duration = -1 if infinity == "1" and artype == "minute"
        duration = 0 if artype == "event"

        round = params[:round].to_i
        price = params[:price].to_d
        round = 1 if round < 1

        @ard.from = params[:from]
        @ard.artype = artype
        @ard.duration = duration
        @ard.round = round
        @ard.price = price
      else
        @ard.price = params["price_#{@ard.id}".to_sym].to_d
        @ard.round = params["round_#{@ard.id}".to_sym].to_i
        #@ard.ghost_percent = params["ghost_percent_#{@ard.id}".to_sym].to_d if mor_11_extend?
      end
      @ard.save
      flash[:status] = _('Rate_updated')
    end
    redirect_to :action => 'user_arates', :id => rate_id, :st => st, :dt => dt
  end


  def user_rate_add
    #@tariff = Tariff.find(params[:id])
    #@dgroup = Destinationgroup.find(params[:dg])
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @ard = Aratedetail.new

    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a
    from_duration = params[:from].to_i+params[:duration].to_i
    artype = params[:artype]

    duration = params[:duration].to_i
    infinity = params[:infinity]
    duration = -1 if infinity == "1" and artype == "minute"
    duration = 0 if artype == "event"

    round = params[:round].to_i
    price = params[:price].to_d
    round = 1 if round < 1

    rate_id = @rate.id
    st = params[:st]
    et = params[:et]
    dt = params[:dt]
    dt = "" if not params[:dt]
    if params[:duration].to_i!= -1 and from_duration < params[:round].to_i
      flash[:notice] = _('Round_by_is_too_big')
    else
      @ard.from = params[:from]
      @ard.artype = artype
      @ard.duration = duration
      @ard.round = round
      @ard.price = price
      @ard.rate_id = @rate.id
      @ard.daytype = dt
      @ard.start_time = st
      @ard.end_time = et
      @ard.save
      flash[:status] = _('Rate_updated')
    end
    redirect_to :action => 'user_arates', :id => rate_id, :st => st, :dt => dt

  end

  def user_rate_delete
    @ard = Aratedetail.find_by_id(params[:id])
    unless @ard
      flash[:notice]=_('Aratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    #@dgroup = @ard.rate.destinationgroup

    a=check_user_for_tariff(@ard.rate.tariff)
    return false if !a

    rate_id = @ard.rate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype

    @ard.destroy

    flash[:status] = _('Rate_deleted')
    redirect_to :action => 'user_arates', :id => rate_id, :st => st, :dt => dt

  end

  #update all rates at once
  # before_filter : tariff(find_taririff_from_id)
  def user_rates_update
    a=check_user_for_tariff(@tariff.id)
    return false if !a

    @dgroups = Destinationgroup.where("destinationgroups.name LIKE '#{params[:st]}%'").order("name ASC, desttype ASC").all

    for dg in @dgroups

      price = ""
      price = params[("rate" + dg.id.to_s).intern] if params[("rate" + dg.id.to_s).intern]
      round = params[("round" + dg.id.to_s).intern].to_i
      round = 1 if round < 0
      #      if price.to_d != 0 or round != 1
      rrate = dg.rate(@tariff.id)
      unless price.blank?
        #let's create ard
        unless rrate
          rate = Rate.new
          rate.tariff_id = @tariff.id
          rate.destinationgroup_id = dg.id
          rate.ghost_min_perc = params[("gch" + dg.id.to_s).intern].to_i if mor_11_extend?
          rate.save

          ard = Aratedetail.new
          ard.from = 1
          ard.duration = -1
          ard.artype = "minute"
          ard.round = round
          ard.price = price.to_d
          ard.rate_id = rate.id
          ard.save

          #my_debug "create rate"

        else
          #update existing ard
          aratedetails = rrate.aratedetails
          #my_debug aratedetails.size
          if aratedetails.size == 1
            ard = aratedetails[0]
            #my_debug price
            #my_debug "--"
            if price == ""
              rrate.destroy_everything
              #ard.destroy
            else
              from_duration_db = ard.from.to_i + ard.duration.to_i
              if ard.duration.to_i != -1 and from_duration_db < round.to_i
                flash[:notice] = _('Rate_not_updated_round_by_is_too_big') + ': '+ "#{dg.name}"
                redirect_to :action => 'user_rates_list', :id => @tariff.id, :page => params[:page], :st => params[:st], :s_prefix => params[:s_prefix] and return false
              else
                ard.price = price.to_d
                ard.round = round
                ard.save
              end
            end
          end

        end
      else
        if rrate
          rrate.ghost_min_perc = params[("gch" + dg.id.to_s).intern].to_i if mor_11_extend?
          rrate.save
        end
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to :action => 'user_rates_list', :id => @tariff.id, :page => params[:page], :st => params[:st], :s_prefix => params[:s_prefix] and return false
  end


  def user_rate_destroy
    rate = Rate.find_by_id(params[:id])
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    tariff_id = rate.tariff_id

    a=check_user_for_tariff(tariff_id)
    return false if !a

    rate.destroy_everything

    flash[:status] = _('Rate_deleted')
    redirect_to :action => 'user_rates_list', :id => tariff_id, :page => params[:page], :st => params[:st], :s_prefix => params[:s_prefix]

  end

  #for final user
  # before_filter : user; tariff
  def user_rates
    @page_title = _('Personal_rates')
    @page_icon = "coins.png"
    if session[:show_rates_for_users].to_i != 1 and session[:usertype].to_s != 'admin'
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    @Show_Currency_Selector = true

    @page = 1
    @page = params[:page].to_i if params[:page]

    (params[:st] and ("A".."Z").include?(params[:st].upcase)) ? @st = params[:st].upcase : @st = "A"
    @dgroupse = Destinationgroup.find(:all, :conditions => ["name like ?", "#{@st}%"], :order => "name ASC, desttype ASC")

    @dgroups = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @dgroupse.size - 1 if iend > (@dgroupse.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @dgroups << @dgroupse[i]
      logger.fatal "ffffffffffffffffffffffffffff"
    end

    if @tariff.purpose == 'user'
      @total_pages = (@dgroupse.size.to_d / session[:items_per_page].to_d).ceil
      #@rates = @tariff.rates_by_st(@st, 0, 10000)
    else


      @rates = @tariff.rates_by_st(@st, 0, 10000)
      @total_pages = (@rates.size.to_d / session[:items_per_page].to_d).ceil

      @all_rates = @rates
      @rates = []
      iend = ((session[:items_per_page] * @page) - 1)
      iend = @all_rates.size - 1 if iend > (@all_rates.size - 1)
      for i in ((@page - 1) * session[:items_per_page])..iend
        @rates << @all_rates[i]
      end

      exrate = Currency.count_exchange_rate(@tariff.currency, session[:show_currency].gsub(/[^A-Za-z]/, ''))
      @ratesd = Ratedetail.find_all_from_id_with_exrate({:rates => @rates, :exrate => exrate, :destinations => true, :directions => true})
    end
    @use_lata = @st == "U" ? true : false

    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id

    @exchange_rate = count_exchange_rate(@tariff.currency, session[:show_currency].gsub(/[^A-Za-z]/, ''))
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], session[:show_currency].gsub(/[^A-Za-z]/, ''))
    @show_rates_without_tax = Confline.get_value("Show_Rates_Without_Tax", @user.owner_id)
  end

  # before_filter : user; tariff
  def user_rates_detailed
    @page_title = _('Personal_rates')
    @page_icon = "view.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Advanced_Rates"
    #    @user = current_user
    #    @tariff = @user.tariff
    if !@tariff or Confline.get_value("Show_Advanced_Rates_For_Users", current_user.owner_id).to_i == 0 or session[:show_rates_for_users].to_i != 1
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

    @page_title = _("Detailed_rates")
    @dgroup = Destinationgroup.find_by_id(params[:id])
    unless @dgroup
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    @rate = @dgroup.rate(@tariff.id)
    unless @rate
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

    @ards = @rate.aratedetails

    if @ards[0].daytype.to_s == ""
      @WDFD = true

      sql = "SELECT * FROM aratedetails WHERE daytype = '' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      @day_arr = ActiveRecord::Base.connection.select_all(sql)
    else
      @WDFD = false

      sql = "SELECT * FROM aratedetails WHERE daytype = 'WD' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      @wd_arr = ActiveRecord::Base.connection.select_all(sql)

      sql = "SELECT * FROM aratedetails WHERE daytype = 'FD' AND rate_id = #{@rate.id} GROUP BY start_time ORDER BY start_time ASC"
      @fd_arr = ActiveRecord::Base.connection.select_all(sql)
    end
    @exchange_rate = count_exchange_rate(@tariff.currency, session[:show_currency])
    @show_rates_without_tax = Confline.get_value("Show_Rates_Without_Tax", @user.owner_id)
  end

  def user_advrates
    @page_title = _('Rates_details')
    @page_icon = "coins.png"

    @dgroup = Destinationgroup.find_by_id(params[:id])
    unless @dgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :list and return false
    end
    @rate = @dgroup.rate(session[:tariff_id])
    @custrate = @dgroup.custom_rate(session[:user_id])

    @cards = Acustratedetail.find(:all, :conditions => "customrate_id = #{@custrate.id}", :order => "daytype DESC, start_time ASC, acustratedetails.from ASC, artype ASC") if @custrate
    @ards = Aratedetail.find(:all, :conditions => "rate_id = #{@rate.id}", :order => "daytype DESC, start_time ASC, aratedetails.from ASC, artype ASC")

    if @cards and @cards.size > 0
      table = "acustratedetails"
      trate_id = "customrate_id"
      rate_id = @custrate.id
    else
      table = "aratedetails"
      trate_id = "rate_id"
      rate_id = @rate.id
    end

    if @ards[0].daytype == ""
      @WDFD = true


      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = '' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for r in res
        @st_arr << r["start_time"]
        @et_arr << r["end_time"]
      end

    else
      @WDFD = false

      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = 'WD' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Wst_arr = []
      @Wet_arr = []
      for r in res
        @Wst_arr << r["start_time"]
        @Wet_arr << r["end_time"]
      end

      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = 'FD' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Fst_arr = []
      @Fet_arr = []
      for r in res
        @Fst_arr << r["start_time"]
        @Fet_arr << r["end_time"]
      end

    end

    @tax = session[:tax]
  end

  #======= Day setup ==========

  def day_setup
    @page_title = _('Day_setup')
    @page_icon = "date.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Day_setup"

    @days = Day.find(:all, :order => "date ASC")

  end

  def day_add

    date = params[:date][:year] + "-" + good_date(params[:date][:month]) + "-" + good_date(params[:date][:day])
    #my_debug  date

    # real_date = Time.mktime(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day]))

    if validate_date(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day])) == 0
      flash[:notice] = _('Bad_date')
      redirect_to :action => 'day_setup' and return false
    end

    #my_debug "---"


    if Day.find(:first, :conditions => ["date = ? ", date])
      flash[:notice] = _('Duplicate_date')
      redirect_to :action => 'day_setup' and return false
    end

    day = Day.new
    day.date = date
    day.daytype = params[:daytype]
    day.description = params[:description]
    day.save

    flash[:status] = _('Day_added') + ": " + date
    redirect_to :action => 'day_setup'
  end


  def day_destroy

    day = Day.find_by_id(params[:id])
    unless day
      flash[:notice]=_('Day_was_not_found')
      redirect_to :action => :list and return false
    end
    flash[:status] = _('Day_deleted') + ": " + day.date.to_s
    day.destroy
    redirect_to :action => 'day_setup'
  end


  def day_edit
    @page_title = _('Day_edit')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Day_setup"

    @day = Day.find_by_id(params[:id])
    unless @day
      flash[:notice]=_('Day_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def day_update
    day = Day.find_by_id(params[:id])
    unless day
      flash[:notice]=_('Day_was_not_found')
      redirect_to :action => :list and return false
    end

    date = params[:date][:year] + "-" + good_date(params[:date][:month]) + "-" + good_date(params[:date][:day])

    if Day.find(:first, :conditions => ["date = ? and id != ?", date, day.id])
      flash[:notice] = _('Duplicate_date')
      redirect_to :action => 'day_setup' and return false
    end

    day.date = date
    day.daytype = params[:daytype]
    day.description = params[:description]
    day.save

    flash[:status] = _('Day_updated') + ": " + date
    redirect_to :action => 'day_setup'

  end


  #======== Make user tariff out of provider tariff ==========
  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff
    @page_title = _('Make_user_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    check_user_for_tariff(@ptariff.id)
  end

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_wholesale
    @page_title = _('Make_user_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    check_user_for_tariff(@ptariff.id)
  end

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_status
    @page_title = _('Make_user_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    a=check_user_for_tariff(@ptariff.id)
    return false if !a

    @add_amount = 0
    @add_percent = 0
    @add_confee_percent = 0
    @add_confee_amount = 0
    if (params[:add_amount].to_s.length + params[:add_percent].to_s.length + params[:add_confee_amount].to_s.length + params[:add_confee_percent].to_s.length) == 0
      flash[:notice] = _('Please_enter_amount_or_percent')
      redirect_to :action => 'make_user_tariff', :id => @ptariff.id and return false
    end

    @add_amount = params[:add_amount] if params[:add_amount].length > 0
    @add_percent = params[:add_percent] if params[:add_percent].length > 0
    @add_confee_amount = params[:add_confee_amount] if params[:add_confee_amount].length > 0
    @add_confee_percent = params[:add_confee_percent] if params[:add_confee_percent].length > 0
    if @ptariff.make_retail_tariff(@add_amount, @add_percent, @add_confee_amount, @add_confee_percent, get_user_id())
      flash[:status] = _('Tariff_created')
    else
      flash[:notice] = _('Tariff_not_created')
    end

  end

  #
  # Makes new tariff and adds fixed percentage and/or amount to prices
  # Most of the work is done inside model.

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_status_wholesale
    @page_title = _('Make_wholesale_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    a=check_user_for_tariff(@ptariff)
    return false if !a
    if (params[:add_amount].to_s.length + params[:add_percent].to_s.length + params[:add_confee_amount].to_s.length + params[:add_confee_percent].to_s.length) == 0
      flash[:notice] = _('Please_enter_amount_or_percent')
      redirect_to :action => 'make_user_tariff_wholesale', :id => @ptariff.id and return false
    end
    @add_amount = params[:add_amount].to_d
    @add_percent = params[:add_percent].to_d
    @add_confee_amount = params[:add_confee_amount].to_d
    @add_confee_percent = params[:add_confee_percent].to_d
    if session[:usertype] == "admin"
      @t_type = params[:t_type] if params[:t_type].to_s.length > 0
    end
    if session[:usertype] == "reseller"
      @t_type ="user_wholesale"
    end

    unless @t_type
      flash[:notice] = _("Please_set_tariff_type")
      redirect_to :action => 'make_user_tariff_wholesale', :id => @ptariff.id and return false
    end

    if @ptariff.make_wholesale_tariff(@add_amount, @add_percent, @add_confee_amount, @add_confee_percent, @t_type)
      flash[:status] = _('Tariff_created')
    else
      flash[:notice] = _('Such_Tariff_Already_Exists')
      redirect_to :action => 'make_user_tariff_wholesale', :id => @ptariff.id and return false
    end
  end

  def change_tariff_for_users
    @page_title = _('Change_tariff_for_users')
    @page_icon = "application_add.png"
    user_id = get_user_id()
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs= Tariff.find(:all, :conditions => "owner_id = #{user_id} #{cond}")

  end


  def update_tariff_for_users
    if params[:tariff_from] and params[:tariff_to]
      @tarif_from = Tariff.find_by_id(params[:tariff_from])
      unless @tarif_from
        flash[:notice]=_('Tariff_was_not_found')
        redirect_to :action => :list and return false
      end
      @tarif_to = Tariff.find_by_id(params[:tariff_to])
      unless @tarif_to
        flash[:notice]=_('Tariff_was_not_found')
        redirect_to :action => :list and return false
      end
      for user in @tarif_from.users
        user.tariff_id = @tarif_to.id
        user.save
      end
      flash[:status] = _('Updated_tariff_for_users')
    else
      flash[:notice] = _('Tariff_not_found')
    end
    redirect_to :action => 'list'
  end


  #----------------- PDF/CSV export

  ###### Generate PDF ########
=begin rdoc
 Needs to be split and part of it moved to PDF model.
 #TODO split and move.
=end
  # before_filter : tariff(find_tariff_whith_currency)
  def generate_provider_rates_pdf
    a = check_user_for_tariff(@tariff)
    return false if !a

    rates = Rate.includes({:destination => :direction}).where(['rates.tariff_id = ?', @tariff.id]).order('directions.name, destinations.subcode ASC').all
    options = {
        :name => @tariff.name,
        :pdf_name => _('Rates'),
        :currency => session[:show_currency],
        :hide_tariff => params[:hide_tariff].to_i == 1
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(pdf, rates, @tariff, options)

    file = pdf.render
    filename = "Rates-#{session[:show_currency]}.pdf"
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_providers_rates_csv
    a = check_user_for_tariff(@tariff)
    return false if !a

    filename = "Rates-#{session[:show_currency]}.csv"
    file = @tariff.generate_providers_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_csv
    filename = "Rates-#{(session[:show_currency]).to_s}.csv"
    file = @tariff.generate_providers_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_pdf
    rates = Rate.includes({:destination => :direction}).where(['rates.tariff_id = ?', @tariff.id]).order('directions.name ASC').all
    options = {
        :name => @tariff.name,
        :pdf_name => _('Rates'),
        :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(pdf, rates, @tariff, options)
    file = pdf.render
    filename = "Rates-#{(session[:show_currency]).to_s}.pdf"
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_pdf

    rates = Rate.joins('LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)').where(['rates.tariff_id = ?', @tariff.id]).order('destinationgroups.name, destinationgroups.desttype ASC').all
    options = {
        :name => @tariff.name,
        :pdf_name => _('Users_rates'),
        :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_user_rates_pdf(pdf, rates, @tariff, options)
    file = pdf.render
    filename = "Rates-#{session[:show_currency]}.pdf"
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_csv
    filename = "Rates-#{session[:show_currency]}.csv"
    file = @tariff.generate_user_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

=begin
 Duplicated in Rate model for portability.
=end


  def get_personal_rate_details(tariff, dg, exrate)
    rate = dg.rate(tariff.id)

    @arates = []
    @arates = Aratedetail.find(:all, :conditions => "rate_id = #{rate.id} AND artype = 'minute'", :order => "price DESC") if rate

    #check for custom rates
    @crates = []
    crate = Customrate.find(:first, :conditions => "user_id = '#{session[:user_id]}' AND destinationgroup_id = '#{dg.id}'")
    if crate && crate[0]
      @crates = Acustratedetail.find(:all, :condition => "customrate_id = '#{crate[0].id}'", :order => "price DESC")
      @arates = @crates if @crates[0]
    end
    if @arates[0]
      @arate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [@arates[0].price.to_d]}) if @arates[0]
    end
  end

  # before_filter : user; tariff
  def generate_personal_rates_pdf
    dgroups = Destinationgroup.find(:all, :order => "name ASC, desttype ASC")
    tax = session[:tax]
    options = {
        :name => @tariff.name,
        :pdf_name => _('Personal_rates'),
        :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_personal_rates(pdf, dgroups, @tariff, tax, @user, options)

    filename = "Rates-Personal-#{@user.username}-#{session[:show_currency]}.pdf"
    file = pdf.render
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : user; tariff
  def generate_personal_rates_csv
    dgroups = Destinationgroup.find(:all, :order => "name ASC, desttype ASC")
    tax = session[:tax]

    sep = Confline.get_value("CSV_Separator").to_s
    dec = Confline.get_value("CSV_Decimal").to_s

    #csv_string = "Name,Type,Rate,Rate_with_VAT(#{vat}%)\n"
    csv_string = _("Name")+sep+_("Type")+sep+_("Rate")+sep+_("Rate_with_VAT")+"\n"

    exrate = Currency.count_exchange_rate(@tariff.currency, session[:show_currency])

    for dg in dgroups
      get_personal_rate_details(@tariff, dg, exrate)

      if @arates.size > 0
        csv_string += "#{dg.name.to_s.gsub(sep, " ")}#{sep}#{dg.desttype}#{sep}"
        csv_string += @arate_cur ? "#{nice_number(@arate_cur).to_s.gsub(".", dec)}#{sep}#{nice_number(tax.count_tax_amount(@arate_cur) + @arate_cur).to_s.gsub(".", dec)}\n" : "0#{sep}0\n"
      end
    end

    filename = "Rates-Personal-#{@user.username}-#{session[:show_currency]}.csv"
    testable_file_send(csv_string, filename, 'text/csv; charset=utf-8; header=present')
  end

  def analysis
    @page_title = _('Tariff_analysis')
    @page_icon = "table_gear.png"

    @prov_tariffs = Tariff.find(:all, :conditions => "purpose = 'provider'", :order => "name ASC")
    @user_wholesale_tariffs = Tariff.find(:all, :conditions => "purpose = 'user_wholesale'", :order => "name ASC")
    @currs = Currency.get_active
  end


  def analysis2
    @page_title = _('Tariff_analysis')
    @page_icon = "table_gear.png"

    @prov_tariffs_temp = Tariff.find(:all, :conditions => "purpose = 'provider'", :order => "name ASC")
    #@user_tariffs_temp = Tariff.find(:all, :conditions => "purpose = 'user'", :order => "name ASC")
    @user_wholesale_tariffs_temp = Tariff.find(:all, :conditions => "purpose = 'user_wholesale'", :order => "name ASC")

    @prov_tariffs = []
    #@user_tariffs = []
    @user_wholesale_tariffs = []
    @all_tariffs = []

    for t in @prov_tariffs_temp
      @prov_tariffs << t if params[("t" + t.id.to_s).intern] == "1"
      @all_tariffs << t.id if params[("t" + t.id.to_s).intern] == "1"
    end

    #for t in @user_tariffs_temp
    #  @user_tariffs << t if params[("t" + t.id.to_s).intern] == "1"
    #  @all_tariffs << t.id if params[("t" + t.id.to_s).intern] == "1"
    #end

    for t in @user_wholesale_tariffs_temp
      @user_wholesale_tariffs << t if params[("t" + t.id.to_s).intern] == "1"
      @all_tariffs << t.id if params[("t" + t.id.to_s).intern] == "1"
    end

    @curr = params[:currency]

    @tariff_line = ""
    for t in @all_tariffs
      @tariff_line += t.to_s
      @tariff_line += "|"
    end
  end


  def generate_analysis_csv

    cs = confline("CSV_Separator")
    dec = confline("CSV_Decimal")

    curr = params[:curr]
    all_tariffs = params[:tariffs].split('|')

    #my_debug "t----"
    #my_debug params[:tariffs]

    exch_rates = []
    tariff_names = []
    tariff_rates = []

    #header

    csv_string = _("Currency")+": #{curr}#{cs}#{cs}#{cs}#{cs}".gsub(cs, " ")

    for t in all_tariffs
      tariff = Tariff.find(t)
      tariff_names << tariff.name
      er = count_exchange_rate(curr, tariff.currency)
      exch_rates << er.to_d
      if tariff.rates
        tariff_rates << tariff.rates.size
      else
        tariff_rates << 0
      end
      csv_string += "(#{curr}/#{tariff.currency}): ".gsub(cs, " ")
      csv_string += er.to_s.gsub(".", dec) if er
      csv_string += cs
    end
    csv_string += "\n"

    #my_debug tariff_names

    #csv_string += "direction#{cs}destinations#{cs}subcode#{cs}prefix#{cs}"
    csv_string += _("Direction")+cs+_("Destinations")+cs+_("Subcode")+cs+_("Prefix")

    for t in all_tariffs
      csv_string += Tariff.find(t).name.gsub(cs, " ")
      csv_string += (" (" + t.to_s.gsub(".", dec) + ")#{cs}")
    end

    csv_string += cs
    #csv_string += "Min#{cs}Min Provider#{cs}Max#{cs}Max Provider"
    csv_string += _("Min")+cs+_("Min_provider")+cs+_("Max")+cs+_("Max_provider")
    csv_string += "\n"


    # data

    res = []
    prefixes = []
    directions = []
    subcodes = []
    destinations = []

    min_rates = []
    max_rates = []

    i = 0
    for t in all_tariffs

      min_rates[i] = 0
      max_rates[i] = 0

      res[i] = []
      tariff = Tariff.find(t)

      sql = "SELECT directions.name, destinations.name as 'dname', destinations.subcode, destinations.prefix, ratedetails.rate FROM destinations JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN  rates ON (destinations.id = rates.destination_id AND rates.tariff_id = '#{tariff.id}')  	LEFT JOIN ratedetails ON (ratedetails.rate_id = rates.id) ORDER BY directions.name ASC, destinations.subcode ASC, destinations.prefix ASC;"
      sqlres = ActiveRecord::Base.connection.select_all(sql)

      j = 0
      for sr in sqlres
        res[i][j] = sr["rate"]
        prefixes[j] = sr["prefix"]
        directions[j] = sr["name"]
        subcodes[j] = sr["subcode"]
        destinations[j] = sr["dname"]

        j += 1
      end

      i += 1
    end


    i = 0
    for rr in 0..res[0].size - 1

      min = nil
      minp = nil
      max = nil
      maxp = nil

      csv_string += directions[i].to_s.gsub(cs, " ") if directions[i]
      csv_string += cs

      csv_string += destinations[i].to_s.gsub(cs, " ") if destinations[i]
      csv_string += cs

      csv_string += subcodes[i] if subcodes[i]
      csv_string += cs

      csv_string += prefixes[i] if prefixes[i]
      csv_string += cs

      j = 0
      for r in res

        rate = nil
        rate = r[i].to_d / exch_rates[j] if r[i] and exch_rates[j]


        if rate and ((min == nil) or (min.to_d > rate.to_d))
          min = rate
          minp = j
        end

        if rate and ((max == nil) or (max.to_d < rate.to_d))
          max = rate
          maxp = j
        end

        #          my_debug "j: #{j}, maxp: #{maxp}"

        csv_string += nice_number(rate).to_s.gsub(".", dec)
        csv_string += cs
        j += 1
      end


      csv_string += cs
      if not min
        min = ""
        minpt = ""
      else
        if minp
          minpt = tariff_names[minp]
          min_rates[minp] += 1
        end
      end

      if not max
        max = ""
        maxpt = ""
      else
        if maxp
          maxpt = tariff_names[maxp]
          max_rates[maxp] += 1
        end
      end

      csv_string += "#{cs}#{min.to_s.gsub(".", dec)}#{cs}#{minpt.to_s.gsub(cs, " ")}#{cs}#{max.to_s.gsub(".", dec)}#{cs}#{maxpt.to_s.gsub(cs, " ")}"

      csv_string += "\n"
      i += 1
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}#{cs}"

    for t in all_tariffs
      csv_string += Tariff.find(t).name
      csv_string += (" (" + t.to_s + ")#{cs}")
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Total rates: #{cs}"

    i = 0
    for t in all_tariffs
      csv_string += ("#{tariff_rates[i]}#{cs}")
      i += 1
    end


    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Min rates: #{cs}"

    i = 0
    for t in all_tariffs
      csv_string += ("#{min_rates[i]}#{cs}")
      i += 1
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Max rates: #{cs}"

    i = 0
    for t in all_tariffs
      csv_string += ("#{max_rates[i]}#{cs}")
      i += 1
    end

    filename = "Tariff_analysis.csv"
    testable_file_send(csv_string, filename, 'text/csv; charset=utf-8; header=present')
  end

  def destinations_csv
    sql = "SELECT prefix, directions.name AS 'dir_name', subcode, destinations.name AS 'dest_name'  FROM destinations JOIN directions ON (destinations.direction_code = directions.code) ORDER BY directions.name, prefix ASC;"
    res = ActiveRecord::Base.connection.select_all(sql)
    cs = confline("CSV_Separator", correct_owner_id)
    cs = "," if cs.blank?
    csv_line = res.map { |r| "#{r["prefix"]}#{cs}#{r["dir_name"].to_s.gsub(cs, " ")}#{cs}#{r["subcode"].to_s.gsub(cs, " ")}#{cs}#{r["dest_name"].to_s.gsub(cs, " ")}" }.join("\n")
    if params[:test].to_i == 1
      render :text => csv_line
    else
      send_data(csv_line, :type => 'text/csv; charset=utf-8; header=present', :filename => "Destinations.csv")
    end
  end

  def check_tariff_time
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    session[:imp_date_day_type] = params[:rate_day_type].to_s

    @f_h, @f_m, @f_s, @t_h, @t_m, @t_s = params[:time_from_hour].to_s, params[:time_from_minute].to_s, params[:time_from_second].to_s, params[:time_till_hour].to_s, params[:time_till_minute].to_s, params[:time_till_second].to_s
    @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)

    #logger.info @f_h

    render(:layout => false)
  end

  private

  def check_user_for_tariff(tariff)
    logger.fatal "aaa1"

    if tariff.class.to_s !="Tariff"
      tariff = Tariff.find(:first, :conditions => ["id = ? ", tariff])
    end

    if session[:usertype].to_s == "accountant"
      if tariff.owner_id != 0 or session[:acc_tariff_manage].to_i == 0
        dont_be_so_smart
        redirect_to :controller => "tariffs", :action => "list" and return false
      end
    elsif session[:usertype].to_s == "reseller" and tariff.owner_id != session[:user_id] and (params[:action] == 'rate_details' or params[:action] == 'rates_list'or params[:action] == 'user_rates_list'or params[:action] == 'user_arates_full')
      if !CommonUseProvider.find(:first, :conditions => ["reseller_id = ? AND tariff_id = ?", current_user.id, tariff.id])
        dont_be_so_smart
        redirect_to :controller => "tariffs", :action => "list" and return false
      end
    else
      if tariff.owner_id != session[:user_id]
        dont_be_so_smart
        redirect_to :controller => "tariffs", :action => "list" and return false
      end
    end
    return true
  end

  def find_tariff_whith_currency
    logger.fatal "aaa2"
    @tariff = Tariff.find(:first, :conditions => ['id=?', params[:id]])
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_tariff_from_id
    logger.fatal "aaa3"
    @tariff = Tariff.find(:first, :conditions => ['id=?', params[:id]])
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_user_from_session
    logger.fatal "aaa4"
    @user = User.find(:first, :include => [:tariff], :conditions => ["users.id = ?", session[:user_id]])
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_user_tariff
    logger.fatal "aaa5"
    @tariff = @user.tariff
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to :action => :list and return false
    end
  end

  def get_user_id()
    logger.fatal "aaa6"
    if session[:usertype].to_s == "accountant"
      user_id = 0
    else
      user_id = session[:user_id].to_i
    end
    return user_id
  end

  def get_provider_rate_details(rate, exrate)
    logger.fatal "aaa7"
    @rate_details = Ratedetail.find(:all, :conditions => ["rate_id = ?", rate.id], :order => "rate DESC")
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({:exrate => exrate, :prices => [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]})
    end
    @rate_details
  end

=begin rdoc

=end

  def accountant_permissions
    logger.fatal "aaa8"
    allow_manage = !(session[:usertype] == "accountant" and (session[:acc_tariff_manage].to_i == 0 or session[:acc_tariff_manage].to_i == 1))
    allow_read = !(session[:usertype] == "accountant" and (session[:acc_tariff_manage].to_i == 0))
    return allow_manage, allow_read
  end
end
