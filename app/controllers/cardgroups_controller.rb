# -*- encoding : utf-8 -*-
class CardgroupsController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :check_calingcards_enabled
  before_filter :authorize

  before_filter :check_if_can_see_finances, :only => [:new, :create]
  #before_filter :authorize_admin

  @@card_view_res = []
  @@card_edit_res = [:list, :search, :show, :new, :create, :edit, :update, :destroy, :cards_to_csv, :upload_card_image]
  before_filter(:only => @@card_view_res+@@card_edit_res) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@card_view_res, @@card_edit_res, {:role => "reseller", :right => :res_calling_cards, :ignore => true})
    c.instance_variable_set :@allow_read_res, allow_read
    c.instance_variable_set :@allow_edit_res, allow_edit
    true
  }

  before_filter :find_card_group , :only=> [:destroy, :show, :edit, :update, :cards_to_csv, :upload_card_image, :gmp_list]

  def index
    redirect_to :action => :list
  end


  def list
    a=check_addon
    return false if !a
    @allow_manage = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0 or session[:acc_callingcard_manage].to_i == 1))
    @allow_read = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0))
    if @allow_read == false
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    @page_title = _('Card_groups')
    @help_link = "http://wiki.kolmisoft.com/index.php/Calling_Card_Groups"

    user_id = get_user_id()

    session[:cardgroup_search_options] ||= {}

    @search, @options = 0, {
        "s_number" => "",
        "s_pin" => "",
        "s_balance_max" => "",
        "s_balance_min" => "",
        "s_sold" => "",
        "s_caller_id" => ''
    }

    @cardgroups = Cardgroup.find(:all, :select => "cardgroups.*, COUNT(*) AS card_count", :joins => "LEFT JOIN cards ON cards.cardgroup_id = cardgroups.id", :include => [:tax], :conditions=>["cardgroups.owner_id = ? AND (cards.hidden =0 or cards is null)", user_id], :group => 'cardgroups.id')
  end

  def search
    a=check_addon
    return false if !a
    @allow_manage = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0 or session[:acc_callingcard_manage].to_i == 1))
    @allow_read = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0))
    if @allow_read == false
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    @page_title = _('Card_groups')
    @help_link = "http://wiki.kolmisoft.com/index.php/Calling_Card_Groups"

    user_id = get_user_id()
    @show_pin = !(session[:usertype] == "accountant" and session[:acc_callingcard_pin].to_i == 0)

    @page_select_params = {}
    session[:cardgroup_search_options] ||= {}

    @options = {
        "s_number" => "",
        "s_pin" => "",
        "s_balance_max" => "",
        "s_balance_min" => "",
        "s_sold" => "",
        "s_caller_id" => ''
    }
    @options.merge!(session[:cardgroup_search_options]).merge!(params.slice(*@options.keys))
    session[:cardgroup_search_options] = @options
    @page = params[:page].to_i
    @cards, @card_count = Card.search(corrected_user_id, @options, {:page => @page, :per_page => session[:items_per_page]})
    @total_pages = (@card_count / session[:items_per_page].to_f).ceil
  end

  def show
    @allow_manage = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0 or session[:acc_callingcard_manage].to_i == 1))
    @page_title = _('Card_group_details')
    @page_icon = "details.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Calling_Card_Groups"

    @cardgroup = Cardgroup.find(:first, :include => [:tariff, :lcr, :location, :tax], :conditions => ["cardgroups.id = ?", params[:id]])

    unless @cardgroup
      flash[:notice] = _("Cardgroup_not_found")
      redirect_to :action => :list and return false
    end
    check_user_for_cardgroup(@cardgroup)

    # Dialplan <-> Did association is broken: did belongs to dialplan but dialplan DOES NOT have many dids for some insane reason!
    @assigned_dids = current_user.dialplans.find(:all, :conditions => {:data1 => @cardgroup.number_length, :data2 => @cardgroup.pin_length}).inject([]) { |dids, dialplan| dids.push(dialplan.dids) }.flatten

  end

  def new
    @allow_manage = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0 or session[:acc_callingcard_manage].to_i == 1))
    unless @allow_manage
      flash[:notice] = _("You_have_no_editing_permission")
      redirect_to :controller => :callc, :action => :main and return false
    end
    @page_title = _('New_card_group')
    @page_icon = "add.png"

    if session[:tmp_new_cardgroup].nil?
      @cardgroup = Cardgroup.new
      @price_with_vat = 0
    else
      @cardgroup = session[:tmp_new_cardgroup]
      if @cardgroup.tax
        @price_with_vat = @cardgroup.price + @cardgroup.get_tax.count_tax_amount(@cardgroup.price)
      else
        @price_with_vat = @cardgroup.price
      end
    end

    user_id = get_user_id()
    user= User.find_by_id(user_id)

    if session[:tmp_new_tax].nil?
      if session[:usertype].to_s == "reseller"
        tax = user.get_tax
      else
        tax = Tax.new
        tax.assign_default_tax({}, {:save => false})
      end
    else
      tax = session[:tmp_new_tax]
    end

    check_addon

    if reseller? and !current_user.reseller_allow_providers_tariff?
      @lcrs = current_user.lcrs.find(:all, :conditions => ["id = ?", user.lcr_id], :order => "name ASC")
    else
      @lcrs = current_user.lcrs.find(:all, :order => "name ASC")
    end
    @locations = current_user.locations

    @cardgroup.tax = tax
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs= Tariff.find(:all, :conditions => "owner_id = #{user_id} #{cond}")

    if @tariffs.empty?
      flash[:notice] = _('No_tariffs_found')
      redirect_to :action => 'list' and return false
    end

    @currencies = Currency.get_active
  end

  def create
    @cardgroup = Cardgroup.new(params[:cardgroup])
    check_addon
    change_date

    price_with_vat = params[:price_with_vat].to_f
    tax = tax_from_params

    @cardgroup.tax = Tax.new(tax)
    tax_save = @cardgroup.tax.save

    @cardgroup.price = @cardgroup.tax.count_amount_without_tax(price_with_vat)
    @cardgroup.valid_from = nice_date_from_params(params[:date_from]) + " 00:00:00"
    @cardgroup.valid_till = nice_date_from_params(params[:date_till]) + " 23:59:59"
    @cardgroup.owner_id = get_user_id()
    @cardgroup.allow_loss_calls = params[:allow_loss_calls].to_i
    @cardgroup.disable_voucher = params[:disable_voucher].to_i
    if session[:usertype].to_s == "reseller" and current_user.own_providers.to_i == 0
      user= User.find_by_id(get_user_id())
      @cardgroup.lcr = Lcr.find(:all, :conditions => "id = '#{user.lcr_id}'", :order => "name ASC")[0]
    end
    if @cardgroup.save and tax_save
      session[:tmp_new_cardgroup] = nil
      session[:tmp_new_tax] = nil
      flash[:status] = _('Cardgroup_was_successfully_created')
      redirect_to :action => 'show', :id => @cardgroup.id
    else
      session[:tmp_new_cardgroup] = @cardgroup
      session[:tmp_new_tax] = @cardgroup.tax
      @cardgroup.tax.destroy if @cardgroup.tax
      @cardgroup.fix_when_is_rendering

      flash_errors_for(_('Cardgroup_was_not_created'), @cardgroup)
      redirect_to :action => 'new'
    end
  end

  def edit
    @page_title = _('Card_group_edit')
    @page_icon = "edit.png"
    @cardgroup = Cardgroup.find(:first, :include => [:tax], :conditions => ["cardgroups.id = ?", params[:id]])
    unless @cardgroup
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to :action => 'list' and return false
    end

    @cardgroup.assign_default_tax if @cardgroup.tax.nil?
    check_user_for_cardgroup(@cardgroup)

    user_id = get_user_id()
    user= User.find_by_id(user_id)

    if reseller? and !current_user.reseller_allow_providers_tariff?
      @lcrs = current_user.lcrs.find(:all, :conditions => ["id = ?", user.lcr_id], :order => "name ASC")
    else
      @lcrs = current_user.lcrs.find(:all, :order => "name ASC")
    end

    @locations = current_user.locations

    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs= Tariff.find(:all, :conditions => "owner_id = #{user_id} #{cond}")

    @price_with_vat =@cardgroup.price.to_f + @cardgroup.get_tax.count_tax_amount(@cardgroup.price.to_f).to_f

    @cardgroup.valid_from = (Date.today.to_s + " 00:00:00") if @cardgroup.valid_from.blank? or @cardgroup.valid_from.to_s == '0000-00-00 00:00:00'
    @cardgroup.valid_till = (Date.today.to_s + " 23:59:59") if @cardgroup.valid_till.blank? or @cardgroup.valid_till.to_s == '0000-00-00 00:00:00'
    @cardgroup.save

    t = @cardgroup.valid_from.to_time
    @year_from = t.year
    @month_from = t.month
    @day_from = t.day
    t = @cardgroup.valid_till.to_time
    @year_till = t.year
    @month_till = t.month
    @day_till = t.day

    #my_debug @year_till
    @currencies = Currency.get_active
    @cardgroup.fix_when_is_rendering
  end

  def update
    @cardgroup = Cardgroup.find(:first, :include => [:tax], :conditions => ["cardgroups.id = ?", params[:id]])
    unless @cardgroup
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to :action => 'list' and return false
    end
    check_user_for_cardgroup(@cardgroup)
    change_date
    @cardgroup.update_attributes(params[:cardgroup])
    @price_with_vat = price_with_vat = params[:price_with_vat].to_f

    tax = tax_from_params
    @cardgroup.get_tax.update_attributes(tax)
    @cardgroup.price = @cardgroup.get_tax.count_amount_without_tax(price_with_vat)
    @cardgroup.valid_from = session_from_date + " 00:00:00"
    @cardgroup.valid_till = session_till_date + " 23:59:59"
    @cardgroup.allow_loss_calls = params[:allow_loss_calls].to_i
    @cardgroup.disable_voucher = params[:disable_voucher].to_i

    if @cardgroup.save
      flash[:status] = _('Cardgroup_was_successfully_updated')
      redirect_to :action => 'show', :id => @cardgroup
    else
      @currencies = Currency.get_active
      flash_errors_for(_('Cardgroup_was_not_updated'), @cardgroup)
      user_id = get_user_id()
      if reseller? and !current_user.reseller_allow_providers_tariff?
        @lcrs = current_user.lcrs.find(:all, :conditions => ["id = ?", user.lcr_id], :order => "name ASC")
      else
        @lcrs = current_user.lcrs.find(:all, :order => "name ASC")
      end

      @locations = current_user.locations
      if Confline.get_value("User_Wholesale_Enabled").to_i == 0
        cond = " AND purpose = 'user' "
      else
        cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
      end
      @cardgroup.fix_when_is_rendering
      @tariffs= Tariff.find(:all, :conditions => "owner_id = #{user_id} #{cond}")
      render :action => 'edit'
    end
  end

  def destroy
    @cg.validate_before_destroy
    if @cg.respond_to?(:errors) and @cg.errors.size.to_i > 0
      flash_errors_for(_('Cardgroup_cannot_be_deleted'), @cg)
      redirect_to :action => 'list' and return false
    end

    if @cg.destroy_or_hide
      flash[:status] = _('Cardgroup_was_deleted')
      redirect_to :action => 'list'
    else
      flash_errors_for(_('Cardgroup_cannot_be_deleted'), @cg)
      redirect_to :action => 'list' and return false
    end
  end


  def cards_to_csv
    params[:file].to_s == "false" ? @file = false : @file = true
    show_pin = !(session[:usertype] == "accountant" and session[:acc_callingcard_pin].to_i == 0)
    cg = Cardgroup.find(params[:id])
    a=check_user_for_cardgroup(cg)
    return false if !a
    cards = cg.cards
    sep, dec = current_user.csv_params

    csv_string = _("Number")+sep
    if show_pin == true
      csv_string += _("Pin")+sep
    end

    if can_see_finances?
      csv_string += _("Balance")+sep+_("Sold")+sep
    end
    csv_string += _("First_use")+sep+_("Daily_charge_paid_till")
    csv_body = [csv_string]
    for card in cards
      csv_line = ['"'+card.number.to_s+'"']
      csv_line << '"'+card.pin.to_s+'"' if show_pin == true
      if can_see_finances?
        csv_line << card.balance.to_s.gsub(".", dec)
        csv_line << card.sold
      end
      csv_line << (card.first_use ? nice_date_time(card.first_use) : "")
      csv_line << (card.daily_charge_paid_till ? nice_date(card.daily_charge_paid_till) : "")
      csv_body << csv_line.join(sep)
    end

    if @file
      filename = "Cards-#{cg.name}.csv"
      send_data(csv_body.join("\n"), :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
    else
      render :text => csv_body.join("\n"), :layput => false
    end
  end

  def upload_card_image
    path = Actual_Dir + '/public/images/cards/'
    @cardgroup=Cardgroup.find_by_id(params[:id])
    unless @cardgroup
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to :action => 'show', :id => @cardgroup.id and return false
    end

    a=check_user_for_cardgroup(@cardgroup)
    return false if !a

    if params[:Card_image]
      @file = params[:Card_image]
      if @file.size > 0
        if @file.size < 524288
          @filename = sanitize_filename(@file.original_filename)
          @ext = @filename.split(".").last.downcase
          if @ext == 'jpg' or @ext == 'jpeg' or @ext == 'png' or @ext == 'gif'
            system("rm #{path}#{@cardgroup.image}")
            @filename=(@cardgroup.id).to_s + "."+@ext.to_s
            File.open(Actual_Dir + '/public/images/cards/' + @filename, "wb") do |f|
              f.write(params[:Card_image].read)
            end
            @cardgroup.image = @filename
            @cardgroup.save
            flash[:status] = _('Card_image_uploaded')
          else
            flash[:notice] = _('Not_a_picture')
          end
        else
          flash[:notice] = _('Image_to_big_max_size_500kb')
        end
      else
        flash[:notice] = _('Zero_size_file')
      end
    else
      flash[:notice] = _('Select_a_file')
    end
    redirect_to :action => 'show', :id => @cardgroup.id and return false
  end


  def loss_calls
    @page_title = _('Loss_calls')
    @page_icon = "call.png"

    check_addon

    user_id = get_user_id()
    change_date

    @search_cardgroup = -1
    @search_cardgroup = params[:s_cardgroup] if params[:s_cardgroup]

    @cgs = Cardgroup.find(:all, :conditions => "owner_id = '#{user_id}'", :order => "name Asc")
    # MorLog.my_debug @cgs.size
    cond = ""
    if @search_cardgroup.to_i != -1
      cond += " AND cards.cardgroup_id = '#{@search_cardgroup.to_i}' "
    end


    sql = "SELECT cards.*, cardgroups.price, calls.calldate, calls.dst, calls.user_price FROM cards
    JOIN calls ON (calls.card_id = cards.id)
    JOIN cardgroups ON (cards.cardgroup_id = cardgroups.id)
    WHERE calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND cards.balance < '0' AND cards.owner_id = '#{user_id}' #{cond}
    ORDER BY cards.id , calldate ASC "

    #MorLog.my_debug "_______________________________(sql)______________________________________________"
    # MorLog.my_debug sql
    price = 0.to_f
    card_id = 0
    @cards_calls = Card.find_by_sql(sql)
    @cards_callsv = []
    @c_c = @cards_calls
    @cards_calls = []
    i=0
    @t_cards = 0
    @t_price = 0.to_f
    for call in @c_c

      if card_id.to_i == call.id.to_i
        price += call.user_price.to_f
        if price.to_f >= call.price.to_f
          @t_price += call.user_price.to_f
          # MorLog.my_debug " Pridejo #{call.id}, nes #{price.to_i} >= #{call.price.to_i}"
          @cards_callsv << call
        end
      else
        card_id = call.id
        price = 0.to_f
        @t_cards +=1
        price += call.user_price.to_f
        if price.to_f >= call.price.to_f
          @t_price += call.user_price.to_f

          #MorLog.my_debug " Pridejo #{call.id}, nes #{price.to_i} >= #{call.price.to_i}"
          @cards_callsv << call
        end
      end
      i=i+1
    end

    # MorLog.my_debug "________________________(masyvas)__________________________________"
    #MorLog.my_debug @cards_callsv.to_yaml


  end


  def gmp_list
    @page_title = _('Ghost_minutes_percents')
    @page_icon = "view.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Ghost_Minute_Percent_per_Destination_for_Calling_Card_Group"

    @cg=Cardgroup.find_by_id(params[:id])
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to :action => 'show', :id => @cg.id and return false
    end

    a=check_user_for_cardgroup(@cg)
    return false if !a

    @gmps = CcGhostminutepercent.find(:all, :conditions => "cardgroup_id = '#{@cg.id}'")

  end


  def gmp_create

    @cg = Cardgroup.find_by_id(params[:cg].to_i)

    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to :action => 'list' and return false
    end

    prefix = params[:prefix].to_s.strip
    if prefix.length == 0
      flash[:notice] = _('Empty_prefix')
      redirect_to :action => 'gmp_list', :id => @cg.id and return false
    end

    percent = params[:percent].to_f
    if percent == 0
      flash[:notice] = _('Bad_percent')
      redirect_to :action => 'gmp_list', :id => @cg.id and return false
    end

    old_gmp = CcGhostminutepercent.find(:first, :conditions => "cardgroup_id = '#{@cg.id}' AND prefix = '#{prefix}' AND percent = '#{percent}'")
    if old_gmp
      flash[:notice] = _('Duplicate_record')
      redirect_to :action => 'gmp_list', :id => @cg.id and return false
    end

    gmp = CcGhostminutepercent.new
    gmp.cardgroup_id = @cg.id
    gmp.prefix = prefix
    gmp.percent = percent
    gmp.save

    flash[:status] = _('Record_created')
    redirect_to :action => 'gmp_list', :id => @cg.id

  end


  def gmp_destroy

    gmp = CcGhostminutepercent.find_by_id(params[:id].to_i)
    unless gmp
      flash[:notice] = _('Record_not_found')
      redirect_to :action => 'list' and return false
    end

    @cg = gmp.cardgroup
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to :action => 'list' and return false
    end

    gmp.destroy

    flash[:status] = _('Record_deleted')
    redirect_to :action => 'gmp_list', :id => @cg.id

  end


  def gmp_edit

    @page_title = _('Ghost_minutes_percent_edit')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Ghost_Minute_Percent_per_Destination_for_Calling_Card_Group"

    @gmp = CcGhostminutepercent.find_by_id(params[:id].to_i)
    unless @gmp
      flash[:notice] = _('Record_not_found')
      redirect_to :action => 'list' and return false
    end

    @cg = @gmp.cardgroup
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to :action => 'list' and return false
    end

  end


  def gmp_update

    @gmp = CcGhostminutepercent.find_by_id(params[:id].to_i)
    unless @gmp
      flash[:notice] = _('Record_not_found')
      redirect_to :action => 'list' and return false
    end

    @cg = @gmp.cardgroup
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to :action => 'list' and return false
    end

    prefix = params[:prefix].to_s.strip
    if prefix.length == 0
      flash[:notice] = _('Empty_prefix')
      redirect_to :action => 'gmp_list', :id => @cg.id and return false
    end

    percent = params[:percent].to_i
    if percent == 0
      flash[:notice] = _('Bad_percent')
      redirect_to :action => 'gmp_list', :id => @cg.id and return false
    end

    old_gmp = CcGhostminutepercent.find(:first, :conditions => "cardgroup_id = '#{@cg.id}' AND prefix = '#{prefix}' AND percent = '#{percent}'")
    if old_gmp
      flash[:notice] = _('Duplicate_record')
      redirect_to :action => 'gmp_list', :id => @cg.id and return false
    end

    @gmp.prefix = prefix
    @gmp.percent = percent
    @gmp.save

    flash[:notice] = _('Record_updated')
    redirect_to :action => 'gmp_list', :id => @cg.id

  end

  def cardgroups_stats
    @page_title = _('Cardgroup_Stats')
    check_addon
    change_date

    session[:card_groups_stats_options] ? @options = session[:card_groups_stats_options] : @options = {}

    #params[:page]          ? @options[:page] = params[:page].to_i                   : (@options[:page] = 1 if !@options[:page] or params[:page].to_i <= 0)
    params[:s_only_first_use] ? @options[:s_only_first_use] = params[:s_only_first_use].to_i : (params[:clean] or !session[:card_groups_stats_options]) ? @options[:s_only_first_use] = 0 : @options[:s_only_first_use] = session[:card_groups_stats_options][:s_only_first_use]

    user_id = get_user_id()

    arr = {:joins => 'LEFT JOIN cards ON (cards.cardgroup_id = cardgroups.id)', :conditions => ["cardgroups.owner_id = ?", user_id]}
    sum_if = "SUM(IF(cards.first_use IS NOT NULL AND (cards.first_use BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'),"
    if @options[:s_only_first_use].to_i == 1
      arr[:select]="COUNT(cards.id) as c_id,  #{sum_if}1,0)) as c_siz, #{sum_if}cards.balance,0)) as sum_b"
    else
      arr[:select]="COUNT(cards.id) as c_id,  #{sum_if}1,0)) as c_siz, SUM(balance) as sum_b"
    end
    @cg_total = Cardgroup.find(:all, arr)
    arr[:select]="cardgroups.id, cardgroups.name,  " + arr[:select]
    arr[:group]='cardgroups.id'
    @cgs = Cardgroup.find(:all, arr)
  end


  def aggregate
    @page_title = _('Aggregate')
    change_date
    user_id = get_user_id()

    #2011.11.18 #3047 reseller doesnt have rights to view callcards/aggregate,
    #cant find any link from menu to link to this page and  acording to ticket
    #he shouldnt. but theres some doubt because code looks like he could
    #2012.04.04 #5379 apprarently rs pro should be able to see this page if he 
    #has cc addon enabled
    #2012.05.15 me again. seems like any reseller with calling cards addon should 
    #have rights to view this page
    if current_user.usertype.include?('reseller') and not calling_cards_active?
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

    #if we have some options preset in session we can retreave them if not new options hash is created.
    session[:aggregate_cards_list_options] ? @options = session[:aggregate_cards_list_options] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:destination_grouping] ? @options[:destination_grouping] = params[:destination_grouping].to_i : (@options[:destination_grouping] = 1 if !@options[:destination_grouping])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "direction" if !@options[:order_by])

    params[:cardgroup] ? @options[:cardgroup] = params[:cardgroup] : (@options[:cardgroup] = "any" if !@options[:cardgroup])
    params[:prefix] ? @options[:prefix] = params[:prefix].gsub(/[^0-9]/, "") : (@options[:prefix] = "" if !@options[:prefix])

    @options[:order] = Call.calls_order_by(params, @options)
    @cardgroups = Cardgroup.find(:all, :include => [:tax], :conditions => ["owner_id = ?", user_id])

    @options[:csv] = params[:csv].to_i
    @options[:from]= session_from_datetime
    @options[:till]= session_till_datetime
    @options[:user_id]=user_id

    if params[:csv].to_i == 1
      session[:aggregate_cards_list_options] = @options
      settings_owner_id = (["reseller", "admin"].include?(session[:usertype]) ? session[:user_id] : session[:owner_id])
      @options[:collumn_separator] = Confline.get_csv_separator(settings_owner_id)
      @options[:current_user] = current_user
      filename = Call.cardgroup_aggregate(@options.merge({:test => params[:test]}))
      filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
      if filename
        filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_f)
        if params[:test].to_i != 1
          send_file(filename)
        else
          render :text => filename
        end
      else
        flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
        redirect_to :controller => :callc, :action => :main and return false
      end
    else
      @result_full = Call.cardgroup_aggregate(@options)
      @result = []
      @total_calls = @result_full.size
      # calculate total values of dataset.
      @total = {:duration => 0, :user_price => 0, :provider_price => 0, :total_calls => 0, :asr => 0, :acd => 0, :answered_calls => 0, :profit => 0, :margin => 0, :markup => 0}
      @result_full.each { |row|
        @total[:duration] += row.duration.to_f
        @total[:total_calls] += row.total_calls.to_i
        @total[:answered_calls] += row.answered_calls.to_i
        @total[:user_price] += row.user_price.to_f
        @total[:provider_price] += row.provider_price.to_f
        @total[:profit] += row.user_price.to_f - row.provider_price.to_f
      }
      @total[:total_calls] == 0 ? @total[:asr] = 0 : @total[:asr] = @total[:answered_calls].to_f/@total[:total_calls].to_f*100
      @total[:answered_calls] == 0 ? @total[:acd] = 0 : @total[:acd] = @total[:duration].to_f / @total[:answered_calls].to_f
      @total[:margin] = ((@total[:user_price] - @total[:provider_price]) / @total[:user_price]) * 100 if @total[:provider_price].to_f != 0.to_f
      @total[:markup] = ((@total[:user_price] / @total[:provider_price]) * 100) - 100 if @total[:provider_price].to_f != 0.to_f

      # fetch required number of items.
      @result = []
      @total_pages = (@total_calls.to_f / session[:items_per_page].to_f).ceil
      @options[:page] = @total_pages if @options[:page] > @total_pages
      start = session[:items_per_page]*(@options[:page]-1)
      (start..(start+session[:items_per_page])-1).each { |i|
        @result << @result_full[i] if @result_full[i]
      }
      session[:aggregate_cards_list_options] = @options
    end
  end

  private

  def check_user_for_cardgroup(cardgroup)
    if session[:usertype].to_s == "accountant"
      if cardgroup.owner_id != 0 or session[:acc_callingcard_manage].to_i == 0
        dont_be_so_smart
        redirect_to(:controller => "cardgroups", :action => "list") and return false
      end
    end

    if session[:usertype].to_s == "reseller"
      if cardgroup.owner_id != session[:user_id] or session[:res_calling_cards].to_i != 2
        MorLog.my_debug("Redirect")
        dont_be_so_smart
        redirect_to :controller => "cardgroups", :action => "list" and return false
        MorLog.my_debug("post_check")
      end
    end

    if session[:usertype].to_s == "admin"
      if cardgroup.owner_id != session[:user_id]
        dont_be_so_smart
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end
    a=check_addon
    return false if !a
    return true
  end

  def get_user_id()
    user_id = session[:user_id]
    user_id = 0 if session[:usertype].to_s == "accountant"
    return user_id
  end

  def check_addon
    if !calling_cards_active? or (session[:res_calling_cards].to_i != 2 and session[:usertype] == "reseller") or (session[:acc_callingcard_manage].to_i == 0 and session[:usertype] == "accountant")
      MorLog.my_debug("Redirect:  from check_addon")
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    else
      return true
    end
  end

  def find_card_group
    @cg = Cardgroup.includes([:tariff, :lcr,:location, :tax]).where(['cardgroups.id=? and cardgroups.hidden = 0',params[:id]]).first
    unless @cg
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to :action => 'list' and return false
    end
    check_user_for_cardgroup(@cg)
  end

end
