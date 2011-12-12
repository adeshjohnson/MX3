require 'pdf/wrapper'

class CcshopController < ApplicationController

  #before_filter :cdr2calls, :check_localization
  before_filter :check_localization
  before_filter :check_calingcards_enabled
  before_filter :check_authentication, :only => [:card_details, :rates, :call_list, :speeddials, :speeddial_add_new, :speeddial_edit, :speeddial_update, :speeddial_destroy]
  before_filter :find_card, :only => [:card_details, :rates]
  before_filter :find_tariff, :only => [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_csv, :generate_personal_wholesale_rates_pdf]
  before_filter :check_paypal, :only =>[:display_cart, :checkout, :empty_cart, :remove_from_cart]

  def index
    list
    render :action => 'list'
  end

  def list
    @page_title = _('Cards')
    join_sql = "LEFT JOIN (SELECT cardgroup_id, count(*) AS 'not_sold_count' FROM cards where sold = 0 GROUP BY cardgroup_id) AS not_sold ON cardgroups.id = not_sold.cardgroup_id"
    session[:ccshop_display_paypal] = Confline.get_value("Paypal_Enabled", 0)
    if session[:ccshop_display_paypal].to_i == 1
      @cardgroups = Cardgroup.find(:all,:include => [:tax], :joins => join_sql,:conditions => "owner_id = 0 AND not_sold_count > 0", :order => "name ASC")
    end
    session[:default_currency] = Currency.find(1).name
  end


  def try_to_login
    if session[:cclogin] == true
      redirect_to :controller => "ccshop", :action => "index" and return false
    end

    if CC_Single_Login == 1
      card = Card.find(:first, :include => [:cardgroup], :conditions => ["CONCAT(cards.number, cards.pin) = ?", params["login"]])
    else
      card = Card.find(:first, :include => [:cardgroup], :conditions => ["cards.number = ? AND cards.pin = ?",params["login_num"],params["login_pin"]])
    end

    if card
      session[:card_id] = card.id
      session[:card_number] = card.number
      session[:nice_number_digits] = Confline.get_value("Nice_Number_Digits", 0).to_i
      session[:cclogin] = true
      session[:items_per_page] = Confline.get_value("Items_Per_Page", 0).to_i
      session[:default_currency] = Currency.find(1).name
      session[:show_currency] = session[:default_currency]
      flash[:notice] = _('login_succesfull')
      redirect_to :controller => "ccshop", :action => "card_details" and return false
    else
      flash[:notice] = _('bad_cc_login')
      redirect_to :controller => "ccshop", :action => "index" and return false
    end
  end


  def logout
    session[:cclogin] = false
    session[:card_id] = nil
    session[:card_number] = nil
    flash[:status] = _('logged_off')
    redirect_to :controller => "ccshop", :action => "index" and return false
  end

  ############# MENU ####################


  def card_details
    @page_title = _('Card')
    @cg = @card.cardgroup
  end

  def call_list
    @page_title = _('Calls')
    @card = Card.find(:first,:include=> [:cardgroup, :calls], :conditions => ["cards.id = ?", session[:card_id]])
    @calls = @card.calls
    @cg = @card.cardgroup
    @total_billsec = 0
    @total_price = 0
    for call in @calls do
      @total_billsec += call.billsec.to_i
      @total_price += call.user_price.to_f
    end
    @total_price_with_vat = @total_price + @cg.get_tax.count_tax_amount(@total_price)
  end

  ############# CART ####################



  def add_to_cart
    cg = Cardgroup.find(:first,:include => [:tax], :conditions => ["cardgroups.id = ? AND cardgroups.owner_id = 0",params[:id]])
    @cart = find_cart
    params[:cards] ? amount = params[:cards][:amount].to_i : amount = 0
    success = true
    if amount.to_i > 0
      for i in 1..amount.to_i
        success = @cart.add_product(cg)
      end
    end
    if success
      flash[:status] = _('Card_added') + ": " + cg.name
    else
      flash[:status] = _('One_Or_More_Cards_Were_Not_Added') + ": " + cg.name
    end
    redirect_to(:action => 'display_cart')
  end


  def display_cart
    @page_title = _('Shopping_cart')
    @page_icon = "cart.png"
    @cart = find_cart
    @items = @cart.items
    #my_debug "@cart.items.size: " + @cart.items.size.to_s
    if @items.empty?
      redirect_to_index(_('Your_cart_is_currently_empty'))
    end

    if params[:context] == :checkout
      render(:layout => false)
    end
  end


  def empty_cart
    find_cart.empty!
    flash[:status] = _('Your_cart_is_now_empty')
    redirect_to(:action => 'index')
  end

  def remove_from_cart
    @cart = find_cart
    @cart.remove_item(params[:cg_id])
    flash[:notice] = _('Item_removed_from_cart')
    redirect_to(:action => 'display_cart')
  end

  ######################## CHECKOUT ####################################
  def checkout
    @page_title = _('Checkout')
    @page_icon = "cart_edit.png"

    @paypal_return_url = Web_URL + Web_Dir + "/ccshop/paypal_complete"
    @paypal_cancel_url = Web_URL + Web_Dir + "/ccshop/display_cart"
    @paypal_ipn_url =    Web_URL + Web_Dir + "/ccshop/paypal_ipn"
    @paypal_currency = Confline.get_value("Paypal_Default_Currency")

    #	@hanza_ipn_url = "https://lt.hanza.net/cgi-bin/lip/pangalink.jsp"
    #	@hanza_return_url = "http://mor.upnet.lt/store/hanza_ipn"

    @paypal_test = Confline.get_value("PayPal_Test").to_s.to_i

    @cart = find_cart
    @items = @cart.items
    if @items.empty?
      redirect_to_index(_('Theres_nothing_in_your_cart'))
    else
      clean_orders
      @order = Ccorder.new(params[:order])
      @order.ordertype = 'unspecified'
      @order.date_added = Time.now
      @order.save
      #begin
      cclineitems = @cart.items
      cardgroups = {}
      cclineitems.each{ |cclineitem|
        cardgroups[cclineitem.cardgroup_id] ? cardgroups[cclineitem.cardgroup_id] += 1 : cardgroups[cclineitem.cardgroup_id] = 1
      }
      cardgroups.each {
        |id ,count| Cclineitem.new(:ccorder_id => @order.id, :cardgroup_id => id, :quantity => count, :price => Cardgroup.find(:first, :conditions => ["id = ?", id]).price).save
      }
      #end
    end
    @total_amount = @cart.total_price*Currency::count_exchange_rate(session[:default_currency], @paypal_currency)
  end


  def paypal_ipn
    if Confline.get_value("PayPal_Enabled", 0).to_i == 0
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end

    my_debug('paypal_ipn accessed')
    notify = Paypal::Notification.new(request.raw_post)
    #if notify.acknowledge
    paypal_email = Confline.get_value("PayPal_Email", 0).to_s
    if paypal_email == notify.business
      MorLog.my_debug("business email is valid")
      MorLog.my_debug('notify acknowledged')
      if @order = Ccorder.find(:first, :conditions => ["id = ?", notify.item_id])
        MorLog.my_debug('found order')
        @order.shipped_at = (notify.complete?) ? Time.now : nil
        @order.ordertype = 'paypal'
        #@order.amount = notify.amount.to_s
        @order.currency = notify.currency
        @order.fee = notify.fee
        @order.amount = notify.gross
        @order.transaction_id = notify.transaction_id
        @order.first_name = notify.first_name
        @order.last_name = notify.last_name
        @order.payer_email = notify.payer_email
        @order.email= notify.payer_email
        @order.residence_country = notify.residence_country
        @order.payer_status = notify.payer_status
        @order.tax = notify.tax

        #my_debug(@order.shipped_at)

        @order.save

        if notify.complete?
          Action.create_cards_action(@order)
          payment = Payment.create_cards_action(@order)
          CcInvoice.invoice_from_order(@order, payment)
        end
        if notify.reversed?
          Action.create_cards_action(@order, "card_payment_reversed")
          invoice = @order.cc_invoice
          payment = invoice.payment if invoice
          invoice.destroy if invoice
          payment.destroy if payment
        end
        MorLog.my_debug('transaction succesfully completed')
      else
        MorLog.my_debug('transaction NOT completed')
      end
    else
      MorLog.my_debug('Hack attempt: Email is not equal as paypal account email')
    end
    #    else
    #      MorLog.my_debug('notify NOT acknowledged')
    #    end
    render :nothing => true
  end


  def paypal_complete
    @page_title = _('Payment_status')
    @page_icon = "money.png"

    if params[:tx]
      session[:tx] = params[:tx]
    else
      session[:tx] = params[:txn_id]
    end
  end


  def tx_status
    @sold_cards = []
    @tx = session[:tx]
    @cart=find_cart
    if @order=Ccorder.find(:first, :conditions => [ "transaction_id = ?", @tx])
      @status = 1
      if @order.completed == 0
        # providing with items which are sold
        for item in @cart.items
          cg = item.cardgroup
          if cg
            id = cg.id

            # new card to sell
            @card = cg.groups_salable_card
            if @card
              item.card_id=@card.id  #saving additional field to recognize card later
              @sold_cards << @card
              @card.sold = 1
              @card.save
            end
          end
        end

        my_debug "@cart.items.size: " + @cart.items.size.to_s

        @order.completed = 1
        @order.cclineitems << @cart.items
        @order.save

        EmailsController::send_to_users_paypal_email(@order)

        @cart.empty!
      else
        # showing card data from db
        for item in @order.cclineitems
          card = Card.find_by_id(item.card_id)
          @sold_cards << card if card
        end
      end

    else
      @status = 0
    end

    render(:layout => false)
  end

  # before_filter
  #   find_card
  def rates
    @page_title = _('Rates')
    @page_icon = "coins.png"
    @cardgroup = @card.cardgroup
    @tariff = @cardgroup.tariff

    @Show_Currency_Selector = true
    @dgroups = Destinationgroup.find(:all, :order => "name ASC, desttype ASC")

    @st = "A"
    @st = params[:st].upcase  if params[:st]

    @page = 1
    @page = params[:page].to_i if params[:page]

    @rates = @tariff.rates_by_st(@st,0,10000)
    @total_pages = (@rates.size.to_f / session[:items_per_page].to_f).ceil
    @all_rates = @rates
    @rates = []
    @rates_cur2 = []
    @rates_free2=[]
    @rates_d=[]
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_rates.size - 1 if iend > (@all_rates.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @rates << @all_rates[i]
    end
    #----

    sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{@tariff.id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name ASC;"
    rates = Rate.find_by_sql(sql)

    exrate = Currency.count_exchange_rate(@tariff.currency, session[:show_currency])
    for rate in rates
      get_provider_rate_details(rate, exrate)
      @rates_cur2[rate.id]=@rate_cur
      @rates_free2[rate.id]=@rate_free
      @rates_d[rate.id]= @rate_increment_s
    end

    @use_lata = false
    @use_lata = true if @st == "U"

    @letter_select_header_id = @tariff.id
    @page_select_header_id = @tariff.id

    @exchange_rate = count_exchange_rate(@tariff.currency, session[:show_currency])
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], session[:show_currency])
  end

  def get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.find(:all, :conditions => "rate_id = #{rate.id.to_s}", :order => "rate DESC")
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({:exrate=>exrate, :prices=>[@rate_details[0]['rate'].to_f, @rate_details[0]['connection_fee'].to_f]})
    end
    @rate_details
  end


  # ====================== Speed dials =============================


  def speeddials
    @page_title = _('Speed_Dials')
    @page_icon = "book.png"

    @card = Card.find(:first, :conditions => ["id = ?", session[:card_id]])
    @sp = Phonebook.find(:all, :conditions => ["card_id = ?",session[:card_id]])
  end

  def speeddial_add_new
    card = Card.find(:first, :conditions => ["id = ?", session[:card_id]])
    number = params[:number]
    name = params[:name]
    speeddial = params[:speeddial]
    if speeddial.length < 2
      flash[:notice]=_('Speeddial_can_only_be_2_and_more_digits')
      redirect_to :action => 'speeddials' and return false
    end
    if number.length > 0 and name.length > 0 and speeddial.length > 0
      ph = Phonebook.new
      ph.name = name
      ph.number = number
      ph.added = Time.now
      ph.speeddial = speeddial
      ph.user_id = 0
      ph.card_id = card.id
      ph.save
      flash[:status] = _('Added')
    else
      flash[:notice] = _('Please_fill_all_fields')
    end
    redirect_to :action => 'speeddials'

  end


  def speeddial_edit
    @page_title = _('Edit_Speed_Dial')
    @page_icon = "edit.png"

    @phonebook = Phonebook.find(:first, :conditions => ["id = ? AND card_id = ?", params[:id], session[:card_id]])
    unless @phonebook
      dont_be_so_smart
      redirect_to :action => 'speeddials' and return false
    end
  end


  def speeddial_update
    @phonebook = Phonebook.find(:first, :conditions => ["id = ? AND card_id = ?", params[:id], session[:card_id]])
    unless @phonebook
      dont_be_so_smart
      redirect_to :action => 'speeddials' and return false
    end
    if params[:phonebook][:speeddial].length < 2
      flash[:notice]=_('Speeddial_can_only_be_2_and_more_digits')
      redirect_to :action => 'speeddials' and return false
    end
    if @phonebook.update_attributes(params[:phonebook])
      flash[:status] = _('Updated')
      redirect_to :action => 'speeddials'
    else
      redirect_to :action => 'speeddial_edit', :id => @phonebook.id
    end
  end

  def speeddial_destroy
    ph = Phonebook.find(:first, :conditions => ["id = ? AND card_id = ?", params[:id], session[:card_id]])
    unless ph
      dont_be_so_smart
      redirect_to :action => 'speeddials' and return false
    end
    ph.destroy
    flash[:status] = _('Deleted')
    redirect_to :action => 'speeddials'
  end

  def generate_personal_rates_pdf
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
    send_data pdf.render, :filename => "Rates-#{session[:show_currency]}.pdf", :type => "application/pdf"
  end

  def generate_personal_rates_csv
    filename = "Rates-#{session[:show_currency]}.csv"
    if testing?
      render :text => @tariff.generate_user_rates_csv(session)
    else
      send_data(@tariff.generate_user_rates_csv(session),   :type => 'text/csv; charset=utf-8; header=present',  :filename => filename)
    end
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_csv
    if testing?
      render :text => @tariff.generate_personal_wholesale_rates_csv(session)
    else
      filename = "Rates-#{(session[:show_currency]).to_s}.csv"
      send_data(@tariff.generate_personal_wholesale_rates_csv(session), :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
    end
  end

  # before_filter : tariff
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
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(rates, @tariff, nil, options)
    send_data pdf.render, :filename => "Rates-#{(session[:show_currency]).to_s}.pdf", :type => "application/pdf"
  end

  # ====================== Private =============================

  private

  def find_cart
    session[:cart] ||= Cart.new
  end

  #cleans old unspecified orders
  def clean_orders
    Ccorder.delete_all(["ordertype = 'unspecified' AND date_added < ?", Time.now - 12.hours])
  end

  def redirect_to_index(msg = nil)
    flash[:notice] = msg if msg
    redirect_to(:action => 'index')
  end

  def find_card
    @card = Card.find(:first, :include => [:cardgroup], :conditions => ["cards.id = ?",session[:card_id]])

    unless @card && @card.cardgroup
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to :controller => "ccshop", :action => "index" and return false
    end
  end

  def check_authentication
    if !session[:card_id] or session[:card_id].size == 0
      flash[:notice] = _('Must_login_first')
      redirect_to :action => 'index' and return false
    end
  end

  def find_tariff
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

  def testing?; params[:test]; end

  def check_paypal
    if Confline.get_value("Paypal_Enabled", 0).to_i == 0
      dont_be_so_smart
      redirect_to :action=>:index and return false
    end
  end
  
end
