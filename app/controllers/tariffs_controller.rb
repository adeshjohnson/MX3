class TariffsController < ApplicationController
  include PdfGen
  include UniversalHelpers
  require 'rubygems'
  layout "callc"

  before_filter :check_localization
  before_filter :authorize,  :except => [:destinations_csv]
  before_filter :check_if_can_see_finances, :only =>[:new, :create, :index, :list, :edit, :update, :destroy, :rates_list, :import_csv, :delete_all_rates, :make_user_tariff, :make_user_tariff_wholesale]
  before_filter :find_user_from_session, :only=>[:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed]
  before_filter :find_user_tariff, :only=>[:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed]
  before_filter :find_tariff_whith_currency, :only => [:find_tariff_whith_currency, :generate_providers_rates_csv, :generate_provider_rates_pdf, :generate_user_rates_pdf, :generate_user_rates_csv]
  before_filter :find_tariff_from_id, :only=>[:check_tariff_time, :rate_new_by_direction, :edit, :update, :destroy, :tariffs_list, :rates_list, :rate_new_quick, :rate_try_to_add, :rate_new, :rate_new_by_direction_add, :delete_all_rates, :user_rates_list, :user_arates_full, :user_rates_update, :make_user_tariff, :make_user_tariff_wholesale, :make_user_tariff_status, :make_user_tariff_status_wholesale ]

  before_filter { |c|
    view = [:list, :rates_list, :user_rates_list, :user_arates_full, :user_arates, :day_setup]
    edit = [:new, :create,:edit, :update, :destroy, :user_rate_update, :user_rates_update, :user_ard_time_edit, :ard_manage, :day_add, :day_edit, :day_update]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_tariff_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update, :rate_destroy, :ratedetail_update, :ratedetail_destroy, :ratedetail_create, :artg_destroy, :user_rate_update, :user_rate_delete, :user_rates_update, :user_rate_destroy, :day_destroy, :day_update, :update_tariff_for_users ],
    :redirect_to => { :action => :list },
    :add_flash => { :notice => _('Dont_be_so_smart'),
    :params => {:dont_be_so_smart => true}}

  def list
    user = User.find_by_id(correct_owner_id)
    unless user
      flash[:notice]=_('User_was_not_found')
      redirect_to :controller=>:callc, :action=>:main and return false
    end

    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Tariffs')
    @page_icon = "view.png"
    #@tariff_pages, @tariffs = paginate :tariffs, :per_page => 10
    if params[:s_prefix]
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/,'')
      dest = Destination.find(:all, :conditions=>["prefix LIKE ?", @s_prefix.to_s])
    end
    @des_id = []
    @des_id_d = []
    if dest and dest.size.to_i > 0
      dest.each{|d| @des_id << d.id}
      dest.each{|d| @des_id_d << d.destinationgroup_id}
      cond = " AND rates.destination_id IN (#{@des_id.join(',')})"
      con = " AND rates.destinationgroup_id IN (#{@des_id_d.join(',')}) "
      @search = 1
    else
      con = ''
      cond = ''
    end
    @prov_tariffs = Tariff.find(:all, :conditions => "purpose = 'provider' AND owner_id = '#{user.id}' #{cond}", :include=>[:rates], :order => "name ASC", :group=>'tariffs.id')
    @user_tariffs = Tariff.find(:all, :conditions => "purpose = 'user' AND owner_id = '#{user.id}' #{con}", :include=>[:rates], :order => "name ASC", :group=>'tariffs.id')
    @user_wholesale_tariffs = Tariff.find(:all, :conditions => "purpose = 'user_wholesale' AND owner_id = '#{user.id}' #{cond}", :include=>[:rates], :order => "name ASC", :group=>'tariffs.id')
    @user_wholesale_enabled = (Confline.get_value("User_Wholesale_Enabled") == "1")

    @Show_Currency_Selector =1
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
    @page_title = _('Tariff_edit')#+": "+ @tariff.name
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
    lrules= Locationrule.find(:all, :conditions=>"tariff_id='#{@tariff.id}'")
    if lrules.size.to_i > 0
      flash[:notice] = lrules.size.to_s + " " + _('locationrules_are_using_this_tariff_cant_delete')
      redirect_to :action => 'list' and return false
    end

    comm_use_prov_table = @tariff.common_use_providers.count
    if comm_use_prov_table > 0
      flash[:notice] =  _('common_use_providers_are_using_this_tariff_cant_delete')
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
    @user = User.find(:all, :conditions => ["tariff_id = ?", @tariff.id] )
    @cardgroup = Cardgroup.find(:all, :conditions => ["tariff_id = ?", @tariff.id] )
  end


  # =============== RATES FOR PROVIDER ==================

  # before_filter : tariff(find_taririff_from_id)
  def rates_list
    return false unless check_user_for_tariff(@tariff.id)

    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Rates_for_tariff') #+": " + @tariff.name
    @can_edit = true

    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first,:conditions =>["reseller_id = ? AND tariff_id = ?",current_user.id, @tariff.id])
      @can_edit = false
    end

    @st = "A"
    @st = params[:st].upcase  if params[:st]

    @directions = Direction.find(
      :all,
      :select => "directions.*, COUNT(destinations.id) AS 'dest_count', COUNT(rates.id) AS 'rate_count'",
      :conditions => ["directions.name LIKE ?", @st+"%"],
      :joins => "LEFT JOIN destinations ON (destinations.direction_code = directions.code) LEFT JOIN rates ON (rates.destination_id = destinations.id AND tariff_id = #{@tariff.id.to_i})",
      :order => "name ASC",
      :group => "directions.id")

    @page = 1
    @page = params[:page].to_i if params[:page]

    if params[:s_prefix]
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/,'')
      dest = Destination.find(:all, :conditions=>["prefix LIKE ?", @s_prefix.to_s])
    end
    @des_id = []
    if @s_prefix
      if dest and dest.size.to_i > 0
        dest.each{|d| @des_id << d.id}
        @search = 1
        @rates = Rate.find(:all, :conditions=>["rates.tariff_id=? AND rates.destination_id IN (#{@des_id.join(',')})", @tariff.id], :include=>[:ratedetails])
      else
        @rates = []
      end
    else
      @rates = Rate.find(:all, :conditions=>["rates.tariff_id=? AND directions.name like ?", @tariff.id, @st+"%"], :include=>[:ratedetails, :destination, :tariff], :joins=>"LEFT JOIN directions ON (directions.code = destinations.direction_code)", :order=>"directions.name ASC, destinations.prefix ASC", :limit=>"0,1000000")
    end

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
    @prefix = request.raw_post || request.query_string
    @prefix = @prefix.gsub(/=/, "")
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
        :conditions => ["rates.tariff_id =? AND destinations.prefix = ?" ,  @tariff.id, @prefix])
      flash[:notice] = _("Rate_already_set")
      redirect_to(:action => :rates_list, :id => @tariff.id, :st => params[:st], :page => @page) and return false
    end
    @destination = Destination.find(:first, :conditions => ["prefix = ?", @prefix])
    if @destination
      if @tariff.add_new_rate( @destination.id , @price, 1, 0)
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
      redirect_to :action=>:index and return false
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    #    MorLog.my_debug(@destinations)
    @total_items = @destinations.size
    @total_pages = (@total_items.to_f / session[:items_per_page].to_f).ceil
    istart = (@page-1)*session[:items_per_page]
    iend = (@page)*session[:items_per_page]-1
    #    MorLog.my_debug(istart)
    #    MorLog.my_debug(iend)
    @destinations = @destinations[istart..iend]
    @page_select_options = {
      :id =>@tariff.id,
      :dir_id=>@direction.id,
      :st=> @st
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
      redirect_to :action=>:index and return false
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    @destinations.each { |dest|
      if params["dest_#{dest.id}"] and params["dest_#{dest.id}"].to_s.length > 0
        @tariff.add_new_rate( dest.id , params["dest_#{dest.id}"], 1, 0)
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
      redirect_to :controller=>:tariffs, :actions=>:list and return false
    end
    
    @page_title = _('Add_new_rate_to_tariff')# +": " + @tariff.name
    @page_icon = "add.png"

    # st - from which letter starts rate's direction (usualy country)
    @st = "A"
    @st = params[:st].upcase  if params[:st]

    @dests = @tariff.free_destinations_by_st(@st)

    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id
  end

  # before_filter : tariff(find_taririff_from_id)
  def rate_try_to_add
    a=check_user_for_tariff(@tariff.id)
    return false if !a

    if @tariff.purpose == 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller=>:tariffs, :actions=>:list and return false
    end

    # st - from which letter starts rate's direction (usualy country)
    params[:st] ? st = params[:st].upcase : st = "A"

    for dest in @tariff.free_destinations_by_st(st)
      #add only rates which are entered
      if params[(dest.id.to_s).intern].to_s.length > 0
        @tariff.add_new_rate( dest.id.to_s , params[(dest.id.to_s).intern], 1, 0)
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
      redirect_to :action=>:index and return false
    end
    if rate
      a=check_user_for_tariff(rate.tariff_id)
      return false if !a

      st = rate.destination.direction.name[0,1]
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
      redirect_to :action=>:index and return false
    end

    rated = Ratedetail.find(:first, :conditions =>["rate_id = ?", params[:id]])

    if !rated
      rd = Ratedetail.new
      rd.start_time = "00:00:00"
      rd.end_time = "23:59:59"
      rd.rate = 0.to_f
      rd.connection_fee = 0.to_f
      rd.rate_id = params[:id].to_i
      rd.increment_s = 0.to_f
      rd.min_time = 0.to_f
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
    @can_edit = true

    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first,:conditions =>["reseller_id = ? AND tariff_id = ?",current_user.id, @tariff.id])
      @can_edit = false
    end
  end

  def ratedetails_manage
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action=>:index and return false
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
      redirect_to :action=>:index and return false
    end
    @page_title = _('Rate_details_edit')
    @page_icon = "edit.png"

    rate = Rate.find_by_id(@ratedetail.rate_id)
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action=>:index and return false
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
      redirect_to :action=>:index and return false
    end
    rd = @ratedetail

    rate = Rate.find_by_id(@ratedetail.rate_id)
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action=>:index and return false
    end

    a=check_user_for_tariff(rate.tariff_id)
    return false if !a

    rdetails = rate.ratedetails_by_daytype(@ratedetail.daytype)

    if (params[:ratedetail] and params[:ratedetail][:end_time]) and ((nice_time2(rd.start_time) > params[:ratedetail][:end_time]) or (params[:ratedetail][:end_time] > "23:59:59"))
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id     and return false
    end


    if @ratedetail.update_attributes(params[:ratedetail])

      # we need to create new rd to cover all day
      if (nice_time2(@ratedetail.end_time) != "23:59:59") and ((rdetails[(rdetails.size - 1)] == @ratedetail) )
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
      redirect_to :action=>:index and return false
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
      redirect_to :action=>:index and return false
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
      redirect_to :action=>:index and return false
    end
    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a

    rd = Ratedetail.find_by_id(params[:id])
    unless rd
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to :action=>:index and return false
    end
    rdetails = @rate.ratedetails_by_daytype(rd.daytype)


    if rdetails.size > 1

      #update previous rd
      et = nice_time2(rd.start_time - 1.second)
      daytype = rd.daytype
      prd = Ratedetail.find(:first, :conditions => ["rate_id = ? AND end_time = ? AND daytype = ?", @rate.id, et, daytype] )
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

    @page_title = _('Import_XLS') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
    @page_icon = 'excel.png';

    @tariff = Tariff.find_by_id(params[:id])
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action=>:index and return false
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

  def find_prefix_column(workbook ,sheet)
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

    @sep, @dec = nice_action_session_csv
    store_location

    params[:step] ? @step = params[:step].to_i : @step = 1
    @step = 1 unless (1..7).include?(@step.to_i)

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
    @page_title = _('Import_CSV') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
    @page_icon = 'excel.png';
    @help_link = "http://wiki.kolmisoft.com/index.php/Rate_import_from_CSV";

    @tariff = Tariff.find(:first, :conditions => ["id = ?", params[:id]])
    unless @tariff
      flash[:notice] = _("Tariff_Was_Not_Found")
      redirect_to :action => :list and return false
    end

    a=check_user_for_tariff(@tariff.id)
    return false if !a

    if @step == 1
      #      if params[:rc].to_i == 0
      #       ac = Action.add_action_hash(current_user, {:action=>'Tariff_step_1', :target_id=>@tariff.id, :target_type=>'Tariff'})
      #      session["step_csv_tariff_action_id_#{@tariff.id}".to_sym] = ac.id
      #       session[:file] = nil
      #      else
      #        session["step_csv_tariff_action_id_#{@tariff.id}".to_sym] = -1
      #     end
    end

    if @step == 2
      my_debug_time "step 2"
      if params[:file] or session[:file]
        if params[:file]
          #          cond = session["step_csv_tariff_action_id_#{@tariff.id}".to_sym].to_i == -1 ? ' AND id = 0 ' : " AND id != #{session["step_csv_tariff_action_id_#{@tariff.id}".to_sym]} "
          #          acc = Action.find(:first, :conditions=>["action = 'Tariff_step_1' #{cond} AND date > ?", (Time.now-1.hour).to_s(:db)])
          #          if acc
          #            flash[:notice] = _('Please_Upload_one_file_in_time')
          #            redirect_to :action => "import_csv", :id => @tariff.id, :step => "1", :rc => 1 and return false
          #          end
          @file = params[:file]
          if @file.size > 0
            if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
              # MorLog.my_debug(@file.class.to_s)
              flash[:notice] = _('Please_select_file')
              redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
            end

            if get_file_ext(@file.original_filename, "csv") == false
              # MorLog.my_debug(@file.original_filename.to_s)
              @file.original_filename
              flash[:notice] = _('Please_select_CSV_file')
              redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
            end

            # disabled because it does not allow to upload file with incorrect separators
=begin
            begin
              csv_file = FasterCSV.new(@file, { :col_sep => @sep, :headers => false, :return_headers => false })
              csv_file.each{}
            rescue
              flash[:notice] = csv_import_invalid_file_notice
              redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
            end
=end
            @file.rewind
            session[:file] = @file.read if @file.size > 0
          end
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
        end

        @file = session[:file]
        check_csv_file_seperators(@file, 2,2)
        arr = @file.split("\n")
        # my_debug("\"" +@sep+"\"")
        @fl = arr[0].to_s.split(@sep)
        flash[:status] = _('File_uploaded') if !flash[:notice]
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
      end
      @rate_type,flash[:notice_2] = @tariff.check_types_periods(params)
    end

    if @step == 3
      my_debug_time "step 3"
      if session[:file]
        if params[:prefix_id] and params[:rate_id] and params[:prefix_id].to_i >= 0 and params[:rate_id].to_i >= 0
          @file = session[:file]
          session[:imp_prefix] = params[:prefix_id].to_i
          session[:imp_rate] = params[:rate_id].to_i
          session[:imp_subcode] = params[:subcode].to_i
          session[:imp_inc] = params[:increment_id].to_i
          session[:imp_mint] = params[:min_time_id].to_i
          session[:imp_cc] = params[:country_code_id].to_i
          session[:imp_dst] = params[:destination_id].to_i
          session[:imp_city] = params[:city_id].to_i
          session[:imp_state] = params[:state_id].to_i
          session[:imp_lata] = params[:lata_id].to_i
          session[:imp_tier] = params[:tier_id].to_i
          session[:imp_ocn] = params[:ocn_id].to_i

          session[:imp_country] = params[:country_id].to_i
          session[:imp_connection_fee] = params[:connection_fee_id].to_i
          session[:imp_date_day_type] = params[:rate_day_type].to_s

          #@f_h, @f_m, @f_s, @t_h, @t_m, @t_s = params[:time_from_hour].to_s,params[:time_from_minute].to_s,params[:time_from_second].to_s,params[:time_till_hour].to_s,params[:time_till_minute].to_s,params[:time_till_second].to_s
          @rate_type,flash[:notice_2] = @tariff.check_types_periods(params)
          unless flash[:notice_2].blank?
            flash[:notice] = _('Tarrif_import_incorect_time')
            flash[:notice] += '<br /> * ' + _('Please_select_period_without_collisions')
            redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
          end

          session[:imp_time_from_type] = params[:time_from][:hour].to_s + ":" + params[:time_from][:minute].to_s + ":" + params[:time_from][:second].to_s
          session[:imp_time_till_type] = params[:time_till][:hour].to_s + ":" + params[:time_till][:minute].to_s + ":" + params[:time_till][:second].to_s
          session[:imp_update_dest_names] = params[:update_dest_names].to_i if admin?

          #priority over csv

          session[:manual_connection_fee] = ""
          session[:manual_increment] = ""
          session[:manual_min_time] = ""

          session[:manual_connection_fee] = params[:manual_connection_fee] if params[:manual_connection_fee]
          session[:manual_increment] = params[:manual_increment] if params[:manual_increment]
          session[:manual_min_time] = params[:manual_min_time] if params[:manual_min_time]

          flash[:status] = _('Columns_assigned')
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
        end
      else
        flash[:notice] = _('Zero_file')
        redirect_to :controller=>"tariffs", :action=>"list" and return false
      end
    end

    #check how many destinations and should we create new ones?
    if @step == 4
      my_debug_time "step 4"
      if session[:file]
        if session[:imp_prefix] and session[:imp_rate]
          @file = session[:file]
          #counting destinations allready in MOR
          destination_data = ActiveRecord::Base.connection.select_all("SELECT prefix, name FROM destinations")
          prefixes  = destination_data.map{|pr| pr["prefix"].to_s.gsub(/\s/, '')}


          session[:destinations_in_db] = prefixes.size
          my_debug_time session[:destinations_in_db].to_s + " destinations in db"

          # counting directions
          country_codes = Direction.find(:all).map{|dc| dc.code}
          session[:directions_in_db] = country_codes.size
          my_debug_time session[:directions_in_db].to_s + " directions in db"

          #csv_prefixes
          csv_prefixes = []
          csv_destinations = {}
          begin
            csv_file = FasterCSV.new(@file, { :col_sep => @sep, :headers => false, :return_headers => false })
            for row in csv_file
              prefix = ""
              prefix = row[session[:imp_prefix].to_i].to_s.gsub(/\s/, '') if row[session[:imp_prefix].to_i].to_i > 0 and row[session[:imp_rate].to_i]
              raise "bad_prefix" if !prefix.blank? and !prefix.to_s.match(/^[0-9]*$/)
              csv_prefixes << prefix
              if session[:imp_update_dest_names].to_i == 1 and session[:imp_dst].to_i > 0
                csv_destinations[prefix] = row[session[:imp_dst].to_i]
              end
            end
          rescue Exception => e
            if e.message == "bad_prefix"
              flash[:notice] = csv_import_invalid_prefix_notice
            else
              MorLog.log_exception(e, "", "", "")
              flash[:notice] = csv_import_invalid_file_notice
            end
            redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
          end
          session[:destinations_in_csv_file] = csv_prefixes.size
          my_debug_time session[:destinations_in_csv_file].to_s + " destinations in csv file"

          existing_prefixes = csv_prefixes & prefixes
          session[:existing_destinations_in_csv_file] = existing_prefixes.size
          my_debug_time session[:existing_destinations_in_csv_file].to_s + " existing_destinations_in_csv_file"

          #tariff prefixes
          sql = "SELECT prefix FROM destinations, rates WHERE rates.tariff_id = #{@tariff.id} AND rates.destination_id = destinations.id"
          tariff_prefixes = ActiveRecord::Base.connection.select_all(sql).map{|pr| pr["prefix"]}
          session[:tariff_rates] = tariff_prefixes.size
          my_debug_time session[:tariff_rates].to_s + " tariff_rates"

          dst_rates_to_update = csv_prefixes & tariff_prefixes
          session[:rates_to_update] = dst_rates_to_update.size
          my_debug_time session[:rates_to_update].to_s + " rates_to_update"

          #duplicate rows in csv file
          dup_prefixes_in_csv = csv_prefixes.dups

          my_debug_time "dup_prefixes_in_csv: #{ dup_prefixes_in_csv}"

          # retrieve direction_codes to hash
          direction_codes = {}
          res = ActiveRecord::Base.connection.select_all("SELECT direction_code, prefix FROM destinations;")
          res.each{|r| direction_codes[r["prefix"]] = r["direction_code"]}

          #counting new destinations in CSV file and checking if we can create new ones if necessary

          #check prefix
          status = []
          # 0 - empty line - skip
          # 1 - everything ok
          # 2 - cc(country_code) = usa
          # 3 - cc from csv
          # 4 - prefix from shorter prefix
          # ERRORS
          # 10 - no cc from csv - can't create destination
          # 11 - bad cc from csv - can't create destination
          # 12 - duplicate

          update_rate = []
          short_prefix = []
          bad_lines = []
          bad_lines_status = []

          @csv_file = FasterCSV.new(@file, { :col_sep => @sep, :headers => false, :return_headers => false })
          my_debug_time "FasterCSV.new"
          ndicf = 0   #new dst in csv file
          bad_dst = 0 #how many dst impossible to create
          destinations_to_create = 0     #destinations to create
          new_rates_to_create = 0    #new rates to create

          ri = 0
          ei = 0

          # Convert Arrays into Hashes to ease the search.
          prefixes = Hash[*prefixes.collect{ |v| [v.to_s, 1] }.flatten]
          dup_prefixes_in_csv = Hash[*dup_prefixes_in_csv.collect{ |v| [v.to_s, 1] }.flatten]
          dst_to_update_hash = {}
          if session[:imp_update_dest_names].to_i == 1
            db_destinations = Hash[*destination_data.collect{ |v| [v["prefix"].to_s.gsub(/\s/, ''), v["name"].to_s] }.flatten]
            MorLog.my_debug(csv_destinations.to_yaml)
            MorLog.my_debug(db_destinations.to_yaml)

            csv_destinations.each{|prefix, name|
              if db_destinations[prefix] and db_destinations[prefix] != name
                dst_to_update_hash[prefix] = {:new_name => name, :old_name => db_destinations[prefix]}
              end
            }
            session
          end
          @csv_file.each_with_index{ |row, i|
            prefix = row[session[:imp_prefix]].to_s.gsub(/\s/, '')
            update_rate[i] = false
            if prefix.to_i > 0 and row[session[:imp_rate]]

              if prefix == existing_prefixes[ei]
                status[i] = 1     #everything is ok
                ei += 1
                if prefix == dst_rates_to_update[ri]
                  update_rate[i] = true
                  ri += 1
                end
              else

                #eliminate duplicates
                if dup_prefixes_in_csv[prefix].to_i == 1
                  status[i] = 12
                  bad_lines << row
                  bad_lines_status << 12
                  #my_debug "duplicate"
                else
                  #my_debug "not   duplicate"

                  #no such prefix in DB
                  #my_debug prefix + " - not found!!!"

                  ndicf += 1

                  lata = row[session[:imp_lata]].to_s

                  if lata.length > 0 and session[:imp_lata] >= 0
                    status[i] = 2     # country is USA
                    destinations_to_create += 1
                  else
                    country_code = row[session[:imp_cc]].to_s     #country_code

                    if country_code.length == 0 or session[:imp_cc] == -1
                      #searching prefix by shorter prefix
                      prefix = row[session[:imp_prefix]].to_s.gsub(/\s/, '')
                      pfound = 0
                      plength = prefix.length
                      j = 1
                      while j < plength and pfound == 0
                        tprefix = prefix[0,plength-j]
                        pfound = 1 if prefixes[tprefix].to_i == 1
                        j += 1
                      end

                      if pfound == 1
                        #my_debug row[session[:imp_prefix]] + " " + res
                        short_prefix[i] = direction_codes[tprefix.to_s]
                        status[i] = 4
                        destinations_to_create += 1
                      else
                        status[i] = 10   # can't create destination
                        bad_lines << row
                        bad_lines_status << 10
                      end
                    else
                      #check if we have such direction (by country_code)
                      if not country_codes.include?(country_code)
                        status[i] = 11  # bad country_code from csv
                        bad_lines << row
                        bad_lines_status << 11
                      else
                        status[i] = 3   # country_code is ok
                        destinations_to_create += 1
                      end
                    end
                  end
                end
              end
            else
              MorLog.my_debug("Empty line? (#{row.join(',')}) Prefix_col:#{session[:imp_prefix]} Rate_col:#{session[:imp_rate]}") if row
              status[i] = 0     #mark empty line
            end

            #my_debug status[i]

            bad_dst +=1 if status[i] > 9
            new_rates_to_create +=1 if status[i] > 0 and status[i] < 10 and not update_rate[i]

            my_debug_time i.to_s + " status/update_rate counted" if i % 1000 == 0
          }

          session[:status_array] = status
          session[:update_rate_array] = update_rate
          session[:short_prefix_array] = short_prefix
          session[:bad_lines_array] = bad_lines
          session[:bad_lines_status_array] = bad_lines_status
          session[:dst_to_update_hash] = dst_to_update_hash

          session[:new_destinations_in_csv_file] = ndicf
          session[:bad_destinations] = bad_dst
          session[:destinations_to_create] = destinations_to_create
          session[:destinations_to_update] = dst_to_update_hash.size
          session[:new_rates_to_create] = new_rates_to_create
          flash[:status] = _('Analysis_completed')
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
      end
    end
    # Create new destinations.
    if @step == 5
      my_debug_time "step 5"
      if session[:file]
        @file = session[:file]
        if session[:imp_prefix] and session[:imp_rate]
          #          acc = Action.find(:first, :conditions=>['action = "Tariff_step_1" AND id not ? AND date > ?', session["step_csv_tariff_action_id_#{@tariff.id}".to_sym], (Time.now-1.hour).to_s(:db)])
          #          if acc
          #            flash[:notice] = _('Please_Upload_one_file_in_time_recheck_data')
          #            redirect_to :action => "import_csv", :id => @tariff.id, :step => "1", :rc => 1 and return false
          #          end
          cd = 0  #created destinations
          if ["admin", "accountant"].include?(session[:usertype])
            begin
              #create destinations
              sql_header ="INSERT INTO destinations (prefix, direction_code, subcode, name, city, state, lata, tier, ocn) VALUES "
              sql_values = []
              sql_line = []
              status = session[:status_array]

              @csv_file = FasterCSV.new(@file, { :col_sep => @sep, :headers => false, :return_headers => false })

              limit = 1000 #how many dst create at once

              unless @csv_file
                flash[:notice] = _('No_Destinations_Were_Created')
                redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
              end

              @csv_file.each_with_index{ |row, i|
                sql_line = []
                sql = ""
                prefix = row[session[:imp_prefix]].to_s.gsub(/\s/, '')
                if status != nil and (status[i] == 2 or status[i] == 3 or status[i] == 4)
                  cd += 1
                  sql_line << "\"" + prefix + "\""
                  if status[i] == 2
                    cc = "USA"
                  else
                    if status[i] == 3
                      cc = row[session[:imp_cc]].to_s.upcase
                    else
                      cc = session[:short_prefix_array][i].to_s.upcase
                    end
                  end
                  sql_line << "\"#{cc}\""

                  if session[:imp_subcode] >= 0 and row[session[:imp_subcode]]
                    subcode = row[session[:imp_subcode]].gsub(/["]/, '\'')   #sanitize a little
                    sql_line << "\"#{subcode}\""
                  else
                    string = prefix.to_i.to_s[0..(prefix.to_i.to_s.length.to_i-2)]
                    dan = true
                    dest = nil
                    while (!dest and string.length.to_i > 1)
                      dest = Destination.find(:first, :conditions=> ["prefix like ?", string.to_s+'%'])
                      if dest
                        sql_line << "'#{dest.subcode.to_s}'"
                        dan = false
                      else
                        string = string.to_s[0..(string.length.to_i-2)].to_s
                      end
                    end
                    if string.length.to_i == 1 and dan == true
                      sql_line << "'NGN'"
                    end
                  end

                  [:imp_dst, :imp_city, :imp_state, :imp_lata, :imp_tier, :imp_ocn].each{|imp_type|
                    if session[imp_type] >= 0 and row[session[imp_type]]
                      sql_line << "\"#{row[session[imp_type]].gsub(/["]/, '\'')}\"" #sanitize a little
                    else
                      sql_line << "NULL"
                    end
                  }

                  sql_values << sql_line.join(",")
                  if sql_values.size > limit
                    res = ActiveRecord::Base.connection.insert(sql_header + "(" + sql_values.join("), (") +")")
                    sql_values = []
                    my_debug_time i.to_s + " dst created"
                  end
                end
              }

              #inserting remaining rows if csv has empty lines at the end
              if sql_values.size > 0
                sql = sql_header + "(" + sql_values.join("), (") +")"
                res = ActiveRecord::Base.connection.insert(sql)
              end

              flash[:status] = _('Created_destinations') + ": " + cd.to_s

              if session[:imp_update_dest_names].to_i == 1 and session[:dst_to_update_hash].size > 0
                updated_names = 0
                session[:dst_to_update_hash].each{|key, value|
                  sql ="UPDATE destinations SET name = '#{q(value[:new_name])}' WHERE prefix = '#{q(key)}' AND name = '#{q(value[:old_name])}'"
                  updated_names += ActiveRecord::Base.connection.update(sql)
                }
                flash[:status] += "<br />"+ _('Destination_names_updated') + ": #{updated_names}" if updated_names > 0
              end
            rescue
              flash[:notice] = _('colission_Please_start_over')
              redirect_to :action => "import_csv", :id => @tariff.id, :step => "0" and return false
            end

          else
            flash[:notice] = _('No_Destinations_Were_Created')
          end
          session[:created_destinations] = cd
          session[:updated_destinations] = updated_names
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
      end
    end

    #update rates (ratedetails actually)
    if @step == 6
      my_debug_time "step 6"
      if session[:file]
        @file = session[:file]
        if session[:imp_prefix] and session[:imp_rate]
          begin
            csv_file = FasterCSV.new(@file, { :col_sep => @sep, :headers => false, :return_headers => false })
            update_rate = session[:update_rate_array]

            ur = 0  #updated rates
            i = 0
            # priskirimas
            ["wd", "fd"].include?(session[:imp_date_day_type].to_s) ? day_type = session[:imp_date_day_type].upcase : day_type = ""
            csv_file.each_with_index{ |row, i|
              if update_rate and update_rate[i]
                prefix = row[session[:imp_prefix]].to_s.gsub(/\s/, '')
                rate = row[session[:imp_rate]].to_s.gsub(@dec, ".").to_f #.gsub!(/[^\d\.]/, '')

                connection_fee = 0
                connection_fee = row[session[:imp_connection_fee]].to_s.gsub(@dec, ".").to_f if session[:imp_connection_fee] >= 0
                connection_fee = session[:manual_connection_fee].to_s.gsub(@dec, ".").to_f if session[:manual_connection_fee].to_s.length > 0

                increment = 1
                increment = row[session[:imp_inc]].to_i if session[:imp_inc] >= 0
                increment = session[:manual_increment].to_i if session[:manual_increment].to_s.length > 0

                min_time = 0
                min_time = row[session[:imp_mint]].to_i if session[:imp_mint] >= 0
                min_time = session[:manual_min_time].to_i if session[:manual_min_time].to_s.length > 0

                #error fixing
                increment = 1 if increment <= 0
                min_time = 0 if min_time < 0
                connection_fee = 0 if connection_fee < 0

                type_sql = day_type.blank? ? '' : " AND ratedetails.daytype = '#{day_type.to_s}' "
                #find rate details by day_type , tariff, prefix and time
                rates = Ratedetail.find(:all, :joins => "LEFT JOIN rates ON (ratedetails.rate_id = rates.id) LEFT JOIN destinations ON (destinations.id = rates.destination_id)", :conditions => ["destinations.prefix = ? AND rates.tariff_id = ? AND start_time = '#{session[:imp_time_from_type]}' AND end_time = '#{session[:imp_time_till_type]}' #{type_sql}", prefix.to_s, @tariff.id ])

                # if rate details exists update
                if rates and rates.size.to_i > 0
                  sql = "UPDATE ratedetails, rates, destinations SET ratedetails.rate = #{rate.to_s}, ratedetails.connection_fee = #{connection_fee.to_s}, increment_s = #{increment.to_s}, min_time = #{min_time.to_s} WHERE ratedetails.rate_id = rates.id AND destinations.id = rates.destination_id AND destinations.prefix = '#{prefix.to_s}' AND rates.tariff_id = #{@tariff.id.to_s} #{type_sql} AND start_time = '#{session[:imp_time_from_type]}' AND end_time = '#{session[:imp_time_till_type]}';"
                  res = ActiveRecord::Base.connection.update(sql)
                else
                  # if rate detail not exists create it
                  begin
                    sql = "INSERT INTO ratedetails (rate, rate_id, increment_s, min_time, connection_fee, daytype, start_time, end_time) VALUES (#{rate}, (SELECT rates.id FROM rates JOIN destinations ON (destinations.id = rates.destination_id) WHERE destinations.prefix = '#{prefix.to_s}' AND rates.tariff_id = #{@tariff.id.to_s} LIMIT 1), #{increment}, #{min_time}, #{connection_fee}, '#{day_type}', '#{session[:imp_time_from_type]}', '#{session[:imp_time_till_type]}');"
                    res = ActiveRecord::Base.connection.update(sql)
                  rescue Exception => e
                    MorLog.log_exception(e, "", "", "")
                    flash[:notice] = _('Rate_not_found')
                    redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
                  end
                end

                # ************************* commented old update method 2011-03-16 #2746
                #              if day_type.blank?
                #                # We are updating 'ALL' rate. Every ratedetails value should be updated.
                #                sql = "UPDATE ratedetails, rates, destinations SET ratedetails.rate = #{rate.to_s}, ratedetails.connection_fee = #{connection_fee.to_s}, increment_s = #{increment.to_s}, min_time = #{min_time.to_s}, ratedetails.daytype = '' WHERE ratedetails.rate_id = rates.id AND destinations.id = rates.destination_id AND destinations.prefix = '#{prefix.to_s}' AND rates.tariff_id = #{@tariff.id.to_s} AND start_time = '#{session[:imp_time_from_type]}' AND end_time = '#{session[:imp_time_till_type]}';"
                #                res = ActiveRecord::Base.connection.update(sql)
                #              else
                #                rates = Ratedetail.find(:all, :joins => "LEFT JOIN rates ON (ratedetails.rate_id = rates.id) LEFT JOIN destinations ON (destinations.id = rates.destination_id)", :conditions => ["destinations.prefix = ? AND rates.tariff_id = ? AND start_time = '#{session[:imp_time_from_type]}' AND end_time = '#{session[:imp_time_till_type]}'", prefix.to_s, @tariff.id ])
                #
                #                if rates.size == 1
                #                  #                  # set old ALL datetype to that should be kept(id updating WD - FD should be kept)
                #                  #                  day_type == 'fd' ? keep_day_type = 'WD' : keep_day_type = 'FD'
                #                  #                  sql = "UPDATE ratedetails, rates, destinations SET ratedetails.daytype = '#{keep_day_type.to_s}' WHERE ratedetails.rate_id = rates.id AND destinations.id = rates.destination_id AND destinations.prefix = '#{prefix.to_s}' AND rates.tariff_id = #{@tariff.id.to_s};"
                #                  #                  res = ActiveRecord::Base.connection.update(sql)
                #                  #                  # the other daytype should be created.
                #                  sql = "UPDATE ratedetails, rates, destinations SET ratedetails.rate = #{rate.to_s}, ratedetails.connection_fee = #{connection_fee.to_s}, increment_s = #{increment.to_s}, min_time = #{min_time.to_s} WHERE ratedetails.rate_id = rates.id AND destinations.id = rates.destination_id AND destinations.prefix = '#{prefix.to_s}' AND rates.tariff_id = #{@tariff.id.to_s} AND ratedetails.daytype = '#{day_type.to_s}';"
                #                  res = ActiveRecord::Base.connection.update(sql)
                #                  if rates[0].daytype !=day_type
                #                    sql = "INSERT INTO ratedetails (rate, rate_id, increment_s, min_time, connection_fee, daytype, start_time, end_time) VALUES (#{rate}, #{rates[0].rate_id}, #{increment}, #{min_time}, #{connection_fee}, '#{day_type}', '#{session[:imp_time_from_type]}', '#{session[:imp_time_till_type]}');"
                #                    res = ActiveRecord::Base.connection.update(sql)
                #                  end
                #                else
                #                  # exists 2 rates - only one needs to be updated.
                #                  sql = "UPDATE ratedetails, rates, destinations SET ratedetails.rate = #{rate.to_s}, ratedetails.connection_fee = #{connection_fee.to_s}, increment_s = #{increment.to_s}, min_time = #{min_time.to_s} WHERE ratedetails.rate_id = rates.id AND destinations.id = rates.destination_id AND destinations.prefix = '#{prefix.to_s}' AND rates.tariff_id = #{@tariff.id.to_s} AND ratedetails.daytype = '#{day_type.to_s}' AND start_time = '#{session[:imp_time_from_type]}' AND end_time = '#{session[:imp_time_till_type]}';"
                #                  res = ActiveRecord::Base.connection.update(sql)
                #                end
                #              end
                # **************************** end *****************
                my_debug_time ur.to_s + " rates updated"  if ur % 1000 == 0
                ur+=1
              end
            }

            session[:updated_rates] = ur
            flash[:status] = _('Rates_updated') + ": " + ur.to_s
          rescue
            flash[:notice] = _('colission_Please_start_over')
            redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
          end
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
      end
    end

    #create rates/ratedetails
    if @step == 7
      my_debug_time "step 7"
      if session[:file]
        @file = session[:file]
        if session[:imp_prefix] and session[:imp_rate]
          begin
            csv_file = FasterCSV.new(@file, { :col_sep => @sep, :headers => false, :return_headers => false })
            update_rate = session[:update_rate_array]
            status = session[:status_array]

            #rates
            #sql = "INSERT INTO rates (tariff_id, destination_id) VALUES "
            sql_header = "INSERT INTO ratedetails (rate, rate_id, increment_s, min_time, connection_fee, daytype, start_time, end_time) VALUES "
            sql_arr = []
            cnr = 0   #created new rates
            limit = 1000  #how much rates insert at once
            ["wd", "fd"].include?(session[:imp_date_day_type].to_s) ? day_type = session[:imp_date_day_type].upcase : day_type = ""
            csv_file.each_with_index{ |row, i|

              ## check if we need to create new rate/ratedetails
              if status and status[i] > 0 and status[i] < 10 and not update_rate[i] #and i < session[:file_lines]
                prefix = row[session[:imp_prefix]].to_s.gsub(/\s/, '')

                ratev = row[session[:imp_rate]].to_s.gsub(@dec, ".").to_f  #.gsub!(/[^\d\.]/, '')
                connection_fee = 0
                connection_fee = row[session[:imp_connection_fee]].to_s.gsub(@dec, ".").to_f if session[:imp_connection_fee] >= 0
                connection_fee = session[:manual_connection_fee].to_s.gsub(@dec, ".").to_f if session[:manual_connection_fee].to_s.length > 0

                increment = 1
                increment = row[session[:imp_inc]].to_i if session[:imp_inc] >= 0
                increment = session[:manual_increment].to_i if session[:manual_increment].to_s.length > 0

                min_time = 0
                min_time = row[session[:imp_mint]].to_i if session[:imp_mint] >= 0
                min_time = session[:manual_min_time].to_i if session[:manual_min_time].to_s.length > 0

                #error fixing
                increment = 1 if increment <= 0
                min_time = 0 if min_time < 0
                connection_fee = 0 if connection_fee < 0

                #my_debug prefix
                dst_id = ActiveRecord::Base.connection.select_value("SELECT id FROM destinations WHERE prefix = '#{prefix}' LIMIT 1")

                rate = Rate.new(:tariff_id => @tariff.id, :destination_id => dst_id)
                if rate.save

                  #my_debug rate.id
                  if day_type.blank?
                    sql_arr << "(#{ratev}, #{rate.id}, #{increment}, #{min_time}, #{connection_fee}, '', '#{session[:imp_time_from_type]}', '#{session[:imp_time_till_type]}')"
                  else
                    sql_arr << "(#{ratev}, #{rate.id}, #{increment}, #{min_time}, #{connection_fee}, '#{day_type}', '#{session[:imp_time_from_type]}', '#{session[:imp_time_till_type]}')"
                  end
                  if (sql_arr.size > limit) or (i+1 >= session[:file_lines].to_i)
                    ActiveRecord::Base.connection.insert(sql_header + sql_arr.join(", "))
                    sql_arr = []
                    my_debug_time cnr.to_s + " rates inserted"
                  end
                  cnr += 1
                end
              end
            }
            #inserting remaining rows if csv has empty lines at the end
            if sql_arr.size > 0
              ActiveRecord::Base.connection.insert(sql_header + sql_arr.join(", "))
            end


            session[:created_new_rates] = cnr
            flash[:status] = _('New_rates_created') + ": " + cnr.to_s

            #deleting not necessary session vars
            session[:file] = nil
            session[:status_array] = nil
            session[:update_rate_array] = nil
            session[:bad_lines_array] = nil
            session[:bad_lines_status_array] = nil
            session[:manual_connection_fee] = nil
            session[:manual_increment] = nil
            session[:manual_min_time] = nil
            session[:imp_date_day_type] = nil
            session[:dst_to_update_hash] = nil
            Action.add_action(session[:user_id], "tariff_import", _('Tariff_was_imported_from_CSV'))
          rescue
            flash[:notice] = _('colission_Please_start_over')
            redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
          end
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv", :id => @tariff.id, :step => "1" and return false
      end
    end
  end

  # ======== CSV IMPORT =================

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
    @page_title = _('Import_CSV') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
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
        a = check_csv_file_seperators(file, 2,2)
        if a
          @fl = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{@tariff.id}".to_sym]}.csv", 1).join("").to_s.split(@sep)
          begin
            session["tariff_name_csv_#{@tariff.id}".to_sym] = @tariff.load_csv_into_db(session["temp_tariff_name_csv_#{@tariff.id}".to_sym], @sep, @dec, @fl)
          rescue Exception => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            session[:import_csv_tariffs_import_csv_options] = {}
            session[:import_csv_tariffs_import_csv_options][:sep] = @sep
            session[:import_csv_tariffs_import_csv_options][:dec] = @dec
            session[:file] = File.open("/tmp/#{session["temp_tariff_name_csv_#{@tariff.id}".to_sym]}.csv", "rb").read
            Tariff.clean_after_import(session["temp_tariff_name_csv_#{@tariff.id}".to_sym])
            session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
            redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
          end
          flash[:status] = _('File_uploaded') if !flash[:notice]
        end
      else
        session["tariff_name_csv_#{@tariff.id}".to_sym] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv2", :id => @tariff.id, :step => "1" and return false
      end
      @rate_type,flash[:notice_2] = @tariff.check_types_periods(params)
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
            @optins[:imp_cc] = params[:country_code_id].to_i
            
            @optins[:imp_city] = params[:city_id].to_i
            @optins[:imp_state] = params[:state_id].to_i
            @optins[:imp_lata] = params[:lata_id].to_i
            @optins[:imp_tier] = params[:tier_id].to_i
            @optins[:imp_ocn] = params[:ocn_id].to_i

            @optins[:imp_country] = params[:country_id].to_i
            @optins[:imp_connection_fee] = params[:connection_fee_id].to_i
            @optins[:imp_date_day_type] = params[:rate_day_type].to_s

            @rate_type,flash[:notice_2] = @tariff.check_types_periods(params)
            unless flash[:notice_2].blank?
              flash[:notice] = _('Tarrif_import_incorect_time')
              flash[:notice] += '<br /> * ' + _('Please_select_period_without_collisions')
              redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
            end

            @optins[:imp_time_from_type] = params[:time_from][:hour].to_s + ":" + params[:time_from][:minute].to_s + ":" + params[:time_from][:second].to_s if params[:time_from]
            @optins[:imp_time_till_type] = params[:time_till][:hour].to_s + ":" + params[:time_till][:minute].to_s + ":" + params[:time_till][:second].to_s if params[:time_till]
            @optins[:imp_update_dest_names] = params[:update_dest_names].to_i if admin?
            
            if admin? and params[:update_dest_names].to_i == 1             
              if params[:destination_id] and params[:destination_id].to_i >=0
                @optins[:imp_dst] = params[:destination_id].to_i
              else
                flash[:notice] = _('Please_Select_Columns_destination')
                redirect_to :action => "import_csv2", :id => @tariff.id, :step => "2" and return false
              end
            else
              @optins[:imp_dst] = params[:destination_id].to_i
            end
            #priority over csv

            @optins[:manual_connection_fee] = ""
            @optins[:manual_increment] = ""
            @optins[:manual_min_time] = ""

            @optins[:manual_connection_fee] = params[:manual_connection_fee] if params[:manual_connection_fee]
            @optins[:manual_increment] = params[:manual_increment] if params[:manual_increment]
            @optins[:manual_min_time] = params[:manual_min_time] if params[:manual_min_time]

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
            if Confline.get_value('Destination_create',current_user.id).to_i == 1
              #redirect back
              flash[:notice] = _('Please_wait_while_first_import_is_finished')
              redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
            else        
              @tariff_analize = session["tariff_analize_csv2_#{@tariff.id}".to_sym]
              my_debug_time "step 5"
              if ["admin", "accountant"].include?(session[:usertype])
                begin
                  session["tariff_analize_csv2_#{@tariff.id}".to_sym][:created_destination_from_file] =  @tariff.create_deatinations(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
                  flash[:status] = _('Created_destinations') + ": #{session["tariff_analize_csv2_#{@tariff.id}".to_sym][:created_destination_from_file]}"
                  if session["tariff_import_csv2_#{@tariff.id}".to_sym][:imp_update_dest_names].to_i == 1
                    session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_destination_from_file] = @tariff.update_destinations(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
                    flash[:status] += "<br />"+ _('Destination_names_updated') + ": #{session["tariff_analize_csv2_#{@tariff.id}".to_sym][:updated_destination_from_file]}"
                  end
                rescue Exception => e
                  my_debug_time e.to_yaml
                  flash[:notice] = _('colission_Please_start_over')
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
              @tariff.insert_ratedetails(session["tariff_name_csv_#{@tariff.id}".to_sym], session["tariff_import_csv2_#{@tariff.id}".to_sym], session["tariff_analize_csv2_#{@tariff.id}".to_sym])
              flash[:status] = _('Rates_updated') + ": " + @tariff_analize[:rates_to_update].to_s
            rescue Exception => e
              my_debug_time e.to_yaml
              flash[:notice] = _('colission_Please_start_over')
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
              my_debug_time "clean done"
              flash[:status] = _('New_rates_created') + ": " + @tariff_analize[:new_rates_to_create].to_s
              Action.add_action(session[:user_id], "tariff_import_2", _('Tariff_was_imported_from_CSV'))
            rescue Exception => e
              my_debug_time e.to_yaml
              flash[:notice] = _('colission_Please_start_over')
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
        redirect_to :controller=>"tariffs", :action=>"list" and return false
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
        @rows =  ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{params[:tariff_id]}".to_sym]} WHERE f_error = 1")
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
        @sep = session["import_csv_tariffs_import_csv_options".to_sym][:sep]
        @csv_file = FasterCSV.new(@file, { :col_sep => @sep, :headers => false, :return_headers => false })
        begin
          @csv_file.each{|row|}
          @csv_file.rewind
        rescue
          flash[:notice] = csv_import_invalid_file_notice
          redirect_to :controller=>"tariffs", :action=>"list" and return false
        end
      else
        @csv2=1
        if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id]}".to_sym])
          @csv_file = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{params[:tariff_id]}".to_sym]} WHERE not_found_in_db = 1 AND f_error = 0")
        end
        render(:layout => "layouts/mor_min")
      end
    else
      flash[:notice] = _('Zero_file_size')
      redirect_to :controller=>"tariffs", :action=>"list"
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
        @dst = ActiveRecord::Base.connection.select_all("SELECT destinations.prefix, col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_dst]} as new_name, destinations.name as dest_name FROM destinations JOIN #{session["tariff_name_csv_#{params[:tariff_id]}".to_sym]} ON (replace(col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]}, '\\r', '') = prefix)  WHERE ned_update = 1 ")
      end
    end
    #    if !@file.blank? or (params[:csv2].to_i == 0 and session[:dst_to_update_hash].size == 0) or (params[:csv2].to_i == 1 and session["tariff_import_csv2_#{params[:tariff_id]}".to_sym][:dst_to_update_hash].size == 0)
    #
    #      render(:layout => "layouts/mor_min")
    #    else
    #      flash[:notice] = _('Zero_file_size')
    #      redirect_to :controller=>"tariffs", :action=>"list"
    #    end
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

  # =============== RATES FOR USER ==================
  # before_filter : tariff(find_taririff_from_id)
  def user_rates_list
    check_user_for_tariff(@tariff.id)

    if @tariff.purpose != 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller=>:tariffs, :actions=>:list and return false
    end
    

    @page_title = _('Rates_for_tariff') #+": " + @tariff.name
    @page_icon = "coins.png"
    @res =[]
    session[:tariff_user_rates_list] ? @options = session[:tariff_user_rates_list] : @options = {:page => 1}
    @options[:page] = params[:page].to_i if !params[:page].blank?
    @items_per_page = Confline.get_value("Items_Per_Page").to_i
    @letter_select_header_id = @tariff.id
    @st = "A"
    @st = params[:st].upcase  if params[:st]

    @page = 1
    @page = params[:page].to_i if params[:page]

    if params[:s_prefix] and !params[:s_prefix].blank?
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/,'')
      cond = "prefix LIKE '#{@s_prefix.to_s}'"
      @search =1
    else
      cond = "destinationgroups.name LIKE '#{@st}%'"
    end

    # Cia reiketu refactorint.
    #    sql = "SELECT destinationgroups.flag, destinationgroups.name, destinationgroups.desttype,  A.*, rates.id as 'rate_id', B.count_arates as 'arates_size', C.price, C.round, C.artype
    #             FROM
    #              (SELECT destinations.destinationgroup_id as 'dg_id', COUNT(destinations.id) as 'destinations' FROM destinations #{cond} GROUP BY destinations.destinationgroup_id) as A
    #                JOIN destinationgroups ON (A.dg_id = destinationgroups.id)
    #                LEFT JOIN rates ON (destinationgroups.id = rates.destinationgroup_id AND rates.tariff_id = #{@tariff.id} )
    #                LEFT JOIN (SELECT rates.id as 'rates_id', COUNT(aratedetails.id) as 'count_arates' FROM rates LEFT JOIN aratedetails ON (aratedetails.rate_id = rates.id) WHERE rates.tariff_id = #{@tariff.id} GROUP BY rates.id) AS B ON (B.rates_id = rates.id)
    #                LEFT JOIN (SELECT rates.id as 'rates_id', aratedetails.* FROM rates LEFT JOIN aratedetails ON (aratedetails.rate_id = rates.id AND aratedetails.artype = 'minute') WHERE rates.tariff_id = #{@tariff.id} GROUP BY rates.id) AS C ON (C.rates_id = rates.id)
    ##{cond2}
    #ORDER BY destinationgroups.name, destinationgroups.desttype ASC;#"

    #Cia refactorintas , veikia x7 greiciau...
    sql = "SELECT * FROM (
                          SELECT destinationgroups.flag, destinationgroups.name, destinationgroups.desttype, destinationgroup_id AS dg_id, COUNT(DISTINCT destinations.id) AS destinations  FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                WHERE #{cond}
                                GROUP BY destinations.destinationgroup_id
                                ORDER BY destinationgroups.name, destinationgroups.desttype ASC
                         ) AS dest
              LEFT JOIN (SELECT rates.destinationgroup_id AS dg_id2, rates.id AS rate_id, COUNT(DISTINCT aratedetails.id) AS arates_size,  IF(art2.id IS NULL, aratedetails.price, NULL) AS price, IF(art2.id IS NULL, aratedetails.round, NULL) AS round, IF(art2.id IS NOT NULL,  NULL, 'minute') as artype FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                LEFT JOIN rates ON (rates.destinationgroup_id = destinationgroups.id )
                                LEFT JOIN aratedetails ON (aratedetails.rate_id = rates.id)
                                LEFT JOIN aratedetails AS art2 ON (art2.rate_id = rates.id and art2.artype != 'minute')
                                WHERE #{cond}  AND rates.tariff_id = #{@tariff.id}
                                GROUP BY rates.destinationgroup_id
                        ) AS rat ON (dest.dg_id = rat.dg_id2)"

    #@rates = Rate.find(:all, :conditions=>["rates.tariff_id = ? #{con}", @tariff.id], :include => [:aratedetails, :destinationgroup ], :order=>"destinationgroups.name, destinationgroups.desttype ASC" )
    @res = ActiveRecord::Base.connection.select_all(sql)
    @options[:total_pages] = (@res.size.to_f / @items_per_page.to_f).ceil
    @options[:page] = 1 if @options[:page] > @options[:total_pages]
    istart = (@options[:page]-1)*@items_per_page
    iend = (@options[:page])*@items_per_page-1
    @res = @res[istart..iend]
    session[:tariff_user_rates_list] = @options

    rids= []
    @res.each { |res| rids << res['rate_id'].to_i if !res['rate_id'].blank? }
    @rates_list = Rate.find(:all, :conditions=>["rates.id IN (#{rids.join(',')})"], :include=>[:aratedetails, :tariff, :destinationgroup]) if rids.size.to_i > 0


    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first,:conditions =>["reseller_id = ? AND tariff_id = ?",current_user.id, @tariff.id])
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

    @ards and @ards.size > 0 ?  @et = nice_time2(@ards[0].end_time) : @et = "23:59:59"

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
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first,:conditions =>["reseller_id = ? AND tariff_id = ?",current_user.id, @tariff.id])
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
      redirect_to :action=>:index and return false
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

      sql = "SELECT start_time, end_time FROM aratedetails WHERE daytype = '' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for r in res
        @st_arr << r["start_time"]
        @et_arr << r["end_time"]
      end

    else
      @WDFD = false

      sql = "SELECT start_time, end_time FROM aratedetails WHERE daytype = 'WD' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Wst_arr = []
      @Wet_arr = []
      for r in res
        @Wst_arr << r["start_time"]
        @Wet_arr << r["end_time"]
      end

      sql = "SELECT start_time, end_time FROM aratedetails WHERE daytype = 'FD' AND rate_id = #{@rate.id} GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @Fst_arr = []
      @Fet_arr = []
      for r in res
        @Fst_arr << r["start_time"]
        @Fet_arr << r["end_time"]
      end

    end
    
    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user.id and CommonUseProvider.find(:first,:conditions =>["reseller_id = ? AND tariff_id = ?",current_user.id, @tariff.id])
      @can_edit = false
    end

  end


  def user_ard_time_edit
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action=>:index and return false
    end
    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a

    dt = params[:daytype]

    et = params[:date][:hour] + ":" + params[:date][:minute] + ":" + params[:date][:second]
    st = params[:st]

    if st.to_s > et.to_s
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'user_arates_full', :id => @rate.tariff_id , :dg => @rate.destinationgroup_id    and return false
    end

    rdetails = @rate.aratedetails_by_daytype(params[:daytype])

    ard = Aratedetail.find(:first, :conditions => "rate_id = #{@rate.id} AND start_time = '#{st}'  AND daytype = '#{dt}'")

    #my_debug ard.start_time
    #my_debug rdetails[(rdetails.size - 1)].start_time

    # we need to create new rd to cover all day
    if (et != "23:59:59") and ((rdetails[(rdetails.size - 1)].start_time == ard.start_time) )
      nst = Time.mktime('2000','01','01', params[:date][:hour], params[:date][:minute], params[:date][:second]) + 1.second
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
        na.start_time = nst
        na.end_time = "23:59:59"
        na.daytype = a.daytype
        na.save

        a.end_time = et
        a.save

      end

    end


    flash[:status] = _('Rate_details_updated')
    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id , :dg => @rate.destinationgroup_id
  end


  def artg_destroy
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action=>:index and return false
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
    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id , :dg => @rate.destinationgroup_id

  end



  def ard_manage
    @rate = Rate.find_by_id(params[:id])
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action=>:index and return false
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


    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id , :dg => @rate.destinationgroup_id


  end

  #update one rate
  def user_rate_update
    @ard = Aratedetail.find_by_id(params[:id])
    unless @ard
      flash[:notice]=_('Aratedetail_was_not_found')
      redirect_to :action=>:index and return false
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
        price = params[:price].to_f
        round = 1 if round < 1

        @ard.from = params[:from]
        @ard.artype = artype
        @ard.duration = duration
        @ard.round = round
        @ard.price = price
      else
        @ard.price = params["price_#{@ard.id}".to_sym].to_f
        @ard.round = params["round_#{@ard.id}".to_sym].to_i
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
      redirect_to :action=>:index and return false
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
    price = params[:price].to_f
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
      redirect_to :action=>:index and return false
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

    @dgroups = Destinationgroup.find(:all, :order => "name ASC, desttype ASC")

    for dg in @dgroups

      price = ""
      price = params[("rate" + dg.id.to_s).intern] if params[("rate" + dg.id.to_s).intern]
      round = params[("round" + dg.id.to_s).intern].to_i
      round = 1 if round < 0

      #      if price.to_f != 0 or round != 1
      unless price.blank?
        #let's create ard
        unless dg.rate(@tariff.id)
          rate = Rate.new
          rate.tariff_id = @tariff.id
          rate.destinationgroup_id = dg.id
          rate.save

          ard = Aratedetail.new
          ard.from = 1
          ard.duration = -1
          ard.artype = "minute"
          ard.round = round
          ard.price = price.to_f
          ard.rate_id = rate.id
          ard.save

          #my_debug "create rate"

        else
          #update existing ard
          aratedetails = dg.rate(@tariff.id).aratedetails
          #my_debug aratedetails.size
          if aratedetails.size == 1
            ard = aratedetails[0]
            #my_debug price
            #my_debug "--"
            if price == ""
              ard.rate.destroy_everything
              #ard.destroy
            else
              from_duration_db = ard.from.to_i + ard.duration.to_i
              if ard.duration.to_i != -1 and from_duration_db < round.to_i
                flash[:notice] = _('Rate_not_updated_round_by_is_too_big') + ': '+ "#{dg.name}"
                redirect_to :action => 'user_rates_list', :id => @tariff.id, :page => params[:page], :st=>params[:st], :s_prefix=>params[:s_prefix] and return false
              else
                ard.price = price.to_f
                ard.round = round
                ard.save
              end
            end
          end

        end

      end
    end
    
    flash[:status] = _('Rates_updated')
    redirect_to :action => 'user_rates_list', :id => @tariff.id, :page => params[:page], :st=>params[:st], :s_prefix=>params[:s_prefix] and return false
  end


  def user_rate_destroy
    rate = Rate.find_by_id(params[:id])
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action=>:index and return false
    end
    tariff_id = rate.tariff_id

    a=check_user_for_tariff(tariff_id)
    return false if !a

    rate.destroy_everything

    flash[:status] = _('Rate_deleted')
    redirect_to :action => 'user_rates_list', :id => tariff_id, :page => params[:page], :st=>params[:st], :s_prefix=>params[:s_prefix]

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
    (params[:st] and ("A".."Z").include?(params[:st].upcase)) ? @st = params[:st].upcase : @st = "A"
    @dgroups = Destinationgroup.find(:all, :conditions => ["name like ?", "#{@st}%"] ,:order => "name ASC, desttype ASC")
    @Show_Currency_Selector = true

    @page = 1
    @page = params[:page].to_i if params[:page]

    @rates = @tariff.rates_by_st(@st,0,10000)
    @total_pages = (@rates.size.to_f / session[:items_per_page].to_f).ceil
    @all_rates = @rates
    @rates = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_rates.size - 1 if iend > (@all_rates.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @rates << @all_rates[i]
    end

    exrate = Currency.count_exchange_rate(@tariff.currency, session[:show_currency])
    @ratesd = Ratedetail.find_all_from_id_with_exrate({:rates=>@rates, :exrate=>exrate, :destinations=>true, :directions=>true})

    @use_lata = @st == "U" ? true : false

    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id

    @exchange_rate = count_exchange_rate(@tariff.currency, session[:show_currency])
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], session[:show_currency])
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
      redirect_to :controller=> :callc, :action=>:main and return false
    end

    @page_title = _("Detailed_rates")
    @dgroup = Destinationgroup.find_by_id(params[:id])
    unless @dgroup
      dont_be_so_smart
      redirect_to :controller=> :callc, :action=>:main and return false
    end
    @rate = @dgroup.rate(@tariff.id)
    unless @rate
      dont_be_so_smart
      redirect_to :controller=> :callc, :action=>:main and return false
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
      redirect_to :action=>:index and return false
    end
    @rate = @dgroup.rate(session[:tariff_id])
    @custrate = @dgroup.custom_rate(session[:user_id])

    @cards = Acustratedetail.find(:all, :conditions => "customrate_id = #{@custrate.id}", :order => "daytype DESC, start_time ASC, acustratedetails.from ASC, artype ASC")  if @custrate
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
      redirect_to :action => 'day_setup'  and return false
    end

    #my_debug "---"


    if Day.find(:first, :conditions =>["date = ? ", date])
      flash[:notice] = _('Duplicate_date')
      redirect_to :action => 'day_setup'  and return false
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
      redirect_to :action=>:index and return false
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
      redirect_to :action=>:index and return false
    end
  end

  def day_update
    day = Day.find_by_id(params[:id])
    unless day
      flash[:notice]=_('Day_was_not_found')
      redirect_to :action=>:index and return false
    end

    date = params[:date][:year] + "-" + good_date(params[:date][:month]) + "-" + good_date(params[:date][:day])

    if Day.find(:first, :conditions => ["date = ? and id != ?", date, day.id])
      flash[:notice] = _('Duplicate_date')
      redirect_to :action => 'day_setup'  and return false
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
    if @ptariff.make_retail_tariff(@add_amount, @add_percent, @add_confee_amount , @add_confee_percent, get_user_id())
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
    @add_amount = params[:add_amount].to_f
    @add_percent = params[:add_percent].to_f
    @add_confee_amount = params[:add_confee_amount].to_f
    @add_confee_percent = params[:add_confee_percent].to_f
    if session[:usertype] == "admin"
      @t_type =  params[:t_type] if params[:t_type].to_s.length > 0
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
        redirect_to :action=>:index and return false
      end
      @tarif_to = Tariff.find_by_id(params[:tariff_to])
      unless @tarif_to
        flash[:notice]=_('Tariff_was_not_found')
        redirect_to :action=>:index and return false
      end
      for user in @tarif_from.users
        user.tariff_id =  @tarif_to.id
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
    require 'pdf/wrapper'
    a = check_user_for_tariff(@tariff)
    return false if !a

    sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{@tariff.id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name, destinations.subcode ASC"
    rates = Rate.find_by_sql(sql)

    options = {
      #font size
      :fontsize => 6,
      :title_fontsize => 16,
      :title2_fontsize => 10,
      :header_size_add => 1,

      #positions
      :page_pos_1 => 150,
      :page_pos_2 => 70,
      :page_num_pos => 780,
      :header_eleveation => 20,
      :step_size => 15,

      :per_page_1 => 40,
      :per_page_2 => 45,

      :total_items => rates.size,
      # col possitions
      :col1_x => 40,
      :col2_x => 220,
      :col3_x => 265,
      :col4_x => 320,
      :col5_x => 370,
      :col6_x => 440,
      :col7_x => 490
    }
    options[:total_pages] = PdfGen::Count.pages(options[:total_items], options[:per_page_1], options[:per_page_2])
    options[:per_page] = options[:per_page_1]
    options[:page_pos] = options[:page_pos_1]
    i=1
    in_page=1
    pdf = PDF::Wrapper.new(:paper => :A4)
    pdf.font("Nimbus Sans L")
    pdf.text(_('Rates'), {:alignment => :left, :font_size => options[:title_fontsize]})

    if params[:hide_tariff] or params[:hide_tariff].to_i != 1
      pdf.text(_('Tariff') + ": #{@tariff.name}", {:font_size => options[:title2_fontsize], :alignment => :left})
    end
    pdf.text(_('Currency') + ": " + session[:show_currency], {:font_size => options[:title2_fontsize], :alignment => :left})
    pdf = PdfGen::Generate.generate_provider_rates_pdf_header(pdf, i, options)

    exrate = Currency.count_exchange_rate(@tariff.currency, session[:show_currency])
    for rate in rates
      get_provider_rate_details(rate, exrate)
      if rate.destination && rate.destination.direction
        pdf.text(rate.destination.direction.name,{:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col1_x], :font_size => options[:fontsize]} )
        pdf.text(rate.destination.subcode,       {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col2_x], :font_size => options[:fontsize]} )
        pdf.text(rate.destination.prefix,        {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col3_x], :font_size => options[:fontsize]} )
      else
        pdf.text("0", {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col1_x], :font_size => options[:fontsize]})
        pdf.text("0", {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col2_x], :font_size => options[:fontsize]})
        pdf.text("0", {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col3_x], :font_size => options[:fontsize]})
      end
      # if there is info about rate
      if @rate_details.size > 0
        @rate_cur = @rate_details.size > 1 ? nice_number(@rate_cur).to_s + " *" : nice_number(@rate_cur)
        pdf.text(@rate_cur,                          {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col4_x], :font_size => options[:fontsize]})
        pdf.text(nice_number(@rate_details[0]['connection_fee']), {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col5_x], :font_size => options[:fontsize]})
        pdf.text(@rate_details[0]['increment_s'],    {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col6_x], :font_size => options[:fontsize]})
        pdf.text(@rate_details[0]['min_time'],       {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col7_x], :font_size => options[:fontsize]})
      else
        pdf.text("0", {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col4_x], :font_size => options[:fontsize]})
        pdf.text("0", {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col5_x], :font_size => options[:fontsize]})
        pdf.text("0", {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col6_x], :font_size => options[:fontsize]})
        pdf.text("0", {:top=> options[:page_pos]+ in_page*options[:step_size], :left=> options[:col7_x], :font_size => options[:fontsize]})
      end

      pdf.text(_('*_Maximum_rate'), {:top=> options[:page_num_pos], :left=> options[:col1_x], :font_size => options[:fontsize] + options[:header_size_add]}) if @rate_details.size > 1
      if in_page == options[:per_page] and i != options[:total_items]
        pdf.start_new_page
        options[:per_page] = options[:per_page_2]
        options[:page_pos] = options[:page_pos_2]
        pdf = PdfGen::Generate.generate_provider_rates_pdf_header(pdf, i, options)
        in_page = 0
      end
      i += 1
      in_page += 1
    end

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
    file = @tariff.generate_personal_wholesale_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_pdf
    sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{@tariff.id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name ASC;"
    rates = Rate.find_by_sql(sql)
    options = {
      #font size
      :fontsize => 6,
      :title_fontsize1 => 16,
      :title_fontsize2 => 10,
      :header_size_add => 1,
      :page_number_size => 8,
      #positions
      :first_page_pos => 150,
      :second_page_pos => 70,
      :page_num_pos => 780,
      :header_eleveation => 20,
      :step_size => 15,
      :title_pos1 => 50,
      :title_pos2 => 70,

      :first_page_items => 40,
      :second_page_items => 45,

      # col possitions
      :col1_x => 30,
      :col2_x => 205,
      :col3_x => 250,
      :col4_x => 310,
      :col5_x => 350,
      :col6_x => 420,
      :col7_x => 470,

      :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(rates, @tariff, @user, options)
    file = pdf.render
    filename = "Rates-#{(session[:show_currency]).to_s}.pdf"
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_pdf
    sql = "SELECT rates.* FROM rates
           LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)
           WHERE rates.tariff_id ='#{@tariff.id}'
           ORDER BY destinationgroups.name, destinationgroups.desttype ASC"
    rates = Rate.find_by_sql(sql)
    options = {
      #font size
      :fontsize => 6,
      :title_fontsize1 => 16,
      :title_fontsize2 => 10,
      :header_size_add => 1,
      :page_number_size => 8,
      #positions
      :first_page_pos => 150,
      :second_page_pos => 70,
      :page_num_pos => 780,
      :header_eleveation => 20,
      :step_size => 15,
      :title_pos1 => 40,
      :title_pos2 => 65,
      :title_pos3 => 80,

      :first_page_items => 40,
      :second_page_items => 45,

      # col possitions
      :col1_x => 40,
      :col2_x => 250,
      :col3_x => 330,
      :col4_x => 410,

      :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_user_rates_pdf(rates, @tariff, options)
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
      @arate_cur = Currency.count_exchange_prices({:exrate=>exrate, :prices=>[@arates[0].price.to_f]}) if @arates[0]
    end
  end

  # before_filter : user; tariff
  def generate_personal_rates_pdf
    dgroups = Destinationgroup.find(:all, :order => "name ASC, desttype ASC")
    tax = session[:tax]
    options = {
      #fontsize
      :title_fontsize => 16,
      :title2_fontsize =>10,
      :fontsize => 5,
      :header_add_size => 2,

      #positions Y
      :title_pos => 40,
      :title2_pos => 65,
      :title3_pos => 80,
      :first_page_pos => 155,
      :second_page_pos => 50,
      :page_number_pos => 780,
      :header_elevation => 20,
      :step_size => 15,
      #positions X
      :col1_x => 40,
      :col2_x => 250,
      :col3_x => 330,
      :col4_x => 410,
      # counts
      :per_page1 => 40,
      :per_page2 => 45,
    }
    pdf = PdfGen::Generate.generate_personal_rates(dgroups, @tariff, tax, @user,session[:show_currency],options)

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
        csv_string += "#{dg.name.to_s.gsub(sep," ")}#{sep}#{dg.desttype}#{sep}"
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
      exch_rates << er.to_f
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
        rate =   r[i].to_f / exch_rates[j] if r[i] and exch_rates[j]


        if rate and ( (min == nil) or (min.to_f > rate.to_f))
          min = rate
          minp = j
        end

        if rate and ( (max == nil) or (max.to_f < rate.to_f))
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
    csv_line = res.map{ |r| "#{r["prefix"]}#{cs}#{r["dir_name"].to_s.gsub(cs," ")}#{cs}#{r["subcode"].to_s.gsub(cs," ")}#{cs}#{r["dest_name"].to_s.gsub(cs," ")}" }.join("\n")
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
    @rate_type,flash[:notice_2] = @tariff.check_types_periods(params)

    #logger.info @f_h

    render(:layout => false)
  end

  private

  def check_user_for_tariff(tariff)

    if tariff.class.to_s !="Tariff"
      tariff = Tariff.find(:first, :conditions => ["id = ? ", tariff])
    end

    if session[:usertype].to_s == "accountant"
      if tariff.owner_id != 0 or session[:acc_tariff_manage].to_i == 0
        dont_be_so_smart
        redirect_to :controller => "tariffs", :action => "list" and return false
      end
    elsif session[:usertype].to_s == "reseller" and tariff.owner_id != session[:user_id] and (params[:action] == 'rate_details' or params[:action] == 'rates_list'or params[:action] == 'user_rates_list'or params[:action] == 'user_arates_full')
      if !CommonUseProvider.find(:first,:conditions =>["reseller_id = ? AND tariff_id = ?",current_user.id, tariff.id])
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
    @tariff = Tariff.find(:first, :conditions=>['id=?', params[:id]])
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action=>:index and return false
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to :action=>:index and return false
    end
  end

  def find_tariff_from_id
    @tariff = Tariff.find(:first, :conditions=>['id=?', params[:id]])
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action=>:index and return false
    end
  end

  def find_user_from_session
    @user = User.find(:first, :include => [:tariff], :conditions => ["users.id = ?", session[:user_id]])
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action=>:index and return false
    end
  end

  def find_user_tariff
    @tariff = @user.tariff
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action=>:index and return false
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to :action=>:index and return false
    end
  end

  def get_user_id()
    if session[:usertype].to_s == "accountant"
      user_id = 0
    else
      user_id = session[:user_id].to_i
    end
    return user_id
  end

  def get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.find(:all, :conditions => ["rate_id = ?", rate.id ], :order => "rate DESC")
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({:exrate=>exrate, :prices=>[@rate_details[0]['rate'].to_f, @rate_details[0]['connection_fee'].to_f]})
    end
    @rate_details
  end

=begin rdoc

=end

  def accountant_permissions
    allow_manage = !(session[:usertype] == "accountant" and (session[:acc_tariff_manage].to_i == 0 or session[:acc_tariff_manage].to_i == 1))
    allow_read = !(session[:usertype] == "accountant" and (session[:acc_tariff_manage].to_i == 0))
    return allow_manage, allow_read
  end
end
