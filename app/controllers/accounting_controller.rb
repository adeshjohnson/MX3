class AccountingController < ApplicationController

  
  require 'pdf/wrapper'
  layout "callc"
  before_filter :check_localization
  before_filter :authorize


  before_filter :check_if_can_see_finances, :only => [:vouchers, :vouchers_list_to_csv, :voucher_new, :voucher_create, :voucher_delete, ]
  before_filter{ |c|   c.instance_variable_set :@allow_read, true
    c.instance_variable_set :@allow_edit, true
  }
  @@voucher_view = [:vouchers , :vouchers_list_to_csv]
  @@voucher_edit = [:vouchers_new, :vouchers_create, :voucher_delete, :bulk_management]
  before_filter(:only =>  @@voucher_view+@@voucher_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@voucher_view, @@voucher_edit, {:role => "accountant", :right => :acc_vouchers_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }
  @@invoice_view = [:invoices]
  @@invoice_edit = [:generate_invoices]
  before_filter(:only =>  @@invoice_view+ @@invoice_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@invoice_view,  @@invoice_edit, {:role => "accountant", :right => :acc_invoices_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :find_invoice, :only => [:invoice_recalculate]

  verify :method => :post, :only => [ :invoice_recalculate, :comment_invoice ],
    :redirect_to => { :controller=>:callc, :action => :main },
    :add_flash => { :notice => _('Dont_be_so_smart'),
    :params => {:dont_be_so_smart => true}}

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :invoice_delete ],
    :redirect_to => {:action => :index_main}

  def index
    redirect_to :action=>"user_invoices"
  end

  def index_main
    dont_be_so_smart
    redirect_to :controller=>"callc", :action => :main and return false
  end

  def generate_invoices
    @users = User.find_all_for_select(correct_owner_id,{:exclude_owner=>true})
    @page_title = _('Generate_invoices')
    @page_icon = "application_go.png"

    @post = 1
    @pre = 0
  end


  def generate_invoices_to_prepaid_users
    @page_title = _('Generate_invoices_to_prepaid_users')
    @page_icon = "application_go.png"
  end

  # ================== sending invoices =============================
  def send_invoices
    change_date
    session[:invoice_sent_options] ? @sent_options = session[:invoice_sent_options] : @sent_options = {}

    [:s_username, :s_first_name, :s_last_name, :s_number, :s_period_start, :s_period_end, :s_issue_date, :s_sent_email, :s_sent_manually, :s_paid, :s_invoice_type].each{|key|
      params[key] ? @sent_options[key] = params[key].to_s : (@sent_options[key] = "" if !@sent_options[key])
    }

    cond = []
    cond_param = []
    # params that need to be searched with appended any value via LIKE in users table
    ["username", "first_name", "last_name"].each{ |col|
      add_contition_and_param(@sent_options["s_#{col}".to_sym], @sent_options["s_#{col}".intern].to_s+"%", "users.#{col} LIKE ?" , cond, cond_param)}
    # params that need to be searched with appended any value via LIKE in invoices table
    add_contition_and_param(@sent_options[:s_number], @sent_options[:s_number].to_s+"%", "invoices.number LIKE ?" , cond, cond_param)
    # params that need to be searched via equality.
    ["period_start", "period_end", "issue_date", "sent_email", "sent_manually", "paid", "invoice_type"].each{|col|
      add_contition_and_param(@sent_options["s_#{col}".to_sym], @sent_options["s_#{col}".to_sym], "invoices.#{col} = ?" , cond, cond_param)}

    session[:usertype] == "accountant" ? owner_id = 0 : owner_id = session[:user_id]
    cond << "users.owner_id = ?"
    cond_param << owner_id

    cond << "users.send_invoice_types > 0"

    @invoices = Invoice.find(:all, :include => [:user, :tax], :conditions => [cond.join(" AND ")] + cond_param)
    MorLog.my_debug("*************Invoice sending, found : #{@invoices.size.to_i}", 1)
    @number = 0
    not_sent = 0

    params[:email_or_not] = 1
    session[:invoice_sent_options] = @sent_options
    email_from = Confline.get_value("Email_from", correct_owner_id)
    if @invoices.size.to_i > 0
      for invoice in @invoices
        user = invoice.user
        attach = []
        params[:id] =invoice.id
        prepaid =  invoice.invoice_type.to_s == 'prepaid'  ? "Prepaid_" : ''
        @invoice = user.send_invoice_types.to_i
        if @invoice.to_i != 0
          if (user.email).length > 0
            if (@invoice % 2) ==1
              @invoice = Confline.get_value("#{prepaid}Invoice_default", correct_owner_id).to_i
            end
            if @invoice >=256
              @i8= 256
              calls_cvs = {}
              calls_cvs[:file] = get_prepaid_user_calls_csv(current_user, user, invoice.period_start, invoice.period_end)
              calls_cvs[:content_type] = "text/csv"
              calls_cvs[:filename] = "#{_('Calls')}.csv"
              attach << calls_cvs
            else
              @i8= 0
            end
            @invoice = @invoice - @i8
            if @invoice >=128
              @i7= 128
              csv4 = {}
              csv4[:file] = generate_invoice_by_cid_csv
              csv4[:content_type] = "text/csv"
              csv4[:filename] = "#{_('Invoice_by_CallerID_csv')}.csv"
              attach << csv4
            else
              @i7=0
            end
            @invoice = @invoice - @i7
            if @invoice >= 64
              @i6= 64
              csv3 = {}
              csv3[:file] = generate_invoice_destinations_csv
              csv3[:content_type] = "text/csv"
              csv3[:filename] = "#{_('Invoice_destinations_csv')}.csv"
              attach << csv3
            else
              @i6=0
            end
            @invoice = @invoice - @i6
            if @invoice >= 32
              @i5= 32
              pdf = {}
              pdf[:file] =  generate_invoice_by_cid_pdf
              pdf[:content_type] = "application/pdf"
              pdf[:filename] = "#{_('Invoice_by_CallerID_pdf')}.pdf"
              attach << pdf
            else
              @i5=0
            end
            @invoice = @invoice - @i5
            if @invoice >= 16
              @i4= 16
              csv2 = {}
              csv2[:file] = generate_invoice_detailed_csv
              csv2[:content_type] = "text/csv"
              csv2[:filename] = "#{_('Invoice_detailed_csv')}.csv"
              attach << csv2
            else
              @i4=0
            end
            @invoice = @invoice - @i4
            if @invoice >= 8
              @i3= 8
              pdf = {}
              pdf[:file] =  generate_invoice_detailed_pdf
              pdf[:content_type] = "application/pdf"
              pdf[:filename] = "#{_('Invoice_detailed_pdf')}.pdf"
              attach << pdf
            else
              @i3=0
            end
            @invoice = @invoice - @i3
            if @invoice >= 4
              @i2= 4
              csv = {}
              csv[:file] = generate_invoice_csv
              csv[:content_type] = "text/csv"
              csv[:filename] = "#{_('Invoice_csv')}.csv"
              attach << csv
            else
              @i2=0
            end
            @invoice = @invoice - @i2
            if @invoice >= 2
              pdf = {}
              pdf[:file] =  generate_invoice_pdf
              pdf[:content_type] = "application/pdf"
              pdf[:filename] = "#{_('Invoice_pdf')}.pdf"
              attach << pdf
            end

            variables = email_variables(user)
            email= Email.find(:first, :conditions => ["name = 'invoices' AND owner_id = ?", user.owner_id] )
            MorLog.my_debug("Try send invoice to : #{user.address.email}, Invoice : #{invoice.id}, User : #{user.id}, Email : #{email.id}", 1)
            @num = EmailsController.send_email_with_attachment(email, email_from, user, attach, variables)
            MorLog.my_debug @num
            if @num and @num[0].to_i != 0
              @number += @num[0].to_i
              invoice.sent_email = 1
              invoice.save
            else
              Action.create_email_sending_action(user, 'error', email, {:er_type=>1, :err_message=>@num})
            end
          else
            not_sent +=1
            email= Email.find(:first, :conditions => ["name = 'invoices' AND owner_id = ?", user.owner_id] )
            Action.create_email_sending_action(user, 'error', email, {:er_type=>1})
          end
        end
        #  end
      end
    end

    flash[:notice] = _('ERROR') + ": " +  @num[1].to_s if  @num and @num[0] == 0
    if @number.to_i > 0
      flash[:status] = _('Invoices_sent') + ": " + @number.to_s
    else
      flash[:notice] = _('Invoices_not_sent') + ": " + not_sent.to_s if  not_sent.to_i > 0
    end
    flash[:notice] = _('No_invoices_found_in_selected_period')  if @invoices.size.to_i == 0
    redirect_to :action => "invoices" and return false
  end

  def get_prepaid_user_calls_csv(requesting_user, user,period_start, period_end)
    sql = "Select calls.calldate, calls.src, calls.dst, calls.billsec, calls.user_price, calls.src_device_id, calls.dst_device_id, calls.prefix, calls.disposition, destinations.name from calls
             JOIN devices on (devices.id = calls.src_device_id or devices.id = calls.dst_device_id)
             LEFT JOIN destinations ON (destinations.prefix = calls.prefix)
                Where devices.user_id  = #{user.id}  AND disposition = 'ANSWERED' AND calldate BETWEEN '#{period_start} 00:00:00' AND  '#{period_end} 23:59:59'
              ORDER BY calls.calldate ASC"

    sep, dec = user.csv_params

    calls = Call.find_by_sql(sql)
    csv_string = "#{_('Date')}#{sep}#{ _('Called_from')}#{sep}#{_('Called_to')}#{sep}#{_('Destination')}#{sep}#{_('Duration')}#{sep}#{_('Price')} (#{_(session[:default_currency].to_s)})\n"    
    for call in calls
      csv_string += "#{nice_date_time(call.calldate)}#{sep}#{call.src.to_s}#{sep}#{hide_dst_for_user(user, "csv", call.dst.to_s)}#{sep}#{call.name }#{sep}#{nice_time(call.billsec) }#{sep}#{nice_number(call.user_price).to_s.gsub(".", dec).to_s }\n"
    end
    return csv_string
  end

  #================= generate invoices ===============================
  def generate_invoices_status
    MorLog.my_debug " ********* \n for period #{session_from_date} - #{session_till_date}"
    change_date
    MorLog.my_debug "for period #{session_from_date} - #{session_till_date}"
    @page_title = _('Generate_invoices')
    @page_icon = "application_go.png"

    @owner_id = correct_owner_id

    invoice_number_start = Confline.get_value("Invoice_Number_Start",@owner_id)
    invoice_number_length = Confline.get_value("Invoice_Number_Length",@owner_id).to_i
    invoice_number_type = Confline.get_value("Invoice_Number_Type",@owner_id).to_i

    MorLog.my_debug("\n\n========== Generating invoices ============", 1)

    add_action(current_user, 'Starting_invoices_generation', Time.now().to_s)
    # count for which period invoices should be generated

    unless params[:invoice]
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    type = params[:invoice][:type]
    type = "postpaid" if !(["postpaid", "prepaid", "user"].include?(type))
    redirect_to :action => :generate_invoices_status_for_prepaid_users, :invoice => {:type => "prepaid"}, :date_from=>params[:date_from], :date_till=>params[:date_till], :date_issue=>params[:date_issue] and return false if type == "prepaid"
    if type == "user"
      @user = User.find(:first, :conditions => ["users.id = ?", params[:user][:id]]) if params[:user] and params[:user][:id]
      unless @user
        flash[:notice] = _("User_not_found")
        redirect_to :action => :generate_invoices and return false
      end
      if @user.postpaid == 0
        redirect_to :action => :generate_invoices_status_for_prepaid_users, :invoice => {:type => "user"}, :user => {:id => @user.id}, :date_from=>params[:date_from], :date_till=>params[:date_till], :date_issue=>params[:date_issue] and return false
      end
    end

    unless [1,2].include?(invoice_number_type)
      flash[:notice] = _('Please_set_invoice_params')
      if session[:usertype] == "reseller"
        redirect_to :controller => :functions, :action => :reseller_settings and return false
      else
        redirect_to :controller => :functions, :action => :settings and return false
      end
    end
    @period_start = session_from_date
    @period_end = session_till_date
    #    # period with time
    period_start = @period_start.to_time
    period_end = (@period_end+" 23:59:59").to_time
    period_start_with_time = session_from_date + " 00:00:00"
    period_end_with_time = session_till_date + " 23:59:59"

    MorLog.my_debug session_from_date
    MorLog.my_debug session_till_date

    total_days =(@period_end.to_date - @period_start.to_date ) + 1

    if session[:invoices_is_generating].to_i == 1
      flash[:notice] = _('Invoices_is_generating')
      redirect_to :controller => :callc, :action => :main and return false
    else
      session[:invoices_is_generating] = 1
    end

    MorLog.my_debug("Invoices will be generated for period #{period_start_with_time} - #{period_end_with_time}")

    @invoices_generated = 0

    # retrieve users to generate invoices to
    if type == "user"
      @users = User.find(:all, :include => [:tax], :conditions => ["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 1 AND users.id = ? AND users.generate_invoice = 1 AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, @user.id, @period_start, @period_end])
    else
      @users = User.find(:all, :include => [:tax], :conditions => ["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 1 AND users.generate_invoice = 1 AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, @period_start, @period_end])
    end

    ind_ex = ActiveRecord::Base.connection.select_all("SHOW INDEX FROM calls")

    use_index = 0
    ind_ex.to_yaml
    ind_ex.each{|ie| use_index = 1; use_index if ie[:key_name].to_s == 'calldate'} if ind_ex

    issue_date = Time.mktime(params[:date_issue][:year], params[:date_issue][:month], params[:date_issue][:day])

    for user in @users
      MorLog.my_debug("******************** For user : #{user.id} ******************************", 1)
      # --- Subscriptions ---
      MorLog.my_debug("start incomming calls", 1)
      incoming_received_calls, incoming_received_calls_price, incoming_made_calls, incoming_made_calls_price, outgoing_calls_price, outgoing_calls_by_users_price, outgoing_calls, outgoing_calls_price, outgoing_calls_by_users = call_details_for_user(user, period_start_with_time, period_end_with_time, use_index)
      MorLog.my_debug("end incomming calls", 1)
      # find subscriptions for user in period
      MorLog.my_debug("start subscriptions", 1)
      subscriptions = user.subscriptions_in_period(period_start_with_time, period_end_with_time)
      MorLog.my_debug("end subscriptions", 1)
      total_subscriptions = 0
      total_subscriptions = subscriptions.size if subscriptions
      MorLog.my_debug("  Total subscriptions this period: #{total_subscriptions}", 1)


      # check if we should generate invoice
      if (outgoing_calls_price > 0) or (outgoing_calls_by_users_price > 0) or (incoming_received_calls_price > 0) or (incoming_made_calls_price > 0) or (total_subscriptions > 0)
        MorLog.my_debug("    Generating invoice....", 1)

        tax = user.get_tax.clone
        tax.save
        invoice = Invoice.new(:user_id => user.id, :period_start => @period_start, :period_end => @period_end, :issue_date => issue_date, :paid => 0, :number => "", :invoice_type => "postpaid", :tax_id => tax.id)
        invoice.save
        price = 0

        # --- add own outgoing calls ---
        if (outgoing_calls_price > 0)
          invoice.invoicedetails.create(:name => _('Calls'), :price => outgoing_calls_price.to_f, :quantity => outgoing_calls, :invdet_type => 0)
          price += outgoing_calls_price.to_f
        end

        # --- add resellers users outgoing calls ---
        if (outgoing_calls_by_users_price > 0)
          invoice.invoicedetails.create(:name => _('Calls_from_users'), :price =>outgoing_calls_by_users_price.to_f, :quantity => outgoing_calls_by_users, :invdet_type => 0)
          price += outgoing_calls_by_users_price.to_f
        end

        # --- add own received incoming calls ---
        #        if (incoming_received_calls_price > 0)
        #          invoice.invoicedetails.create(:name => _('Incoming_received_calls'), :price => incoming_received_calls_price.to_f, :quantity => incoming_received_calls, :invdet_type => 0)
        #          price += incoming_received_calls_price.to_f
        #        end

        # --- add own made incoming calls ---
        #        if (incoming_made_calls_price > 0)
        #          invoice.invoicedetails.create(:name => _('Incoming_made_calls'), :price => incoming_made_calls_price.to_f, :quantity => incoming_made_calls, :invdet_type => 0)
        #          price += incoming_made_calls_price.to_f
        #        end


        MorLog.my_debug("    Invoice price without subscriptions: #{price.to_s}",1)

        # nasty hack for Balticom to recalculate invoices/balance - DO NOT USE!!!
        #user.balance -= price
        #user.save

        # --- add subscriptions ---
        MorLog.my_debug("start subscriptions sum", 1)
        for sub in subscriptions

          service = sub.service
          count_subscription = 0
          MorLog.my_debug("start subscriptions flat_rate", 1)
          if service.servicetype == "flat_rate"
            start_date, end_date = subscription_period(sub, period_start, period_end)
            invd_price = service.price * (months_between(start_date.to_date, end_date.to_date)+1)
            count_subscription = 1
          end
          MorLog.my_debug("end subscriptions flat_rate", 1)
          MorLog.my_debug("start subscriptions one_time_fee", 1)
          if service.servicetype == "one_time_fee"
            # one-time-fee subscription only counts once for full price
            if (sub.activation_start >= period_start and sub.activation_start <= period_end)
              invd_price = service.price
              count_subscription = 1
            end
          end
          MorLog.my_debug("end subscriptions one_time_fee", 1)
          MorLog.my_debug("start subscriptions periodic_fee", 1)
          if service.servicetype == "periodic_fee"
            count_subscription = 1

            #from which day used?
            if sub.activation_start < period_start
              use_start = period_start
            else
              use_start = sub.activation_start
            end
            #till which day used?
            if sub.activation_end > period_end
              use_end = period_end
            else
              use_end = sub.activation_end
            end
            start_date = use_start.to_date
            end_date = use_end.to_date
            days_used = use_end.to_date - use_start.to_date

            if start_date.month == end_date.month and start_date.year == end_date.year
              total_days = start_date.to_time.end_of_month.day
              invd_price = service.price / total_days * (days_used+1)
            else
              invd_price = 0
              if months_between(start_date, end_date) > 1
                # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
                invd_price += (months_between(start_date, end_date)-1) * service.price
              end
              #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
              last_day_of_month = start_date.to_time.end_of_month.to_date
              last_day_of_month2 = end_date.to_time.end_of_month.to_date
              invd_price += service.price/last_day_of_month.day * (last_day_of_month - start_date+1).to_i
              invd_price += service.price/last_day_of_month2.day * (end_date.day)
            end
          end
          MorLog.my_debug("end subscriptions periodic_fee", 1)
          MorLog.my_debug("    Invoice Subscriptions price: #{invd_price.to_s}",1)


          if count_subscription == 1
            invoice.invoicedetails.create(:name => service.name.to_s + " - " + sub.memo.to_s, :price =>invd_price, :quantity => "1")
            price += invd_price.to_f
          end
        end
        MorLog.my_debug("end subscriptions sum", 1)
        invoice.price = price.to_f
        invoice.number_type = invoice_number_type
        invoice.number = generate_invoice_number(invoice_number_start, invoice_number_length, invoice_number_type, invoice.id, period_start)
        MorLog.my_debug("    Invoice number: #{invoice.number}", 1)
        invoice.save
        @invoices_generated += 1
      end
    end
    add_action(current_user, 'Finish_invoices_generation', Time.now().to_s)
    session[:invoices_is_generating] = 0
  end

  # before_filter
  #   find_invoice
  def invoice_recalculate
    if @invoice.paid?
      flash[:notice] = _('Invoice_already_paid')
      redirect_to :action => :invoice_details, :id => @invoice.id
    else
      regenerate_invoice_price(@invoice)
      flash[:status] = _('Invoice_successfully_recalculated')
      redirect_to :action => :invoice_details, :id => @invoice.id
    end
  end

  def generate_invoices_status_for_prepaid_users
    @page_title = _('Generate_invoices')
    @page_icon = "application_go.png"

    change_date

    MorLog.my_debug("==== generate_invoices_status_for_prepaid_users =====", 1)

    @owner_id = correct_owner_id
    type = params[:invoice][:type]
    invoice_number_start = Confline.get_value("Prepaid_Invoice_Number_Start", @owner_id).to_s
    invoice_number_length = Confline.get_value("Prepaid_Invoice_Number_Length", @owner_id).to_i
    if session[:usertype] == "reseller"
      invoice_number_start = Confline.get_value("Invoice_Number_Start", @owner_id).to_s
      invoice_number_length = Confline.get_value("Invoice_Number_Length", @owner_id).to_i
      invoice_number_type = Confline.get_value("Invoice_Number_Type", @owner_id).to_i
    else
      invoice_number_type = Confline.get_value("Prepaid_Invoice_Number_Type", @owner_id).to_i
    end

    unless [1,2].include?(invoice_number_type)
      flash[:notice] = _('Please_set_invoice_params')
      if session[:usertype] == "reseller"
        redirect_to :controller => :functions, :action => :reseller_settings and return false
      else
        redirect_to :controller => :functions, :action => :settings and return false
      end
    end
    MorLog.my_debug("\n\n========== Generating invoices ============", 1)

    @period_start = session_from_date
    @period_end = session_till_date
    #    # period with time
    period_start = @period_start.to_time
    period_end = (@period_end+" 23:59:59").to_time
    period_start_with_time = session_from_date + " 00:00:00"
    period_end_with_time = session_till_date + " 23:59:59"
    total_days =(@period_end.to_date - @period_start.to_date ) + 1

    if session[:invoices_is_generating].to_i == 1
      flash[:notice] = _('Invoices_is_generating')
      redirect_to :controller => :callc, :action => :main and return false
    else
      session[:invoices_is_generating] = 1
    end

    MorLog.my_debug("Prepaid Invoices will be generated for period #{period_start_with_time} - #{period_end_with_time}", 1)

    @invoices_generated = 0

    # count total users (by owner_id)
    if type == "user"
      @total_users = 1
    else
      @total_users = User.count(:all, :conditions => "owner_id = #{@owner_id} AND hidden = 0 AND postpaid = 0 AND users.id not in (SELECT user_id from invoices where period_start = '#{@period_start}' AND period_end = '#{@period_end}' )")
    end
    # retrieve users without invoices this period

    if type == "user"
      @users = User.find(:all, :include => [:tax], :conditions => ["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 0 AND users.id = ? AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, params[:user][:id],@period_start, @period_end])
    else
      @users = User.find(:all, :include => [:tax], :conditions => ["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 0 AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, @period_start, @period_end])
    end

    ind_ex = ActiveRecord::Base.connection.select_all("SHOW INDEX FROM calls")
    use_index = 0
    ind_ex.to_yaml
    ind_ex.each{|ie| use_index = 1; use_index if ie[:key_name].to_s == 'calldate'} if ind_ex

    issue_date = Time.mktime(params[:date_issue][:year], params[:date_issue][:month], params[:date_issue][:day])

    for user in @users
      MorLog.my_debug("******************** For user : #{user.id} ******************************", 1)
      MorLog.my_debug("incoming calls start", 1)
      incoming_received_calls, incoming_received_calls_price, incoming_made_calls, incoming_made_calls_price, outgoing_calls_price, outgoing_calls_by_users_price, outgoing_calls, outgoing_calls_price, outgoing_calls_by_users = call_details_for_user(user, period_start_with_time, period_end_with_time, use_index)
      MorLog.my_debug("incoming calls end", 1)
      MorLog.my_debug("subscriptions start", 1)
      subscriptions = user.subscriptions_in_period(period_start_with_time, period_end_with_time)
      MorLog.my_debug("subscriptions end", 1)
      total_subscriptions = 0
      total_subscriptions = subscriptions.size if subscriptions
      if (outgoing_calls_price > 0) or (outgoing_calls_by_users_price > 0) or (incoming_received_calls_price > 0) or (incoming_made_calls_price > 0) or (total_subscriptions > 0)
        MorLog.my_debug("    Generating invoice....", 1)
        user_tax = user.tax
        # possible error fix
        if not user_tax
          user.assign_default_tax2
          user_tax = user.tax
        end

        # tax for invoice
        tax = user_tax.clone
        tax.save
        invoice = Invoice.new(:user_id => user.id, :period_start => @period_start, :period_end => @period_end, :issue_date => issue_date, :paid => 1, :number => "", :invoice_type => "prepaid", :tax_id =>tax.id)
        invoice.save

        price = 0

        if (outgoing_calls_price > 0)
          invoice.invoicedetails.create(:name => _('Calls'), :price => outgoing_calls_price.to_f, :quantity => outgoing_calls, :invdet_type => 0)
          price += outgoing_calls_price.to_f
        end

        # --- add resellers users outgoing calls ---
        if (outgoing_calls_by_users_price > 0)
          invoice.invoicedetails.create(:name => _('Calls_from_users'), :price =>outgoing_calls_by_users_price.to_f, :quantity => outgoing_calls_by_users, :invdet_type => 0)
          price += outgoing_calls_by_users_price.to_f
        end

        #        # --- add own received incoming calls ---
        #        if (incoming_received_calls_price > 0)
        #          invoice.invoicedetails.create(:name => _('Incoming_received_calls'), :price => incoming_received_calls_price.to_f, :quantity => incoming_received_calls, :invdet_type => 0)
        #          price += incoming_received_calls_price.to_f
        #        end
        #
        #        # --- add own made incoming calls ---
        #        if (incoming_made_calls_price > 0)
        #          invoice.invoicedetails.create(:name => _('Incoming_made_calls'), :price => incoming_made_calls_price.to_f, :quantity => incoming_made_calls, :invdet_type => 0)
        #          price += incoming_made_calls_price.to_f
        #        end

        # --- add subscriptions ---
        MorLog.my_debug("start subscriptions sum", 1)
        for sub in subscriptions

          service = sub.service
          count_subscription = 0
          MorLog.my_debug("start subscriptions one_time_fee", 1)
          if service.servicetype == "one_time_fee"
            # one-time-fee subscription only counts once for full price
            if (sub.activation_start >= period_start and sub.activation_start <= period_end)
              invd_price = service.price
              count_subscription = 1
            end
          end
          MorLog.my_debug("end subscriptions one_time_fee", 1)
          MorLog.my_debug("start subscriptions flat_rate", 1)
          if service.servicetype == "flat_rate"
            start_date, end_date = subscription_period(sub, period_start, period_end)
            invd_price = service.price.to_f * (months_between(start_date.to_date, end_date.to_date)+1)
            count_subscription = 1
          end
          MorLog.my_debug("end subscriptions flat_rate", 1)
          MorLog.my_debug("start subscriptions periodic_fee", 1)
          if service.servicetype == "periodic_fee"
            count_subscription = 1

            #from which day used?
            if sub.activation_start < period_start
              use_start = period_start
            else
              use_start = sub.activation_start
            end
            #till which day used?
            if sub.activation_end > period_end
              use_end = period_end
            else
              use_end = sub.activation_end
            end
            start_date = use_start.to_date
            end_date = use_end.to_date
            days_used = use_end.to_date - use_start.to_date

            if start_date.month == end_date.month and start_date.year == end_date.year
              total_days = start_date.to_time.end_of_month.day
              invd_price = service.price / total_days * (days_used+1)
            else
              invd_price = 0
              if months_between(start_date, end_date) > 1
                # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
                invd_price += (months_between(start_date, end_date)-1) * service.price.to_f
              end
              # suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
              last_day_of_month = start_date.to_time.end_of_month.to_date
              last_day_of_month2 = end_date.to_time.end_of_month.to_date
              invd_price += service.price/last_day_of_month.day * (last_day_of_month - start_date+1).to_i
              invd_price += service.price/last_day_of_month2.day * (end_date.day)
            end
          end

          if count_subscription == 1
            invoice.invoicedetails.create(:name => service.name.to_s + " - " + sub.memo.to_s, :price => invd_price.to_f, :quantity => "1")
            price += invd_price.to_f
          end
          MorLog.my_debug("end subscriptions periodic_fee", 1)
        end
        MorLog.my_debug("end subscriptions sum", 1)
        invoice.price = price.to_f
        invoice.number_type = invoice_number_type
        invoice.number = generate_invoice_number(invoice_number_start, invoice_number_length, invoice_number_type, invoice.id, period_start)
        MorLog.my_debug("    Invoice number: #{invoice.number}", 1)
        invoice.save
        @invoices_generated += 1
      end
    end
    session[:invoices_is_generating] = 0
  end

  def date_query(date_from, date_till)
    # date query
    if date_from == ""
      date_sql = ""
    else
      if date_from.length > 11
        date_sql = "AND calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'"
      else
        date_sql = "AND calldate BETWEEN '" + date_from.to_s + " 00:00:00' AND '" + date_till.to_s + " 23:59:59'"
      end
    end
    date_sql
  end


  def invoices

    @Show_Currency_Selector =1

    session[:invoice_options] ? @options = session[:invoice_options] : @options = {}
    session[:invoice_sent_options] ? @sent_options = session[:invoice_sent_options] : @sent_options = {}

    @page_title = _('Invoices')
    @page_icon = "view.png"

    change_date
    # search params parsing. Assign new params if they were sent, default unset params to "" and leave if param is set but not sent
    if params[:clear].to_s == "true"
      @options.each {|key, value|
        logger.debug "Need to clear search."
        if key.to_s.scan(/^s_.*/).size > 0
          @options[key] = nil
          logger.debug "     clearing #{key}"
        end
      }
    end
    [:s_username, :s_first_name, :s_last_name, :s_number, :s_period_start, :s_period_end, :s_issue_date, :s_sent_email, :s_sent_manually, :s_paid, :s_invoice_type].each{|key|
      params[key] ? @options[key] = params[key].to_s : (@options[key] = "" if !@options[key])
    }
    # page number is an exception because it defaults to 1
    if params[:page] and params[:page].to_i > 0
      @options[:page] = params[:page].to_i
    else
      @options[:page] = 1 if !@options[:page] or @options[:page] <= 0
    end
    # same goes for order descending
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])

    cond = []
    cond_param = []
    # params that need to be searched with appended any value via LIKE in users table
    ["username", "first_name", "last_name"].each{ |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "users.#{col} LIKE ?" , cond, cond_param)}
    # params that need to be searched with appended any value via LIKE in invoices table
    add_contition_and_param(@options[:s_number], @options[:s_number].to_s+"%", "invoices.number LIKE ?" , cond, cond_param)
    # params that need to be searched via equality.
    ["period_start", "period_end", "issue_date", "sent_email", "sent_manually", "paid", "invoice_type"].each{|col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".to_sym], "invoices.#{col} = ?" , cond, cond_param)}

    session[:usertype] == "accountant" ? owner_id = 0 : owner_id = session[:user_id]
    cond << "users.owner_id = ?"
    cond_param << owner_id

    @options[:order_by], order_by = invoices_order_by(params, @options)

    @total_pages = (Invoice.count(:all, :include => [:user], :conditions => [cond.join(" AND ")] + cond_param).to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages and @total_pages > 0

    dc = session[:show_currency]
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])


    if params[:to_csv].to_i == 0
      @tot_in_wat = 0
      @tot_in2 = 0
      @tot_inv = Invoice.find(:all, :include => [:user, :tax], :conditions => [cond.join(" AND ")] + cond_param)
      @tot_inv.each{|r| @tot_in2+= r.converted_price(@ex).to_f ; @tot_in_wat += (r.price_with_tax(:ex=>@ex, :precision => nice_invoice_number_digits(r.invoice_type)) )}

      @invoices = Invoice.find(:all, :include => [:user, :tax],
        :conditions => [cond.join(" AND ")] + cond_param,
        :offset => session[:items_per_page]*(@options[:page]-1),
        :limit => session[:items_per_page], :order => order_by)
      #logger.fatal(([cond.join(" AND ")] + cond_param).inspect)
      cond.length > 1 ? @search = 1 : @search = 0
      cond.length > 1 ? @send_invoices = 1 : @send_invoices = 0

      @period_starts = ActiveRecord::Base.connection.select_all("SELECT DISTINCT period_start FROM invoices")
      @period_ends = ActiveRecord::Base.connection.select_all("SELECT DISTINCT period_end FROM invoices")
      @issue_dates = ActiveRecord::Base.connection.select_all("SELECT DISTINCT issue_date FROM invoices")

      session[:invoice_options] = @options
    else
      invoices = Invoice.find(:all, :include => [:user, :tax],
        :conditions => [cond.join(" AND ")] + cond_param,
        :order => order_by)
      sep, dec = current_user.csv_params
      csv_line = "'#{_('ID')}'#{sep}'#{_('User')}'#{sep}'#{_('Amount')} (#{dc})'#{sep}'#{_('Tax')}'#{sep}'#{_('Amount_with_tax')} (#{dc})'\n"
      csv_line += invoices.map{ |r| "#{r.id}#{sep}#{nice_user(r.user).delete(sep)}#{sep}#{nice_invoice_number(r.converted_price(@ex), r.invoice_type).to_s.gsub(".", dec).to_s}#{sep}#{nice_invoice_number((r.price_with_tax(:ex=>@ex, :precision => nice_invoice_number_digits(r.invoice_type)) - r.converted_price(@ex)), r.invoice_type).to_s.gsub(".", dec).to_s}#{sep}#{nice_invoice_number((r.price_with_tax(:ex=>@ex, :precision => nice_invoice_number_digits(r.invoice_type))), r.invoice_type).to_s.gsub(".", dec).to_s}" }.join("\n")
      if params[:test].to_i == 1
        render :text => "Invoices-#{session[:show_currency]}.csv" + csv_line.to_s
      else
        send_data(csv_line, :type => 'text/csv; charset=utf-8; header=present', :filename => "Invoices-#{session[:show_currency]}.csv")
      end
    end
  end

  def user_invoices
    @Show_Currency_Selector =1
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    @page_title = _('Invoices')
    @page_icon = "view.png"
    @invoices = Invoice.find(:all, :include => [:tax], :conditions => ["invoices.user_id = ?", session[:user_id]])
  end

  def pay_invoice
    if request.get?
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end

    invoice = Invoice.find(params[:id], :include=> [:tax])
    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
    user = invoice.user
    if invoice.paid == 0
      invoice.paid = 1
      invoice.paid_date = Time.now
      if params[:create_payment].to_i == 1
        paym = invoice.payment
        paym = Payment.new if not paym
        paym.paymenttype = "invoice"
        paym.amount = invoice.price
        paym.currency = session[:default_currency]
        paym.date_added = Time.now
        paym.shipped_at = Time.now
        paym.completed = 1
        paym.user_id = invoice.user_id
        paym.owner_id = correct_owner_id
        paym.save
        invoice.payment_id = paym.id
        user.balance += invoice.price
      end
    else
      invoice.paid = 0
      if invoice.payment
        invoice.payment.destroy
        user.balance -= invoice.price
      end
    end
    user.save
    invoice.save
    redirect_to :action => "invoices"
  end


  def sent_invoice
    invoice = Invoice.find_by_id(params[:id])
    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    if params[:status].to_s == 'email'
      invoice.sent_email == 0 ? invoice.sent_email = 1 : invoice.sent_email = 0
    end

    if params[:status].to_s == 'manually'
      invoice.sent_manually == 0 ? invoice.sent_manually = 1 : invoice.sent_manually = 0
    end
    invoice.save

    redirect_to :action => "invoice_details", :id=>invoice.id

  end

  def invoice_details

    @Show_Currency_Selector =1
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    unless can_see_finances?
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to :controller => :callc, :action => :main and return false
    end
    logger.fatal session[:show_currency]
    flash[:notice] = _('Invoice_not_found') and redirect_to :action => 'invoices' and return false  if not params[:id]
    @invoice = Invoice.find_by_id(params[:id], :include => [:user])
    @invoice_invoicedetails = @invoice.invoicedetails if @invoice

    unless @invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    @user = @invoice.user
    @page_title = _('Invoice')  + ": " + @invoice.number
    @page_icon = "view.png"
  end

  def comment_invoice
    invoice = Invoice.find(:first, :include => [:user], :conditions => ["invoices.id = ?", params[:id]])
    unless invoice or ["admin", "accountant"].include?(session[:usertype]) or session[:user_id] == @invoice.user.owner_id
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    invoice.comment = params[:invoice][:comment].to_s
    if invoice.save
      flash[:notice] = _("Invoice_Commented")
    else
      flash[:notice] = _("Invoice_Not_Commented")
    end
    redirect_to :action => :invoice_details, :id => invoice.id
  end

  def user_invoice_details
    @Show_Currency_Selector =1
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    @invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])
    @invoice_invoicedetails = @invoice.invoicedetails if @invoice

    unless @invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    if @invoice.user_id != current_user.id
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end


    @user = @invoice.user
    @page_title = _('Invoice')  + ": " + @invoice.number
    @page_icon = "view.png"
  end

  def invoice_delete
    inv = Invoice.find_by_id(params[:id], :include => [:user, :tax])
    if ! inv
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    inv_num = inv.number
    inv_invoicedetails = inv.invoicedetails
    @user = inv.user

=begin
    for id in inv_invoicedetails
      #Deduct subscription price from balance
      if @user.postpaid.to_i == 1
        if id.invdet_type > 0
          user = inv.user
          user.balance += id.price
          user.save
        end
      end
      id.destroy
    end
=end

    # we should _decrease_ user's balance by payments amount, because it is deleted and user should owe more (because there are no payment)
    payment = inv.payment
    if payment
      @user.balance -= payment.amount
      @user.save
      payment.destroy
    end

    Action.add_action(session[:user_id], "invoice_deleted", @user.id.to_s)
    inv.destroy

    flash[:status] = _('Invoice_deleted') + ": " + inv_num
    redirect_to :action => 'invoices' and return false
  end

  ############ PDF ###############

  def invoice_header_pdf(invoice, pdf, company = session[:company], default_currency = session[:default_currency])
    user = invoice.user
    address = user.address
    

    ex = Currency.count_exchange_rate(session[:default_currency], default_currency)


    (invoice.invoice_type.to_s == 'prepaid' and user.owner_id == 0) ? prepaid = "Prepaid_" : prepaid = ""

    # ----------- Invoice details ----------

    pdf.color(:Gray)
    pdf.text( _('INVOICE'), {:left => 330, :top => 43, :font_size =>16})
    pdf.color(:Black)
    pdf.text(_('Date') + ": " + invoice.issue_date.to_s, {:left => 330, :top => 75, :font_size => 9})
    pdf.text(_('Invoice_number') + ": " + invoice.number.to_s, {:left => 330, :top => 90, :font_size => 9})

    # ---------- Company details ----------

    pdf.text(company, {:left => 40, :top => 40, :font_size => 13})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address1", user.owner_id), {:left => 40, :top => 70, :font_size => 8})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address2", user.owner_id), {:left => 40, :top => 85, :font_size => 8})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address3", user.owner_id), {:left => 40, :top => 100, :font_size => 8})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address4", user.owner_id), {:left => 40, :top => 115, :font_size => 8})

    # ----------- Separation line ---------

    pdf.rectangle(40, 140, 520, 0,{:line_width => 1, :fill_color => :Gray, :color => :Gray})

    # ---------- Client details -----------
    if user.owner_id != 0
      inv_address_format = Confline.get_value("#{prepaid.to_s}Invoice_Address_Format", user.owner_id).to_i == 0 ? Confline.get_value("Invoice_Address_Format",0).to_i : Confline.get_value("#{prepaid.to_s}Invoice_Address_Format", user.owner_id).to_i
    else
      inv_address_format = Confline.get_value("#{prepaid.to_s}Invoice_Address_Format", user.owner_id).to_i
    end

    if inv_address_format == 1
      pdf.text(user.first_name.to_s + " " + user.last_name.to_s,                         {:left => 40, :top => 150, :font_size => 13})
      if address
        adr_direction = address.direction
        pdf.text(address.address.to_s,                                                        {:left => 40, :top => 180, :font_size => 8})
        pdf.text(address.city.to_s + ", " + address.postcode.to_s + ", " + address.state.to_s,{:left => 40, :top => 195, :font_size => 8})
        if adr_direction
          pdf.text(adr_direction.name.to_s,                                                  {:left => 40, :top => 210, :font_size => 8})
        end
      end
    end

    if inv_address_format == 2
      pdf.text(user.first_name.to_s + " " + user.last_name.to_s, {:left => 40, :top => 150, :font_size => 13})
      if address
        pdf.text(address.address.to_s,                           {:left => 40, :top => 180, :font_size => 8})
        pdf.text(address.city.to_s + ", " + address.state.to_s,  {:left => 40, :top => 195, :font_size => 8})
        pdf.text(address.postcode.to_s,                          {:left => 40, :top => 210, :font_size => 8})
      end
    end

    pdf.text(_('Company_Personal_ID') + " : " + user.clientid.to_s,      {:left => 40, :top => 225, :font_size => 8})
    pdf.text(_('VAT_Reg_number') + " : " + user.vat_number.to_s,         {:left => 40, :top => 240, :font_size => 8})
    pdf.text(_('Agreement_number') + " : " + user.agreement_number.to_s, {:left => 40, :top => 255, :font_size => 8})
    pdf.text(_('Agreement_date') + " : " + user.agreement_date.to_s,     {:left => 40, :top => 270, :font_size => 8})

    pdf.text(_('Time_period') + ": " + invoice.period_start.to_s + " - " + invoice.period_end.to_s , {:left => 40, :top => 295, :font_size => 9})

    #balance line
    if  Confline.get_value("#{prepaid.to_s}Invoice_Show_Balance_Line", user.owner_id).to_i == 1
      balance = owned_balance_from_previous_month(invoice)
      if balance
        pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Balance_Line", user.owner_id) + " " + sprintf("%0.#{2}f",balance[0].to_f * ex.to_f) + " (" + _('With_TAX') + " " + sprintf("%0.#{2}f",balance[1].to_f * ex.to_f).to_s + ") " + default_currency.to_s, {:left => 40, :top => 311, :font_size => 9})
      end
    end
    pdf
  end

=begin
 Generates grid for invoice. Rows with alternating colors
=end
  def invoice_layout_pdf(pdf, options = {})
    opts = {
      :rows => 12,
      :fill_color => :LIGHT_GREY,
      :line_width => 1
    }.merge(options)
    for i in 1..opts[:rows]/2
      pdf.rectangle(40, 320+i*40, 520, 20, {:line_width => 0, :fill_color => opts[:fill_color]})
    end
    #header text
    dc = options[:dc]
    pdf.text(_('Service'), {:left => 50, :top => 343, :font_size => 9})
    pdf.text(_('Quantity_invoice'), {:left => 330, :top => 343, :font_size => 9})
    pdf.text(_('Price') + " (#{dc})", {:left => 400, :top => 343, :font_size => 9})
    pdf.text(_('Total') + " (#{dc})", {:left => 485, :top => 343, :font_size => 9})
    #header vertical lines
    pdf.line(40, 340, 560, 340,{:line_width => opts[:line_width]})
    pdf.line(40, 360, 560, 360,{:line_width => opts[:line_width]})
    #bottom vertical line
    pdf.line(40, 360+opts[:rows]*20, 560, 360+opts[:rows]*20,{:line_width => opts[:line_width]})
    #Vertical lines
    pdf.line(40,  340, 40,  360+opts[:rows]*20, {:line_width => opts[:line_width]})
    pdf.line(560, 340, 560, 360+opts[:rows]*20,{:line_width => opts[:line_width]})
    pdf.line(320, 340, 320, 360+opts[:rows]*20,{:line_width => opts[:line_width]})
    pdf.line(390, 340, 390, 360+opts[:rows]*20,{:line_width => opts[:line_width]})
    pdf.line(470, 340, 470, 360+opts[:rows]*20,{:line_width => opts[:line_width]})

    pdf
  end

  def detailed_invoice_tax_box(pdf, invoice, total_calls, total_time, dc, ex)
    user = invoice.user
    tax = invoice.tax
    tax = invoice.user.get_tax unless tax
    prep, type = invoice_type(invoice, user)
    top = 695
    ilg=0
    tax_amount = 0
    #dc = current_user.currency.name
    if invoice.tax
      taxes = tax.applied_tax_list(nice_invoice_number(invoice.converted_price(ex), prep), :precision => nice_invoice_number_digits(prep))
      taxes.each{ |tax_hash|
        if tax.get_tax_count > 1
          pdf.line(360, top, 560, top,{:line_width => 1})
          pdf.text(tax_hash[:name].to_s + ": " + tax_hash[:value].to_s + " %", {:left =>255, :top => top-1, :font_size => 6})
          pdf.text(nice_invoice_number(tax_hash[:tax], prep).to_s+"    ", {:left =>0, :top => top-1, :font_size => 6, :alignment => :right})
          top += 10
          ilg +=1
        end
        tax_amount += nice_invoice_number(tax_hash[:tax].to_f, prep, {:no_repl=>1}).to_f
      }
      price_with_tax = nice_invoice_number(invoice.converted_price(ex), prep, {:no_repl=>1}).to_f + nice_invoice_number(tax_amount.to_f, prep, {:no_repl=>1}).to_f
    else
      price_with_tax = nice_invoice_number(invoice.converted_price_with_vat(ex), prep, {:no_repl=>1}).to_f
      tax_amount = price_with_tax.to_f - nice_invoice_number(invoice.converted_price(ex), prep, {:no_repl=>1}).to_f
    end
    pdf.line(360, top, 560, top,{:line_width => 1})
    top = 695 + (ilg * 10 )
    # SUBTOTAL
    pdf.text(nice_invoice_number(invoice.converted_price(ex).to_f, prep).to_s+"   ", {:left =>0, :top => 679, :font_size => 9, :alignment => :right})
    # TAXES
    pdf.text(nice_invoice_number(tax_amount.to_f, prep).to_s+"   ", {:left =>0, :top => top-2, :font_size => 9, :alignment => :right})
    # TOTAL
    pdf.text(nice_invoice_number(price_with_tax.to_f, prep).to_s+"   ", {:left =>0, :top => (top+11), :font_size => 9, :alignment => :right})

    if total_calls > 0
      pdf.text(total_calls.to_s, {:left =>395-(pdf.text_width(total_calls.to_s)-(total_calls.to_s.size*5)), :top =>(top+11), :font_size => 9})
    end
    pdf.text(nice_time(total_time).to_s, {:left =>430, :top => (top+11), :font_size => 9})

    top = 695 + (ilg * 10 )
    pdf.text(invoice_total_tax_name(tax).to_s, {:left =>255, :top => top-2, :font_size => 9})

    pdf.text(_('SUBTOTAL') + " (#{dc})", {:left =>255, :top => 679, :font_size => 9})
    pdf.text(_('TOTAL') + " (#{dc})", {:left =>255, :top => (top+11), :font_size => 9})   
    bottom = 721+(ilg*10).to_i
    # TO PAY
    if Confline.get_value("#{prep.to_s}Invoice_Show_Balance_Line", user.owner_id).to_i == 1
      balance = owned_balance_from_previous_month(invoice)
      to_pay = price_with_tax
      pdf.text(Confline.get_value("#{prep.to_s}Invoice_To_Pay_Line", user.owner_id), {:left =>255, :top => (top+23), :font_size => 9})
      pdf.line(360, (top+40), 560, (top+40),{:line_width => 1})
      to_pay += balance[1].to_f * ex if balance
      pdf.text(nice_invoice_number(to_pay.to_f, prep).to_s+"   ", {:left =>0, :top => (top+24), :font_size => 9, :alignment => :right})
      bottom +=14
      pdf.line(360, (top+40), 560, (top+40),{:line_width => 1})
    end

    pdf.line(360, top+13, 560, top+13,{:line_width => 1})
    pdf.line(360, (top+26), 560, (top+26),{:line_width => 1})

    # Vertical line
    pdf.line(560, 680, 560, bottom,{:line_width => 1})
    pdf.line(360, 680, 360, bottom,{:line_width => 1})
    pdf.line(410, 680, 410, bottom,{:line_width => 1})
    pdf.line(490, 680, 490, bottom,{:line_width => 1})
    return pdf, tax_amount
  end

  def invoice_total_box_pdf(pdf, invoice, ex, dc)
    user = invoice.user
    tax = invoice.tax
    tax = invoice.user.get_tax unless tax
    prep, prepaid = invoice_type(invoice, user)
    top = 620
    ilg = 0
    tax_amount = 0
    
    if invoice.tax
      taxes = tax.applied_tax_list(invoice.converted_price(ex), :precision => nice_invoice_number_digits(prep))

      taxes.each { |tax_hash|
        if tax.get_tax_count > 1

          pdf.line(470, top, 560, top,{:line_width => 1})
          pdf.text(tax_hash[:name].to_s+ ": " + tax_hash[:value].to_s + " %", {:left =>350, :top => top-1, :font_size => 7})
          pdf.text(nice_invoice_number(tax_hash[:tax], prep).to_s+"     ", {:left =>0, :top => top-1, :font_size => 7, :alignment => :right})
          top +=12
          ilg +=1
        end
        tax_amount += nice_invoice_number(tax_hash[:tax], prep, {:no_repl=>1}).to_f
      }
      price_with_tax = nice_invoice_number(invoice.converted_price(ex), prep, {:no_repl=>1}).to_f+tax_amount.to_f
    else
      price_with_tax = nice_invoice_number(invoice.converted_price_with_vat(ex), prep, {:no_repl=>1}).to_f
      tax_amount = price_with_tax - invoice.converted_price(ex)
    end

    top = 620
    bottom = 650+ilg*12
    pdf.text(_('SUBTOTAL') + " (#{dc})", {:left => 350, :top => 605, :font_size => 9})
    top =605 + (ilg * 12 )+15
    pdf.text(invoice_total_tax_name(tax).to_s, {:left => 350, :top => top, :font_size => 9})
    pdf.text(_('TOTAL') + " (#{dc})", {:left => 350, :top => top+15, :font_size => 9})
    if Confline.get_value("#{prep.to_s}Invoice_Show_Balance_Line", user.owner_id).to_i == 1
      bottom += 15
      pdf.line(470, top+45, 560, top+45,{:line_width => 1})
      pdf.text(Confline.get_value("#{prep.to_s}Invoice_To_Pay_Line", user.owner_id), {:left => 350, :top => top+29, :font_size => 9})
      balance = owned_balance_from_previous_month(invoice)
      to_pay = price_with_tax
      to_pay += balance[1].to_f if balance
      pdf.text(nice_invoice_number(to_pay.to_f * ex, prep).to_s+"    ", {:left =>0, :top => top+29, :font_size => 9, :alignment=>:right})
    end

    pdf.text(nice_invoice_number(invoice.converted_price(ex).to_f, prep).to_s+"    ", {:left =>0, :top => 602, :font_size => 9, :alignment=>:right})
    pdf.text(nice_invoice_number(tax_amount.to_f, prep).to_s+"    ", {:left =>0, :top => top-1, :font_size => 9, :alignment=>:right})
    pdf.text(nice_invoice_number(price_with_tax.to_f, prep).to_s+"    ", {:left =>0, :top => top+14, :font_size => 9, :alignment=>:right})

    pdf.line(470, 600, 470, bottom, {:line_width => 1})
    pdf.line(560, 600, 560, bottom, {:line_width => 1})
    top = 620 + (ilg * 12 )
    pdf.line(470, top, 560,top,{:line_width => 1})
    pdf.line(470, top+15, 560, top+15,{:line_width => 1})
    pdf.line(470, top+30, 560, top+30,{:line_width => 1})
    return pdf, tax_amount
  end

  def invoice_footer_pdf(pdf, invoice, options = {})
    opts = {
      :show_end_title => true
    }.merge(options)

    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? "Prepaid_" : ""
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line1", owner), {:left =>50, :top => 605, :font_size => 9})
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line2", owner), {:left =>50, :top => 630, :font_size => 9})
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line3", owner), {:left =>50, :top => 645, :font_size => 9})
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line4", owner), {:left =>50, :top => 660, :font_size => 9})
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line5", owner), {:left =>50, :top => 675, :font_size => 9})
    if opts[:show_end_title] == true
      inv_end_title = Confline.get_value("#{prepaid}Invoice_End_Title", owner)
      pdf.text(inv_end_title.to_s, {:left => 0, :top => 770, :font_size =>11, :alignment=>:center})
    end
    pdf
  end

  def generate_invoice_pdf
    opts = {
      :current_page => 12,
      :last_page => 12,
      :all_pages => 12
    }
    invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])
    idetails = invoice.invoicedetails if invoice

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    old_invoice = invoice.clone

    user = invoice.user
    dc = params[:email_or_not] ? user.currency.name : session[:show_currency]
    ex = Currency.count_exchange_rate(session[:default_currency], dc)

    prepaid, prep = invoice_type(invoice, user)
    type = (user.postpaid.to_i == 1 or invoice.user.owner_id != 0) ? "" : "Prepaid_"
    limit = Confline.get_value("#{type}Invoice_page_limit", user.owner).to_i
    company = Confline.get_value("Company",user.owner_id)
    begin
      ###### Generate PDF ########
      pages = PdfGen::Count.pages(idetails.size, 12)
      if Confline.get_value("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id).to_i == 1
        pages = pages + 1
      end
      page = 1

      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")
      pdf = invoice_header_pdf(invoice, pdf, company, dc)
      pdf = invoice_layout_pdf(pdf, {:rows => opts[:current_page], :dc=>dc})
      pdf = invoice_footer_pdf(pdf, invoice, {:show_end_title => (pages == 1), :dc=>dc})
      pdf = PdfGen::Count.page_number(pdf, page, pages)

      i = 0

      for id in idetails
        pdf.text(nice_inv_name(id.name.to_s), {:left => 50, :top => 362+i*20, :font_size => 9})
        qt = ""
        tp = id.converted_price(ex)

        if id.quantity
          qt = id.quantity
          if id.invdet_type > 0 and id.name != 'Calls'
            tp = qt * id.converted_price(ex) if id.price
          else
            tp = id.converted_price(ex) if id.price
          end
        end
        pdf.text(qt.to_s+add_space(54).to_s, {:left => 0, :top => 362+i*20, :font_size => 9, :alignment=>:right})
        pdf.text(nice_number(id.converted_price(ex)).to_s+add_space(30).to_s, {:left => 0, :top => 362+i*20, :font_size => 9, :alignment=>:right})
        pdf.text(nice_number(tp).to_s+add_space(4).to_s, {:left => 0, :top => 362+i*20, :font_size => 9 , :alignment=>:right})

        i += 1
        if i % opts[:current_page] == 0 and idetails.last != id
          i = 0
          page = PdfGen::Count.check_page_number(page, limit)
          pdf.start_new_page
          pdf = invoice_header_pdf(invoice, pdf, company, dc)
          pdf = invoice_layout_pdf(pdf, {:rows => opts[:current_page], :dc=>dc})
          pdf = invoice_footer_pdf(pdf, invoice, {:show_end_title => (page == pages), :dc=>dc})
          pdf = PdfGen::Count.page_number(pdf, page, pages)
        end
      end

      pdf,tax_amount = invoice_total_box_pdf(pdf, invoice, ex, dc)

      if Confline.get_value("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id).to_i == 1
        pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id), {:page=>page+1, :pages=>pages})
      end

    rescue PdfGen::PDFInvoiceLimitError
      pdf = PdfGen::Count.error_message_from_limit(pdf, limit, current_user, invoice)
    end

    filename = Invoice.filename(user, type, "Invoice-#{user.first_name}_#{user.last_name}-#{invoice.user_id}-#{invoice.number}-#{invoice.issue_date}-#{dc}", "pdf")

    if params[:email_or_not]
      return pdf.render
    else
      if params[:test].to_i == 1
        pdf.render
        text = "Ok"
        text += "\n" + old_invoice.to_yaml if old_invoice
        text += "\n" + idetails.to_yaml if idetails
        text += "\n" + prep
        text += "\n" + filename
        text += "\n" + "currency => #{dc}"
        text += "\n" + "tax => #{tax_amount}"
        render :text=> text
      else
        send_data pdf.render, :filename => filename, :type => "application/pdf"
      end
    end
  end


  def invoice_detailed_helper_pdf(pdf, dc)
    pdf.rectangle(40, 340, 520, 20, {:color=>[0.89, 0.88, 0.87]})
    for i in 1..8
      pdf.rectangle(40, 320+i*40, 520, 20,{:color=>[0.89, 0.88, 0.87] ,:fill_color=>[0.89, 0.88, 0.87]})
    end
    pdf.text( _('Direction'), {:left => 50, :top =>343 , :font_size => 8})
    pdf.text( _('Calls_short'), {:left => 370, :top => 343 , :font_size => 8})

    pdf.text(_('Time') , {:left =>440, :top =>343 , :font_size => 8})
    pdf.text(_('Price') + " (#{dc.to_s})", {:left =>495, :top =>343 , :font_size => 8})

    pdf.line(320, 340, 320, 680,{:line_width => 1})

    pdf.line(40, 340, 560, 340,{:line_width => 1})
    pdf.line(40, 360, 560, 360,{:line_width => 1})
    pdf.line(40, 680, 560, 680,{:line_width => 1})

    pdf.line(40, 340, 40, 680,{:line_width => 1})
    pdf.line(560, 340, 560, 680, {:line_width => 1})

    pdf.line(360, 340, 360, 680, {:line_width => 1})
    pdf.line(410, 340, 410, 680, {:line_width => 1})
    pdf.line(490, 340, 490, 680, {:line_width => 1})
    pdf
  end



  def generate_invoice_detailed_pdf
    invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])

    unless invoice
      if params[:action] == "generate_invoice_detailed_pdf"
        flash[:notice] = _("Invoice_not_found")
        redirect_to :controller => :callc, :action => :main and return false
      else
        raise "Invoice_not_found"
      end
    end

    idetails = invoice.invoicedetails

    user = invoice.user
    company = Confline.get_value("Company",user.owner_id)

    prepaid, prep = invoice_type(invoice, user)

    dc = params[:email_or_not] ? user.currency.name : session[:show_currency]
    ex = Currency.count_exchange_rate(session[:default_currency], dc)
    
    default_currency = dc

    tariff_purpose = user.tariff.purpose
    format = Confline.get_value('Date_format', current_user.owner_id).gsub('M', 'i')
    user_price = SqlExport.replace_price('(calls.user_price + calls.did_price + calls.did_inc_price)', {:ex=>ex})
    reseller_price = SqlExport.replace_price('(calls.reseller_price + calls.did_price + calls.did_inc_price)', {:ex=>ex})
    did_price = SqlExport.replace_price('SUM(IF(calls.did_price < 0,calls.did_price, 0 ))', {:ex=>ex, :reference=> 'did_prc'})

    selfcost = SqlExport.replace_price('SUM(provider_price)', {:ex=>ex, :reference=> 'selfcost'})
    user_rate =  SqlExport.replace_price('calls.user_rate', {:ex=>ex, :reference=> 'user_rate'})

    show_zero_calls = user.invoice_zero_calls.to_i
    show_zero_calls == 0  ? zero_calls_sql = " AND calls.user_price > 0 ": zero_calls_sql = ""

    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? "Prepaid_" : ""

    limit = Confline.get_value("#{prepaid}Invoice_page_limit", owner).to_i
    begin

      billsec_cond = Confline.get_value("#{prepaid}Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
      if tariff_purpose == "user"

        sql = "SELECT destinationgroups.id as 'dgid', destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{user_price}) as 'price', #{user_rate}, #{did_price}  " +
          "FROM calls "+
          "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
          "JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)
          WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
          " AND card_id = 0 AND (devices.user_id = '#{user.id}' ) #{zero_calls_sql}" +
          "GROUP BY destinationgroups.id , calls.user_rate "+
          "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"

        if user.usertype == "reseller"
          sql2 = "SELECT destinationgroups.id as 'dgid', destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{reseller_price}) as 'price', #{user_rate}, #{did_price}  " +
            "FROM calls "+
            "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
            "WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
            " AND card_id = 0 AND (calls.reseller_id = '#{user.id}' ) #{zero_calls_sql}" +
            "GROUP BY destinationgroups.id, calls.user_rate "+
            "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"
        end
      else
        #wholesale

        sql = "SELECT calls.user_rate as 'user_rate', destinations.id as 'dgid',  directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type',  COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{user_price}) as 'price', #{did_price}  FROM calls 	JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix) 	JOIN directions  ON (destinations.direction_code = directions.code) WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED'  AND card_id = 0 AND (devices.user_id =  '#{user.id}' ) #{zero_calls_sql} GROUP BY destinations.id, calls.user_rate ORDER BY destinations.name ASC, destinations.subcode ASC"

        if user.usertype == "reseller"
          sql2 = "SELECT calls.user_rate as 'user_rate', destinations.id as 'dgid',  directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type',  COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{reseller_price}) as 'price', #{did_price}  FROM calls JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)  LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  JOIN directions  ON (destinations.direction_code = directions.code) WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED'  AND card_id = 0 AND (calls.reseller_id =  '#{user.id}' )  #{zero_calls_sql} GROUP BY destinations.id, calls.user_rate ORDER BY destinations.name ASC, destinations.subcode ASC"
        end
      end

      res_arr = []
      res = ActiveRecord::Base.connection.select_all(sql)
      res_arr << res if params[:test].to_i == 1
      #    MorLog.my_debug sql
      if user.usertype == "reseller"
        res2 = ActiveRecord::Base.connection.select_all(sql2)
        res_arr << res2 if params[:test].to_i == 1
        #      MorLog.my_debug sql2
      end

      total_calls = 0
      total_time = 0
      total_did = 0
      #if prep != "prepaid"
      for r in res
        total_calls += r["calls"].to_i
        total_time += r["billsec"].to_i
        total_did += r["did_prc"].to_f
      end

      if user.usertype == "reseller"
        for r in res2
          total_calls += r["calls"].to_i
          total_time += r["billsec"].to_i
          total_did += r["did_prc"].to_f if r["did_prc"].to_f < 0.to_f
        end
      end
      #end

      lines_in_pdf = 16


      ###### Generate PDF ########http://trac.kolmisoft.com/trac/ticket/3488
      

      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")
      pdf = invoice_header_pdf(invoice,pdf,company, dc)
      pdf.text(_('Credit_for_incoming_calls') + ": " + sprintf("%0.#{2}f",total_did.to_f) + " " + default_currency.to_s, {:left => 40, :top => 322, :font_size => 8})
      pdf = invoice_detailed_helper_pdf(pdf, dc)

      details_y = 362

      idetails_count = 0
      i = 0
      page = 1
      for id in idetails

        if id.invdet_type > 0 and id.name != 'Calls'

          idetails_count += 1

          pdf.text(nice_inv_name(id.name.to_s).to_s, {:left =>50, :top => details_y+i*20, :font_size => 9})
          if id.quantity
            qt = id.quantity
            tp = qt * id.converted_price(ex) if id.price
          else
            qt = ""
            tp = id.converted_price(ex)
          end
          pdf.text(qt, {:left =>330, :top =>details_y+i*20 , :font_size => 9})
          pdf.text(nice_number(tp).to_s+"   ", {:left =>0, :top =>details_y+i*20 , :font_size => 9, :alignment => :right})

          i += 1
          if i % 16 == 0 and idetails.last != id
            i = 0
            page = PdfGen::Count.check_page_number(page, limit)
            pdf.start_new_page
            pdf = invoice_header_pdf(invoice, pdf,company)
            pdf.text(_('Credit_for_incoming_calls') + ": " + sprintf("%0.#{2}f",total_did.to_f) + " " + default_currency.to_s, {:left => 40, :top => 322, :font_size => 8})
            pdf = invoice_detailed_helper_pdf(pdf, dc)
          end

        else

        end

      end

      dgids = []
      ti = 0

      # sizes for arrays

      res1_size = 0
      res1_size = res.size if res

      res2_size = 0
      res2_size = res2.size if user.usertype == "reseller" and res2



      res_sizes = idetails_count + res1_size + res2_size

      total_pages = (res_sizes.to_f / lines_in_pdf.to_f).ceil

      for r in res

        dgids << [r["dgid"], r["user_rate"]] if !dgids.include?([r["dgid"], r["user_rate"]])
        pdf.text(r["dg_name"].to_s, {:left =>50, :top =>details_y+i*20 , :font_size => 9})
        pdf.text(r["dg_type"].to_s, {:left =>325, :top => details_y+i*20, :font_size => 9})
        pdf.text( r["calls"].to_s, {:left =>395-(pdf.text_width(r["calls"].to_s)-(r["calls"].to_s.size*5)), :top =>details_y+i*20 , :font_size => 9})
        pdf.text(nice_time(r["billsec"]), {:left =>430, :top => details_y+i*20, :font_size => 9})
        pdf.text(nice_number(r["price"])+"   ", {:left =>0, :top => details_y+i*20, :font_size => 9, :alignment => :right})

        i += 1
        ti += 1

        if i  == lines_in_pdf and page < total_pages
          i = 0
          page = PdfGen::Count.check_page_number(page, limit)
          pdf.start_new_page
          pdf = invoice_header_pdf(invoice, pdf, company, dc)
          pdf.text(_('Credit_for_incoming_calls') + ": " + sprintf("%0.#{2}f",total_did.to_f) + " " + default_currency.to_s, {:left => 40, :top => 322, :font_size => 8})
          pdf = invoice_detailed_helper_pdf(pdf, dc)

        end
      end

      # reseller calls
      if user.usertype == "reseller"
        ti = 0
        for r in res2

          dgids << [r["dgid"], r["user_rate"]] if !dgids.include?([r["dgid"], r["user_rate"]])
          pdf.text(r["dg_name"].to_s, {:left =>50, :top =>details_y+i*20 , :font_size => 9})
          pdf.text(r["dg_type"].to_s, {:left =>325, :top => details_y+i*20, :font_size => 9})
          pdf.text( r["calls"].to_s, {:left =>395-(pdf.text_width(r["calls"].to_s)-(r["calls"].to_s.size*5)), :top =>details_y+i*20 , :font_size => 9})
          pdf.text(nice_time(r["billsec"]).to_s, {:left =>430, :top => details_y+i*20, :font_size => 9})
          pdf.text(nice_number(r["price"]).to_s+"   ", {:left =>0, :top => details_y+i*20, :font_size => 9, :alignment => :right})

          i += 1
          ti += 1
          if i  == lines_in_pdf and page < total_pages
            #new page
            i = 0
            page = PdfGen::Count.check_page_number(page, limit)
            pdf.start_new_page
            pdf = invoice_header_pdf(invoice, pdf, company)
            pdf.text(_('Credit_for_incoming_calls') + ": " + sprintf("%0.#{2}f",total_did.to_f) + " " + default_currency.to_s, {:left => 40, :top => 322, :font_size => 8})
            pdf = invoice_detailed_helper_pdf(pdf, dc)
          end
        end
      end # reseller calls

      #end

      pdf, tax_amount = detailed_invoice_tax_box(pdf, invoice, total_calls, total_time, dc,ex)
      pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line1", user.owner_id).to_s, {:left =>50, :top =>685 , :font_size => 9})
      pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line2", user.owner_id).to_s, {:left =>50, :top =>700 , :font_size => 9})
      pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line3", user.owner_id).to_s, {:left =>50, :top =>715 , :font_size => 9})
      pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line4", user.owner_id).to_s, {:left =>50, :top =>730 , :font_size => 9})
      pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line5", user.owner_id).to_s, {:left =>50, :top =>745 , :font_size => 9})

      inv_end_title = Confline.get_value("#{prepaid}Invoice_End_Title", user.owner_id)

      pdf.text(inv_end_title.to_s, {:left =>0, :top => (740 + 33), :font_size => 12, :alignment => :center})

      has_calls = 0
      for invd in idetails
        has_calls = 1 if invd.invdet_type == 0
      end

      #every call
      if Confline.get_value("#{prepaid}Invoice_Show_Calls_In_Detailed", user.owner_id).to_i == 1 and has_calls == 1
        page = PdfGen::Count.check_page_number(page, limit)
        pdf.start_new_page

        font_size = 5
        lines_per_page = 80
        line_height=9
        line = 1
        ystart = 20

        # print outgoing calls

        dgids.compact.each do |val|
         
          dgid = val[0]
          user_rate = val[1]
          if tariff_purpose == "user"

            sql = "SELECT destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type', #{SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', { :format=>format, :tz=>current_user.time_zone}), "calldate")}, calls.#{billsec_cond}, #{user_price} as user_price, #{reseller_price} as reseller_price, calls.dst  FROM calls JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id AND destinationgroups.id = #{dgid}) WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (devices.user_id = #{user.id} AND calls.user_rate = #{user_rate}) ORDER BY calls.calldate ASC"

            if user.usertype == "reseller"
              sql2 = "SELECT destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type', #{SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', { :format=>format, :tz=>current_user.time_zone}), "calldate")}, calls.#{billsec_cond}, #{user_price} as user_price, #{reseller_price} as reseller_price, calls.dst  FROM calls LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id AND destinationgroups.id = #{dgid}) WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (calls.reseller_id = #{user.id} AND calls.user_rate = #{user_rate} ) ORDER BY calls.calldate ASC"
            end

          else

            sql = "SELECT destinations.id, directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type', #{SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', { :format=>format, :tz=>current_user.time_zone}), "calldate")}, calls.#{billsec_cond}, #{user_price} as user_price, #{reseller_price} as reseller_price, calls.dst  FROM calls 	JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  	JOIN directions  ON (destinations.direction_code = directions.code AND destinations.id = #{dgid}) WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (devices.user_id = #{user.id} AND calls.user_rate = #{user_rate}) ORDER BY calls.calldate ASC"

            if user.usertype == "reseller"
              sql2 = "SELECT destinations.id, directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type', #{SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', { :format=>format, :tz=>current_user.time_zone}), "calldate")},  calls.#{billsec_cond}, #{user_price} as user_price, #{reseller_price} as reseller_price, calls.dst  FROM calls   LEFT JOIN destinations ON (destinations.prefix = calls.prefix)    JOIN directions  ON (destinations.direction_code = directions.code AND destinations.id = #{dgid}) WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (calls.reseller_id = #{user.id} AND calls.user_rate = #{user_rate}) ORDER BY calls.calldate ASC"
            end
          end
          res = ActiveRecord::Base.connection.select_all(sql)
          res_arr << res if params[:test].to_i == 1

          if user.usertype == "reseller"
            res2 = ActiveRecord::Base.connection.select_all(sql2)
            res_arr << res2 if params[:test].to_i == 1
          end

          if res.size > 0 or (user.usertype == "reseller" and res2.size > 0)

            if (res.size > 0)
              pdf.text(res[0]["dg_name"].to_s + " " + res[0]["dg_type"].to_s, {:left =>50, :top => ystart+line*line_height, :font_size => font_size}) if tariff_purpose == "user"
              pdf.text(res[0]["dg_name"].to_s + " " + res[0]["prefix"].to_s + " " + res[0]["dg_type"].to_s, {:left =>50, :top =>ystart+line*line_height , :font_size => font_size}) if tariff_purpose != "user"

              line, page = line_increment(pdf, line, lines_per_page, page, limit)
              pdf.text(_('Calldate'), {:left =>50, :top => ystart+line*line_height, :font_size => font_size})
              pdf.text(_('Billsec'), {:left =>180, :top => ystart+line*line_height, :font_size => font_size})
              pdf.text(_('Destination'), {:left =>250, :top => ystart+line*line_height, :font_size => font_size})
              pdf.text(_('Price') + " (#{dc})", {:left =>400, :top => ystart+line*line_height, :font_size => font_size})

              line, page = line_increment(pdf, line, lines_per_page, page, limit)
              tprice = 0
              for r in res
                pdf.text(r["calldate"].to_s, {:left =>50, :top =>ystart+line*line_height , :font_size => font_size})
                ll = 4
                tl = r["#{billsec_cond}"].to_s.length * ll
                pdf.text(r["#{billsec_cond}"].to_s, {:left =>200 - tl, :top => ystart+line*line_height, :font_size => font_size})
                if params[:email_or_not]
                  pdf.text(hide_dst_for_user(user, "pdf", r["dst"].to_s), {:left =>250, :top => ystart+line*line_height, :font_size => font_size})
                else
                  pdf.text(hide_dst_for_user(current_user, "pdf", r["dst"].to_s), {:left =>250, :top => ystart+line*line_height, :font_size => font_size})
                end

                tl = nice_number(r["user_price"]).to_s.length * ll

                pdf.text(nice_number(r["user_price"]).to_s, {:left =>425 - tl, :top => ystart+line*line_height, :font_size => font_size})
                tprice += r["user_price"].to_f

                line, page = line_increment(pdf, line, lines_per_page, page, limit)
              end
            end

            if (user.usertype == "reseller"  and res2.size > 0)
              res = res2
              pdf.text(res[0]["dg_name"].to_s + " " + res[0]["dg_type"].to_s, {:left =>50, :top => ystart+line*line_height, :font_size => font_size}) if tariff_purpose == "user"
              pdf.text(res[0]["dg_name"].to_s + " " + res[0]["prefix"].to_s + " " + res[0]["dg_type"].to_s, {:left =>50, :top =>ystart+line*line_height , :font_size => font_size}) if tariff_purpose != "user"

              line, page = line_increment(pdf, line, lines_per_page, page, limit)
              pdf.text(_('Calldate'), {:left =>50, :top => ystart+line*line_height, :font_size => font_size})
              pdf.text(_('Billsec'), {:left =>180, :top => ystart+line*line_height, :font_size => font_size})
              pdf.text(_('Destination'), {:left =>250, :top => ystart+line*line_height, :font_size => font_size})
              pdf.text(_('Price') + " (#{dc})", {:left =>400, :top => ystart+line*line_height, :font_size => font_size})

              line, page = line_increment(pdf, line, lines_per_page, page, limit)
              tprice = 0
              for r in res
                pdf.text(r["calldate"].to_s, {:left =>50, :top =>ystart+line*line_height , :font_size => font_size})
                ll = 4
                tl = r["#{billsec_cond}"].to_s.length * ll
                pdf.text(r["#{billsec_cond}"].to_s, {:left =>200 - tl, :top => ystart+line*line_height, :font_size => font_size})
                if params[:email_or_not]
                  pdf.text(hide_dst_for_user(user, "pdf", r["dst"].to_s), {:left =>250, :top => ystart+line*line_height, :font_size => font_size})
                else
                  pdf.text(hide_dst_for_user(current_user, "pdf", r["dst"].to_s), {:left =>250, :top => ystart+line*line_height, :font_size => font_size})
                end
                tl = nice_number(r["reseller_price"]).to_s.length * ll

                pdf.text(nice_number(r["reseller_price"]).to_s, {:left =>425 - tl, :top => ystart+line*line_height, :font_size => font_size})
                tprice += r["reseller_price"].to_f

                line, page = line_increment(pdf, line, lines_per_page, page, limit)
              end
            end

            tpvat = nice_number(user.get_tax.count_tax_amount(tprice)).to_f
            pdf.text(_('Total_calls_invoice') + ": " + res.size.to_s + ", " + _('price_invoice') + ": " + nice_number(tprice).to_s + " (" + nice_number(tpvat).to_s + ")", {:left =>50, :top => ystart+line*line_height, :font_size => font_size})
            line, page = line_increment(pdf, line, lines_per_page, page, limit)
            line, page = line_increment(pdf, line, lines_per_page, page, limit)
          end
        end
      end

      if Confline.get_value("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id).to_i == 1
        pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id))
      end

    rescue PdfGen::PDFInvoiceLimitError
      pdf = PdfGen::Count.error_message_from_limit(pdf, limit, current_user, invoice)
    end

    if params[:email_or_not]
      return  pdf.render
    else
      filename = Invoice.filename(user, prep, "Invoice_detailed-#{user.first_name}_#{user.last_name}-#{invoice.user_id}-#{invoice.number}-#{invoice.issue_date}", "pdf")
      if params[:test].to_i == 1
        pdf.render
        text = "Ok"
        res_arr.each{|r|
          text += "\n" + r.to_yaml if r
        }
        text += "\n" + prepaid
        text += "\n" + filename
        text += "\n" + "currency => #{dc}"
        text += "\n" + "tax => #{tax_amount}"
        render :text=> text
      else
        send_data pdf.render, :filename => filename, :type => "application/pdf"
      end
    end

  end

  def add_space (space)
    space = space.to_i
    sp = ""
    space.times do
      sp += " "
    end
    sp
  end

  def generate_invoice_by_cid_pdf
    invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    dc = current_user.currency.name

    idetails = invoice.invoicedetails
    user = invoice.user

    dc = params[:email_or_not] ? user.currency.name : session[:show_currency]
    ex = Currency.count_exchange_rate(session[:default_currency], dc)

    company = Confline.get_value("Company",user.owner_id)

    format = Confline.get_value('Date_format', current_user.owner_id).gsub('M', 'i')

    prepaid, prep = invoice_type(invoice, user)
    pdf = PDF::Wrapper.new(:paper => :A4)
    pdf.font("Nimbus Sans L")
    pdf = invoice_header_pdf(invoice, pdf, company)

    user_price = SqlExport.replace_price('(calls.user_price + calls.did_price + calls.did_inc_price)', {:ex=>ex})

    show_zero_calls = user.invoice_zero_calls.to_i
    if show_zero_calls == 0
      zero_calls_sql = " AND calls.user_price > 0 "
    else
      zero_calls_sql = ""
    end
    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? "Prepaid_" : ""
    limit = Confline.get_value("#{prepaid}Invoice_page_limit", owner).to_i
    begin
      page=1
      did_sql_price = SqlExport.replace_price('calls.did_price', {:ex=>ex, :reference=>'did_price'})
      did_inc_sql_price = SqlExport.replace_price('calls.did_inc_price', {:ex=>ex, :reference=>'did_inc_price'})
      #did_sql_price = SqlExport.replace_price('calls.did_price', 'did_price')
      #selfcost = SqlExport.replace_price('SUM(provider_price)', 'selfcost')
      calldate = SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format=>format}), "calldate")
      user_rate =  SqlExport.replace_price('calls.user_rate', {:ex=>ex, :reference=> 'user_rate'})

      billsec_cond = Confline.get_value("#{prepaid}Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
      # with incoming calls - not used anymore
      sql = "SELECT * FROM
             ((SELECT calls.src, #{did_sql_price}, #{did_inc_sql_price} FROM calls WHERE user_id = #{user.id} AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 AND card_id = 0 #{zero_calls_sql})
              UNION
             (SELECT calls.src, #{did_sql_price}, #{did_inc_sql_price} FROM calls JOIN devices ON (calls.dst_device_id = devices.id) WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_price > 0 )
              UNION
             (SELECT calls.src, #{did_sql_price}, #{did_inc_sql_price} FROM calls JOIN devices ON (calls.src_device_id = devices.id) WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_inc_price > 0 )
               ) AS b
           GROUP BY b.src ORDER BY b.src ASC"

      # incoming calls disabled
      sql = "SELECT calls.src, #{did_sql_price}, #{did_inc_sql_price} FROM calls JOIN devices ON (calls.src_device_id = devices.id) WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 AND card_id = 0 #{zero_calls_sql} GROUP BY calls.src;"

      cids = ActiveRecord::Base.connection.select_all(sql)
      space = 150
      font_size = 5
      lines_per_page = 80
      line_height=9
      line = 35
      ystart = 20
      x_margin = 40

      ttp = 0

      calls_to_test = []

      for cid in cids
        src = cid["src"]
        if cid["did_price"].to_f == 0.to_f and cid["did_inc_price"].to_f == 0.to_f
          sql = "SELECT dst, #{calldate}, #{billsec_cond} as billsec, #{did_inc_sql_price}, #{did_sql_price}, #{user_rate}, #{user_price} as 'user_price', directions.name as 'direction' FROM calls LEFT JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED'  AND billsec > 0 AND card_id = 0  AND calls.src = '#{src}' #{zero_calls_sql} ORDER BY calls.calldate ASC"
        else
          #          if cid["did_price"].to_f > 0.to_f
          #            sql = "SELECT dst, #{calldate}, #{billsec_cond} as billsec, #{did_sql_price}, #{did_inc_sql_price}, #{user_rate}, #{user_price} as 'user_price', directions.name as 'direction' FROM calls JOIN devices ON (calls.dst_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_price > 0 AND calls.src = '#{src}' ORDER BY calls.calldate ASC;"
          #          else
          sql = "SELECT dst, #{calldate}, #{billsec_cond} as billsec, #{did_sql_price}, #{did_inc_sql_price}, #{user_rate}, #{user_price} as 'user_price', directions.name as 'direction' FROM calls JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_inc_price > 0 AND calls.src = '#{src}' ORDER BY calls.calldate ASC;"
          #          end
        end
        calls = ActiveRecord::Base.connection.select_all(sql)
        if params[:test].to_i == 1
          calls_to_test << calls
        end


        client_number = _('Client_number') + ":         " + src
        pdf.text(client_number, {:left =>x_margin, :top => ystart+line*line_height, :font_size => font_size})

        line, page = line_increment(pdf, line, lines_per_page, page, limit)
        line, page = line_increment(pdf, line, lines_per_page, page, limit)
        pdf.text(_('Number'), {:left =>x_margin, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text( _('Date'), {:left =>x_margin + 80, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(_('Duration'), {:left =>x_margin + 170, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(_('Rate'), {:left =>x_margin + 230, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(_('Price') + " (#{dc})", {:left =>x_margin + 290, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(_('Destination'), {:left =>x_margin + 350, :top => ystart+line*line_height, :font_size => font_size})

        line, page = line_increment(pdf, line, lines_per_page, page, limit)

        for call in calls
          if params[:email_or_not]
            pdf.text(hide_dst_for_user(user, "pdf", call["dst"].to_s), {:left =>x_margin, :top => ystart+line*line_height, :font_size => font_size})
          else
            pdf.text(hide_dst_for_user(current_user, "pdf", call["dst"].to_s), {:left =>x_margin, :top => ystart+line*line_height, :font_size => font_size})
          end
          pdf.text(call["calldate"].to_s, {:left =>x_margin + 80, :top => ystart+line*line_height, :font_size => font_size})
          pdf.text(nice_time(call["billsec"]).to_s, {:left =>x_margin + 170, :top => ystart+line*line_height, :font_size => font_size})
          pdf.text(nice_number(call["user_rate"]).to_s, {:left =>x_margin + 230, :top => ystart+line*line_height, :font_size => font_size})
          pdf.text(nice_number(call["user_price"]).to_s, {:left =>x_margin + 290, :top => ystart+line*line_height, :font_size => font_size})
          pdf.text(call["direction"].to_s, {:left =>x_margin + 350, :top => ystart+line*line_height, :font_size => font_size})

          line, page = line_increment(pdf, line, lines_per_page, page, limit)

        end

        line, page = line_increment(pdf, line, lines_per_page, page, limit)
        if cid["did_price"].to_f == 0.to_f and cid["did_inc_price"].to_f == 0.to_f
          sql = "SELECT directions.name as 'direction', SUM(#{user_price}) as 'price', COUNT(calls.src) as 'calls' FROM calls LEFT JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND card_id = 0  AND calls.src = '#{src}' GROUP BY directions.name ORDER BY directions.name ASC"
        else
          #          if cid["did_price"].to_f > 0.to_f
          #            sql = "SELECT directions.name as 'direction', SUM(#{user_price}) as 'price', COUNT(calls.src) as 'calls' FROM calls JOIN devices ON (calls.dst_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_price > 0 AND calls.src = '#{src}' GROUP BY directions.name ORDER BY directions.name ASC"
          #          else
          sql = "SELECT directions.name as 'direction', SUM(#{user_price}) as 'price', COUNT(calls.src) as 'calls' FROM calls JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_inc_price > 0 AND calls.src = '#{src}' GROUP BY directions.name ORDER BY directions.name ASC"
        end
        #        end
        directions = ActiveRecord::Base.connection.select_all(sql)

        total_price = 0.0
        for dir in directions
          pdf.text(dir["direction"].to_s+add_space(space), {:left =>0, :top => ystart+line*line_height, :font_size => font_size, :alignment => :right} )

          pdf.text(nice_number(dir["price"]).to_s, {:left =>x_margin+290, :top => ystart+line*line_height, :font_size => font_size})
          curr = dc.to_s + " (" + _('Without_VAT') + ")"
          pdf.text(curr.to_s, {:left =>x_margin+350, :top => ystart+line*line_height, :font_size => font_size})

          total_price += dir["price"].to_f

          line, page = line_increment(pdf, line, lines_per_page, page, limit)

        end

        total = _('Total') + ":"
        pdf.text(total.to_s+add_space(space).to_s, {:left =>0, :top =>ystart+line*line_height , :font_size => font_size, :alignment => :right})


        pdf.text(nice_number(total_price).to_s, {:left =>x_margin+290, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(curr.to_s, {:left =>x_margin+350, :top => ystart+line*line_height, :font_size => font_size})

        ttp += total_price.to_f

        line, page = line_increment(pdf, line, lines_per_page, page, limit)
        line, page = line_increment(pdf, line, lines_per_page, page, limit)

      end

      sql = "SELECT COUNT(calls.id) as calls_size, SUM(#{billsec_cond}) as billsec, SUM(#{user_price}) as 'user_price' FROM calls JOIN devices ON (calls.dst_device_id = devices.id) WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 AND card_id = 0 #{zero_calls_sql};"
      
      in_calls = ActiveRecord::Base.connection.select_all(sql)

      if in_calls and in_calls[0]['calls_size'].to_i > 0
        pdf.text(_('incoming_calls'), {:left =>x_margin, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(_('Duration'), {:left =>x_margin + 170, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(_('Price') + " (#{dc})", {:left =>x_margin + 290, :top => ystart+line*line_height, :font_size => font_size})
        line, page = line_increment(pdf, line, lines_per_page, page, limit)
        pdf.text(nice_time(in_calls[0]["billsec"]).to_s, {:left =>x_margin + 170, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(nice_number(in_calls[0]["user_price"]).to_s, {:left =>x_margin + 290, :top => ystart+line*line_height, :font_size => font_size})

        line, page = line_increment(pdf, line, lines_per_page, page, limit)
        ttp += in_calls[0]["user_price"].to_f
        line += 1
      end
      
      for id in idetails
        if id.invdet_type > 0 and id.name != 'Calls'
          pdf.text(nice_inv_name(id.name.to_s).to_s+add_space(space), {:left =>0, :top =>ystart+line*line_height , :font_size => font_size, :alignment => :right})
          pdf.text(nice_number(id.converted_price(ex)).to_s, {:left =>x_margin+290, :top =>ystart+line*line_height , :font_size => font_size})
          pdf.text(curr.to_s, {:left =>x_margin+350, :top =>ystart+line*line_height , :font_size => font_size})

          ttp += id.price.to_f

          line, page = line_increment(pdf, line, lines_per_page, page, limit)

        end
      end

      line, page = line_increment(pdf, line, lines_per_page, page, limit)
      pdf.text(_('Subtotal') + ":"+add_space(space).to_s, {:left =>0, :top => ystart+line*line_height, :font_size => font_size, :alignment => :right})

      pdf.text(nice_invoice_number(ttp, prep).to_s, {:left =>x_margin+290, :top => ystart+line*line_height, :font_size => font_size})
      pdf.text(curr.to_s, {:left =>x_margin+350, :top => ystart+line*line_height, :font_size => font_size})
      tax_amount = 0
      if invoice.tax
        tax = invoice.tax
        taxes = tax.applied_tax_list(ttp, :precision => nice_invoice_number_digits(prep), :x=>ex)

        taxes.each { |tax_hash|
          if tax.get_tax_count > 1
            line, page = line_increment(pdf, line, lines_per_page, page, limit)
            pdf.text(tax_hash[:name].to_s + "(" + tax_hash[:value].to_s + "%):"+add_space(space), {:left =>0, :top => ystart+line*line_height, :font_size => font_size, :alignment => :right})
            pdf.text(nice_invoice_number(tax_hash[:tax], prep).to_s, {:left =>x_margin+290, :top => ystart+line*line_height, :font_size => font_size})
          end
          tax_amount += nice_invoice_number(tax_hash[:tax], prep, {:no_repl=>1}).to_f
        }
        price_with_tax = nice_invoice_number(ttp, prep, {:no_repl=>1}).to_f + tax_amount
      else
        tax = user.get_tax
        price_with_tax = nice_invoice_number(invoice.converted_price_with_vat(ex), prep, {:no_repl=>1}).to_f
        tax_amount = price_with_tax - nice_invoice_number(invoice.converted_price(ex), prep, {:no_repl=>1}).to_f
      end
      line, page = line_increment(pdf, line, lines_per_page, page, limit)
      pdf.text(invoice_total_tax_name(tax).to_s + ":"+add_space(space), {:left =>0, :top => ystart+line*line_height, :font_size => font_size, :alignment => :right})

      pdf.text(nice_invoice_number(tax_amount, prep).to_s, {:left =>x_margin+290, :top => ystart+line*line_height, :font_size => font_size})
      pdf.text(curr.to_s, {:left =>x_margin+350, :top => ystart+line*line_height, :font_size => font_size})
      # TOTAL
      line, page = line_increment(pdf, line, lines_per_page, page, limit)
      pdf.text(_('TOTAL') + ":"+add_space(space).to_s, {:left =>0, :top => ystart+line*line_height, :font_size => font_size, :alignment => :right})
      pdf.text(nice_invoice_number(price_with_tax, prep).to_s, {:left =>x_margin+290, :top => ystart+line*line_height, :font_size => font_size})
      # TO PAY
      prepaid, prep = invoice_type(invoice, user)
      if Confline.get_value("#{prepaid.to_s}Invoice_Show_Balance_Line", user.owner_id).to_i == 1
        line, page = line_increment(pdf, line, lines_per_page, page, limit)
        balance = owned_balance_from_previous_month(invoice)
        to_pay = price_with_tax
        to_pay += balance[1].to_f if balance
        pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_To_Pay_Line", user.owner_id) + ":"+add_space(space).to_s, {:left =>0, :top => ystart+line*line_height, :font_size => font_size, :alignment => :right})
        pdf.text(nice_invoice_number(to_pay, prep).to_s, {:left =>x_margin+290, :top => ystart+line*line_height, :font_size => font_size})
        pdf.text(curr.to_s, {:left =>x_margin+350, :top => ystart+line*line_height, :font_size => font_size})
      end

      inv_end_title = Confline.get_value("#{prepaid}Invoice_End_Title",user.owner_id)
      pdf.text(inv_end_title.to_s, {:left =>0, :top =>770 , :font_size => 11, :alignment => :center})

      if Confline.get_value("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id).to_i == 1
        pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id))
      end

    rescue PdfGen::PDFInvoiceLimitError
      pdf = PdfGen::Count.error_message_from_limit(pdf, limit, current_user, invoice)
    end

    if params[:email_or_not]
      return pdf.render
    else
      filename = Invoice.filename(user, prep, "Invoice_by_cid-#{user.first_name}_#{user.last_name}-#{invoice.user_id}-#{invoice.number}-#{invoice.issue_date}", "pdf")
      if params[:test].to_i == 1
        pdf.render
        text = "Ok"
        text += "\n" + calls_to_test.to_yaml if calls_to_test
        text += "\n" + directions.to_yaml if directions
        text += "\n" + prepaid
        text += "\n" + filename
        text += "\n" + "total => #{price_with_tax}"
        text += "\n" + "currency => #{dc}"
        text += "\n" + "tax => #{tax_amount}"
        text += "\n" + in_calls.to_yaml if in_calls
        render :text=> text
      else
        send_data pdf.render, :filename => filename, :type => "application/pdf"
      end
    end

  end


  def line_increment(pdf, line, lines_per_page, page, limit)
    line += 1
    if line % lines_per_page == 0
      page = PdfGen::Count.check_page_number(page, limit)
      pdf.start_new_page
      line = 1
    end
    return line, page
  end

  def generate_invoice_csv
    invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])

    unless invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    user = invoice.user
    sep, dec = user.csv_params


    dc = params[:email_or_not] ? user.currency.name : session[:show_currency]
    ex = Currency.count_exchange_rate(session[:default_currency], dc)

    csv_string = ["number#{sep}user_id#{sep}period_start#{sep}period_end#{sep}issue_date#{sep}price (#{dc})#{sep}price_with_tax (#{dc})#{sep}accounting_number"]
    csv_string << "#{invoice.number.to_s}#{sep}#{invoice.user_id}#{sep}#{invoice.period_start}#{sep}#{invoice.period_end}#{sep}#{invoice.issue_date}#{sep}#{nice_invoice_number(invoice.converted_price(ex), invoice.invoice_type).to_s.gsub(".", dec).to_s}#{sep}#{nice_invoice_number(invoice.price_with_tax(:ex=>ex, :precision => nice_invoice_number_digits(invoice.invoice_type)), invoice.invoice_type).to_s.gsub(".", dec).to_s}#{sep}#{user.accounting_number}"
    #  my_debug csv_string
    prepaid, prep = invoice_type(invoice, user)
    filename = Invoice.filename(user, prep, "Invoice-#{user.first_name}_#{user.last_name}-#{invoice.user_id}-#{invoice.number}-#{invoice.issue_date}-#{dc}", "csv")

    if params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"),   :type => 'text/csv; charset=utf-8; header=present',  :filename => filename)
      end
    end
  end

  def generate_invoice_detailed_csv
    invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])

    unless invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    idetails = invoice.invoicedetails
    user = invoice.user

    dc = params[:email_or_not] ? user.currency.name : session[:show_currency]
    ex = Currency.count_exchange_rate(session[:default_currency], dc)

    sep, dec = user.csv_params

    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? "Prepaid_" : ""

    billsec_cond = Confline.get_value("#{prepaid}Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
    user_price = SqlExport.replace_price('(calls.user_price + calls.did_price + calls.did_inc_price)', {:ex=>ex})
    reseller_price = SqlExport.replace_price('(calls.reseller_price + calls.did_price + calls.did_inc_price)', {:ex=>ex})
    did_sql_price = SqlExport.replace_price('calls.did_price', {:ex=>ex , :reference=> 'did_price'})
    did_inc_sql_price = SqlExport.replace_price('calls.did_inc_price', {:ex=>ex, :reference=>'did_inc_price'})
    #did_sql_price = SqlExport.replace_price('calls.did_price', 'did_price')
    selfcost = SqlExport.replace_price('SUM(provider_price)', {:ex=>ex, :reference=>'selfcost'})
    user_rate =  SqlExport.replace_price('calls.user_rate', {:ex=>ex, :reference=> 'user_rate'})

    csv_string = []

    for id in idetails
      if id.invdet_type > 0
        sub = 1
      end
    end

    if idetails
      if sub.to_i == 1
        csv_string << "services#{sep}quantity#{sep}price"
      end

      total_price=0
      for id in idetails
        #MorLog.my_debug(id.to_yaml)
        @iprice= id.price if id.price
        if id.invdet_type > 0
          if id.invdet_type > 0
            if id.quantity
              qt = id.quantity
              tp = qt * id.converted_price(ex) if id.price
            else
              qt = ""
              tp = id.converted_price(ex)
            end
            csv_string << "#{nice_inv_name(id.name)}#{sep}#{ nice_number(qt)}#{sep}#{nice_number(tp).to_s.gsub(".",dec).to_s}"
          end
        end
      end
    end

    show_zero_calls = user.invoice_zero_calls.to_i
    if show_zero_calls == 0
      zero_calls_sql = " AND calls.user_price > 0 "
    else
      zero_calls_sql = ""
    end

    sql = "SELECT #{user_rate}, destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{user_price}) as 'price'  " +
      "FROM calls "+
      "JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)
        LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  "+
      "JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
      "WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
      " AND card_id = 0 AND devices.user_id = '#{user.id}'  #{zero_calls_sql}" +
      "GROUP BY destinationgroups.id, calls.user_rate "+
      "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"

    if user.usertype == "reseller"
      sql2 = "SELECT
calls.dst,  COUNT(*) as 'count_calls', SUM(#{billsec_cond}) as 'sum_billsec', #{selfcost}, SUM(#{reseller_price}) as 'price', #{user_rate}  " +
        "FROM calls "+
        "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
        "WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
        " AND card_id = 0 AND (calls.reseller_id = '#{user.id}' ) #{zero_calls_sql}" +
        "GROUP BY destinationgroups.id, calls.user_rate "+
        "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"
    end

    res = ActiveRecord::Base.connection.select_all(sql)
    if user.usertype == "reseller"
      res2 = ActiveRecord::Base.connection.select_all(sql2)
    end

    if res != []
      csv_string << "number#{sep}accounting_number#{sep}country#{sep}type#{sep}rate#{sep}calls#{sep}billsec#{sep}price (#{dc})"
    end

    for r in res

      country = r["dg_name"]
      type = r["dg_type"]
      calls = r["calls"]
      billsec = r["billsec"]
      rate = r["user_rate"]
      price = r["price"]
      csv_string << "#{invoice.number.to_s}#{sep}#{user.accounting_number.to_s.blank? ? ' ' : user.accounting_number.to_s}#{sep}#{country}#{sep}#{type}#{sep}#{rate}#{sep}#{calls}#{sep}#{billsec}#{sep}#{nice_number(price).to_s.gsub(".",dec).to_s}"
    end

    params[:email_or_not] ? req_user = user : req_user = current_user

    if user.usertype == 'reseller' and res2
      csv_string << "\n" + _('Calls_from_users') + ":"
      csv_string << "#{_('DID')}#{sep}#{_('Calls')}#{sep}#{_('Total_time')}#{sep}#{_('Price')}(#{dc})"
      for r in res2
        csv_string << "#{hide_dst_for_user(req_user, "csv", r["dst"].to_s)}#{sep}#{r["count_calls"].to_s}#{sep}#{nice_time(r["sum_billsec"])}#{sep}#{nice_number(r["price"]).to_s.gsub(".",dec).to_s}"
      end
    end

    prepaid, prep = invoice_type(invoice, user)
    filename = Invoice.filename(user, prep, "Invoice-#{user.first_name}_#{user.last_name}-#{invoice.user_id}-#{invoice.number}-#{invoice.issue_date}-#{dc}", "csv")
    if params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"),   :type => 'text/csv; charset=utf-8; header=present',  :filename => filename)
      end
    end
  end

  def generate_invoice_destinations_csv
    invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])

    unless invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    idetails = invoice.invoicedetails
    user = invoice.user


    dc = params[:email_or_not] ? user.currency.name : session[:show_currency]
    ex = Currency.count_exchange_rate(session[:default_currency], dc)

    sep, dec = user.csv_params
    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? "Prepaid_" : ""

    billsec_cond = Confline.get_value("#{prepaid}Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
    user_price = SqlExport.replace_price('(calls.user_price + calls.did_price + calls.did_inc_price)', {:ex=>ex})

    csv_string = ["Invoice NO.:#{sep} #{invoice.number.to_s}"]

    csv_string << ""
    csv_string << "Invoice Date:#{sep} #{invoice.period_start.to_s} - #{invoice.period_end.to_s}"
    csv_string << ""
    csv_string << "Due Date:#{sep} #{invoice.issue_date.to_s}"
    csv_string << ""
    csv_string << ""


    for id in idetails
      if id.name != 'Calls' and id.name != 'Calls_To_Dids'
        sub = 1
      end
    end


    if idetails

      if sub.to_i == 1
        csv_string << "services#{sep}quantity#{sep}price\n"
      end

      for id in idetails
        if id.name != 'Calls' and id.name != 'Calls_To_Dids'

          @iprice= id.price
          if id.invdet_type > 0
            if id.quantity
              qt = id.quantity
              tp = qt * id.converted_price(ex) if id.converted_price(ex)
            else
              qt = ""
              tp = id.converted_price(ex)
            end
            csv_string << "#{nice_inv_name(id.name)}#{sep}#{qt}#{sep}#{nice_number(tp).to_s.gsub(".",dec).to_s}"
          end
        end
      end
    end
    csv_string << ""
    csv_string << ""


    show_zero_calls = user.invoice_zero_calls.to_i
    if show_zero_calls == 0
      zero_calls_sql = " AND calls.user_price > 0 "
    else
      zero_calls_sql = ""
    end


    sql= "SELECT destinations.id, destinations.prefix as 'prefix', dir.name as 'country', destinations.name as 'dg_name', destinations.subcode as 'dg_type', MAX(#{SqlExport.replace_price('calls.user_rate',{:ex=>ex})}) as 'rate', sum(IF(DISPOSITION='ANSWERED',1,0)) AS 'answered', Count(*) as 'all_calls', SUM(IF(DISPOSITION='ANSWERED',calls.#{billsec_cond},0)) as 'billsec', SUM(IF(DISPOSITION='ANSWERED',#{SqlExport.replace_price('calls.provider_price', {:ex=>ex})},0)) as 'selfcost', SUM(IF(DISPOSITION='ANSWERED',#{user_price},0)) as 'price'  FROM calls
JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)
LEFT JOIN destinations ON (destinations.prefix = calls.prefix)
    LEFT JOIN directions as dir ON (destinations.direction_code = dir.code)
    where devices.user_id = '#{user.id}' AND card_id = 0  and calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' #{zero_calls_sql} AND LENGTH(calls.prefix) > 0
    group by destinations.id, calls.user_rate ORDER BY destinations.direction_code ASC, destinations.id ASC"

    # my_debug sql
    res = ActiveRecord::Base.connection.select_all(sql)

    if res != []
      csv_string << "country#{sep}rate#{sep}ASR %#{sep}calls#{sep}ACD#{sep}billsec#{sep}Sum"
    end
    for r in res
      id=r["id"].to_s
      country = r["country"].to_s
      type = r["dg_type"].to_s
      rate = r["rate"].to_s
      calls = r["answered"].to_s
      prefix = r["prefix"].to_s
      billsec = r["billsec"].to_s
      if r["answered"].to_s.to_i > 0
        asr = (r["answered"].to_f /  r["all_calls"].to_f) * 100
        acd = (r["billsec"].to_f / r["answered"].to_f).to_f
      else
        asr =0
        acd =0
      end
      price = r["price"].to_s
      if r["answered"].to_s.to_i > 0
        if idetails
          csv_string << "#{country.to_s + ' ' + type.to_s + ' ' + prefix.to_s }#{sep}#{rate.to_s.gsub(".", dec).to_s}#{sep}#{nice_number(asr).to_s.gsub(".", dec).to_s}#{sep}#{calls}#{sep}#{nice_number(acd).to_s.gsub(".", dec).to_s}#{sep}#{billsec}#{sep}#{nice_number(price).to_s.gsub(".", dec).to_s}"
        else
          csv_string << "#{country + ' ' + type.to_s + ' ' + prefix.to_s }#{sep}#{rate.to_s.gsub(".", dec).to_s}#{sep}#{nice_number(asr).to_s.gsub(".", dec).to_s}#{sep}#{calls}#{sep}#{nice_number(acd).to_s.gsub(".", dec).to_s}#{sep}#{billsec}#{sep}#{nice_number(price).to_s.gsub(".", dec).to_s}"
        end
      end
    end
    prepaid, prep = invoice_type(invoice, user)
    filename = Invoice.filename(user, prep, "Invoice-#{user.first_name}_#{user.last_name}-#{invoice.user_id}-#{invoice.number}-#{invoice.issue_date}-#{dc}", "csv")

    if  params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"), :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      end
    end
  end

  def generate_invoice_by_cid_csv
    invoice = Invoice.find_by_id(params[:id], :include => [:tax, :user])

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    dc = current_user.currency.name
    user = invoice.user


    dc = params[:email_or_not] ? user.currency.name : session[:show_currency]
    ex = Currency.count_exchange_rate(session[:default_currency], dc)

    sep, dec = user.csv_params

    show_zero_calls = user.invoice_zero_calls.to_i
    if show_zero_calls == 0
      zero_calls_sql = " AND calls.user_price > 0 "
    else
      zero_calls_sql = ""
    end
    user_price = SqlExport.replace_price('(calls.user_price + calls.did_price + calls.did_inc_price)', {:ex=>ex})
    csv_s = []
    sql = "SELECT calls.src, SUM(#{user_price}) as 'price', COUNT(calls.id) AS calls_size FROM calls JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 AND card_id = 0 #{zero_calls_sql} GROUP BY calls.src;"

    cids = Call.find_by_sql(sql)

    if cids != []
      csv_s<< "CallerID#{sep}price(#{dc})#{sep}calls#{sep}"

      for ci in cids
        csv_s << ci.src.to_s + sep.to_s + ci.price.to_f.to_s.gsub(".", dec).to_s + sep + ci.calls_size.to_i.to_s
      end
    end

    csv_string = csv_s.join("\n")
    prepaid, prep = invoice_type(invoice, user)
    filename = Invoice.filename(user, prep, "Invoice-#{user.first_name}_#{user.last_name}-#{invoice.user_id}-#{invoice.number}-#{invoice.issue_date}-#{dc}", "csv")
    if  params[:email_or_not]
      return csv_string
    else
      if params[:test].to_i == 1
        render :text => "Filename: #{filename}" + csv_string
      else
        send_data(csv_string,   :type => 'text/csv; charset=utf-8; header=present',  :filename => filename)
      end
    end
  end

  def generate_test_pdf
    require 'pdf/wrapper'

    pdf = PDF::Wrapper.new(:paper => :A4)
    pdf.font("Nimbus Sans L")
    #      logo_file = Actual_Dir+"/public/images/"+session[:logo_picture]

    #logo
    #info = ::PDF::Writer::Graphics::ImageInfo.new(File.read(logo_file))

    #pdf.font("Times new roman")
    #      pdf.image(logo_file,{ :left => 40, :top=>38, :height=>55, :width =>300, :proportional => true})
    pdf.color(:Gray)
    pdf.text( _('INVOICE'), {:left => 330, :top => 43, :font_size =>16})
    pdf.color(:Black)
    pdf.rectangle(40, 190, 520, 0,{:line_width => 1, :fill_color => :Gray, :color => :Gray})
    pdf.text(session[:company], {:left => 40, :top => 110, :font_size => 13})
    pdf.text(confline("Invoice_Address1"), {:left => 40, :top => 130, :font_size => 7})
    pdf.text(confline("Invoice_Address2"), {:left => 40, :top => 145, :font_size => 7})
    pdf.text(confline("Invoice_Address3"), {:left => 40, :top => 160, :font_size => 7})
    pdf.text(confline("Invoice_Address4"), {:left => 40, :top => 175, :font_size => 7})

    # logo removed from invoice due to buggy picture support in pdf generating libraries
    logo_file = Actual_Dir+"/public/images/rails.png"
    pdf.image(logo_file,{ :left => 40, :top=>8, :height=>55, :width =>300, :proportional => true})


    pdf.text("Test Text : ąčęėįšųūž_йцукенгшщз", {:left =>50, :top =>200 , :font_size => 9})


    send_data pdf.render, :filename => "test.pdf", :type => "application/pdf"
  end

  def change_session_flag
    session[:invoices_is_generating] = 0
    redirect_to :controller=>:callc, :action=>:main
  end

  def invoices_recalculation
    @users = User.find_all_for_select(correct_owner_id,{:exclude_owner=>true})
    @page_title = _('Recalculate_invoices')
    @page_icon = "application_go.png"

    @post = 1
    @pre = 0
  end

  def invoices_recalculation_status
    @page_title = _('Recalculate_invoices_status')
    @page_icon = "application_go.png"

    change_date

    unless params[:invoice]
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    type = params[:invoice][:type]
    type = "postpaid" if !(["postpaid", "prepaid", "user"].include?(type))
    if type == "user"
      @invoices = Invoice.find(:all, :include=>[:user], :conditions=>['paid = 0 AND user_id = ? AND period_start >= ? AND period_end <= ? AND users.owner_id = ?', params[:user][:id], session_from_date, session_till_date, correct_owner_id ])
    else
      @invoices = Invoice.find(:all, :include=>[:user], :conditions=>['paid = 0 AND invoice_type = ? AND period_start >= ? AND period_end <= ? AND users.owner_id = ?', type, session_from_date, session_till_date, correct_owner_id])
    end

    @period_start = session_from_date
    @period_end = session_till_date

    if @invoices and @invoices.size.to_i > 0
      @i = 0
      for invoice in @invoices
        if !invoice.paid?
          regenerate_invoice_price(invoice)
          @i+=1
        end
      end
      flash[:status] = _('Invoices_recalculated') + ": " + @i.to_s
      redirect_to :action=>:invoices and return false
    else
      flash[:notice] = _('No_invoice_found_to_recalculate')
      redirect_to :action=>:invoices_recalculation and return false
    end

  end

  private

  def subscription_period(sub, period_start, period_end)
    if sub.activation_start < period_start
      use_start = period_start
    else
      use_start = sub.activation_start
    end
    #till which day used?
    if sub.activation_end > period_end
      use_end = period_end
    else
      use_end = sub.activation_end
    end
    return use_start.to_date, use_end.to_date
  end

  def call_details_for_user(user, period_start_with_time, period_end_with_time, use_index = 0)
    MorLog.my_debug("\nChecking user with id: #{user.id}, name: #{nice_user(user)}, type: #{user.usertype}", 1)

    use_index = 0
    MorLog.my_debug("Search with index ? : #{use_index}",1)
    # --- Outgoing calls ---

    # find own outgoing (made by this user) calls stats (count and sum price)
    outgoing_calls, outgoing_calls_price = user.own_outgoing_calls_stats_in_period(period_start_with_time, period_end_with_time, use_index)
    MorLog.my_debug("  Outgoing calls: #{outgoing_calls}, for price: #{outgoing_calls_price}", 1)

    # find users outgoing (made by this resellers users) calls stats (count and sum price)
    if user.usertype == "reseller"
      outgoing_calls_by_users, outgoing_calls_by_users_price = user.users_outgoing_calls_stats_in_period(period_start_with_time, period_end_with_time, use_index)
      MorLog.my_debug("  Outgoing calls by users: #{outgoing_calls_by_users}, for price: #{outgoing_calls_by_users_price}", 1)
    else
      outgoing_calls_by_users = 0
      outgoing_calls_by_users_price = 0
    end

    # --- Incoming calls ---

    incoming_received_calls, incoming_received_calls_price = user.incoming_received_calls_stats_in_period(period_start_with_time, period_end_with_time,use_index)
    MorLog.my_debug("  Incoming RECEIVED calls: #{incoming_received_calls}, for price: #{incoming_received_calls_price}", 1)

    incoming_made_calls, incoming_made_calls_price = user.incoming_made_calls_stats_in_period(period_start_with_time, period_end_with_time, use_index)
    MorLog.my_debug("  Incoming MADE calls: #{incoming_made_calls}, for price: #{incoming_made_calls_price}", 1)

    return incoming_received_calls, incoming_received_calls_price, incoming_made_calls, incoming_made_calls_price, outgoing_calls_price, outgoing_calls_by_users_price, outgoing_calls, outgoing_calls_price, outgoing_calls_by_users
  end

  def calls_to_invoice()

  end

  def regenerate_invoice_price(invoice)
    user = invoice.user
    invoice.invoicedetails.destroy_all # we'll add new details

    period_start_with_time, period_end_with_time = invoice.period_start.to_time, invoice.period_end.to_time.change(:hour => 23, :min => 59, :sec => 59, :usec => 999999.999)

    ind_ex = ActiveRecord::Base.connection.select_all("SHOW INDEX FROM calls")

    use_index = 0
    ind_ex.to_yaml
    ind_ex.each{|ie| use_index = 1; use_index if ie[:key_name].to_s == 'calldate'} if ind_ex

    incoming_received_calls, incoming_received_calls_price, incoming_made_calls, incoming_made_calls_price, outgoing_calls_price, outgoing_calls_by_users_price, outgoing_calls, outgoing_calls_price, outgoing_calls_by_users = call_details_for_user(user, period_start_with_time.strftime("%Y-%m-%d %H:%M:%S"), period_end_with_time.strftime("%Y-%m-%d %H:%M:%S"), use_index)

    # find subscriptions for user in period
    subscriptions = user.subscriptions_in_period(period_start_with_time, period_end_with_time)
    total_subscriptions = 0
    total_subscriptions = subscriptions.size if subscriptions
    MorLog.my_debug("  Total subscriptions this period: #{total_subscriptions}")


    # check if we should generate invoice
    if (outgoing_calls_price > 0) or (outgoing_calls_by_users_price > 0) or (incoming_received_calls_price > 0) or (incoming_made_calls_price > 0) or (total_subscriptions > 0)
      MorLog.my_debug("    Generating invoice....")

      tax = user.get_tax.clone
      tax.save
      price = 0

      # --- add own outgoing calls ---
      if (outgoing_calls_price > 0)
        invoice.invoicedetails.create(:name => _('Calls'), :price => outgoing_calls_price.to_f, :quantity => outgoing_calls, :invdet_type => 0)
        price += outgoing_calls_price.to_f
      end

      # --- add resellers users outgoing calls ---
      if (outgoing_calls_by_users_price > 0)
        invoice.invoicedetails.create(:name => _('Calls_from_users'), :price =>outgoing_calls_by_users_price.to_f, :quantity => outgoing_calls_by_users, :invdet_type => 0)
        price += outgoing_calls_by_users_price.to_f
      end

      #      # --- add own received incoming calls ---
      #      if (incoming_received_calls_price > 0)
      #        invoice.invoicedetails.create(:name => _('Incoming_received_calls'), :price => incoming_received_calls_price.to_f, :quantity => incoming_received_calls, :invdet_type => 0)
      #        price += incoming_received_calls_price.to_f
      #      end
      #
      #      # --- add own made incoming calls ---
      #      if (incoming_made_calls_price > 0)
      #        invoice.invoicedetails.create(:name => _('Incoming_made_calls'), :price => incoming_made_calls_price.to_f, :quantity => incoming_made_calls, :invdet_type => 0)
      #        price += incoming_made_calls_price.to_f
      #      end

      MorLog.my_debug("    Invoice price without subscriptions: #{price.to_s}", 1)

      # nasty hack for Balticom to recalculate invoices/balance - DO NOT USE!!!
      #user.balance -= price
      #user.save

      # --- add subscriptions ---

      for sub in subscriptions

        service = sub.service
        count_subscription = 0

        if service.servicetype == "flat_rate"
          start_date, end_date = subscription_period(sub, period_start_with_time, period_end_with_time)
          invd_price = service.price * (months_between(start_date.to_date, end_date.to_date)+1)
          count_subscription = 1
        end

        if service.servicetype == "one_time_fee"
          # one-time-fee subscription only counts once for full price
          if (sub.activation_start >= period_start_with_time and sub.activation_start <= period_end_with_time)
            invd_price = service.price
            count_subscription = 1
          end
        end

        if service.servicetype == "periodic_fee"
          count_subscription = 1

          #from which day used?
          if sub.activation_start < period_start_with_time
            use_start = period_start_with_time
          else
            use_start = sub.activation_start
          end
          #till which day used?
          if sub.activation_end > period_end_with_time
            use_end = period_end_with_time
          else
            use_end = sub.activation_end
          end
          start_date = use_start.to_date
          end_date = use_end.to_date
          days_used = use_end.to_date - use_start.to_date

          if start_date.month == end_date.month and start_date.year == end_date.year
            total_days = start_date.to_time.end_of_month.day
            invd_price = service.price / total_days * (days_used+1)
          else
            invd_price = 0
            if months_between(start_date, end_date) > 1
              # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
              invd_price += (months_between(start_date, end_date)-1) * service.price
            end
            #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
            last_day_of_month = start_date.to_time.end_of_month.to_date
            last_day_of_month2 = end_date.to_time.end_of_month.to_date
            invd_price += service.price/last_day_of_month.day * (last_day_of_month - start_date+1).to_i
            invd_price += service.price/last_day_of_month2.day * (end_date.day)
          end
        end

        #my_debug("    Invoice Subscriptions price: #{invd_price.to_s}")

        if count_subscription == 1
          invoice.invoicedetails.create(:name => service.name.to_s + " - " + sub.memo.to_s, :price =>invd_price, :quantity => "1")
          price += invd_price.to_f
        end
      end
      invoice.price = price.to_f
      MorLog.my_debug(" Recalculated Invoice number: #{invoice.number}", 1)
      invoice.save
    end
  end

  def find_invoice
    @invoice = Invoice.find_by_id(params[:id])

    unless @invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :controller => :callc, :action => :invoices
    end
  end

  def invoices_order_by(params, options)
    case params[:order_by].to_s
    when "user" then  order_by = "users.first_name"
    when "number" then order_by = "invoices.number"
    when "invoice_type" then  order_by = "invoices.invoice_type"
    when "period_start" then  order_by = "invoices.period_start"
    when "period_end" then  order_by = "invoices.period_end"
    when "issue_date" then  order_by = "invoices.issue_date"
    when "sent_email" then  order_by = "invoices.sent_email"
    when "sent_manually" then  order_by = "invoices.sent_manually"
    when "paid" then  order_by = "invoices.paid"
    when "paid_date" then  order_by = "invoices.paid_date"
    when "price" then  order_by = "invoices.price"
    else
      options[:order_by] ? order_by = options[:order_by] : order_by = "users.first_name"
    end

    without = order_by
    order_by = "users.first_name " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", users.last_name" if order_by.to_s == "users.first_name"
    options[:order_desc].to_i == 1 ? order_by += " DESC" : order_by += " ASC"
    return without, order_by
  end

  def invoice_type(invoice, user)
    if invoice.invoice_type.to_s == 'prepaid' and user.owner_id == 0
      return "Prepaid_", "prepaid"
    else
      return "", "postpaid"
    end
  end
end
