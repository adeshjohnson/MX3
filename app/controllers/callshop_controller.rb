# -*- encoding : utf-8 -*-
class CallshopController < ApplicationController

  layout "callshop", :except => [:new, :free_booth, :topup_booth, :invoice_print, :invoice_edit, :comment_update]

  before_filter :check_localization
  before_filter :check_addon
  skip_before_filter :redirect_callshop_manager
  #skip_before_filter :set_current_user

  @@invoice_searchable_cols = ["created_at", "balance", "state", "comment", "invoice_type"]
  @@invoice_default_search = {:order_by => "created_at", :order_dir => "DESC", :page => 1}

  @@callshop_view = []
  @@callshop_edit = [:show, :show_json, :new, :reserve_booth, :update, :free_booth, :release_booth, :comment_update, :topup_booth, :topup_update, :invoices, :invoice_print, :invoice_edit, :get_number_data]
  before_filter(:only => @@callshop_view+@@callshop_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@callshop_view, @@callshop_edit, {:role => "reseller", :right => :res_call_shop, :ignore => true})
    c.instance_variable_set :@callshop, allow_read
    c.instance_variable_set :@callshop, allow_edit
    true
  }

  before_filter :find_shop_and_authorize, :except => [:new, :show_json, :get_number_data]
  # manager view
  def show
    @users = @cshop.users
    unless @users
      flash[:notice] = _("Usesr_Were_Not_Found")
      redirect_to :controller => :callc, :action => :main and return false
    end
    session[:callshop] = {}
    session[:callshop][:booths] ||= @users.collect { |user| user.id }
    @users.each { |user| store_invoice_in_session(user, user.cs_invoices.first) }
  end

  # load JSON using data about users from variable that is set in show_v2
  def show_json
    if session[:callshop] and session[:callshop][:booths] and session[:callshop][:booths].size > 0
      booths = status_for_ajax(session[:callshop][:booths])
      json_hash = {
          #        :free_booths => booths.collect{|b| b[:state] if b[:state] == "free"}.compact.size,
          #        :active_calls => booths.collect{|b| b[:state] if b[:state] == "occupied"}.compact.size,
          :booths => booths}
      render :json => json_hash.to_json
    else
      render :text => "{}"
    end
  end

  # reservation form (mean to be used by xhr)
  # in case we cant find current user redirect to login page
  def new
    @invoice = CsInvoice.new(:user_id => params[:user_id])
    if current_user
      @currency = current_user.currency.name #Currency.get_default.name
    else
      redirect_to :controller => "callc", :action => "logout" and return false
    end
  end

  # reservation action (xhr)
  def reserve_booth
    @invoice = CsInvoice.new(params[:invoice].merge!({:callshop_id => params[:id]}))
    @user = @invoice.user
    @old_invoice = @user.cs_invoices.first
    unless @old_invoice
      tax = @user.get_tax.dup
      tax.save
      @invoice.tax_id = tax.id
      @invoice.balance_with_tax = params[:invoice][:balance].to_f
      @invoice.save
      user_type = (params[:invoice][:invoice_type].to_s == "postpaid" ? 1 : 0)
      balance = (user_type == 1 ? 0 : params[:invoice][:balance].to_f)
      if params[:add_with_tax_new].to_i == 1 and @invoice.tax
        balance = @invoice.tax.count_amount_without_tax(balance).to_f
        @invoice.balance_with_tax = params[:invoice][:balance].to_f
        @invoice.balance = balance
        @invoice.save
      else
        @invoice.balance_with_tax = @invoice.tax.apply_tax(balance)
        @invoice.save
      end
      @user.update_attributes({:balance => balance, :postpaid => user_type, :blocked => 0})
    end
    store_invoice_in_session(@user, @invoice)

    respond_to do |format|
      format.json {
        render :json => @invoice.attributes.merge(:created_at => nice_date_time(@invoice.created_at)).to_json
      }
    end
  end

  # balance update topup action (xhr)
  def update
    @invoice = CsInvoice.find_by_id(params[:invoice_id])
    @user = @invoice.user

    if params[:increase] && params[:increase] != "true"
      params[:invoice][:balance] = 0 if @invoice.balance - params[:invoice][:balance].to_f <= 0 # so it won't get negative
    end

    if params[:add_with_tax].to_i == 1 and @invoice.tax
      params[:invoice][:balance_with_tax] = params[:invoice][:balance].to_f
      params[:invoice][:balance] = @invoice.tax.count_amount_without_tax(params[:invoice][:balance]).to_f
    else
      if @invoice.tax
        params[:invoice][:balance_with_tax] = @invoice.tax.apply_tax(params[:invoice][:balance]).to_f
      end
    end

    @invoice.update_attributes(params[:invoice])

    if params[:invoice][:balance]
      @user.update_attributes({:balance => params[:invoice][:balance].to_f})
    end
    store_invoice_in_session(@user, @invoice)

    respond_to do |format|
      format.json { render :json => "OK".to_json }
    end
  end

  # booth summary form (xhr)
  def free_booth
    @booth = User.find_by_id(params[:user_id])
    @invoice = @booth.cs_invoices.first
    if @invoice
      begin
        # terminated calls if any
        server_id, channel = params.values_at(:server, :channel)

        unless server_id.blank? or channel.blank?
          server = Server.find(:first, :conditions => "id = #{server_id.to_i}")

          if server
            server.ami_cmd("soft hangup #{channel}")
          end

          MorLog.my_debug "Hangup channel: #{channel} on server: #{server_id}"
        end
      rescue Exception => e
        @status = _('Unable_to_terminate_calls_check_connectivity')
      end
    end
  end

  # booth release action (xhr)
  def release_booth
    @user = User.find_by_id(params[:user_id])
    @invoice = @user.cs_invoices.first
    if @invoice
      @user.update_attributes(:balance => 0, :blocked => 1)
      opts = {
          :state => (params[:full_payment].eql?("true")) ? "full" : "partial"
      }
      calls = @invoice.calls
      if calls and calls.size > 0
        @invoice.update_attributes({:comment => params[:comment], :balance => params[:balance], :paid_at => Time.now}.merge(opts))
      else
        @invoice.destroy
      end
      @user.cs_invoices.find(:all, :conditions => ["state = 'unpaid'"]).each(&:destroy)
      store_invoice_in_session(@user, nil)
      render :text => "OK"
    else
      render :text => _("Invoice_not_found")
    end
  end

  # comment update form (xhr)
  def comment_update
    @invoice = User.find_by_id(params[:user_id]).cs_invoices.first
  end

  # booth topup form (xhr)
  def topup_booth
    @invoice = CsInvoice.find(:first, :conditions => ["cs_invoices.user_id = ? AND state = 'unpaid'", params[:user_id]])
  end

  def topup_update
    logger.debug " >> Finding targets"
    @invoice = CsInvoice.find(:first, :include => [:user, :tax], :conditions => ["cs_invoices.id = ?", params[:invoice_id]])
    @user = @invoice.user
    params[:invoice][:balance_with_tax] = params[:invoice][:balance].to_f
    if params[:increase] and params[:invoice] and !params[:invoice][:balance].to_f.zero?
      if params[:add_with_tax].to_i == 1 and @invoice.tax
        params[:invoice][:balance] = round_to_cents(@invoice.tax.count_amount_without_tax(params[:invoice][:balance]).to_f)
      end
      if params[:increase] == "true"
        logger.debug " >> Increasing balance by #{params[:invoice][:balance].to_f}"
        @user.balance += params[:invoice][:balance].to_f
        @invoice.balance += params[:invoice][:balance].to_f
        @invoice.balance_with_tax += params[:invoice][:balance_with_tax].to_f
      else
        logger.debug " >> Decreasing balance by #{params[:invoice][:balance].to_f}"
        @user.balance -= params[:invoice][:balance].to_f
        @invoice.balance -= params[:invoice][:balance].to_f
        @invoice.balance_with_tax -= params[:invoice][:balance_with_tax].to_f
      end

      @user.balance = @invoice.balance = @invoice.balance_with_tax = 0 if @user.balance < 0
      @user.save
      @invoice.save
      store_invoice_in_session(@user, @invoice)
    else
      logger.debug " >> Not enough params"
      logger.debug "   >> Increase? #{params[:increase]}"
      logger.debug "   >> Adjustment: #{params[:invoice][:balance]}" if params[:invoice] and params[:invoice][:balance]
    end
    render :text => "OK"
  end

  # invoices view
  def invoices
    @search_params = session[:callshop_invoices_order] ||= @@invoice_default_search
    @currency = current_user.currency.name #Currency.get_default.name
    @search_params = invoices_parse_params(params, @search_params)
    @total_invoices = @cshop.invoices.count(:conditions => ["paid_at IS NOT NULL"])
    @total_pages = (@total_invoices.to_f / session[:items_per_page].to_f).ceil
    @search_params[:page] = correct_page_number(@search_params[:page], @total_pages)
    @invoices = @cshop.invoices.find(:all,
                                     :conditions => ["paid_at IS NOT NULL"],
                                     :order => invoices_order(@search_params),
                                     :offset => (@search_params[:page].to_i - 1) * session[:items_per_page],
                                     :limit => session[:items_per_page]
    )

    respond_to do |format|
      format.html {}
      format.json {
        invoices = @invoices.map { |invoice|
          {:id => invoice.id,
           :issue_date => invoice.created_at.strftime("%Y-%m-%d %H:%M:%S"),
           :amount => format_money(invoice.balance, @currency),
           :status => invoice_state(invoice),
           :comment => invoice.comment,
           :user_type => invoice.invoice_type}
        }
        render :text => {:invoices => invoices, :pages => page_select_header(@search_params[:page].to_i, @total_pages, {}, {}, "array")}.to_json
      }
    end
    session[:callshop_invoices_order] = @search_params
  end

  # invoice print
  def invoice_print
    @invoice = CsInvoice.find_by_id(params[:invoice_id])
  end

  def invoice_edit
    @invoice = CsInvoice.find_by_id(params[:invoice_id])
  end

  def get_number_data
    number = params[:number]
    arguments = {
        "directions.name" => "direction_name",
        "directions.code" => "code",
        "destinations.prefix" => "prefix",
        "destinations.subcode" => "subcode",
        "destinations.name" => "dest_name",
        "rates.id" => "rate_id"
    }
    joins = [
        "LEFT JOIN directions on (destinations.direction_code = directions.code)",
        "LEFT JOIN rates ON (rates.destination_id = directions.id)",
    ]
    sql = "SELECT #{arguments.map { |key, value| "#{key} AS #{value}" }.join(", ")} FROM destinations #{joins.join("\n")} WHERE prefix = SUBSTRING('#{number}', 1, LENGTH(destinations.prefix)) ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1"
    rez = ActiveRecord::Base.connection.select_all(sql)
    result = []
    if rez and rez[0]
      rez = rez[0]
      MorLog.my_debug("..........................")
      MorLog.my_debug(sql)

      destination = [rez["direction_name"], rez["subcode"], rez["dest_name"]].compact

      result = [{:type => "with_flag", :flag => rez["code"].downcase, :name => _("Destination"), :value => destination.join(" ")}, {:name => "SOMENAME", :value => "somevalue"}]
    end
    render :json => result.to_json
  end

  private

  def find_shop_and_authorize
    @cshop = Callshop.find_by_id(params[:id], :include => {:users => [:cs_invoices]}, :order => "usergroups.position asc", :conditions => ["usergroups.gusertype = 'user'"])

    unless @cshop
      reset_session
      flash[:notice] = _('Callshop_was_not_found_or_is_empty')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    unless session[:cs_group] && @cshop.id == session[:cs_group].group_id
      reset_session
      flash[:notice] = _('You_are_not_authorized_to_manage_callshop')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    @currency = current_user.currency.name #@cshop.manager_user.currency.name #Currency.get_default.name
  end

  def check_addon
    unless defined?(CS_Active) && CS_Active == 1
      reset_session
      flash[:notice] = _("Callshop_not_enabled")
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end


  def invoices_parse_params(params, search_params)
    search_params[:page] = params[:page] if params[:page] and params[:page].to_i > 0
    search_params[:order_by] = params[:order_by].to_s if params[:order_by] and @@invoice_searchable_cols.include?(params[:order_by].to_s)
    search_params[:order_dir] = params[:order_dir].upcase if params[:order_dir] and ["ASC", "DESC"].include?(params[:order_dir].upcase)
    search_params
  end


  def invoices_order(search_params)
    col = @@invoice_searchable_cols.include?(search_params[:order_by]) ? search_params[:order_by] : @@invoice_default_search[:order_by]
    dir = ["ASC", "DESC"].include?(search_params[:order_dir].upcase) ? search_params[:order_dir].upcase : @@invoice_default_search[:order_dir]
    "#{col} #{dir}"
  end

  def status_for_ajax(users)

    session[:callshop] ||= {}
    #MorLog.my_debug( session[:callshop].inspect)
    session[:callshop][:cs_invoices] ||= {}

    old_countries = session[:callshop][:countries] ||= {}
    countries = {}
    columns = {
        :id => "users.id",
        :number => "activecalls.dst",
        :prefix => "activecalls.prefix",
        #here getting only answer time
        :duration => "activecalls.answer_time",
        :user_rate => "activecalls.user_rate",
        :user_type => "users.postpaid",
        :timestamp => "activecalls.start_time",
        :balance => "ABS(users.balance)",
    }

    sql = "SELECT #{columns.map { |key, value| "#{value} AS #{key.to_s}" }.join(", ")} FROM users
  LEFT JOIN activecalls ON (users.id = activecalls.user_id)
  WHERE users.id IN (#{users.join(", ")});"
    #MorLog.my_debug("-----------------------------------------------\n"  + sql.to_s)
    rez = ActiveRecord::Base.connection.select_all(sql)
    all_booths = rez.inject([]) { |booths, row|
      booth = {:id => nil, :created_at => nil, :number => nil, :duration => nil, :user_rate => nil, :country => nil, :user_type => nil, :timestamp => nil, :balance => nil, :state => nil}
      row.each { |key, value| booth[key.to_sym] = value if booth.has_key?(key.to_sym) } # parse values from SQL

      #replaced duration counting from sql NOW() to Time.now.getlocal()
      #booth[:duration] = nice_time(booth[:duration])
      booth[:duration] = nice_time(Time.now.getlocal()- Time.parse(booth[:duration].to_s))
      booth[:user_type] = (booth[:user_type].to_i == 1 ? "postpaid" : "prepaid")

      if booth[:number]
        if countries[booth[:number]].blank?
          countries[booth[:number]] ||= old_countries[booth[:number]] ||= Direction.name_by_prefix(row["prefix"])
        end
        booth[:country] = countries[booth[:number]]
      end

      # Add invoice data
      if invoice = session[:callshop][:cs_invoices][booth[:id].to_s]
        booth[:comment] = invoice[:comment]
        booth[:created_at] = invoice[:created_at]
        updated = invoice[:updated_at]
        if updated
          booth[:timestamp] = booth[:timestamp] ? booth[:timestamp] : updated
        else
          booth[:timestamp] = nil
        end
      else
        booth[:number] = booth[:comment] = booth[:user_rate] = booth[:timestamp] = booth[:duration] = booth[:balance] = nil
      end
      booth[:state] = booth_state(booth)
      booths.push(booth)
    }
    session[:callshop][:countries] = countries
    all_booths
  end

  def booth_state(booth)
    if !booth[:created_at].blank? and !booth[:duration].blank?
      "occupied"
    else
      booth[:created_at] ? "reserved" : "free"
    end
  end

  def store_invoice_in_session(user, invoice)
    invoice = {:comment => invoice.comment, :created_at => nice_date_time(invoice.created_at), :updated_at => invoice.updated_at.to_i} if invoice
    user = user.id if user.class == User
    session[:callshop] ||= {}
    session[:callshop][:cs_invoices] ||= {}
    session[:callshop][:cs_invoices][user.to_s] = invoice
  end
end
