# -*- encoding : utf-8 -*-
class CardsController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only=>[:destroy, :create, :update]
  before_filter :check_localization
  before_filter :check_calingcards_enabled
  before_filter :authorize
  before_filter :check_cc_addon
  before_filter :find_cardgruop, :only=>[:card_buy_finish, :card_buy, :import_csv, :create, :new, :card_payment_finish, :list, :act, :act_confirm, :act2, :card_pay, :card_payment_status]
  before_filter :find_card, :only=>[:card_active, :card_buy_finish, :card_buy, :payments, :destroy, :update, :edit, :card_pay, :card_payment_status, :card_payment_finish, :show]
  before_filter :check_distrobutor, :only=>[:create, :update]
  before_filter :check_distrobutor_cards, :only=>[:user_list, :card_active, :bullk_for_activate, :bulk_confirm, :card_active_bulk]

  @@card_view = [:index, :list]
  @@card_edit = [:new, :import_csv, :act, :edit, :destroy]
  before_filter(:only =>  @@card_view+@@card_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@card_view, @@card_edit, {:role => "accountant", :right => :acc_callingcard_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  @@card_view_res = []
  @@card_edit_res = [:new, :import_csv, :act, :index, :list]
  before_filter(:only =>  @@card_view_res+@@card_edit_res) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@card_view_res, @@card_edit_res, {:role => "reseller", :right => :res_calling_cards, :ignore => true})
    c.instance_variable_set :@allow_read_res, allow_read
    c.instance_variable_set :@allow_edit_res, allow_edit
    true
  }

  def index
    #CardgroupsController::list
    redirect_to :controller=>"cardgroups", :action => 'list' and return false
  end

  def list
    @page_title = _('Cards')

    @show_pin = !(session[:usertype] == "accountant" and session[:acc_callingcard_pin].to_i == 0)
    @allow_manage = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0 or session[:acc_callingcard_manage].to_i == 1))
    @allow_read = !(session[:usertype] == "accountant" and (session[:acc_callingcard_manage].to_i == 0))
    session[:cards_list_options] ? @options = session[:cards_list_options] : @options = {}

    # search paramaters
    params[:page]          ? @options[:page] = params[:page].to_i                   : (@options[:page] = 1 if !@options[:page] or params[:page].to_i <= 0)
    params[:s_number]      ? @options[:s_number] = params[:s_number].to_s           : (params[:clean] or !session[:cards_list_options])? @options[:s_number] = ""      : @options[:s_number] = session[:cards_list_options][:s_number]
    params[:s_name]      ? @options[:s_name] = params[:s_name].to_s           : (params[:clean] or !session[:cards_list_options])? @options[:s_name] = ""      : @options[:s_name] = session[:cards_list_options][:s_name]
    params[:s_pin]         ? @options[:s_pin] = params[:s_pin].to_s                 : (params[:clean] or !session[:cards_list_options])? @options[:s_pin] = ""         : @options[:s_pin] = session[:cards_list_options][:s_pin]
    params[:s_sold]        ? @options[:s_sold] = params[:s_sold].to_s               : (params[:clean] or !session[:cards_list_options])? @options[:s_sold] = "all"     : @options[:s_sold] = session[:cards_list_options][:s_sold]
    params[:s_balance_min] ? @options[:s_balance_min] = params[:s_balance_min].to_s : (params[:clean] or !session[:cards_list_options])? @options[:s_balance_min] = "" : @options[:s_balance_min] = session[:cards_list_options][:s_balance_min]
    params[:s_balance_max] ? @options[:s_balance_max] = params[:s_balance_max].to_s : (params[:clean] or !session[:cards_list_options])? @options[:s_balance_max] = "" : @options[:s_balance_max] = session[:cards_list_options][:s_balance_max]
    params[:search_on]     ? @options[:search_on] = params[:search_on].to_i         : (@options[:search_on] = 0 if !@options[:search_on])
    params[:s_callerid]   ? @options[:s_callerid] = params[:s_callerid].to_s     : (params[:clean] or !session[:cards_list_options])? @options[:s_callerid] = ""   : @options[:s_callerid] = session[:cards_list_options][:s_callerid]
    params[:s_language]        ? @options[:s_language] = params[:s_language].to_s               : (params[:clean] or !session[:cards_list_options])? @options[:s_language] = _('All')     : @options[:s_language] = session[:cards_list_options][:s_language]
    params[:s_user]        ? @options[:s_user] = params[:s_user].to_i               : (params[:clean] or !session[:cards_list_options])? @options[:s_user] = -1     : @options[:s_user] = session[:cards_list_options][:s_user]

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (params[:clean] or !session[:cards_list_options])? @options[:order_by] = "number" : @options[:order_by] = session[:cards_list_options][:order_by]

    cond = [ "cards.cardgroup_id = #{@cg.id}" ]; var =[]
    ["number", 'name', 'pin', 'callerid' ].each{ |col|
      add_contition_and_param_like(@options["s_#{col}".to_sym], @options["s_#{col}".intern], "#{col} LIKE ?" , cond, var)}

    add_integer_contition_and_param(@options[:s_balance_min], @options[:s_balance_min], "cards.balance >= ?" , cond, var)
    add_integer_contition_and_param(@options[:s_balance_max], @options[:s_balance_max], "cards.balance <= ?" , cond, var)


    cond << "sold = 1"  if @options[:s_sold].to_s == "yes"
    cond << "sold = 0"  if @options[:s_sold].to_s == "no"
    add_contition_and_param_not_all(@options[:s_language], @options[:s_language], "cards.language = ?" , cond, var)
    add_integer_contition_and_param_not_negative(@options[:s_user], @options[:s_user], "user_id = ?" , cond, var)
    @search = 1 if cond.size.to_i > 1

    @page = @options[:page].to_i

    @cards_all = Card.find(:all, :conditions=> [cond.join(" AND ")] +var).size.to_i

    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@cards_all.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @fpage = ((@options[:page] -1 ) * session[:items_per_page]).to_i

    order_by =  Card.get_order_by(params, @options)
    @cards = Card.find(:all, :select=>"cards.*, #{SqlExport.nice_user_sql}",
      :conditions=> [cond.join(" AND ")] +var,
      :joins=>"LEFT JOIN users ON (users.id = user_id)",
      :order=>order_by, :limit=>"#{@fpage}, #{session[:items_per_page].to_i}")

    @users = User.find_all_for_select(current_user.id)

    session[:cards_list_options] = @options
  end

  def user_list
    @page_title = _('Cards')

    session[:cards_user_list_options] ? @options = session[:cards_user_list_options] : @options = {}

    # search paramaters
    params[:page]          ? @options[:page] = params[:page].to_i                   : (@options[:page] = 1 if !@options[:page] or params[:page].to_i <= 0)
    params[:s_number]      ? @options[:s_number] = params[:s_number].to_s           : (params[:clean] or !session[:cards_list_options])? @options[:s_number] = ""      : @options[:s_number] = session[:cards_list_options][:s_number]
    params[:s_name]      ? @options[:s_name] = params[:s_name].to_s           : (params[:clean] or !session[:cards_list_options])? @options[:s_name] = ""      : @options[:s_name] = session[:cards_list_options][:s_name]
    params[:s_pin]         ? @options[:s_pin] = params[:s_pin].to_s                 : (params[:clean] or !session[:cards_list_options])? @options[:s_pin] = ""         : @options[:s_pin] = session[:cards_list_options][:s_pin]
    params[:s_balance_min] ? @options[:s_balance_min] = params[:s_balance_min].to_s : (params[:clean] or !session[:cards_list_options])? @options[:s_balance_min] = "" : @options[:s_balance_min] = session[:cards_list_options][:s_balance_min]
    params[:s_balance_max] ? @options[:s_balance_max] = params[:s_balance_max].to_s : (params[:clean] or !session[:cards_list_options])? @options[:s_balance_max] = "" : @options[:s_balance_max] = session[:cards_list_options][:s_balance_max]
    params[:s_language]        ? @options[:s_language] = params[:s_language].to_s               : (params[:clean] or !session[:cards_list_options])? @options[:s_language] = _('All')     : @options[:s_language] = session[:cards_list_options][:s_language]
    params[:s_sold]        ? @options[:s_sold] = params[:s_sold].to_s               : (params[:clean] or !session[:cards_list_options])? @options[:s_sold] = "all"     : @options[:s_sold] = session[:cards_list_options][:s_sold]

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (params[:clean] or !session[:cards_user_list_options])? @options[:order_by] = "number" : @options[:order_by] = session[:cards_user_list_options][:order_by]

    cond = [ "cards.user_id = #{current_user.id}" ]; var =[]

    ["number", 'name', 'pin' ].each{ |col|
      add_contition_and_param_like(@options["s_#{col}".to_sym], @options["s_#{col}".intern], "#{col} LIKE ?" , cond, var)}

    add_integer_contition_and_param(@options[:s_balance_min], @options[:s_balance_min], "cards.balance >= ?" , cond, var)
    add_integer_contition_and_param(@options[:s_balance_max], @options[:s_balance_max], "cards.balance <= ?" , cond, var)
    
    add_contition_and_param_not_all(@options[:s_language], @options[:s_language], "cards.language = ?" , cond, var)
    cond << "sold = 1"  if @options[:s_sold].to_s == "yes"
    cond << "sold = 0"  if @options[:s_sold].to_s == "no"

    @page = @options[:page].to_i

    @cards_all = Card.count(:conditions=> [cond.join(" AND ")] +var)

    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@cards_all.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @fpage = ((@options[:page] -1 ) * session[:items_per_page]).to_i

    order_by =  Card.get_order_by(params, @options)
    @cards = Card.find(:all,
      :conditions=> [cond.join(" AND ")] +var,
      :order=>order_by, :limit=>"#{@fpage}, #{session[:items_per_page].to_i}")


    session[:cards_user_list_options] = @options
  end


  #================ Batch_manegemant  ===============


  def act
    @page_title =  _('Batch_management')
    @page_icon = "groups.png"
    
    @users = User.find_all_for_select(current_user.id)
  end

  def act_confirm
    @page_title = _('Batch_management')
    @page_icon = "groups.png"

    @start_num = params[:start_number].to_i <= params[:end_number].to_i ? params[:start_number] : params[:end_number]
    @end_num = params[:end_number].to_i >= params[:start_number].to_i ?  params[:end_number] : params[:start_number]
    @activate = params[:activate].to_i
    @u_id = params[:user_id].to_i

    if ((@start_num.length != @cg.number_length) or (@end_num.length != @cg.number_length)) or ((@start_num.to_i == 0) or (@end_num.to_i == 0))
      flash[:notice] = _('Bad_number_length_should_be') + ": " + @cg.number_length.to_s
      redirect_to :action => 'act', :cg => @cg and return false
    end
    user_id = get_user_id()
    @list2 = Card.count(:all, :conditions => ["number >= ? and number <= ? and sold =? AND owner_id = '#{user_id}' AND cardgroup_id = ? ", @start_num, @end_num,1, @cg.id ])
    @list = Card.count(:all, :conditions => ["number >= ? and number <= ? and sold =? AND owner_id = '#{user_id}' AND cardgroup_id = ? ", @start_num, @end_num,0, @cg.id ])

    @a_name = _('Disable')  if @activate.to_i == 0
    @a_name = _('Activate') if @activate.to_i == 1
    @a_name = _('Delete')  if @activate.to_i == 2
    @a_name = _('Change_distributor')  if @activate.to_i == 4

    if @activate.to_i == 3
      @a_name = _('Buy')
      @user = User.find(:first, :include => :address, :conditions => "users.id = #{user_id}")
      real_price = Card.find(:all, :select => "sum(balance) as balance_sum", :conditions => "number >= #{@start_num} and number <= #{@end_num} and sold = 0 AND owner_id = #{session[:user_id]} AND cardgroup_id = '#{@cg.id}' ")[0].balance_sum.to_f
      @real_price = real_price.to_f * User.current.currency.exchange_rate.to_f
      @tax = @cg.get_tax
      @taxes = @tax.applied_tax_list(@real_price)
      @total_tax_name = @tax.total_tax_name
    end
  end

  def act2

    start_num = params[:start].to_i <= params[:end].to_i ? params[:start] : params[:end]
    end_num = params[:end].to_i >= params[:start].to_i ?  params[:end] : params[:start]
    action = params[:activate_i].to_i
    user_id = get_user_id()
    case(action)
    when 0:
        cards = Card.find(:all, :conditions => ["number >= ? AND number <= ? AND sold = 1 AND owner_id = ? AND cardgroup_id = ?", start_num, end_num, user_id,  @cg.id])
      for card in cards
        card.sold = 0
        card.save
      end
    when 2:
        cards_deleted = 0
      cards_not_deleted = 0
      cards = Card.find(:all, :conditions => ["number >= ? AND number <= ? AND owner_id = ? AND cardgroup_id = ?", start_num, end_num, user_id,  @cg.id] )
      for card in cards
        if card.destroy_with_check
          cards_deleted += 1
        else
          cards_not_deleted += 1
        end
      end
    when 3:
        creation_time = Time.now
      list = Card.find(:all, :conditions => ["number >= ? and number <= ? and sold = 0 AND owner_id = ? AND cardgroup_id = ? ", start_num,end_num, user_id, @cg.id ])
      @email = params[:email].to_s

      gross = 0
      list.each{ |card|
        gross += card.balance
        card.sold = 1
        card.save
      }

      tax = @cg.get_tax.count_tax_amount(gross)
      currency = current_user.currency.name
      if list.size > 1
        Payment.create(:paymenttype => "manual", :amount => tax+gross, :currency => currency, :email => @email, :completed => 1, :date_added => creation_time, :shipped_at => creation_time, :fee => 0, :gross => gross, :payer_email => @email, :tax => tax, :owner_id => session[:user_id], :card => 1)
      else
        Payment.create(:paymenttype => "manual", :amount => tax+gross, :currency => currency, :email => @email, :completed => 1, :date_added => creation_time, :shipped_at => creation_time, :fee => 0, :gross => gross, :payer_email => @email, :tax => tax, :owner_id => session[:user_id], :card => 1, :user_id => list.first.id)
      end
    when 4:
        cards = Card.find(:all, :conditions => ["number >= ? AND number <= ?  AND owner_id = ? AND cardgroup_id = ?", start_num, end_num, user_id,  @cg.id])
      for card in cards
        card.user_id = params[:user].to_i
        card.save
      end
    end
    case(action)
    when 0 : flash[:status] = _('Cards_were_successfully_disabled')
    when 1 : flash[:status] = _('Cards_were_successfully_activated')
    when 2 :
        if cards_deleted == 0
        flash[:notice] = _('Cards_were_not_deleted')
      else
        flash[:status] = cards_deleted.to_s + ' ' + _('Cards_were_successfully_deleted')
        if cards_not_deleted > 0
          flash[:status] += '<br>' + cards_not_deleted.to_s + ' ' + _('Cards_were_not_deleted')
        end
      end
    when 3 : flash[:status] = _('Cards_were_successfully_bought')
    when 4 : flash[:status] = _('Distributor_changed')
    end

    redirect_to :action => 'list', :cg => @cg and return false

  end

  # ============= Card_pay ============================

  def card_pay
    @page_title = _('Add_card_payment')
    @page_icon = "money.png"

    @currs =Currency.get_active
    @user = User.find(:first, :conditions => ["users.id = ?", session[:user_id]], :include => :address)
  end

  def card_payment_status
    @page_title = _('Add_card_payment')
    @page_icon = "money.png"

    @amount = params[:amount].to_f
    @curr = params[:currency]
    @exchange_rate = count_exchange_rate(current_user.currency.name, @curr)
    if @exchange_rate == 0
      flash[:notice] = _('Currency_not_found')
      redirect_to :action => 'card_pay', :id =>params[:id], :cg=>params[:cg] and return false
    end
    @converted_amount = @amount /  @exchange_rate

    @real_amount = @cg.get_tax.count_amount_without_tax(@converted_amount)

    if @card.sold == 0
      flash[:notice] = _('Cannot_fill_unsold_Card')
      redirect_to(:action => 'card_pay', :id =>params[:id], :cg=>params[:cg]) and return false
    end
  end

  def card_payment_finish
    amount = params[:amount].to_f
    real_amount = params[:real_amount].to_f
    currency = params[:currency]

    @card.balance += real_amount
    @card.save


    paym = Payment.new
    paym.paymenttype = 'Card'
    paym.amount = amount
    paym.currency = currency
    paym.date_added = Time.now
    paym.shipped_at = Time.now
    paym.completed = 1
    paym.user_id = @card.id
    paym.card = 1
    paym.owner_id = current_user.id
    paym.save

    flash[:status] = _('Payment_added')
    redirect_to :action => 'list', :cg => @cg and return false
  end

  def show
    @show_pin = !(session[:usertype] == "accountant" and session[:acc_callingcard_pin].to_i == 0)

    @page_title = _('Card_details')
    @cg = @card.cardgroup(:include => [:tax])

    check_user_for_cardgroup(@cg)
  end

  def new
    @page_title = _('Add_cards')
    @page_icon = "add.png"
    
    @users = User.find_all_for_select(current_user.id)
  end

  def create

    start_num = params[:start_number]
    end_num = params[:end_number]

    if ((start_num.length != @cg.number_length) or (end_num.length != @cg.number_length)) or ((start_num.to_i == 0) or (end_num.to_i == 0))
      flash[:notice] = _('Bad_number_length_should_be') + ": " + @cg.number_length.to_s
      redirect_to :action => 'new', :cg => @cg and return false
    elsif end_num.to_i < start_num.to_i
      flash[:notice] = _('Bad_interval_start_and_end')
      redirect_to :action => 'new', :cg => @cg and return false
    end

    user_want_to_create = (end_num.to_i - start_num.to_i)+1
    #only 1/5 to create
    user_can_create_only = ((10**@cg.pin_length.to_i)*0.2).to_i

    if user_want_to_create >  user_can_create_only
      flash[:notice] = _('Bad_number_interval_max') + ": " + user_can_create_only.to_s + " "+ _('cards')
      redirect_to :action => 'new', :cg => @cg and return false
    else
      # call pin list generator
      pins = []
      pins = all_pins(@cg.pin_length,user_can_create_only,user_want_to_create )
      if not pins
        redirect_to :action => 'new', :cg => @cg and return false
      end
    end

    #randomly select pin from pins array to card_pins array and delete selected pin from pins array
    card_pins = []
    user_want_to_create.times do
      key = rand(pins.size)
      card_pins << pins[key]
      #pins.drop(key)- nuo ruby 1.8.7 veikia
      pins[key] = nil
      pins = pins.compact
    end

    @cards_with_errors=[]
    #start_num = start_num.to_i
    #end_num = end_num.to_i

    if (start_num) and (end_num)

      owner_id = get_user_id()

      cards_created = 0
      #for pin counter
      i = 0
      for n in start_num..end_num
        card = Card.new({:user_id=>params[:user_id], :balance=>@cg.price, :cardgroup_id=>@cg.id, :sold=>false, :number=>n, :pin=>card_pins[i], :owner_id=>owner_id, :language=>params[:card_language]})
        i += 1
        if card.save
          cards_created += 1
        else
          @cards_with_errors << card
        end
      end

      flash[:status] = _('Cards_created') + ": " + cards_created.to_s
      if @cards_with_errors.size.to_i > 0
        render :partial => "new_cards", :locals => {:cards=>@cards_with_errors, :cg=>@cg}, :layout=>true and return false
      else
        redirect_to :action => 'list', :cg => @cg and return false
      end
    else
      flash[:notice] = _('Bad_number_range')
      redirect_to :action => 'new', :cg => @cg and return false
    end

  end

  #create array of available pins
  def all_pins(length, max, user_wants)
    #get pins from db
    pins_in_db = Card.find(:all, :select => 'pin', :conditions => "Length(pin) = #{length}").map(&:pin)
    #count available pins
    available_pin_number = max - pins_in_db.size
    if available_pin_number < user_wants
      # if user wants more - message about available amount
      flash[:notice] = _('Bad_number_interval_no_pin_left') + ": " + available_pin_number.to_s + " "+ _('cards')
      return false
    else
      # generate pin list, no match
      pins = []
      random_num = (max/0.2).to_i     
      until pins.size == user_wants
        begin
          pin =  sprintf("%0#{length}d", rand(random_num))
        end while pins_in_db.include?(pin) or pins.include?(pin)
        pins <<  pin
      end    
      pins
    end  
  end


  def edit
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    @page_title = _('Edit_card')
    @page_icon = "edit.png"
    @cg = @card.cardgroup
    @users = User.find_all_for_select(current_user.id)

    check_user_for_cardgroup(@cg)
  end

  def update
    return_controller = params[:return_to_controller] if params[:return_to_controller]
    return_action = params[:return_to_action] if params[:return_to_action]
    @card_old = @card.clone
    @cg = @card.cardgroup
    result=check_user_for_cardgroup(@cg)
    return false if result == false
    #safety hack
    params[:card] = params[:card].except("sold", "balance", :sold, :balance) if params[:card]

    if @card.update_attributes(params[:card])
      if @card.pin != @card_old.pin
        Action.add_action_hash(session[:user_id], {:target_id => @card.id, :target_type => "card", :action => "card_pin_changed", :data => @card_old.pin, :data2=>@card.pin})
      end
      flash[:status] = _('Card_was_successfully_updated')
      if return_controller and return_action
        redirect_to :controller => return_controller, :action => return_action
      else
        redirect_to :action => 'show', :id => @card.id
      end
    else
      flash_errors_for(_('Card_was_not_updated'), @card)
      @users = User.find_all_for_select(current_user.id)
      render :action => 'edit'
    end
  end

  def destroy
    cg = @card.cardgroup

    a=check_user_for_cardgroup(cg)
    return false if !a

    if @card.calls.count == 0
      if not Payment.find(:first, :conditions => ["paymenttype = ? and user_id = ?", "Card", @card.id] )
        @card.destroy
        flash[:status] = _('Card_was_deleted')
        redirect_to :action => 'list', :cg => cg and return false
      else
        flash[:notice] = _('Card_cannot_be_deleted')
        redirect_to :action => 'list', :cg => cg and return false
      end
    else
      flash[:notice] = _('Card_cannot_be_deleted')
      redirect_to :action => 'list', :cg => cg and return false
    end
  end

  def payments
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    @page_title = _('Card_payments')
    @page_icon = "details.png"

    @cg = @card.cardgroup
    @payments = Payment.find(:all, :conditions => { :user_id => @card.id , :paymenttype => "Card"})

    if check_user_for_cardgroup(@cg)
      if current_user.is_not_admin? and @card.is_not_owned_by?(current_user)
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end
  end

  # ======== CSV IMPORT =================

  def import_csv

    step_names = [_('Import_cards'), _('File_upload'), _('Column_assignment'), _('Column_confirmation'), _('Analysis'), _('Create_cards')]
    params[:step] ? @step = params[:step].to_i : @step = 0
    @step = 0 if @step > step_names.size or @step < 0
    @step_name = step_names[@step]

    @page_title = _('Import_CSV') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name.to_s
    @page_icon = 'excel.png';

    @sep, @dec = nice_action_session_csv

    if @step == 0
      my_debug_time "**********import CARDS ************************"
      my_debug_time "step 0"
      session[:card_import_csv] = nil
      session[:temp_card_import_csv] = nil
      session[:import_csv_card_import_csv_options] = nil
      session[:card_import_csv2] = nil
    end

    if @step == 1
      my_debug_time "step 1"
      session[:temp_card_import_csv] = nil
      session[:card_import_csv] = nil
      if params[:file]
        @file = params[:file]
        if  @file.size > 0
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => :import_csv,  :step => 0, :cg => @cg.id and return false
          end
          if get_file_ext(@file.original_filename, "csv") == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to :action => :import_csv,  :step => 0, :cg => @cg.id and return false
          end
          @file.rewind
          file = @file.read
          session[:card_file_size] = file.size
          session[:temp_card_import_csv] = CsvImportDb.save_file("_crd_",file)
          flash[:status] = _('File_downloaded')
          redirect_to :action => :import_csv,  :step => 2, :cg => @cg.id and return false
        else
          session[:temp_card_import_csv] = nil
          flash[:notice] = _('Please_select_file')
          redirect_to :action => :import_csv,  :step => 0, :cg => @cg.id and return false
        end
      else
        session[:temp_card_import_csv] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => :import_csv,  :step => 0, :cg => @cg.id and return false
      end
    end


    if @step == 2
      my_debug_time "step 2"
      my_debug_time "use : #{session[:temp_card_import_csv]}"
      if session[:temp_card_import_csv]
        file = CsvImportDb.head_of_file("/tmp/#{session[:temp_card_import_csv]}.csv", 20).join("").to_s
        session[:file] = file
        a = check_csv_file_seperators(file, 2,2, {:cg=>@cg, :line=>0})
        if a
          @fl = CsvImportDb.head_of_file("/tmp/#{session[:temp_card_import_csv]}.csv", 1).join("").to_s.split(@sep)
          begin
            colums ={}
            colums[:colums] = [{:name=>"f_error", :type=>"INT(4)", :default=>0}, {:name=>"nice_error", :type=>"INT(4)", :default=>0},{:name=>"do_not_import", :type=>"INT(4)", :default=>0},{:name=>"changed", :type=>"INT(4)", :default=>0}, {:name=>"not_found_in_db", :type=>"INT(4)", :default=>0}, {:name=>"id", :type=>'INT(11)', :inscrement=>' NOT NULL auto_increment '}]
            session[:card_import_csv] = CsvImportDb.load_csv_into_db(session[:temp_card_import_csv], @sep, @dec, @fl, nil, colums)
          rescue Exception => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            session[:import_csv_card_import_csv_options] = {}
            session[:import_csv_card_import_csv_options][:sep] = @sep
            session[:import_csv_card_import_csv_options][:dec] = @dec
            session[:file] = File.open("/tmp/#{session[:temp_card_import_csv]}.csv", "rb").read
            CsvImportDb.clean_after_import(session[:temp_card_import_csv])
            session[:temp_card_import_csv] = nil
            redirect_to :action => "import_csv",  :step => 2, :cg => @cg.id and return false
          end
          flash[:status] = _('File_uploaded') if !flash[:notice]
        end
      else
        session[:card_import_csv] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => :import_csv,  :step => 1, :cg => @cg.id and return false
      end

    end

    if  @step > 2

      unless ActiveRecord::Base.connection.tables.include?(session[:temp_card_import_csv])
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => :import_csv,  :step => 0, :cg => @cg.id and return false
      end

      if session[:card_import_csv]

        if @step == 3
          my_debug_time "step 3"
          if params[:number_id] and params[:pin_id] and params[:number_id].to_i >= 0 and params[:pin_id].to_i >= 0
            @options = {}

            @options[:imp_number] = params[:number_id].to_i
            @options[:imp_pin] = params[:pin_id].to_i
            @options[:imp_balance] = params[:balance_id].to_i
            @options[:sep] = @sep
            @options[:dec] = @dec

            @options[:file]= session[:file]
            @options[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session[:card_import_csv]}")
            session[:card_import_csv2] = @options
            flash[:status] = _('Columns_assigned')
          else
            flash[:notice] = _('Please_Select_Columns')
            redirect_to :action => :import_csv,  :step => 2, :cg => @cg.id and return false
          end
        end

        if session[:card_import_csv2] and session[:card_import_csv2][:imp_pin] and session[:card_import_csv2][:imp_number]


          if @step == 4
            my_debug_time "step 4"
            @card_analize = @cg.analize_card_import(session[:temp_card_import_csv], session[:card_import_csv2])
            session[:card_analize] = @card_analize
          end


          if @step == 5
            my_debug_time "step 5"
            start_time = Time.now
            @card_analize = session[:card_analize]
            @run_time = 0
            begin
              @total_cards, @errors =  @cg.create_from_csv(current_user, session[:temp_card_import_csv], session[:card_import_csv2])
              flash[:status] = _('Import_completed')
              session[:temp_card_import_csv] = nil
              @run_time = Time.now - start_time
            rescue Exception => e
              flash[:notice] = _('Error')
              MorLog.log_exception(e, Time.now, 'Cards', 'csv_import')
            end
          end

        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => :import_csv,  :step => "2", :cg => @cg.id and return false
        end
      else
        flash[:notice] = _('Zero_file')
        redirect_to :controller=>"cards", :action=>"list", :cg => @cg.id and return false
      end
    end
  end


  def bad_cards
    if ActiveRecord::Base.connection.tables.include?(session[:temp_card_import_csv])
      @rows =  ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_card_import_csv]} WHERE f_error = 1")
    end
  end

=begin rdoc
 Allows admin to buy calling cards.
=end

  def card_buy
    @page_title = _('Buy_Card')
    @page_icon = "money.png"

    @email = params[:email]
    @real_price = @card.balance+@cg.get_tax.count_tax_amount(@card.balance)
    @send_invoice = params[:send_invoice]
    @total_tax_name = Confline.get_value("Total_tax_name")
  end


=begin rdoc

=end

  def card_buy_finish
    creation_time = Time.now
    if @card.sold.to_i == 1
      flash[:notice] = _("Card_is_already_sold")
      redirect_to(:action =>:card_pay, :id => @card.id, :cg => @cg.id) and return false
    end
    @email = params[:email].to_s
    invoice = CcInvoice.new(:email => @email, :owner_id => session[:user_id])
    invoice.number = CcInvoice.get_next_number(session[:user_id])
    invoice.sent_email = 0
    invoice.sent_manually = 0
    invoice.paid = 1
    invoice.created_at = creation_time
    invoice.paid_date = creation_time
    invoice.email = @email

    amount = @card.balance + @cg.get_tax.count_tax_amount(@card.balance)

    ccorder = Ccorder.new(:ordertype => "manual", :email => @email, :currency => session[:default_currency])
    ccorder.amount = amount
    ccorder.payer_email = @email
    ccorder.date_added = creation_time
    ccorder.shipped_at = creation_time
    ccorder.completed = 1
    ccorder.tax = @cg.get_tax.count_tax_amount(@card.balance)
    ccorder.gross = @card.balance
    ccorder.save
    item = Cclineitem.new(:cardgroup_id => @cg.id, :quantity => "1", :ccorder_id =>ccorder.id, :card_id => @card.id, :price => @card.balance)
    item.save

    invoice.ccorder = ccorder
    invoice.save

    paym = Payment.new
    paym.paymenttype = 'Card'
    paym.amount = amount
    paym.currency = session[:default_currency]
    paym.date_added = creation_time
    paym.shipped_at = creation_time
    paym.completed = 1
    paym.user_id = @card.id
    paym.card = 1
    paym.owner_id = current_user.id
    paym.save

    if params[:send_invoice].to_i == 1
      options = {
        :title_fontsize => 13,
        :title_fontsize1 => 16,
        :title_fontsize2 => 9,
        :address_fontsize => 8,
        :fontsize => 7,
        :tax_fontsize => 7,
        # header/address text
        :address_pos1 => 40,     :title_pos0 => 43,
        :address_pos2 => 70,     :title_pos1 => 75,
        :address_pos3 => 85,     :title_pos2 => 90,
        :address_pos4 => 100,
        :address_pos5 => 115,

        :left => 40,
        :title_left2 => 330,
        :item_line_height => 20,
        :item_line_add_y => 3,
        :item_line_add_x => 6,
        :line_y => 140,
        :length => 520,
        :item_line_start => 220,
        :lines => 20,
        :col1_x => 320,
        :col2_x => 390,
        :col3_x => 470,
        :tax_box_h => 11,
        :tax_box_text_add_y => 1,
        :tax_box_text_x => 360,
        :bank_details_step => 15
      }
      PdfGen::Generate.generate_cc_invoice(invoice, options)
      invoice.save
    end
    @card.sold = 1
    @card.save
    @card.disable_voucher
    flash[:status] = _("Card_is_sold")
    redirect_to(:action =>:list, :id => @card.id, :cg => @cg.id) and return false
  end


  def card_active

    if @card.user_id != current_user.id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    
    @card.sold = @card.sold.to_i == 1 ? 0 : 1
    @card.save
    Action.add_action_hash(current_user, {:action=>"Card activation", :data=>@card.sold.to_i, :target_id=>@card.id, :target_type=>"Card"})
    flash[:status] = @card.sold.to_i == 1 ? _("Cards_are_activated") : _("Cards_are_deactivated")
    redirect_to(:action =>:user_list) and return false

  end

  def bullk_for_activate

  end

  def bulk_confirm
    @start_num = params[:start_number].to_i <= params[:end_number].to_i ? params[:start_number] : params[:end_number]
    @end_num = params[:end_number].to_i >= params[:start_number].to_i ?  params[:end_number] : params[:start_number]
    @activate = params[:activate].to_i
   

    if ((@start_num.to_i == 0) or (@end_num.to_i == 0))
      flash[:notice] = _('Bad_number_length_should_be') 
      redirect_to :action => :bullk_for_activate and return false
    end

    @list2 = Card.count(:all, :conditions => ["number >= ? and number <= ? and sold =? AND user_id = '#{current_user.id}' ", @start_num, @end_num,1 ])
    @list = Card.count(:all, :conditions => ["number >= ? and number <= ? and sold =? AND user_id = '#{current_user.id}' ", @start_num, @end_num,0 ])

    @a_name = _('Disable')  if @activate.to_i == 0
    @a_name = _('Activate') if @activate.to_i == 1
  end

  def card_active_bulk

    start_num = params[:start].to_i <= params[:end].to_i ? params[:start] : params[:end]
    end_num = params[:end].to_i >= params[:start].to_i ?  params[:end] : params[:start]
    action = params[:activate_i].to_i

    case(action)
    when 0:
        cards = Card.find(:all, :conditions => ["number >= ? AND number <= ? AND sold = 1 AND user_id = ? ", start_num, end_num, current_user.id])
      for card in cards
        card.sold = 0
        card.save
        Action.add_action_hash(current_user, {:action=>"Card activation", :data=>card.sold.to_i, :target_id=>card.id, :target_type=>"Card"})
      end
    when 1:
        cards = Card.find(:all, :conditions => ["number >= ? AND number <= ? AND sold = 0 AND user_id = ? ", start_num, end_num, current_user.id])
      for card in cards
        card.sold = 1
        card.save
        Action.add_action_hash(current_user, {:action=>"Card activation", :data=>card.sold.to_i, :target_id=>card.id, :target_type=>"Card"})
      end
    end

    flash[:status] = action.to_i == 1 ? _('Card_is_activated') : _('Card_is_deactivated')
    redirect_to(:action =>:user_list) and return false
  end


  private
  #replaced with all_pins
  def card_pin(length)
    good = 0
    try = 0

    while good == 0 and try < 10
      number = random_digit_password(length)
      good = 1 if not Card.find(:first, :conditions => "pin = '#{number}'")
      try += 1
    end

    number = "" if try == 10

    number
  end


  def clean_value(value)
    cv = value

    #remove spaces
    cv = cv.gsub(/\s/, '')

    #remove columns from start and end
    cv = cv[1..cv.length] if cv[0,1] == "\""
    cv = cv[0..cv.length-2] if cv[cv.length-1,1] == "\""

    cv
  end

  def get_user_id()
    if session[:usertype].to_s == "accountant"
      user_id = 0
    else
      user_id = session[:user_id]
    end
    return user_id
  end
=begin
 Checks if reseller or accounant is allowed to edit cardgroups.
=end
  def check_user_for_cardgroup(cardgroup)
    if session[:usertype].to_s == "accountant"
      if cardgroup.owner_id != 0 or session[:acc_callingcard_manage].to_i == 0
        dont_be_so_smart
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end

    if session[:usertype].to_s == "reseller"
      if cardgroup.owner_id != session[:user_id] or session[:res_calling_cards].to_i != 2
        dont_be_so_smart
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end

    if session[:usertype].to_s == "admin"
      if cardgroup.owner_id != session[:user_id]
        dont_be_so_smart
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end

    return true
  end
=begin

=end
  def check_cc_addon
    unless cc_active?
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def find_cardgruop
    @cg = Cardgroup.find(:first, :include => [:tax], :conditions => ["cardgroups.id = ?", params[:cg]])
    unless @cg
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to :controller=>"callc", :action => 'main' and return false
    end

    result = check_user_for_cardgroup(@cg)
    return false if result == false
  end

  def find_card
    @card = Card.find(:first, :conditions=>{:id=>params[:id]}, :include => [:cardgroup, :user])
    unless @card
      flash[:notice] = _('Card_was_not_found')
      redirect_to :controller=>"cardgroups", :action => 'list' and return false
    end
  end

  def check_distrobutor
    if params[:card] and params[:card][:user_id]
      dis = User.find(:first, :conditions=>{:id=>params[:card][:user_id]})
      if current_user.usertype == 'reseller'
        if  dis and  dis.id != current_user.id and dis.owner_id != correct_owner_id
          dont_be_so_smart
          redirect_to :controller => "callc", :action => "main" and return false
        end
      else
        if  dis and dis.owner_id != correct_owner_id
          dont_be_so_smart
          redirect_to :controller => "callc", :action => "main" and return false
        end
      end
    end
  end


  def check_distrobutor_cards
    if !current_user.cards or current_user.cards.size.to_i == 0
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end
end
