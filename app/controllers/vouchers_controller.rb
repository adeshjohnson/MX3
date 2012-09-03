# -*- encoding : utf-8 -*-
class VouchersController < ApplicationController
  layout "callc"

  before_filter :check_post_method, :only => [:invoice_delete]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_if_can_see_finances, :only => [:vouchers, :vouchers_list_to_csv, :voucher_new, :voucher_create, :voucher_delete,]
  before_filter :find_voucher, :only => [:voucher_pay]
  before_filter { |c| c.instance_variable_set :@allow_read, true
  c.instance_variable_set :@allow_edit, true
  }
  @@voucher_view = [:vouchers, :vouchers_list_to_csv]
  @@voucher_edit = [:vouchers_new, :vouchers_create, :voucher_delete, :bulk_management]
  before_filter(:only => @@voucher_view+@@voucher_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@voucher_view, @@voucher_edit, {:role => "accountant", :right => :acc_vouchers_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }
  before_filter :find_vouchers, :only => [:voucher_delete, :voucher_active]

  # ============= V O U C H E R S ====================

  def vouchers
    @page_title = _('Vouchers')

    @default = {:page => 1, :s_usable => "all", :s_active => "all", :s_number => "", :s_tag => "", :s_credit_min => "", :s_credit_max => "", :s_curr => "", :s_use_date => "", :s_active_till => ""}
    session[:vouchers_vouchers_options] ? @options = session[:vouchers_vouchers_options] : @options = @default

    # search

    if params[:clean]
      @options = @default
    else
      @options[:page] = params[:page].to_i if params[:page]
      @options[:s_usable] = params[:s_usable].to_s if params[:s_usable]
      @options[:s_usable] = params[:s_usable].to_s if params[:s_usable]
      @options[:s_active] = params[:s_active].to_s if params[:s_active]
      @options[:s_number] = params[:s_number].to_s if params[:s_number]
      @options[:s_tag] = params[:s_tag].to_s if params[:s_tag]
      @options[:s_credit_min] = params[:s_credit_min].to_s if params[:s_credit_min]
      @options[:s_credit_max] = params[:s_credit_max].to_s if params[:s_credit_max]
      @options[:s_curr] = params[:s_curr].to_s if params[:s_curr]
      @options[:s_use_date] = params[:s_use_date].to_s if params[:s_use_date]
      @options[:s_active_till] = params[:s_active_till].to_s if params[:s_active_till]
    end

    cond = ['vouchers.id > 0']
    var = []

    if @options[:s_active].to_s.downcase != 'all'
      if @options[:s_active].to_s == 'yes'
        cond << "vouchers.active = 1"
      else
        cond << "vouchers.active = 0"
      end
    end

    if @options[:s_usable].to_s.downcase != 'all'
      is_active = "(NOT ISNULL(use_date) OR active_till < ?)"

      if @options[:s_usable].to_s == 'yes'
        cond << "(NOT (#{is_active}) AND active = 1)"
      else
        cond << "NOT (NOT (#{is_active}) AND active = 1)"
      end
      var << current_user.user_time(Time.now)
    end

    ["number", "tag"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], "%"+@options["s_#{col}".intern].to_s+"%", "vouchers.#{col} LIKE ?", cond, var) }

    ["use_date", "active_till"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "vouchers.#{col} LIKE ?", cond, var) }

    if !@options[:s_credit_min].blank?
      cond << "credit_with_vat >= ?"; var << @options[:s_credit_min]
    end

    if !@options[:s_credit_max].blank?
      cond << "credit_with_vat <= ?"; var << @options[:s_credit_max]
    end

    if !@options[:s_curr].blank?
      cond << "currency = ?"; var << @options[:s_curr]
    end

    @total_vouchers = Voucher.count(:all, :conditions => [cond.join(" AND ")]+var, :order => "use_date DESC, active_till ASC")
    MorLog.my_debug("TW: #{@total_vouchers}")
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@total_vouchers.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @vouchers = Voucher.find(:all, :include => [:tax, :user], :conditions => [cond.join(" AND ")]+var, :order => "use_date DESC, active_till ASC", :limit => "#{@fpage}, #{session[:items_per_page].to_i}")

    @search = 0
    @search = 1 if cond.length > 0

    @use_dates = Voucher.get_use_dates
    @active_tills = Voucher.get_active_tills
    @currencies = Voucher.get_currencies

    session[:vouchers_vouchers_options] = @options

    if params[:csv] and params[:csv].to_i > 0
      sep = Confline.get_value("CSV_Separator", 0).to_s
      dec = Confline.get_value("CSV_Decimal", 0).to_s

      csv_string = _("Active")+sep+_("Number")+sep+_("Tag")+sep+_("Credit")+sep + _("Credit_with_VAT")+sep + _("Currency")+sep + _("Use_date")+sep + _("Active_till")+sep + _("User")
      csv_string += "\n"
      for v in @vouchers
        # credit= nice_number v.get_tax.count_amount_without_tax(v.credit_with_vat)
        user = v.user
        active = 1
        active = 0 if v.use_date
        active = 0 if v.active_till.to_s < Time.now.to_s
        user ? nuser = nice_user(user) : nuser = ""

        csv_string += "#{active.to_s}#{sep}#{v.number.to_s}#{sep}#{v.tag.to_s}#{sep}"
        if can_see_finances?
          csv_string += "#{nice_number(v.count_credit_with_vat).to_s.gsub(".", dec).to_s}#{sep}#{nice_number(v.credit_with_vat).to_s.gsub(".", dec).to_s}#{sep}#{v.currency}#{sep}"
        end
        csv_string += "#{nice_date_time v.use_date}#{sep}#{nice_date(v.active_till).to_s}#{sep}#{nuser}"
        csv_string +="\n"
      end

      filename = "Vouchers.csv"
      if params[:test].to_i == 1
        render :text => csv_string
      else
        send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      end
    end

  end

  def voucher_new
    @page_title = _('Add_vouchers')
    @page_icon = "add.png"
    @currencies = Currency.get_active
    @tax = Confline.get_default_tax(session[:user_id])
    @amaunt = ""
    @credit = ""
    @tag = ""
    @curr = ""
  end

  def vouchers_create
    @page_title = _('New_vouchers')
    @page_icon = "add.png"
    tax = tax_from_params
    change_date_from

    credit = params[:credit]

    @vouchers = []

    if credit.to_d <= 0 or session_from_date.to_date <= Time.now.to_date
      @amaunt = params[:amount_total]
      @credit = params[:credit]
      @tag = params[:tag]
      @curr = params[:currency]
      @currencies = Currency.get_active
      @tax = Tax.new(tax)
      if credit.to_d <= 0
        flash[:notice] = _('Please_enter_credit')
        render :action => 'voucher_new' and return false
      end
      if session_from_date.to_date <= Time.now.to_date
        flash[:notice] = _('Time_should_be_in_future')
        render :action => 'voucher_new' and return false
      end
    end

    amount = params[:amount]

    if amount == "one"
      #one voucher
      v = Voucher.new
      v.number = voucher_number(confline("Voucher_Number_Length").to_i)
      v.tag = Time.now.strftime("%Y%m%d%H%M%S")
      v.tag = params[:tag] if params[:tag].length > 0
      v.credit_with_vat = params[:credit].to_d
      v.currency = params[:currency]
      v.active_till = session_from_date
      v.user_id = -1
      v.save
      v.tax = Tax.new(tax)
      v.tax.save
      if  v.save
        flash[:status] = _('Voucher_was_created')
      end
      @vouchers << v
    else
      #many vouchers
      total = params[:amount_total]

      if total.to_i <= 0
        @amaunt = params[:amount_total]
        @credit = params[:credit]
        @tag = params[:tag]
        @curr = params[:currency]
        @currencies = Currency.get_active
        @tax = Tax.new(tax)
        flash[:notice] = _('Please_enter_amount')
        render :action => 'voucher_new' and return false
      end

      for i in 1..total.to_i
        v = Voucher.new
        v.number = voucher_number(confline("Voucher_Number_Length").to_i)
        v.tag = Time.now.strftime("%Y%m%d%H%M%S")
        v.tag = params[:tag] if params[:tag].length > 0
        v.credit_with_vat = params[:credit].to_d
        v.currency = params[:currency]
        v.active_till = session_from_date
        v.user_id = -1
        v.tax = Tax.new(tax)
        v.tax.save
        v.save
        @vouchers << v
      end
      flash[:status] = _('Vouchers_was_created')
    end
  end

  def voucher_use
    @page_title = _('Voucher')

    @user = current_user

    if current_user.vouchers_disabled_till > Time.now
      flash[:notice] = _('Vouchers_disabled_till') + ": " + nice_date_time(current_user.vouchers_disabled_till)
      redirect_to :controller => "callc", :action => 'main'
    end

    session[:voucher_attempt] = 0 if session[:voucher_attempt] >= Confline.get_value("Voucher_Attempts_to_Enter").to_i and current_user.vouchers_disabled_till < Time.now + confline("Voucher_Disable_Time").to_i.minutes

  end


  def voucher_status
    @page_title = _('Voucher')

    @number = params[:number]
    @voucher = Voucher.find(:first, :conditions => ["number = ?", @number])
    unless @voucher
      flash[:notice] = _('Voucher_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
    @user = User.find_by_id(session[:user_id])

    if  @user.vouchers_disabled_till > Time.now
      flash[:notice] = _('Vouchers_disabled_till') + ": " + nice_date_time(@user.vouchers_disabled_till)
      redirect_to :controller => "callc", :action => 'main'
    end

    if @voucher
      @credit_without_vat = @voucher.get_tax.count_amount_without_tax(@voucher.credit_with_vat)
      @credit_in_default_currency = @credit_without_vat * count_exchange_rate(@voucher.currency, session[:default_currency])
    else
      session[:voucher_attempt] += 1
    end

    if session[:voucher_attempt] >= Confline.get_value("Voucher_Attempts_to_Enter").to_i and @user.vouchers_disabled_till < Time.now
      @user.vouchers_disabled_till = Time.now + Confline.get_value("Voucher_Disable_Time").to_i.minutes
      @user.save
      flash[:notice] = _('Too_many_wrong_attempts_Vouchers_disabled_till') + ": " + nice_date_time(@user.vouchers_disabled_till)
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    @active = 0

    if @voucher
      v=@voucher
      @active = 1
      @active = 0 if v.use_date
      @active = 0 if v.active_till < Time.now
    end

    flash[:notice] = _('Voucher_not_found') if @active == 0

  end

  def voucher_pay

    @user = current_user

    if @user.vouchers_disabled_till > Time.now
      flash[:notice] = _('Vouchers_disabled_till') + ": " + nice_date_time(@user.vouchers_disabled_till)
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    @credit_without_vat = @voucher.get_tax.count_amount_without_tax(@voucher.credit_with_vat)

    @credit_in_default_currency = @credit_without_vat * count_exchange_rate(@voucher.currency, session[:default_currency])

    @active = 0
    if @voucher
      v=@voucher
      @active = 1
      @active = 0 if v.use_date
      @active = 0 if v.active_till < Time.now
    end

    if @active == 0
      flash[:notice] = _('Voucher_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    # active == 1 so lets do what must be done
    # user's balance
    @user.balance += @credit_in_default_currency * User.current.currency.exchange_rate.to_d
    @user.save

    if @user.owner_id != 0
      ruser = User.find_by_id(@user.owner_id)
      ruser.balance += @credit_in_default_currency * User.current.currency.exchange_rate.to_d
      ruser.save
      pr = Payment.new({:tax => (@voucher.credit_with_vat - @credit_in_default_currency), :gross => @credit_in_default_currency, :paymenttype => "voucher", :amount => @voucher.credit_with_vat, :currency => @voucher.currency, :date_added => Time.now, :shipped_at => Time.now, :completed => 1, :user_id => ruser.id, :first_name => ruser.first_name, :last_name => ruser.last_name})
      pr.save
    end
    #payment
    p = Payment.new
    p.tax = @voucher.credit_with_vat - @credit_in_default_currency
    p.gross = @credit_in_default_currency
    p.paymenttype = "voucher"
    p.amount = @voucher.credit_with_vat
    p.currency = @voucher.currency
    p.date_added = Time.now
    p.shipped_at = Time.now
    p.completed = 1
    p.user_id = @user.id
    p.first_name = @user.first_name
    p.last_name = @user.last_name
    p.owner_id = @user.owner_id
    p.save

    #voucher
    @voucher.user_id = @user.id
    @voucher.use_date = Time.now
    @voucher.payment_id = p.id
    @voucher.save

    @voucher.disable_card
    flash[:status] = _('Voucher_used_to_update_balance_thank_you')
    redirect_to :controller => "callc", :action => 'main'
  end

  def bulk_management
    @page_title = _('Bulk_management')
    @page_icon = "edit.png"
    @tag=params[:v_tag] if params[:v_tag]
    @active = params[:v_active] if params[:v_active]
    @credit_min = params[:v_credit_min].to_i if params[:v_credit_min]
    @credit_max= params[:v_credit_max].to_i if params[:v_credit_max]
    @atill = params[:v_atill] if params[:v_atill]
    @action = params[:vaction] if params[:vaction]
    @tags = Voucher.get_tags
    @active_tills = Voucher.get_active_tills
  end

  def vouchers_interval #_delete
    @page_title = _('Delete_Vouchers_interval')
    @page_icon = "edit.png"
    @tag=params[:v_tag].to_s if params[:v_tag]
    @active = params[:v_active] if params[:v_active]
    @credit_min = params[:v_credit_min].to_i if !params[:v_credit_min].blank?
    @credit_max= params[:v_credit_max].to_i if !params[:v_credit_max].blank?
    @atill = params[:v_atill] if params[:v_atill]
    @action = params[:vaction] if params[:vaction]

    cond = ""
    today = nice_date_time(Time.now)
    cond += " ISNULL(use_date) AND active_till >= '#{today}' " if @active == "yes"
    cond += " NOT (ISNULL(use_date) AND active_till >= '#{today}') " if @active == "no"

    cond += " AND " if cond.length > 0 and @tag.to_s.length > 0
    cond += " tag = '#{@tag.to_s}' " if @tag.to_s.length > 0

    #credit
    cond += " AND " if cond.length > 0 and @credit_min.to_s.length > 0
    cond += " credit_with_vat #{@credit_min.to_i <= @credit_max.to_i ? ">=" : "<=" } #{@credit_min.to_s} " if @credit_min.to_s.length > 0

    cond += " AND " if cond.length > 0 and @credit_max.to_s.length > 0
    cond += " credit_with_vat #{@credit_min.to_i <= @credit_max.to_i ? "<=" : ">=" } #{@credit_max.to_s} " if @credit_max.to_s.length > 0


    cond += " AND " if cond.length > 0 and @atill.to_s.length > 0
    cond += " active_till LIKE '#{@atill.to_s}%' " if @atill.to_s.length > 0
    if cond.length > 0
      @vouchers = Voucher.find(:all, :conditions => cond)
    end

    session[:vouchers_bulk] = @vouchers

  end

  def voucher_delete
    # @vouchers set in before_filter
    vch = 0
    @vouchers.each { |voucher| vch += 1 if voucher.destroy }
    if params[:interval].to_i == 1
      if vch == 0
        flash[:notice] = _('Vouchers_interval_was_not_deleted')
      else
        flash[:status] = _('Vouchers_interval_deleted')
      end
    else
      if vch == 0
        flash_errors_for(_("Voucher_was_not_deleted"), @vouchers[0])
      else
        flash[:status] = _('Voucher_deleted')
      end
    end
    redirect_to :action => 'vouchers'
  end

  def voucher_active
    # @vouchers set in before_filter
    @page = params[:page] if params[:page]
    if params[:interval].to_i == 1
      @active = params[:vaction].to_s == 'active' ? 1 : 0
    else
      @active = @vouchers[0].active.to_i == 1 ? 0 : 1
    end
    sql = "UPDATE vouchers SET active = #{@active.to_i} WHERE id IN (#{@vouchers.collect { |t| [t.id] }.join(',')})"
    ActiveRecord::Base.connection.update(sql)
    if @active.to_i == 1
      if !session[:vouchers_bulk].blank? or params[:id].to_i > 0
        flash[:status] = _('Vouchers_interval_activeted')
      else
        flash[:notice] = _('No_Vouchers_found_to_activete')
      end
    else
      if !session[:vouchers_bulk].blank? or params[:id].to_i > 0
        flash[:status] = _('Vouchers_interval_deactiveted')
      else
        flash[:notice] = _('No_Vouchers_found_to_deactivete')
      end
    end
    redirect_to :action => 'vouchers', :page => @page
  end

  private

  def find_vouchers
    @vouchers = []
    if params[:interval].to_i == 1
      if session[:vouchers_bulk] != nil
        @vouchers = Voucher.find(:all, :conditions => ["vouchers.id IN (?)", session[:vouchers_bulk]])
      end
    else
      @vouchers << Voucher.find(:first, :conditions => ["vouchers.id = ?", params[:id]])
    end
    @vouchers.compact!

    if @vouchers.size == 0
      if params[:interval].to_i == 1
        flash[:notice] = _('No_Vouchers_found_to_delete') if params[:action] == 'voucher_delete'
        flash[:notice] = _('No_Vouchers_found_to_activete') if params[:action] == 'voucher_active' and params[:vaction].to_s == 'active'
        flash[:notice] = _('No_Vouchers_found_to_deactivete') if params[:action] == 'voucher_active' and params[:vaction].to_s != 'active'
      else
        flash[:notice] = _('Voucher_not_found')
      end
      redirect_to :action => 'vouchers'
    end
  end

  def find_voucher
    @voucher = Voucher.find(:first, :conditions => {:id => params[:id]})
    unless @voucher
      flash[:notice] = _('Voucher_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end
end
