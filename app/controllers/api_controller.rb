# -*- encoding : utf-8 -*-
class ApiController < ApplicationController

  skip_before_filter :verify_authenticity_token

  session :off, :except => [:login, :login_form]

  include SqlExport

  require 'builder/xmlbase'
  skip_before_filter :set_current_user, :set_charset, :redirect_callshop_manager
  before_filter :check_allow_api
  before_filter :check_send_method, :except => [:simple_balance, :balance]
  before_filter :log_access
  before_filter :find_current_user_for_api, :only => [:user_subscriptions, :user_invoices, :personal_payments, :user_rates, :callflow_edit, :devices_callflow, :user_devices, :main_page, :logout, :cc_by_cli, :create_payment, :payments_list, :show_calling_card_group, :buy_card_from_callingroup, :financial_statements]
  before_filter :check_mor_11_extend, :only => [:credit_notes, :credit_note_update, :credit_note_delete, :credit_note_create, :financial_statements, :create_payment, :cc_by_cli, :show_calling_card_group, :buy_card_from_callingroup, :send_sms]
  before_filter :check_api_parrams_with_hash, :only => [:show_calling_card_group, :buy_card_from_callingroup, :cc_by_cli, :financial_statements]
  before_filter :check_calling_card_addon, :only => [:show_calling_card_group, :cc_by_cli, :buy_card_from_callingroup]
  before_filter :check_sms_addon, :only => [:send_sms]

  require 'xmlsimple'

  def method_missing(method_name, *args, &block)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.error {
      doc.type("Undefined method")
      doc.name(method_name.to_s)
    }
    #logger.info out_string
    send_xml_data(out_string, params[:test].to_i)
  end


  #logins user to the system
  def login
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8", :standalone => "yes"
    check_user(params[:u], params[:p])
    login_ok = false
    if @user
      add_action(@user.id, "login", request.env["REMOTE_ADDR"].to_s)

      @user.logged = 1
      @user.save

      if Confline.get_value("API_Login_Redirect_to_Main").to_i == 0
        doc.action {
          doc.name("login")
          doc.status("ok")
          doc.user_id("#{@user.id.to_s}")
          doc.status_message("Succesfully logged in")
        }
      else
        login_ok = true
        renew_session(@user)
        session[:login] = login_ok
        check_devices()
      end

    else
      add_action2(0, "bad_login", params[:u].to_s + "/" +  params[:p].to_s, request.env["REMOTE_ADDR"].to_s)
      doc.action {
        doc.name("login")
        doc.status("failed")

        if Action.disable_login_check(request.env["REMOTE_ADDR"].to_s).to_i == 0
          doc.status_message("Please wait 10 seconds before trying to login again")
        else
          doc.status_message("Login failed")
        end
      }
    end
    if Confline.get_value("API_Login_Redirect_to_Main").to_i == 1 and login_ok
      bad_psw = (params[:p].to_s == 'admin' and @user.id == 0) ? _('ATTENTION!_Please_change_admin_password_from_default_one_Press')+ " <a href='#{Web_Dir}/users/edit/0'> #{_('Here')} </a> " + _('to_do_this') : ''
      flash[:notice] = bad_psw if !bad_psw.blank?
      flash[:status] = _('login_succesfull')
      redirect_to :controller => :callc, :action => :main and return false
    else
      send_xml_data(out_string, params[:test].to_i)
    end
  end


  #logout user from the system
  def logout

    username = params[:u]
    password = params[:p]

    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8", :standalone => "yes"

    if username.length > 0 and password.length > 0 and user = User.find(:first, :conditions => ["username = ? and password = ?", username, Digest::SHA1.hexdigest(password)])

      add_action(@current_user.id, "logout", "")

      user.logged = 0
      user.save
      doc.action {
        doc.name("logout")
        doc.status("ok")
      }
    else
      doc.action {
        doc.name("logout")
        doc.status("failed")
      }
    end
    send_xml_data(out_string, params[:test].to_i)

  end

  #Initiates callback
  def callback

    if callback_active?
      username = params[:u].to_s
      password = params[:p].to_s

      user = User.find(:first, :conditions => ["username = ? and password = ?", username, Digest::SHA1.hexdigest(password)])

      if username.length > 0 and password.length > 0 and user
        device = Device.find(:first, :conditions => ["id =?", params[:device]])
        if params[:device] and device and device.user_id == user.id
          if params[:src] and params[:src].length > 0
            src = params[:src]
            dst = ""
            dst = params[:dst] if params[:dst]
            channel = "Local/#{src}@mor_cb_src/n"
            if dst.length > 0
              st = originate_call(device.id, src, channel, "mor_cb_dst", dst, device.callerid_number)
            else
              st = originate_call(device.id, src, channel, "mor_cb_dst_ask", "123", device.callerid_number)
            end
            doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
            doc.Status(st.to_i == 0 ? "Ok" : _('Cannot_connect_to_asterisk_server'))
          else
            doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
            doc.Status("No source")
          end
        else
          doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
          doc.Status("Bad device")
        end
      else
        doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
        doc.Status("Not authenticated")
      end
    else
      doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
      doc.Status("Dont be so smart")
    end
    send_xml_data(out_string, params[:test].to_i)

  end


  #Retrieves list of invoices in selected time period.
=begin rdoc
 Returns invoices for selected user in selected period

 *Params*

 * +file+ - return file or plain response. Values - [true, false]  Default : true
=end
  def invoices
    MorLog.my_debug("INVOICES")

    opts = {}
    ["true", "false"].include?(params[:file].to_s) ? opts[:file] = params[:file] : opts[:file] = "true"

    username = params[:u]
    password = params[:p]
    from = params[:from]
    till = params[:till]

    username = "" if not username
    password = "" if not password
    from = 0 if not password
    till = 0 if not password

    from_t = Time.at(from.to_i)
    till_t = Time.at(till.to_i)

    from_nice = nice_date(from_t, 0)
    till_nice = nice_date(till_t, 0)

    user = User.find(:first, :conditions => ["username = ? and password = ?", username, Digest::SHA1.hexdigest(password)])

    if user
      User.current = user
      cond = ""
      case user.usertype.to_s
        when "admin"
          cond = " AND users.owner_id = #{user.id}"
        when "accountant"
          cond = " AND users.owner_id = #{user.owner_id}"
        when "reseller"
          cond = " AND (users.owner_id = #{user.id} OR users.id = #{user.id})"
        when "user"
          cond = " AND invoices.user_id = #{user.id}"
      end
      invoices = Invoice.find(:all, :select => "invoices.*", :joins => "JOIN users on (users.id = invoices.user_id)", :conditions => ["period_start >= ? AND period_end <= ? AND users.generate_invoice != 0 #{cond}", from_nice, till_nice])

      if invoices or invoices.size == 0
        doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
        doc.Invoices("from" => from_nice, "till" => till_nice) {
          for inv in invoices
            iuser = inv.user
            doc.Invoice("user_id" => inv.user_id, "agreementnumber" => iuser.agreement_number, "clientid" => iuser.clientid, "number" => inv.number) {
              for invdet in inv.invoicedetails
                doc.Product {
                  doc.Name(invdet.name)
                  doc.Quantity(invdet.quantity)
                  doc.Price(nice_number(invdet.price))
                  doc.Date_added((inv.payment ? nice_date(inv.payment.date_added, 0) : ''))
                  doc.Issue_date(nice_date(inv.issue_date, 0))
                }
              end
            }
          end
        }
      else
        doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
        doc.Error("no invoices found")
      end
    else
      doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
      doc.Error("user not found")
    end

    #return out_string
    if opts[:file] == "true"
      if confline("XML_API_Extension").to_i == 0
        send_data(out_string, :type => "text/xml", :filename => "mor_api_response.xml")
      else
        send_data(out_string, :type => "text/html", :filename => "mor_api_response.html")
      end
    else
      render :text => out_string
    end
  end

  def login_form
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8", :standalone => "yes"

    check_user(params[:u], params[:p])

    if @user
      @user.logged = 1
      @user.save

      doc.page {
        doc.pagename("Login page")
        doc.language("#{Localization.lang}")
        doc.error_msg("")
        doc.aval_languages {
        }
      }

    else
      doc.page {
        doc.pagename("Login page")
        doc.language("#{Localization.lang}")
        doc.error_msg("")
        doc.aval_languages {
        }
      }

    end

    send_xml_data(out_string, params[:test].to_i)
  end


  def payments_list

    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8", :standalone => "yes"

    if @current_user.is_accountant?
      unless @current_user.accountant_allow_read('payments_manage')
        doc.status { doc.error(_('Dont_be_so_smart')) }
        send_xml_data(out_string, params[:test].to_i)
        return false
      end
    end
    if allow == true
      #show uncompleted payments?
      hide_uncompleted_payment = Confline.get_value("Hide_non_completed_payments_for_user", 0).to_i

      @options = {}
      [:s_transaction, :s_completed, :s_username, :s_first_name, :s_last_name, :s_paymenttype, :s_amount_min, :s_amount_max, :s_currency, :s_user_id, :s_from, :s_till, :s_number, :s_pin].each { |key|
        params[key] ? @options[key] = params[key].to_s : (@options[key] = "" if !@options[key])
      }

      #set correct owner id;
      if @current_user.usertype == 'accountant' or @current_user.usertype == 'admin'
        @owner_id = 0
      elsif @current_user.usertype == 'reseller'
        if @options[:s_user_id].to_i == @user.id.to_i
          @owner_id = 0
        else
          @owner_id = @current_user.id
        end
      else
        #user can see only his, so overwrite s_user_id
        @owner_id = @current_user.owner_id
        @options[:s_user_id] = @current_user.id
      end

      if @options[:s_user_id] and !@options[:s_user_id].blank?
        if !@current_user.is_user?

          if @options[:s_user_id] =~ /[0-9]/
            user = User.find(:first, :conditions => {:id => @options[:s_user_id], :owner_id => @owner_id})
          end
          unless user
            doc.status { doc.error(_('Dont_be_so_smart')) }
            send_xml_data(out_string, params[:test].to_i)
            return false
          end
        end
      end

      cond = ["date_added BETWEEN ? AND ?"]
      cond << "payments.owner_id = ?"

      #default today
      if !@options[:s_from].blank? and !@options[:s_till].blank?
        cond_param = ["#{q(Time.at(@options[:s_from].to_i).to_s(:db))}", "#{q(Time.at(@options[:s_till].to_i).to_s(:db))}", @owner_id]
      else
        cond_param = ["#{Time.mktime(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0).to_s(:db)}", "#{Time.mktime(Time.now.year, Time.now.month, Time.now.day, 23, 59, 59).to_s(:db)}", @owner_id]
      end


      if hide_uncompleted_payment == 1
        cond << " (payments.pending_reason != 'Unnotified payment' or payments.pending_reason is null)"
      end

      ["username", "first_name", "last_name"].each { |col|
        add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "users.#{col} LIKE ?", cond, cond_param) }

      ["number", "pin"].each { |col|
        add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "cards.#{col} LIKE ?", cond, cond_param) }

      ["paymenttype", "currency", "completed", "user_id"].each { |col|
        add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s, "payments.#{col} = ?", cond, cond_param) }

      ["transaction"].each { |col|
        add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "payments.transaction_id LIKE ?", cond, cond_param) }

      cond << "amount >= '#{q(@options[:s_amount_min])}' " if !@options[:s_amount_min].blank?
      cond << "amount <= '#{q(@options[:s_amount_max])}' " if !@options[:s_amount_max].blank?


      @payments = Payment.find(:all,
                               :select => "payments.*, payments.user_id as 'user_id', payments.first_name as 'payer_first_name', payments.last_name as 'payer_last_name', users.username, users.first_name, users.last_name, cards.number, cards.pin, cards.id as card_id",
                               :joins => "left join users on (payments.user_id = users.id and payments.card = '0') left join cards on (payments.user_id = cards.id and payments.card != '0')   left join cardgroups on (cards.cardgroup_id = cardgroups.id)",
                               :conditions => [cond.join(" AND ")] + cond_param)

      doc.page {
        doc.pagename("#{_('Payments_list')}")
        doc.payments {
          @payments.each { |payment|
            doc.payment {
              if payment.card == 0
                user = User.find(:first, :conditions => ["id = ?", payment.user_id]) if !payment.user_id.blank?
                if user
                  doc.user("#{nice_user(user)}")
                end
              else
                if Card.find_by_id(payment.user_id)
                  doc.user("#{payment.number}+" "+(#{payment.pin})")
                else
                  doc.user(" #{_('Batch_card_sale')}")
                end
              end
              digits = (payment.paymenttype == "invoice" and payment.invoice) ? nice_invoice_number_digits(payment.invoice.invoice_type) : 0
              payment.paymenttype == "gateways_authorize_net" ? doc.payer("#{payment.payer_first_name.to_s}"+" "+"#{payment.payer_last_name.to_s}") : doc.payer("#{payment.payer_email}")
              doc.transaction_id("#{payment.transaction_id}")
              doc.date("#{nice_date_time payment.date_added}")
              doc.confirm_date("#{ nice_date_time payment.shipped_at}")
              doc.type("#{payment.paymenttype.capitalize}") if payment.paymenttype
              doc.amount("#{nice_number(payment.payment_amount)}")
              doc.fee("#{nice_number(payment.fee)}")
              doc.amount_with_tax("#{nice_number(payment.payment_amount_with_vat(digits))}")
              doc.currency("#{payment.currency}")
              if payment.completed.to_i == 0
                doc.completed("No (#{payment.pending_reason})")
              else
                doc.completed("Completed")
              end
              if !payment.completed? and payment.pending_reason == "Waiting for confirmation"
                doc.confirmed_by_admin("No")
              else
                doc.confirmed_by_admin("Yes")
              end
            }
          }
        }
      }
    else
      doc.error("Incorrect hash")
    end
    send_xml_data(out_string, params[:test].to_i)
  end


  def main_page

    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])

    if @user
      @user.logged = 1
      @user.save
      today = Time.now.strftime("%Y-%m-%d")
      @missed_calls = @user.calls("missed_inc", today, today)
      @missed_calls_today = @missed_calls.size
      @not_processed_calls_today = @user.calls("missed_not_processed_inc", today, today).size
      @not_processed_calls_total = @user.calls("missed_not_processed_inc", "2000-01-01", today).size


      #front_page_stats

      month_t = Time.now.year.to_s + "-" + good_date(Time.now.month.to_s)
      last_day = last_day_of_month(Time.now.year.to_s, good_date(Time.now.month.to_s))
      day_t = Time.now.year.to_s + "-" + good_date(Time.now.month.to_s) + "-" + good_date(Time.now.day.to_s)


      if @current_user.usertype == "admin"
        @callsm = Call.find_by_sql("SELECT calls.* FROM calls WHERE calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59' AND disposition = 'ANSWERED'")
        @callsd = Call.find_by_sql("SELECT calls.* FROM calls WHERE calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59' AND disposition = 'ANSWERED'")
      else
        @callsm = Call.find_by_sql("SELECT calls.* FROM calls WHERE calls.user_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59' AND disposition = 'ANSWERED'")
        @callsd = Call.find_by_sql("SELECT calls.* FROM calls WHERE calls.user_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59' AND disposition = 'ANSWERED'")
        if @current_user.usertype == "reseller"
          @callsm = Call.find_by_sql("SELECT calls.* FROM calls WHERE calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59' AND disposition = 'ANSWERED'")
          @callsd = Call.find_by_sql("SELECT calls.* FROM calls WHERE calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59' AND disposition = 'ANSWERED'")
        end

      end


      @total_durationm = 0
      @total_call_pricem = 0
      @total_call_selfpricem = 0
      @total_callsm = 0

      @total_durationd = 0
      @total_call_priced = 0
      @total_call_selfpriced = 0
      @total_callsd = 0

      if @current_user.usertype == "reseller"
        for call in @callsm
          @total_callsm = @total_callsm + 1
          @total_durationm += (call.billsec).to_i
          @total_call_pricem += (call.user_price).to_f
          @total_call_selfpricem += (call.reseller_price).to_f
        end
      else
        for call in @callsm
          @total_callsm= @total_callsm + 1
          @total_durationm += (call.billsec).to_i
          if call.reseller_id == 0
            @total_call_pricem = @total_call_pricem + (call.user_price).to_f
          else
            @total_call_pricem = @total_call_pricem + (call.reseller_price).to_f
          end
          @total_call_selfpricem = @total_call_selfpricem + (call.provider_price).to_f
        end
      end


      if @current_user.usertype == "reseller"
        for call in @callsd
          @total_callsd=@total_callsd+1
          @total_durationd += (call.billsec).to_i
          @total_call_priced += (call.user_price).to_f
          @total_call_selfpriced += (call.reseller_price).to_f
        end
      else
        for call in @callsd
          @total_callsd=@total_callsd+1
          @total_durationd += (call.billsec).to_i
          if call.reseller_id == 0
            @total_call_priced = @total_call_priced + (call.user_price).to_f
          else
            @total_call_priced = @total_call_priced + (call.reseller_price).to_f
          end
          @total_call_selfpriced = @total_call_selfpriced + (call.provider_price).to_f
        end
      end


      @total_profitm = @total_call_pricem - @total_call_selfpricem
      @total_profitd = @total_call_priced - @total_call_selfpriced


      doc.page {
        doc.pagename("#{_('Main_page')}")
        doc.username("#{params[:u]}")
        doc.userid("#{@current_user.id}")
        doc.language("#{Localization.lang}")
        doc.stats {
          doc.missed_calls {
            doc.missed_today("#{@missed_calls_today}")
            doc.missed_total("#{@not_processed_calls_total}")
          }
          doc.call_history {
            doc.calls {
              doc.call_counts("#{@total_callsm}")
              doc.period("#{_('Month')}")
              doc.call_duration("#{ nice_time @total_durationm}")
              if @current_user.usertype == "reseller" or @current_user.usertype == "admin"
                doc.call_profit("#{@total_profitm}")
              end
            }
            doc.calls {
              doc.call_counts("#{@total_callsd}")
              doc.period("#{_('Day')}")
              doc.call_duration("#{nice_time @total_durationd}")
              if @current_user.usertype == "reseller" or @current_user.usertype == "admin"
                doc.call_profit("#{@total_profitd}")
              end
            }
          }
          doc.finances {
            if @user.postpaid == 1
              doc.account("#{_('Postpaid')}")
            else
              doc.account("#{_('Prepaid')}")
            end
            doc.balance("#{nice_number @user.balance } #{Currency.get_default.name}")
            if @user.credit.to_i == -1
              doc.credit("#{_('Unlimited')}")
            else
              doc.credit("#{nice_number @user.credit}")
            end
          }
        }
      }

    else
      doc.page {
        doc.pagename("#{_('Main_page')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
          doc.language("#{tr.short_name}")

        }
      }

    end

    send_xml_data(out_string, params[:test].to_i)
  end

=begin rdoc
 Returns user personal information.

 *Post*/*Get* *params*:
 * user_id - User ID
 * hash - SHA1 hash

=end

  def user_details
    allow, values =MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    if allow == true
      #a bit nasty, huh? there are some issues after disabling session.
      #if current user is set then currency would be converted to logged 
      #in user's currency, but tests say it should be default currency and
      #no conversion, hence no User.current should be set
      User.current = nil

      username = params[:u].to_s
      password = params[:p].to_s

      @user_logged = User.find(:first, :conditions => ["username = ? and password = ?", username, Digest::SHA1.hexdigest(password)])
      if @user_logged
        if @user_logged.usertype == 'admin'
          @user = User.find(:first, :conditions => "id = #{values[:user_id].to_i}") if values [:user_id]
        elsif @user_logged.usertype == 'reseller'
          if values [:user_id]
            if @user_logged.id.to_i == values[:user_id].to_i
              owner = 0
            else
              owner = @user_logged.id
            end
            @user = User.find(:first, :conditions => "id = #{values[:user_id].to_i} AND owner_id = #{owner.to_i}")
          end

        else
          @user = User.find(:first, :conditions => ["username = ? and password = ?", username, Digest::SHA1.hexdigest(password)])
        end

        if @user
          @address = @user.address
          @country = Direction.find(:first, :conditions => ["id =?", @user.taxation_country])
          doc.page {
            doc.pagename("#{_('Personal_details')}")
            doc.language("en")
            doc.userid("#{@user_logged.id}")
            doc.details {
              doc.main_detail {
                @user.postpaid == 1 ? doc.account("#{_('Postpaid')}") : doc.account("#{_('Prepaid')}")
                doc.balance("#{nice_number @user.balance } #{Currency.get_default.name}")
                #ticket #4913, there's a rumor that api wil be rewriten, thats the only viable 
                #reason to add these elements, cause this mess wil be thrown away soon
                doc.balance_number(@user.balance.to_s)
                doc.balance_currency(Currency.get_default.name)
                @user.credit != -1 ? doc.credit("#{ nice_number(@user.credit.to_s) }") : doc.credit("#{ _('Unlimited')}")
              }
              doc.other_details {
                doc.username("#{@user.username}")
                doc.first_name("#{@user.first_name}")
                doc.surname("#{@user.last_name}")
                doc.personalid("#{@user.clientid}")
                doc.agreement_number("#{@user.agreement_number}")
                ad = @user.agreement_date
                ad= Time.now if !ad
                doc.agreement_date("#{nice_date(ad, 0)}")
                doc.taxation_country("#{@country.name[0, 22]}") if @country
                doc.vat_reg_number("#{@user.vat_number}")
                doc.vat_percent("#{@user.vat_percent}")
              }
              if @address
                doc.registration {
                  doc.reg_address("#{@address.address}")
                  doc.reg_postcode("#{@address.postcode}")
                  doc.reg_city("#{@address.city}")
                  doc.reg_country("#{@address.county}")
                  doc.reg_state("#{@address.state}")
                  doc.reg_direction("#{@address.email}")
                  doc.reg_phone("#{@address.phone}")
                  doc.reg_mobile("#{@address.mob_phone}")
                  doc.reg_fax("#{@address.fax}")
                  doc.reg_email("#{@address.email}")
                }
              end
            }
          }
        else
          doc.error("User was not found")
        end
      else
        doc.error("User was not found")
        MorApi.create_error_action(params, request, 'API : User not found by login and password')
      end
    else
      doc.error("Incorrect hash")
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def user_devices
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    check_user(params[:u], params[:p])

    if @user
      @user.logged = 1
      @user.save


      @devices = @user.devices #Device.find(:all, :conditions => "user_id = #{@current_user.id}", :order => "name")

      doc.page {
        doc.pagename("#{_('Devices')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.devices {
          for dev in @devices
            doc.device {
              doc.acc("#{dev.id}")
              doc.description("#{dev.description}")
              doc.type("#{dev.device_type}")
              doc.extension("#{dev.extension}")
              doc.username("#{dev.name}")
              doc.password("#{dev.secret}")
              doc.cid("#{dev.callerid}")
              doc.last_time_registered("#{nice_date_time(Time.at(dev.regseconds))}")
            }
          end
        }
      }

    else
      doc.page {
        doc.pagename("#{_('Devices')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {

          doc.language("#{tr.short_name}")

        }
      }

    end

    send_xml_data(out_string, params[:test].to_i)
  end

  def devices_callflow

    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])

    if @user
      @user.logged = 1
      @user.save

      if @current_user.usertype != "admin"
        if @current_user.usertype == "user" and @current_user.manager_in_groups.size == 0
          #simple user
          @device = Device.find(params[:device_id])

        else
          #group manager
          @device = Device.find(params[:id])
          @user = @device.user

          can_check = false
          for group in @current_user.manager_in_groups
            for user in group.users
              can_check = true if user.id == @user.id
            end
          end

          #     redirect_to :controller => "callc", :action => 'main' if not can_check

        end
      else
        #admin
        @device = Device.find(params[:device_id])
        @user = @device.user
      end
      #need security increase because rigth now everybody can see everybodies call flows

      @before_call_cfs = Callflow.find(:all, :conditions => "cf_type = 'before_call' AND device_id = #{@device.id}", :order => "priority ASC")
      @no_answer_cfs = Callflow.find(:all, :conditions => "cf_type = 'no_answer' AND device_id = #{@device.id}", :order => "priority ASC")
      @busy_cfs = Callflow.find(:all, :conditions => "cf_type = 'busy' AND device_id = #{@device.id}", :order => "priority ASC")
      @failed_cfs = Callflow.find(:all, :conditions => "cf_type = 'failed' AND device_id = #{@device.id}", :order => "priority ASC")

      if @before_call_cfs.empty?
        cf = create_empty_callflow(@device.id, "before_call")
        @before_call_cfs << cf
      end

      if @no_answer_cfs.empty?
        cf = create_empty_callflow(@device.id, "no_answer")
        @no_answer_cfs << cf
      end

      if @busy_cfs.empty?
        cf = create_empty_callflow(@device.id, "busy")
        @busy_cfs << cf
      end

      if @failed_cfs.empty?
        cf = create_empty_callflow(@device.id, "failed")
        @failed_cfs << cf
      end

      doc.page {
        doc.pagename("#{_('Call_Flow')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.device {
          doc.device_id("#{@device.id}")
          doc.device_description("#{@device.description}")
          doc.device_icon("#{}")
          doc.callflows {
            doc.callflow {
              doc.call_state("#{_('Before_Call')}")
              doc.callflow_action("#{draw_callflows(@before_call_cfs)}")
            }
            doc.callflow {
              doc.call_state("#{_('Call')}")
              doc.callflow_action("#{"Dial(#{@device.device_type}/#{@device.name}|#{@device.timeout})"}")
            }
            doc.callflow {
              doc.call_state("#{_('Answered')}")
              doc.callflow_action("#{_('Hangup')}")
            }
            doc.callflow {
              doc.call_state("#{_('No_Answer')}")
              doc.callflow_action("#{draw_callflows(@no_answer_cfs)}")
            }
            doc.callflow {
              doc.call_state("#{_('Busy')}")
              doc.callflow_action("#{draw_callflows(@busy_cfs)}")
            }
            doc.callflow {
              doc.call_state("#{_('Failed')}")
              doc.callflow_action("#{draw_callflows(@failed_cfs)}")
            }
          }
        }
      }

    else
      doc.page {
        doc.pagename("#{_('Call_Flow')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {

          doc.language("#{tr.short_name}")

        }
      }

    end

    send_xml_data(out_string, params[:test].to_i)
  end

  def draw_callflows(cfs)
    output = ""
    for cf in cfs
      case cf.action
        when "empty"
          output += "-"
        when "forward"
          dev = Device.find(cf.data) if cf.data2 == "local"
          output += _('Forward') + " " + dev.device_type + "/" + dev.name if cf.data2 == "local"
          output += _('Forward') + " " + cf.data if cf.data2 == "external"
          output += _('Forward_not_functional_please_enter_dst') if cf.data2 == ""
        when "voicemail"
          output += _('VoiceMail')
        when "fax_detect"
          dev = Device.find(cf.data) if cf.data2 == "fax"
          output += _('Fax_detect') + ": " + dev.device_type + "/" + dev.extension if cf.data2 == "fax"
          output += _('Fax_detect_not_functional_please_select_fax_device') if cf.data2 == ""
      end
    end
    output
  end


  def callflow_edit

    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])

    if @user
      @user.logged = 1
      @user.save

      @device = Device.find(params[:device_id])
      @user = @device.user
      @cf = Callflow.find(params[:cf])
      @devices = @user.devices

      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.callflow {
          doc.device_id("#{@device.id}")
          doc.device_description("#{@device.description}")
          doc.device_icon("#{}")
          doc.call_state("#{params[:cft]}")
          doc.actions {
            doc.action {
              doc.priority("#{@cf.priority}")
              doc.action_id("#{"1"}")
              doc.aval_devices {
                for dev in @devices
                  doc.device {
                    doc.device_id("#{dev.id}")
                    doc.device_name("#{dev.name}")
                  }
                end
              }
            }
            doc.action {
              doc.priority("#{@cf.priority}")
              doc.action_id("#{"3"}")
            }
            doc.action {
              doc.priority("#{@cf.priority}")
              doc.action_id("#{"4"}")
              doc.aval_devices {
                for dev in @devices
                  doc.device {
                    doc.device_id("#{dev.id}")
                    doc.device_name("#{dev.name}")
                  }
                end
              }
            }
          }
        }
      }
    else
      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
        }
      }
    end

    send_xml_data(out_string, params[:test].to_i)
  end

  def user_rates


    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])
    if @user
      @user.logged = 1
      @user.save

      @tariff = User.find(@current_user.id).tariff
      @dgroups = Destinationgroup.find(:all, :order => "name ASC, desttype ASC")
      @vat = 0.to_f
      @rates_cur2 = []

      sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{@tariff.id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name ASC;"
      rates = Rate.find_by_sql(sql)

      exrate = Currency.count_exchange_rate(@tariff.currency, @current_user.currency.name)
      for rate in rates
        get_provider_rate_details(rate, exrate)
        @rates_cur2[rate.id]=@rate_cur
      end

      @currency = Currency.get_active

      doc.page {
        doc.pagename("#{_('Payments')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.currency("#{@current_user.currency.name}")
        doc.vat_percent("#{@vat}")
        doc.aval_currencies {
          for curr in @currency
            doc.currency("#{curr.name}")
          end
        }
        doc.rates {
          for rat in rates
            doc.rate {
              doc.ratename("#{rat.destination.direction.name}")
              doc.rateicon("#{rat.destination.prefix}")
              doc.ratetype("#{rat.destination.subcode}")
              doc.ratecost("#{nice_number @rates_cur2[rat.id]}")
              doc.rate_vat_cost("#{nice_number(@rates_cur2[rat.id] * (100 + @vat) / 100)}")
            }
          end
        }
      }
    else
      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
        }
      }

    end
    send_xml_data(out_string, params[:test].to_i)
  end


  def get_tariff
    allow, values = MorApi.check_params_with_all_keys(params, request)
    #doc = Builder::XmlMarkup.new( :target => out_string = "", :indent => 2 )

    #doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])
    outstring = '<?xml version="1.0" encoding="UTF-8"?>'

    if allow
      if @user
        #admin? reseller? user?
        if values[:tariff_id] and @user.usertype != 'user' and @user.usertype != 'accountant'
          if @user.usertype == 'admin'
            @tariff = Tariff.find(values[:tariff_id].to_i)
          else
            @tariff = Tariff.find(:first, :conditions => ["id = ? and owner_id = ?", values[:tariff_id].to_i, @user.id.to_i])
          end
        else
          @tariff = @user.tariff
        end

        if @tariff
          if @tariff.purpose.to_s == 'user'

            result = @tariff.tariffs_api_retail

            rates={}

            result.each { |rate|
              rates[rate['name'].to_s] ||= {}
              rates[rate['name'].to_s][rate['desttype'].to_s] ||= []

              rates[rate['name'].to_s][rate['desttype'].to_s] << rate
            }

            outstring << "<page>
                            <pagename>#{_('Tariff')}</pagename>
                            <tariff_name>#{CGI::escapeHTML(@tariff.name.to_s)}</tariff_name>
                            <purpose>#{@tariff.purpose}</purpose>
                            <currency>#{@tariff.currency}</currency>
                            <rates>"

            rates.each { |name, type|

              type.each { |type_name, rate_data|
                outstring << " <destination> "
                outstring << "<destination_group_name>#{CGI::escapeHTML(name)}</destination_group_name>
                               <destination_group_type>#{CGI::escapeHTML(type_name)}</destination_group_type>"

                rate_data.each { |rate|
                  outstring << "<rate>"
                  if rate["duration"].to_i == -1
                    outstring << "<duration>Infinity</duration>"
                  else
                    outstring << "<duration>#{rate['duration']}</duration>"
                  end
                  outstring << "<type>#{rate['artype'].to_s}</type>
                  <round_by>#{rate['round'].to_s}</round_by>
                  <tariff_rate>#{rate['price'].to_s}</tariff_rate>
                  <start_time>#{rate['start_time'].to_s[%r[\w{2}:\w{2}:\w{2}]]}</start_time>
                  <end_time>#{rate['end_time'].to_s[%r[\w{2}:\w{2}:\w{2}]]}</end_time>
                  <daytype>#{rate['daytype'].to_s}</daytype>
                  <from>#{rate['from'].to_s}</from>
                  </rate>"
                }
                outstring << " </destination>"
              }
            }

            outstring << "</rates>
                        </page>"

            #            doc.page{
            #              doc.pagename("#{_('Tariff')}")
            #              doc.tariff_name("#{@tariff.name.to_s}")
            #              doc.currency("#{@tariff.currency}")
            #              doc.rates{
            #                result.each{ |rate|
            #                  doc.rate{
            #                    doc.destination_group_name("#{rate['name'].to_s}")
            #                    doc.destination_group_type("#{rate['desttype'].to_s}")
            #                    if rate["duration"].to_i == -1
            #                      doc.duration("Infinity")
            #                    else
            #                      doc.duration("#{rate["duration"]}")
            #                    end
            #                    doc.type("#{rate['artype'].to_s}")
            #                    doc.round_by("#{rate['round'].to_s}")
            #                    doc.tariff_rate("#{rate['price'].to_s}")
            #                    doc.start_time("#{rate['start_time'].to_s}")
            #                    doc.end_time("#{rate['end_time'].to_s}")
            #                    doc.daytype("#{rate['daytype'].to_s}")
            #                  }
            #                }
            #              }
            #            }

          else

            result = @tariff.tariffs_api_wholesale

            outstring << "<page>
                                     <pagename>#{_('Tariff')}</pagename>
                                     <tariff_name>#{CGI::escapeHTML(@tariff.name.to_s)}</tariff_name>
                                     <purpose>#{@tariff.purpose}</purpose>
                                     <currency>#{@tariff.currency}</currency>
                                    <rates>"
            result.each { |rate|
              outstring << "<rate>
                                       <direction>#{CGI::escapeHTML(rate['direction'].to_s)}</direction>
                                       <destination>#{CGI::escapeHTML(rate['destination'].to_s)}</destination>
                                       <prefix>#{rate['prefix'].to_s}</prefix>
                                       <subcode>#{rate['subcode'].to_s}</subcode>
                                       <code>#{rate['code'].to_s}</code>
                                       <tariff_rate>#{nice_number(rate['rate']).to_s}</tariff_rate>
                                       <con_fee>#{nice_number(rate['connection_fee']).to_s}</con_fee>
                                       <increment>#{rate['increment_s'].to_s}</increment>
                                       <min_time>#{rate['min_time'].to_s}</min_time>
                                       <start_time>#{rate['start_time'].to_s[%r[\w{2}:\w{2}:\w{2}]]}</start_time>
                                       <end_time>#{rate['end_time'].to_s[%r[\w{2}:\w{2}:\w{2}]]}</end_time>
                                       <daytype>#{rate['daytype'].to_s}</daytype>
                                       </rate>"
            }
            outstring << "</rates>
                         </page>"

            #            doc.page{
            #              doc.pagename("#{_('Tariff')}")
            #              doc.tariff_name("#{@tariff.name.to_s}")
            #              doc.currency("#{@tariff.currency}")
            #              doc.rates{
            #                result.each{ |rate|
            #                  doc.rate{
            #                    doc.direction("#{rate['direction'].to_s}")
            #                    doc.destination("#{rate['destination'].to_s}")
            #                    doc.prefix("#{rate['prefix'].to_s}")
            #                    doc.subcode("#{rate['subcode'].to_s}")
            #                    doc.code("#{rate['code'].to_s}")
            #                    doc.tariff_rate("#{nice_number(rate["rate"]).to_s}")
            #                    doc.con_fee("#{nice_number(rate["connection_fee"]).to_s}")
            #                    doc.increment("#{rate['increment_s'].to_s}")
            #                    doc.min_time("#{rate['min_time'].to_s}")
            #                    doc.start_time("#{rate['start_time'].to_s}")
            #                    doc.end_time("#{rate['end_time'].to_s}")
            #                    doc.daytype("#{rate['daytype'].to_s}")
            #                  }
            #                }
            #              }
            #            }
          end
        else
          outstring << "<status><error>No tariff found</error></status>"
        end
      else
        outstring << "<status><error>Bad login</error></status>"
      end
    else
      outstring << "<status><error>Incorrect hash</error></status>"
    end
    send_xml_data(outstring, params[:test].to_i, "get_tariff_#{Time.now.to_i}.xml", true)
  end


  def get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.find(:all, :conditions => "rate_id = #{rate.id.to_s}", :order => "rate DESC")
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({:exrate => exrate, :prices => [@rate_details[0]['rate'].to_f, @rate_details[0]['connection_fee'].to_f]})
    end
    @rate_details
  end


  def dg_list_user_destinations

    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])
    if @user
      @user.logged = 1
      @user.save

      @destgroup = Destinationgroup.find(params[:dest_gr_id])
      @destinations = @destgroup.destinations

      doc.page {
        doc.pagename("#{_('Destinations')}")
        doc.language("#{Localization.lang}")
        doc.groupname("#{@destgroup.name} #{@destgroup.desttype}")
        doc.groupicon("#{@destgroup.flag}")
        doc.directions {
          for destination in @destinations
            doc.direction {
              doc.details("#{destination.direction.name} #{destination.name}")
              doc.prefix("#{destination.prefix}")
              doc.dir_code("#{destination.subcode}")
            }
          end
        }
      }

    else

      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
        }
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end


  def personal_payments

    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])
    if @user
      @user.logged = 1
      @user.save

      @payments = @user.payments
      doc.page {
        doc.pagename("#{_('Payments')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.payments {
          for payment in @payments
            completed = _('Yes')
            if  payment.completed.to_i == 0
              completed = _('No')
              completed += " (" + payment.pending_reason + ")" if payment.pending_reason
            end
            doc.payment {
              doc.payment_date("#{nice_date_time payment.date_added}")
              doc.confirmed_date("#{nice_date_time payment.shipped_at}")
              doc.payment_type("#{payment.paymenttype.capitalize}")
              pa = payment.amount
              pa = (payment.amount / (100 + @user.vat_percent)) * 100 if payment.paymenttype == "paypal"
              pa = (payment.amount / (100 + payment.vat_percent)) * 100 if payment.paymenttype == "voucher"
              doc.amount("#{nice_number pa}")
              if payment.paymenttype != "voucher"
                doc.vat("#{@user.vat_percent}")
              else
                doc.vat("#{payment.vat_percent}")
              end
              awv = payment.amount
              awv = payment.amount if payment.paymenttype == "paypal"
              awv = payment.invoice.price_with_vat if payment.paymenttype == "invoice"
              awv = payment.amount if payment.paymenttype == "voucher"
              doc.amount_vat("#{nice_number awv}")
              doc.currency("#{payment.currency}")
              doc.completed("#{completed}")
            }
          end
        }
      }
    else

      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
        }
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end


  def user_invoices
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])
    if @user
      @user.logged = 1
      @user.save
      @user.postpaid.to_i == 1 ? type = "postpaid" : type = "prepaid"
      @invoices = @user.invoices(:include => [:tax, :user])

      doc.page {
        doc.pagename("#{_('Invoices')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.invoices {
          for inv in @invoices
            doc.invoice {
              user = inv.user
              doc.user("#{user.first_name + " " + user.last_name}")
              doc.inv_number("#{inv.number}")
              doc.period_start("#{inv.period_start}")
              doc.period_end("#{inv.period_end}")
              doc.issue_date("#{inv.issue_date}")
              doc.paid("#{inv.paid}")
              doc.paid_date("#{nice_date_time inv.paid_date if inv.paid == 1 }")
              doc.price("#{nice_invoice_number(inv.price, type)}")
              doc.price_vat("#{nice_invoice_number(inv.price_with_tax(:precision => nice_invoice_number_digits(type)), type)}")
            }
          end
        }
      }
    else
      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
        }
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def user_subscriptions
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    check_user(params[:u], params[:p])

    if @user
      @user.logged = 1
      @user.save

      @subscriptions = @user.subscriptions

      doc.page {
        doc.pagename("#{_('User_subscriptions')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.subscriptions {
          for sub in @subscriptions
            doc.subscription {
              doc.service("#{sub.service.name}")
              doc.date_added("#{sub.added}")
              doc.activation_start("#{sub.activation_start}")
              doc.activation_end("#{sub.activation_end}")
              doc.price("#{sub.service.price}")

            }
          end
        }
      }
    else
      doc.page {
        doc.pagename("#{_('User_subscriptions')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
        }
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end

=begin rdoc
 *Post*/*Get* *params*:
 *s_direction - "outgoing"
 * period_start - calls period starting date.
   Default - Today 00:00
 * period_end - calls period ending date.
   Default - Today 23:59
 *s_call_type -"all",
 *s_device=>"all",
 *s_provider=>"all",
 *s_hgc=>0,
 *s_user => "all",
 *user => nil,
 *s_did => "all",
 *s_destination => "",
 *order_by => "time",
 *order_desc => 0,
 *s_country=>''
 * Hash - SHA1 hash
=end

  def user_calls

    allow, values =MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    if allow == true

      username = params[:u].to_s
      password = params[:p].to_s

      @user_logged = check_user(username, password)
      if @user_logged
        @options = last_calls_stats_parse_params
        if @user_logged.usertype.to_s == "user"
          user = @user_logged
          device = Device.find_by_id(@options[:s_device]) if @options[:s_device] != "all" and !@options[:s_device].blank?
        end

        if @user_logged.usertype.to_s == "reseller"
          user = User.find(:first, :conditions => ["id=? and owner_id =?", @options[:s_user], @user_logged.id]) if @options[:s_user] =~ /^[0-9]+$/
          user = @user_logged if @options[:s_user].to_i == @user_logged.id.to_i
          device = Device.find_by_id(@options[:s_device]) if @options[:s_device] != "all" and !@options[:s_device].blank?
          if Confline.get_value('Show_HGC_for_Resellers').to_i == 1
            hgc = Hangupcausecode.find_by_id(@options[:s_hgc]) if @options[:s_hgc].to_i > 0
          end

          if @user_logged.reseller_allow_providers_tariff?
            if @options[:s_provider].to_i > 0
              provider = Provider.find(:first, :conditions => ["providers.id = ?", @options[:s_provider]])
              unless provider
                provider = nil
              end
            end
          else
            provider = nil
          end

        end

        if ["admin", "accountant"].include?(@user_logged.usertype.to_s)
          user = User.find_by_id(@options[:s_user]) if @options[:s_user] =~ /^[0-9]+$/
          device = Device.find_by_id(@options[:s_device]) if @options[:s_device] != "all" and !@options[:s_device].blank?
          did = Did.find_by_id(@options[:s_did]) if @options[:s_did] != "all" and !@options[:s_did].blank?
          hgc = Hangupcausecode.find_by_id(@options[:s_hgc]) if @options[:s_hgc].to_i > 0
          provider = Provider.find_by_id(@options[:s_provider]) if @options[:s_provider].to_i > 0
        end

        if user or @options[:s_user] == "all"

          @options[:from] = values[:period_start] ? Time.at(values[:period_start]).to_s(:db) : Time.mktime(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0).to_s(:db)
          @options[:till] = values[:period_end] ? Time.at(values[:period_end]).to_s(:db) : Time.mktime(Time.now.year, Time.now.month, Time.now.day, 23, 59, 59).to_s(:db)
          @options[:exchange_rate] = 1 #exchange_rate
          options = last_calls_stats_set_variables(@options, {:user => user, :device => device, :hgc => hgc, :did => did, :current_user => @user_logged, :provider => provider, :can_see_finances => ((not @user_logged.is_accountant?) || @user_logged.can_see_finances?)})
          options[:current_user] = @user_logged

          calls = Call.last_calls_csv(options.merge({:pdf => 1}))


          doc.page {
            doc.pagename("Calls")
            doc.language("en")
            doc.error_msg("#{}")
            doc.userid(@user_logged.id)
            doc.username(@user_logged.username)
            doc.total_calls("#{calls.size}")
            doc.currency(Currency.find(1).name)
            doc.calls_stat {
              doc.period {
                doc.period_start(@options[:from])
                doc.period_end(@options[:till])
              }
              doc.show_user(@options[:s_user])
              doc.show_device(@options[:s_device])
              doc.show_status(@options[:s_call_type])
              doc.show_provider(@options[:s_provider]) if !@options[:s_provider].blank?
              doc.show_hgc(((@options[:s_hgc].to_i > 0) ? @options[:s_hgc].to_i : 'all')) if !@options[:s_hgc].blank?
              doc.show_did(@options[:s_did]) if !@options[:s_did].blank?
              doc.show_destination(@options[:s_destination]) if !@options[:s_destination].blank?
              if calls and calls.size.to_i > 0
                doc.calls {
                  for call in calls
                    doc.call {
                      call.attributes.sort.each { |key, value|
                        case key.to_s
                          when 'calldate'
                            doc.tag!(key, nice_date_time(value))
                          when 'dst'
                            doc.tag!(key, hide_dst_for_user(@user_logged, "gui", value))
                          else
                            doc.tag!(key, call[key])
                        end
                      }
                    }
                  end
                }
              end
            }
          }
        else
          doc.error("User was not found")
        end
      else
        doc.error('Dont be so smart')
        MorApi.create_error_action(params, request, 'API : User not found by login and password')
      end
    else
      doc.error("Incorrect hash")
    end

    send_xml_data(out_string, params[:test].to_i)
  end

=begin rdoc
*Post*/*Get* *params*:
* monitoring_id - monitoring id
* users - user id list separated by commas
* email - true/false send or do not send emails
* block - true/false block ar do not block users
=end

  def ma_activate
    allow, values =MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    users = []
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    if allow == true
      if defined?(MA_Active) and MA_Active == 1
        if (values.keys & [:monitoring_id, :users, :block, :email, :mtype]).size == 5
          monitoring = Monitoring.find(:first, :conditions => {:id => values[:monitoring_id], :block => (values[:block] == "true") ? true : false, :email => (values[:email] == "true") ? true : false, :mtype => values[:mtype]})
          if monitoring
            doc.status {
              doc.monitoring_found("success")
              doc.users {
                values[:users].split(",").each { |id|
                  user = User.find_by_id(id)
                  doc.user {
                    doc.id(id)
                    if user
                      users << user
                      status = ""

                      if monitoring.block_user?
                        unless user.blocked?
                          user.update_attribute(:blocked, 1) unless user.blocked?
                          status << " blocked"
                        else
                          status << " already blocked"
                        end
                      end

                      if monitoring.send_email?
                        if Confline.get('Email_Sending_Enabled').value.to_i == 1
                          admin = User.find_by_id(monitoring.owner_id)
                          if admin.address and !admin.address.email.empty?
                            status << " email sent"
                          else
                            status << " monitoring owner has no email set"
                          end
                        else
                          status << " email sending not enabled, check configuration"
                        end

                        unless users.empty?
                          email = Email.find(:first, :conditions => {:name => 'monitoring_activation', :owner_id => monitoring.owner_id})
                          user = User.find_by_id(monitoring.owner_id)

                          if monitoring.monitoring_type == 'simultaneous'
                            for calls in monitoring.simultaneous_calls
                              call_list = calls.dst + '|' + calls.calldateA + '|' + calls.srcA + '|' + calls.calldateB + '|' + calls.srcB + '|\n'
                            end
                          else
                            call_list = ''
                          end

                          variables = Email.email_variables(user, nil, {:monitoring => monitoring, :monitoring_type => monitoring.monitoring_types, :monitoring_users_list => users, :call_list => call_list})
                          EmailsController::send_email(email, Confline.get_value("Email_from", user.id), [user], variables)
                        end

                      end

                      Action.add_action_hash(monitoring.owner_id, # for admin
                                             {:action => "monitoring_activate",
                                              :data => "Monitoring activated",
                                              :data2 => status,
                                              :data3 => "user: #{user.id} #{user.username} #{user.balance} #{Currency.get_default.name}",
                                              :target_id => monitoring.id,
                                              :target_type => "monitoring"
                                             })

                      doc.status(status)
                      #                      else
                      #                        doc.status("error: this monitoring does not apply for this user")
                      #                      end
                    else
                      doc.status("error: not found")
                    end
                  }
                }


              }
            }
          else
            doc.status {
              doc.error("Such monitoring was not found. Verify master-slave database integrity.")
            }
          end
        else
          doc.status {
            doc.error("You must supply these params: monitoring_id, users, block, email, mtype")
          }
        end
      else
        doc.status {
          doc.error("Monitorings addon is disabled")
        }
      end
    else
      doc.status {
        doc.error("Incorrect hash")
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def new_calls_list
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    check_user(params[:u], params[:p])
    if @user
      @user.logged = 1
      @user.save

      calls_hash = @user.new_calls(@current_user.system_time(Date.today.to_s, 1))

      @calls = []
      for call_h in calls_hash
        @calls << Call.find(call_h["id"])
      end

      @select_date = false

      doc.page {
        doc.pagename("#{_('New_calls')}")
        doc.language("#{Localization.lang}")
        doc.userid("#{@current_user.id}")
        doc.calls_stat {
          doc.total_calls("#{@calls.size}")
          doc.calls {
            for call in @calls
              doc.call {
                doc.date("#{call.date.strftime("%Y-%m-%d %H:%M:%S")}")
                doc.called_from("#{call.src}")
                doc.called_to("#{hide_dst_for_user(@user, "gui", call.dst)}")
                if @call_type != "missed"
                  doc.duration("#{nice_time call.billsec}")
                else
                  doc.duration("#{nice_time call.duration}")
                end
                doc.hangup_cause("#{call.disposition}")
              }
            end
          }
        }
      }
    else

      doc.page {
        doc.pagename("#{_('User_subscriptions')}")
        doc.language("en")
        doc.error_msg("")
        doc.aval_languages {
        }
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def simple_balance
    if Confline.get_value("Devices_Check_Ballance").to_i == 1
      @user = User.find(:first, :conditions => "uniquehash = '#{params[:id]}'")
      if @user
        if params[:currency].to_s.blank? # in case currency was not supplied or is blank return balance in system's currency
          user_balance = @user.balance
        elsif params[:currency].to_s.downcase == 'user'
          user_balance = @user.balance * Currency.count_exchange_rate(Currency.get_default.name, @user.currency.name)
        elsif Currency.find(:first, :conditions => {:name => params[:currency]}) # in case valid currency was supplied return balance in that currency
          user_balance = @user.balance * Currency.count_exchange_rate(Currency.get_default.name, params[:currency])
        else # in case invalid currency value was supplied, return currency in system's currency
          user_balance = @user.balance
        end
        render :text => nice_number(user_balance).to_s
      else
        render :text => _("User_Not_Found")
      end
    else
      render :text => _("Feature_Disabled")
    end
  end

  def balance
    if Confline.get_value("Devices_Check_Ballance").to_i == 1
      user = User.find(:first, :conditions => ["username = ?", params[:username]])
      if user
        if params[:currency].to_s.blank? # in case currency was not supplied or is blank return balance in system's currency
          user_balance = user.balance
        elsif params[:currency].to_s.downcase == 'user'
          user_balance = user.balance * Currency.count_exchange_rate(Currency.get_default.name, user.currency.name)
        elsif Currency.find(:first, :conditions => {:name => params[:currency]}) # in case valid currency was supplied return balance in that currency
          user_balance = user.balance * Currency.count_exchange_rate(Currency.get_default.name, params[:currency])
        else # in case invalid currency value was supplied, return currency in system's currency
          user_balance = user.balance
        end
        render :text => nice_number(user_balance).to_s
      else
        render :text => _("User_Not_Found")
      end
    else
      render :text => _("Feature_Disabled")
    end
  end

  def rate
    if Confline.get_value("Devices_Check_Rate").to_i == 1
      prefix = split_number(params[:prefix])
      if prefix.size > 0
        user = User.find(:first, :conditions => ["username = ?", params[:username]])
        if user
          destination = Destination.find(:first, :include => [:destinationgroup],
                                         :conditions => ["prefix IN (?)", prefix],
                                         :order => "LENGTH(prefix) DESC")
          if destination
            dg = destination.destinationgroup
            rate = Rate.find(:first, :include => [:ratedetails, :aratedetails], :conditions => ["(rates.destination_id = ? or rates.destinationgroup_id = ?) AND rates.tariff_id = ?", destination.id, dg.id, user.tariff_id])
            if rate and (rate.ratedetails.size > 0 or rate.aratedetails.size > 0)
              text = "#{rate.aratedetails[0].price}\##{destination.name}\##{destination.prefix}" if rate.aratedetails.size > 0
              text = "#{rate.ratedetails[0].rate}\##{destination.name}\##{destination.prefix}" if rate.ratedetails.size > 0
              render :text => text.to_s
            else
              tariff = user.tariff
              err = ["MorApi.Rate error: rate not found"]
              err << "  >> Destination: ID:'#{destination.id}' Name: #{destination.name}, Prefix:#{destination.prefix}"
              err << "  >> Tariff: ID:#{tariff.id} Name:'#{tariff.name}' Purpose:'#{tariff.purpose}'" if tariff
              err << "  >> Rate: ID:#{rate.id}" if rate
              err << "  >> RateDetails: #{rate.ratedetails.size}" if rate and rate.ratedetails
              err << "  >> aRateDetails: #{rate.aratedetails.size}" if rate and rate.aratedetails
              MorLog.my_debug(err.join("\n"))
              render :text => _("Rate_was_not_found") # Rate not found
            end
          else
            MorLog.my_debug("MorApi.Rate error: destination/prefix was not found")
            render :text => _("Prefix_not_found") # Destination/prefix not found
          end
        else
          MorLog.my_debug("MorApi.Rate error: user was not found")
          render :text => _("User_not_found") # User not found
        end
      else
        MorLog.my_debug("MorApi.Rate error: prefix is blank")
        render :text => _("Empty_prefix") # empty prefix
      end
    else
      MorLog.my_debug("MorApi.Rate error: Feature is disabled")
      render :text => _("Feature_Disabled")
    end
  end


  def user_register
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8", :standalone => "yes"
    doc.page {
      if Confline.get_value("API_Allow_registration_ower_API").to_i == 1
        if !params[:id] or !User.find(:first, :conditions => ["uniquehash = ?", params[:id]])
          doc.status { doc.error(_('Dont_be_so_smart')) }
        else
          owner = User.find(:first, :conditions => ['uniquehash=?', params[:id]])
          if owner
            notice = User.validate_from_registration(params)
            capt = true
            if Confline.get_value("reCAPTCHA_enabled").to_i == 1
              usern = User.new
              capt = verify_recaptcha(usern) ? true : (false; notice = _('Please_enter_captcha'))
            end
            if capt and notice.blank?
              reg_ip = request.remote_ip
              user, send_email_to_user, device, notice2 = User.create_from_registration(params, owner, reg_ip, free_extension(), new_device_pin(), random_password(12), next_agreement_number, 1)
              if notice2.blank?
                doc.status { doc.success(_('Registration_succesful')) }
                a = Thread.new { configure_extensions(device.id, {:api => 1, :current_user => owner}) }
                doc.user_device_settings {
                  MorLog.my_debug user.to_yaml
                  us = User.find(user.id)
                  MorLog.my_debug "************************************************88"
                  MorLog.my_debug us.to_yaml if us
                  if send_email_to_user == 1
                    doc.email(user.address.email)
                  end
                  #if !a
                  if device
                    doc.device_type(device.device_type)
                    doc.username(device.username)
                    doc.password(device.secret)
                    doc.pin(device.pin)
                    doc.server_ip(Confline.get_value("Asterisk_Server_IP", 0))
                  end
                  doc.registration_notice("*#{_('Registration_notice')}")
                  #end
                }
              else
                doc.status { doc.error(notice2) }
              end
            else
              doc.status { doc.error(notice) }
            end
          else
            doc.status { doc.error(_('Dont_be_so_smart')) }
          end
        end
      else
        doc.status { doc.error("Registration over API is disabled") }
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end


=begin rdoc
 *Post*/*Get* *params*:
 * user_id - User id
 * balance - balance.
 * Hash - SHA1 hash
=end

  def user_balance_change
    allow, values =MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user
        user_b = User.find(:first, :conditions => ["id = ? AND owner_id = ? ", values[:user_id], @user.id]) if values[:user_id]
        if user_b
          old_balance = user_b.balance.to_f
          if values[:balance]
            user_b.balance = user_b.balance + values[:balance].to_f
            if user_b.save
              Action.add_action_hash(@user, {:target_id => user_b.id, :target_type => 'User', :action => 'User balance changed from API', :data => old_balance, :data2 => user_b.balance, :data3 => request.env["REMOTE_ADDR"].to_s})
              doc.page {
                doc.status("User balance updated")
                doc.user {
                  doc.username(user_b.username)
                  doc.id(user_b.id)
                  doc.balance(user_b.balance)
                }
              }
            else
              Action.add_action_hash(@user, {:target_id => user_b.id, :target_type => 'User', :action => 'User balance not changet from API', :data => request["REQUEST_URI"].to_s[0..255], :data2 => request["REMOTE_ADDR"].to_s, :data3 => params.inspect.to_s[0..255], :data4 => user_b.errors.to_yaml})
              doc.error("User balance not updeted")
              #doc.notice("User balance not updeted")
            end
          else
            Action.add_action_hash(@user, {:target_id => user_b.id, :target_type => 'User', :action => 'User balance not changet from API', :data => request["REQUEST_URI"].to_s[0..255], :data2 => request["REMOTE_ADDR"].to_s, :data3 => params.inspect.to_s[0..255], :data4 => user_b.errors.to_yaml})
            doc.error("User balance not updeted")
          end
        else
          doc.error("User was not found")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
           }
    send_xml_data(out_string, params[:test].to_i)
  end

  # http://trac.kolmisoft.com/trac/ticket/4236
  # ALTER TABLE devices ADD allow_grandstreams INT default 0 COMMENT 'Allow grandstreams realtime data sending';
  #
  #  def grandstreams_realtime_data_for_callshop
  #
  #    doc = Builder::XmlMarkup.new( :target => out_string = "", :indent => 2 )
  #    doc.instruct! :xml, :version => "1.0"
  #    doc.Screen{
  #      doc.IdleScreen{
  #        doc.ShowStatusLine("true")
  #        if call_shop_active?
  #          user = User.find(:first, :include=>[:tariff, :currency],:conditions=>{:id => params[:id]})
  #          if user
  #            device = Device.find(:first, :conditions=>{:user_id => user.id})
  #            if device and device.try(:allow_grandstreams).to_i == 1
  #              call = Activecall.find(:first, :select=>"activecalls.prefix, activecalls.answer_time, activecalls.user_rate, activecalls.start_time",:conditions=>{:user_id => user.id})
  #
  #              if call
  #                time = nice_time2(call.start_time)
  #                duration = nice_time(call.duration)
  #                dest = Destination.find(:first, :conditions => ["prefix = ?", call.prefix])
  #                if dest
  #                  n_dest =  dest.direction.name if dest.direction
  #                end
  #
  #                if user.tariff.purpose == 'user'
  #                  connection_fee = 0
  #                else
  #                  ratedetails = Rate.find(:first, :select=>"*", :joins=>" JOIN ratedetails ON (rate_id = rates.id)", :conditions=>["tariff_id = ? and destination_id = ?  AND ? BETWEEN ratedetails.start_time AND ratedetails.end_time", user.tariff_id, dest.id, time ])
  #                  connection_fee = ratedetails.connection_fee
  #                end
  #
  #                price =  nice_number((call.user_rate.to_f * (call.duration.to_f / 60.to_f).to_f) + connection_fee.to_f)
  #
  #                rate = call.user_rate
  #
  #                doc.DisplayString(:font=>"f8"){
  #                  doc.DisplayStr(n_dest.to_s + ' ' + _('Rate') + ': ' + rate.to_s + ' ' + user.currency.name.to_s + '/min')
  #                  doc.x(0)
  #                  doc.y(0)
  #                }
  #                doc.DisplayString(:font=>"f8"){
  #                  doc.DisplayStr(_('Time') + ': ' +duration.to_s + ' ' + _('Price') + ': '+ price.to_s + ' ' + user.currency.name.to_s)
  #                  doc.x(65)
  #                  doc.y(12)
  #                }
  #              else
  #                doc.DisplayString(:font=>"f8"){
  #                  doc.DisplayStr(_('Call_not_found'))
  #                  doc.x(65)
  #                  doc.y(12)
  #                }
  #              end
  #            else
  #              doc.DisplayString(:font=>"f8"){
  #                doc.DisplayStr(_('Setting_is_off'))
  #                doc.x(65)
  #                doc.y(12)
  #              }
  #            end
  #          else
  #            doc.DisplayString(:font=>"f8"){
  #              doc.DisplayStr(_('User_not_found'))
  #              doc.x(65)
  #              doc.y(12)
  #            }
  #          end
  #        else
  #          doc.DisplayString(:font=>"f8"){
  #            doc.DisplayStr(_('No_callshop_addon_active'))
  #            doc.x(65)
  #            doc.y(12)
  #          }
  #        end
  #
  #      }
  #    }
  #    send_xml_data(out_string, params[:test].to_i, "gs_screen.xml")
  #  end


  def user_update_api
    allow, values =MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user
        if @user.usertype == 'user' or (@user.usertype == 'accountant' and (values[:user_id].to_i == 0 or values[:user_id].to_i == @user.id))
          doc.error("Don't be so smart")
        else
          if @user.usertype == 'accountant'
            owner_id = 0
          else
            owner_id = @user.id
          end
          if @user.usertype == 'reseller'
            user_u = User.find(:first, :conditions => ["id = ? AND owner_id = ? ", values[:user_id], owner_id]) if values[:user_id]
            user_u = @user if values[:user_id] == owner_id
          else
            user_u = User.find(:first, :conditions => ["id = ? AND owner_id = ? ", values[:user_id], owner_id]) if values[:user_id]
          end
          if user_u

            params[:address] = {}
            ['address', 'city', 'postcode', 'county', 'mob_phone', 'fax', 'direction_id', 'phone', 'email', 'state'].each_with_index { |s, i|
              params[:address][s.to_sym] = params["a#{i}"] if params["a#{i}"]
            }

            params[:user] = {}
            ['vat_number', 'lcr_id', 'warning_email_hour', 'hide_destination_end', 'currency_id', 'tariff_id', 'warning_email_balance',
             'spy_device_id', 'language', 'username', 'warning_balance_call', 'acc_group_id', 'generate_invoice', 'usertype', 'taxation_country', 'blocked', 'quickforwards_rule_id', 'last_name', 'call_limit',
             'clientid', 'recording_hdd_quota', 'cyberplat_active', 'recordings_email', 'first_name', 'warning_balance_sound_file_id', 'postpaid', 'accounting_number', 'agreement_number', 'hidden'].each_with_index { |s, i|
              params[:user][s.to_sym] = params["u#{i}"] if params["u#{i}"]
            }

            params[:agr_date] = {}
            params[:agr_date][:year] = params[:ay]
            params[:agr_date][:day] = params[:ad]
            params[:agr_date][:month] = params[:am]


            params[:block_at_date] = {}
            params[:block_at_date][:year] = params[:by]
            params[:block_at_date][:day] = params[:bd]
            params[:block_at_date][:month] = params[:bm]

            params[:password] = {}
            params[:password][:password]=params[:pswd] if params[:pswd]


            params[:date] = {}
            params[:date][:user_warning_email_hour] = params[:user_warning_email_hour]

            params[:privacy] = {}
            params[:privacy][:gui] = params[:pgui]
            params[:privacy][:csv] = params[:pcsv]
            params[:privacy][:pdf] = params[:ppdf]

            #paramas += pp
            MorLog.my_debug @user.usertype
            if @user.usertype == 'accountant'
              sql = "SELECT value FROM acc_group_rights JOIN acc_groups ON (acc_groups.id = acc_group_id) JOIN acc_rights ON (acc_rights.id = acc_right_id) WHERE acc_rights.name ='user_manage' and right_type = 'accountant' AND acc_group_id = #{@user.acc_group_id}"
              v = ActiveRecord::Base.connection.select_value(sql)
              MorLog.my_debug v
              MorLog.my_debug sql
              allow_edit = v.to_i == 2 ? true : false
            else
              allow_edit = true
            end
            notice, par = user_u.validate_from_update(@user, params, allow_edit, 1)
            if notice.blank?
              tax = {"tax1_enabled" => 1}
              tax.merge!({:tax2_enabled => params[:tax2_enabled].to_i}) if params[:tax2_enabled]
              tax.merge!({:tax3_enabled => params[:tax3_enabled].to_i}) if params[:tax3_enabled]
              tax.merge!({:tax4_enabled => params[:tax4_enabled].to_i}) if params[:tax4_enabled]
              tax.merge!({:tax1_name => params[:tax1_name].to_s}) if not params[:tax1_name].to_s.blank?
              tax.merge!({:tax2_name => params[:tax2_name].to_s}) if not params[:tax2_name].to_s.blank?
              tax.merge!({:tax3_name => params[:tax3_name].to_s}) if not params[:tax3_name].to_s.blank?
              tax.merge!({:tax4_name => params[:tax4_name].to_s}) if not params[:tax4_name].to_s.blank?
              tax.merge!({:total_tax_name => params[:total_tax_name].to_s}) if params[:total_tax_name]
              tax.merge!({:tax1_value => params[:tax1_value].to_f}) if params[:tax1_value]
              tax.merge!({:tax2_value => params[:tax2_value].to_f}) if params[:tax2_value]
              tax.merge!({:tax3_value => params[:tax3_value].to_f}) if params[:tax3_value]
              tax.merge!({:tax4_value => params[:tax4_value].to_f}) if params[:tax4_value]
              tax.merge!({:compound_tax => params[:compound_tax].to_i}) if params[:compound_tax]

              user_u.update_from_edit(par, @user, tax, monitoring_enabled_for(@user), rec_active?, 1)

              if user_u.save
                if user_u.usertype == "reseller"
                  user_u.check_default_user_conflines
                end
                user_u.address.save
                doc.status("User was updated")
              else
                doc.error("User was not updated")
                user_u.errors.each { |key, value|
                  doc.message(_(value))
                } if user_u.respond_to?(:errors)
              end
            else
              doc.error(notice)
            end
          else
            doc.error("User was not found")
          end
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
                       }
    send_xml_data(out_string, params[:test].to_i)
  end

  def device_destroy

    allow, values =MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user
        device = Device.find(:first, :conditions => {:id => params[:device]})
        if device
          if check_owner_for_device(device.user_id, 0, @user)
            if @user.usertype == 'accountant'
              sql = "SELECT value FROM acc_group_rights JOIN acc_groups ON (acc_groups.id = acc_group_id) JOIN acc_rights ON (acc_rights.id = acc_right_id) WHERE acc_rights.name ='device_manage' and right_type = 'accountant' AND acc_group_id = #{@user.acc_group_id}"
              v = ActiveRecord::Base.connection.select_value(sql)
              allow_edit = v.to_i == 1 ? true : false
            else
              allow_edit = true
            end
            notice = device.validate_before_destroy(@user, allow_edit)
            if !notice.blank?
              doc.error(notice)
            else
              device.destroy_all
              doc.status("Device was deleted")
            end
          else
            dont_be_so_smart(@user.id)
            doc.error("Dont be so smart")
          end
        else
          doc.error("Device was not found")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end


  # HACK: laikinas metodas pritaikantis xmlsimple parse formata prie parasyto funcionalumo
  # TO DO: reikia patvarkyti kad veiktu be sito!!!
  def transition_hash(h)
    def clean_keys(h)
      nh = {}
      h.each_pair do |k, v|
        if v.is_a?(Array) and v.first.is_a?(String)
          nh[k.to_sym] = v.first.strip
        elsif v.is_a?(Array)
          nh[k.to_sym] = []
          v.each { |i| nh[k.to_sym] << clean_keys(i) }
        end
      end
      nh
    end

    # get one level down
    h.each_pair do |key, value|
      if value.is_a?(Array) and value.first.is_a?(Hash) and value.first.keys.size == 1
        value = value.first[value.first.keys.first]
        h[key] = value
      end
    end

    clean_keys(h)
  end

  #----

  def import_tariff_retail

    doc = Builder::XmlMarkup.new(:target => out_string4 = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    #check if user exists
    @user = check_user(params[:u], params[:p])
    collision_rates = []
    collision_rates_with_db = []
    bad_destination_array = []
    bad_rates_array = []
    bad_rates_time_array = []
    day_type_collision = []
    if @user
      # get xml and parse
      if params[:xml]
        xml = params[:xml]
        tariffs = []

        begin
          tariffs = XmlSimple.xml_in(xml)
          value = transition_hash(tariffs)

          #---- TO CHECK PARAMS HERE!-------------------
          logger.fatal "CHECK HERE"
          logger.fatal value.inspect
          value, error = check_params_name_id(value, @user)

          if error.empty? #then proceed

            logger.fatal "TARIFF NAME "+ value[:name].to_s

            #now we have tariff with name and id
            tariff_id = value[:id]

            #check if there are destinations
            if value[:destinations]
              #go trough destinations

              logger.fatal "DESTINATIONS FOUND: " +value[:destinations].size.to_s

              value[:destinations].each do |destination|
                logger.fatal "----------DATA -------------------------------------"
                logger.fatal "Direction name: '" + destination[:direction].to_s + "'"
                logger.fatal "Destination name: '" + destination[:destination_group_name].to_s + "'"
                logger.fatal "Destination type: '"+ destination[:destination_group_type].to_s + "'"
                logger.fatal "Rates for this destination: "+destination[:rates].size.to_s

                #check for collision in xml rates
                ##### bad_rates_time TO DO ISVESTI KUR BLOGI LAIKAI, RATES ISTRINAMI
                collision_rates, bad_rates_time_array = check_params_rates(destination[:rates], destination) if destination[:rates].size > 1

                logger.fatal "Rates for this destination after collision check in xlm: "+destination[:rates].size.to_s
                logger.fatal "----------WORK  WITH DB ----------------------------"

                #find destinationgroups_id by name and type
                sql = "SELECT destinationgroup_id FROM destinations WHERE destinationgroup_id = (SELECT id FROM destinationgroups WHERE name = \"#{destination[:destination_group_name].to_s}\" AND desttype = '#{destination[:destination_group_type].to_s}') GROUP BY subcode"
                rate_destinationgroups_id = ActiveRecord::Base.connection.select_value(sql)
                if rate_destinationgroups_id
                  logger.fatal "DB DESTINATION ID: " + rate_destinationgroups_id.to_s
                  #find rate by tariff id and destination group
                  rate_id = Rate.find(:first, :conditions => ["tariff_id = ? and destinationgroup_id = ?", tariff_id, rate_destinationgroups_id])

                  if rate_id

                    #find existing rates
                    db_rates = Aratedetail.find(:all, :conditions => ['rate_id= ?', rate_id.id])
                    collision_rates_with_db = []
                    #start1 <= end2 and start2 <= end1
                    db_rates.each do |rate1|
                      # tikrinimas del koliziju su egzistuojanciu tarifu
                      destination[:rates].each do |rate2|
                        if (["WD", "FD"].include?(rate2[:day_type].to_s) and ["WD", "FD"].include?(rate1[:daytype].to_s)) or ([""].include?(rate2[:day_type].to_s) and [""].include?(rate1[:daytype].to_s))
                          if (rate1[:start_time].strftime("%X") != rate2[:rate_start_time] or rate1[:end_time].strftime("%X") != rate2[:rate_end_time]) and (rate1[:start_time].strftime("%X") <= rate2[:rate_end_time] and rate2[:rate_start_time] <= rate1[:end_time].strftime("%X")) and rate2[:day_type].to_s == rate1[:daytype].to_s
                            logger.fatal 'COLLISION!!!!!!!!!!!!!!!!!'
                            collision_rates_with_db << "#{destination[:destination_group_name]} #{destination[:destination_group_type]} COLLISION WITH EXISTING RATES IN " +[rate1[:start_time].strftime("%X"), rate2[:rate_start_time]].min.to_s + " AND " + [rate1[:end_time].strftime("%X"), rate2[:rate_end_time]].max.to_s + " TIME RANGE"
                            #delete all xml rates in collision time range
                            destination[:rates].delete_if { |el| (([rate1[:end_time].strftime("%X"), rate2[:rate_end_time]].max >= el[:rate_start_time] and el[:rate_start_time] >= [rate1[:start_time].strftime("%X"), rate2[:rate_start_time]].min) or ([rate1[:start_time].strftime("%X"), rate2[:rate_start_time]].min <= el[:rate_end_time] and el[:rate_end_time]<= [rate1[:end_time].strftime("%X"), rate2[:rate_end_time]].max)) and el[:day_type].to_s == rate1[:daytype].to_s }
                          end
                        else
                          day_type_collision << destination
                          destination[:rates].delete_if { |el| el == rate2 }
                        end
                      end
                    end

                    logger.fatal "Rates for this destination after collision check xml with db: "+destination[:rates].size.to_s
                    logger.fatal "DB RATE ID " + rate_id.id.to_s
                    #create rates and log bad rates
                    bad_rates_array = create_rates_merge(destination, rate_id.id, db_rates)
                  else
                    logger.fatal "DB RATE ID NOT FOUND"
                    logger.fatal "LETS CREATE"

                    rate_new = Rate.new()
                    rate_new.tariff_id = tariff_id.to_i
                    rate_new.destination_id = 0
                    rate_new.destinationgroup_id = rate_destinationgroups_id.to_i

                    if rate_new.save
                      #set now existing tariff id
                      logger.fatal "RATE CREATED " + rate_new.id.to_s
                    else
                      logger.fatal "RATE exists??!!! "
                      doc.response {
                        doc.error("RATE exists??!!")
                      }
                    end

                    #create rates and log bad rates
                    bad_rates_array = create_rates(destination, rate_new.id)
                  end

                  logger.fatal "---------------END----------------------------"
                else
                  logger.fatal "THIS DESTINATION NAME OR TYPE IS WRONG!"
                  bad_destination_array << destination
                end

              end

              bad_rates_array = bad_rates_array + bad_rates_time_array

              doc.response {
                doc.tariff_id("#{tariff_id}")
                doc.tariff_name("#{value[:name]}")
                doc.bad_destinations { |bd|
                  bad_destination_array.each { |d|
                    doc.destination { |i|
                      doc.destination_group_name("#{d[:destination_group_name]}")
                      doc.destination_group_type("#{d[:destination_group_type]}")
                    }
                  }
                }

                doc.destination_with_day_type_collision { |bd|
                  day_type_collision.each { |d|
                    doc.destination { |i|
                      doc.destination_group_name("#{d[:destination_group_name]}")
                      doc.destination_group_type("#{d[:destination_group_type]}")
                    }
                  }
                }

                doc.destination_with_bad_rates { |br|
                  bad_rates_array.each { |r|
                    doc.destination { |i|
                      doc.destination_group_name("#{r[:destination_group_name]}")
                      doc.destination_group_type("#{r[:destination_group_type]}")
                      doc.rate_price("#{r[:rate_price]}")
                      doc.rate_round_by("#{r[:rate_round_by]}")
                      doc.rate_duration("#{r[:rate_duration]}")
                      doc.rate_type("#{r[:rate_type]}")
                      doc.rate_start_time("#{r[:rate_start_time]}")
                      doc.rate_end_time("#{r[:rate_end_time]}")
                      doc.day_type("#{r[:day_type]}")
                    }
                  }
                }


                doc.destination_with_time_collisions_in_xml { |tc|
                  collision_rates.each { |d|
                    doc.destination { |i|
                      doc.collision_in_time_range("#{d}")
                    }
                  }
                }

                doc.destination_with_time_collisions_in_db { |tc|
                  collision_rates_with_db.each { |d|
                    doc.destination { |i|
                      doc.collision_in_time_range("#{d}")
                    }
                  }
                }
              }
            else

              doc.response {
                doc.error("No destinations!")
                doc.tariff_id("#{tariff_id}")
                doc.tariff_name("#{value[:name]}")
              }
            end
          else
            doc.response {
              doc.error(error)
            }
          end

        rescue REXML::ParseException
          logger.fatal 'No data!'
          doc.response {
            doc.error("Bad XML data")
          }
        rescue ArgumentError
          logger.fatal 'File does not exist!'
          doc.response {
            doc.error("File does not exist")
          }
        end

      else
        doc.response {
          doc.error("No XML")
        }
      end

    else
      doc.response {
        doc.error("Bad login")
      }
    end

    send_xml_data(out_string4, params[:test].to_i)
    #----------------------------------------------------------END--------------

  end

  def wholesale_tariff
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user and mor_11_extend? and (@user.is_admin? or @user.is_reseller? or (@user.is_accountant? and @user.accountant_allow_edit('Tariff_manage')))
        tariff_id = params[:id].to_i
        if tariff_id == 0
          tariff = Tariff.new
          tariff.name = params[:name].to_s if params[:name]
          tariff.currency = params[:currency].to_s if params[:currency]
          tariff.purpose = 'user_wholesale'
          tariff.owner_id = @current_user.id
          if tariff.save
            doc.status('ok')
            doc.tariff_id(tariff.id)
          else
            doc.error {
              tariff.errors.each { |key, value|
                doc.message(_(value))
              } if tariff.respond_to?(:errors)
            }
          end
        else
          tariff = Tariff.find(:first, :conditions => {:id => tariff_id, :owner_id => @user.id, :purpose => 'user_wholesale'})
          if tariff
            tariff.name = params[:name].to_s if params[:name]
            tariff.currency = params[:currency].to_s if params[:currency]
            if tariff.save
              doc.status('ok')
            else
              doc.error {
                tariff.errors.each { |key, value|
                  doc.message(_(value))
                } if tariff.respond_to?(:errors)
              }
            end
          else
            doc.error('Tariff not found')
          end
        end
      else
        doc.error('Bad login')
      end
    else
      doc.error('Incorrect hash')
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def check_params_name_id(tariff, user)
    error = ""
    # id - found - do not create tariff, but proceed
    # id - not found:
    #                name - found - error:check id! change name or id -> exit
    #                name - not found - will create tariff -> proceed

    if tariff[:id] and !tariff[:id].to_s.empty?
      if tariff[:name] and !tariff[:name].empty?

        #try find tariff by id
        #if not found - create one with given name
        try_find_tariff = Tariff.find_by_id(tariff[:id].to_i)
        if !try_find_tariff
          logger.fatal "TARIFF NOT FOUND. CREATING ONE"
          tariff_new = Tariff.new()
          tariff_new.name = tariff[:name].to_s
          tariff_new.purpose = "user"
          tariff_new.owner_id = @user.id
          tariff_new.currency = @user.currency.name

          if tariff_new.save
            #set now existing tariff id
            tariff[:id] = tariff_new.id
            logger.fatal "TARIFF CREATED " + tariff[:id].to_s
          else
            find_tariff_id = Tariff.find(:first, :conditions => ['name =? and purpose = "user"', tariff[:name].to_s])
            if find_tariff_id and (find_tariff_id.owner_id.to_i == user.id or user.usertype.to_s == 'admin')
              logger.fatal "TARIFF with same name exists, ID:#{find_tariff_id.id}!!! CHANGE NAME OR ID"
              error += "TARIFF with same name exists, ID:#{find_tariff_id.id}!!! CHANGE NAME OR ID"
            else
              logger.fatal "TARIFF with same name exists, it belongs to other user! CHANGE NAME OR ID"
              error += "TARIFF with same name exists, it belongs to other user! CHANGE NAME OR ID"
            end
          end

        else
          if try_find_tariff.owner_id.to_i == user.id
            if try_find_tariff.name.to_s == tariff[:name].to_s
              logger.fatal "TARIFF FOUND ID: " + tariff[:id].to_s
            else
              logger.fatal "NAME AND ID DO NOT MATCH !!! TARIFF FOUND ID: " + tariff[:id].to_s
              error += "TARIFF NAME WITH THIS ID DO NOT MATCH !!!"
              error += "FOUND " + try_find_tariff.name.to_s
            end
          else
            error += "Tariff belongs to other user!"
          end
        end
      else
        logger.fatal("No tariff name")
        error += "No tariff name"
      end
    else
      logger.fatal("No tariff id")
      error += "No tariff id"
    end
    return tariff, error
  end

  def check_params_rates(rates, destination)
    collision_rates = []
    bad_destination_time_rates = []
    #start1 <= end2 and start2 <= end1
    rates.each do |rate1|
      # tikrinimas del koliziju
      if rate1[:rate_start_time].length == 8 and rate1[:rate_start_time].to_s !~ /[^0-9.\:]/ and rate1[:rate_end_time].length == 8 and rate1[:rate_end_time].to_s !~ /[^0-9.\:]/
        rates.each do |rate2|
          if  rate2[:rate_start_time].length == 8 and rate2[:rate_start_time].to_s !~ /[^0-9.\:]/ and rate2[:rate_end_time].length == 8 and rate2[:rate_end_time].to_s !~ /[^0-9.\:]/
            if (rate1[:rate_start_time] != rate2[:rate_start_time] or rate1[:rate_end_time] != rate2[:rate_end_time]) and (rate1[:rate_start_time] <= rate2[:rate_end_time] and rate2[:rate_start_time] <= rate1[:rate_end_time]) and rate2[:day_type].to_s == rate1[:daytype].to_s
              logger.fatal 'COLLISION!!!!!!!!!!!!!!!!!'
              logger.fatal "#{destination[:destination_group_name]} #{destination[:destination_group_type]} COLLISION IN " +[rate1[:rate_start_time], rate2[:rate_start_time]].min.to_s + " AND " + [rate1[:rate_end_time], rate2[:rate_end_time]].max.to_s + " TIME RANGE "
              collision_rates << "#{destination[:destination_group_name]} #{destination[:destination_group_type]} COLLISION IN " +[rate1[:rate_start_time], rate2[:rate_start_time]].min.to_s + " AND " + [rate1[:rate_end_time], rate2[:rate_end_time]].max.to_s + " TIME RANGE "
              #delete all rates in collision time range
              rates.delete_if { |el| (([rate1[:rate_end_time], rate2[:rate_end_time]].max >= el[:rate_start_time] and el[:rate_start_time] >= [rate1[:rate_start_time], rate2[:rate_start_time]].min) or ([rate1[:rate_start_time], rate2[:rate_start_time]].min <= el[:rate_end_time] and el[:rate_end_time]<= [rate1[:rate_end_time], rate2[:rate_end_time]].max))and el[:day_type].to_s == rate2[:day_type].to_s }
            end
          else
            bad_destination_time_rates << rate2.merge!(:destination_group_name => destination[:destination_group_name], :destination_group_type => destination[:destination_group_type])
            rates.delete_if { |el| el==rate2 }
            logger.fatal 'BAD TIME!!!!!!!!!!!!!!!!!'
          end
        end
      else
        bad_destination_time_rates << rate1.merge!(:destination_group_name => destination[:destination_group_name], :destination_group_type => destination[:destination_group_type])
        rates.delete_if { |el| el==rate1 }
        logger.fatal 'BAD TIME!!!!!!!!!!!!!!!!!'
      end
    end
    return collision_rates, bad_destination_time_rates
  end

  def create_rates(destination, rate_id)
    #check params, duration, round by, increase from
    array_of_values = []
    array_to_create = []
    @from = 1
    @end = []
    @start = []
    @daytype = []
    @is_duration_infinity = false
    @is_round_by_bigger_than_from_plus_duration = false
    bad_rates = ""
    bad_rates_array = []
    destination[:rates].each do |rate|
      bad = check_rates_params(rate)
      if bad
        rate.merge!(:destination_group_name => destination[:destination_group_name], :destination_group_type => destination[:destination_group_type])
        bad_rates_array << rate
      else
        from_to_create = array_to_create.find_all { |r| r[:start_time] == rate[:rate_start_time] and r[:end_time] == rate[:rate_end_time] and r[:daytype] == rate[:day_type] }.sort_by { |a| a[:from].to_i }.last
        if !from_to_create
          @from = 1
        else
          #if minute goes after event, 'from' matches
          @from = from_to_create[:from].to_i + from_to_create[:duration].to_i if from_to_create[:artype] != 'event'
          @from = from_to_create[:from].to_i if from_to_create[:artype] == 'event'
        end
        #check if rate was infinity or round_by is too big in that time period and daytype, if not - proceed, if was - skip
        if (!@is_duration_infinity or !@is_round_by_bigger_than_from_plus_duration) and (!@start.include?(rate[:rate_start_time]) or !@end.include?(rate[:rate_end_time]) or !@daytype.include?(rate[:daytype].to_s))
          arate_new = {}
          arate_new[:rate_id] = rate_id
          arate_new[:price] = rate[:rate_price].to_f
          arate_new[:round] = rate[:rate_round_by].to_i

          arate_new[:artype] = rate[:rate_type] ? rate[:rate_type].to_s : "minute"
          arate_new[:start_time] = rate[:rate_start_time] if rate[:rate_start_time]
          arate_new[:end_time] = rate[:rate_end_time] if rate[:rate_end_time]
          arate_new[:daytype] = rate[:day_type] ? rate[:day_type] : ''

          #if duration -1 , no new rate added to this rate time interval!
          arate_new[:duration] = rate[:rate_duration] ? rate[:rate_duration] : -1
          if arate_new[:duration].to_i == -1 and arate_new[:artype] != 'event'
            @is_duration_infinity = true
            @start << rate[:rate_start_time]
            @end << rate[:rate_end_time]
            @daytype << rate[:day_type].to_s
          end
          #count this by duration

          arate_new[:from] = @from

          if arate_new[:duration].to_i != -1 and arate_new[:artype] != 'event' and (arate_new[:from].to_i + arate_new[:duration].to_i) < arate_new[:round].to_i
            #round by check
            @is_round_by_bigger_than_from_plus_duration = true
            @start << rate[:rate_start_time]
            @end << rate[:rate_end_time]
            @daytype << rate[:day_type].to_s
            bad_rates += "// Price: " +rate[:rate_price].to_s + " Round: " + rate[:rate_round_by].to_s + " Duration: " + rate[:rate_duration].to_s + " From: " + arate_new[:from].to_s + " Artype: "+ rate[:rate_type].to_s + " Start time: "+ rate[:rate_start_time].to_s + " End time: "+ rate[:rate_end_time].to_s + " Daytype: "+ rate[:day_type].to_s + "//"
            rate.merge!(:destination_group_name => destination[:destination_group_name], :destination_group_type => destination[:destination_group_type])
            bad_rates_array << rate
          else
            array_to_create << arate_new
            array_of_values << "('#{arate_new[:duration]}' , '#{arate_new[:price]}' , '#{arate_new[:end_time]}','#{arate_new[:daytype]}' ,'#{arate_new[:from]}' , '#{arate_new[:artype]}' , '#{arate_new[:rate_id]}','#{arate_new[:round]}','#{arate_new[:start_time]}')"
          end
        end
      end
    end

    if !array_of_values.empty?
      sql_insert = "INSERT INTO aratedetails (`duration`, `price`, `end_time`, `daytype`, `from`, `artype`, `rate_id`, `round`, `start_time`)
                  VALUES #{array_of_values.join(',')};"
      logger.fatal "#{sql_insert}"
      ActiveRecord::Base.connection.execute(sql_insert)
    end
    bad_rates_array
  end


  def create_rates_merge(destination, rate_id, db_rates)
    #check params, duration, round by, increase from
    database_rates = db_rates
    array_of_values = []
    array_to_create = []
    bad_rates_array = []
    @from = 1
    @type = ""
    @end = []
    @start = []
    @daytype = []
    @is_duration_infinity = false
    @is_round_by_bigger_than_from_plus_duration = false
    bad_rates = ""
    destination[:rates].each do |rate|

      bad = check_rates_params(rate)
      if bad
        rate.merge!(:destination_group_name => destination[:destination_group_name], :destination_group_type => destination[:destination_group_type])
        bad_rates_array << rate
      else
        #find last 'from' in that time period

        db_from = database_rates.find_all { |r| r.start_time.strftime("%X") == rate[:rate_start_time] and r.end_time.strftime("%X") == rate[:rate_end_time] and r.daytype.to_s == rate[:day_type].to_s }.sort_by { |a| a.from.to_i }.last
        from_to_create = array_to_create.find_all { |r| r[:start_time] == rate[:rate_start_time] and r[:end_time] == rate[:rate_end_time] and r[:daytype] == rate[:day_type] }.sort_by { |a| a[:from].to_i }.last

        #check first rates to create
        if !from_to_create
          @from = 1
        else
          #if minute goes after event, 'from' matches
          @from = from_to_create[:from].to_i + from_to_create[:duration].to_i if from_to_create[:artype] != 'event'
          @from = from_to_create[:from].to_i if from_to_create[:artype] == 'event'
        end

        #then check with db rates
        if db_from
          if db_from[:duration].to_i == -1
            #last rate is infinity, do not add!
            @is_duration_infinity = true
            @start << db_from[:start_time].strftime("%X")
            @end << db_from[:end_time].strftime("%X")
            @daytype << db_from[:daytype]
          else
            #set next from
            sum = db_from[:from].to_i + db_from[:duration].to_i
            if sum < @from
              @from = @from
            else
              @from = sum if db_from[:artype] != 'event'
              @from = db_from[:from].to_i if db_from[:artype] == 'event'
            end
          end
        end

        #check if rate was infinity or round_by is too big in that time period and daytype, if not - proceed, if was - skip
        if (!@is_duration_infinity or !@is_round_by_bigger_than_from_plus_duration) and (!@start.include?(rate[:rate_start_time]) or !@end.include?(rate[:rate_end_time]) or !@daytype.include?(rate[:daytype].to_s))
          arate_new = {}
          arate_new[:rate_id] = rate_id
          arate_new[:price] = rate[:rate_price].to_f
          arate_new[:round] = rate[:rate_round_by].to_i

          arate_new[:artype] = rate[:rate_type] ? rate[:rate_type].to_s : "minute"
          @type = arate_new[:artype]
          arate_new[:start_time] = rate[:rate_start_time] if rate[:rate_start_time]
          arate_new[:end_time] = rate[:rate_end_time] if rate[:rate_end_time]
          arate_new[:daytype] = rate[:day_type] ? rate[:day_type] : ''
          #if duration -1 , no new rate added to this rate time interval!
          arate_new[:duration] = rate[:rate_duration] ? rate[:rate_duration] : -1
          if arate_new[:duration].to_i == -1 and arate_new[:artype] != 'event'
            @is_duration_infinity = true
            @start << rate[:rate_start_time]
            @end << rate[:rate_end_time]
            @daytype << rate[:day_type].to_s
          end
          #count this by duration
          arate_new[:from] = @from

          if arate_new[:duration].to_i != -1 and arate_new[:artype] != 'event' and (arate_new[:from].to_i + arate_new[:duration].to_i) < arate_new[:round].to_i
            #round by check
            @is_round_by_bigger_than_from_plus_duration = true
            @start << rate[:rate_start_time]
            @end << rate[:rate_end_time]
            @daytype << rate[:day_type].to_s
            bad_rates += "// Price: " +rate[:rate_price].to_s + " Round: " + rate[:rate_round_by].to_s + " Duration: " + rate[:rate_duration].to_s + " From: " + arate_new[:from].to_s + " Artype: "+ rate[:rate_type].to_s + " Start time: "+ rate[:rate_start_time].to_s + " End time: "+ rate[:rate_end_time].to_s + " Daytype: "+ rate[:day_type].to_s + "//"
            rate.merge!(:destination_group_name => destination[:destination_group_name], :destination_group_type => destination[:destination_group_type])
            bad_rates_array << rate
            logger.fatal rate.inspect
          else
            array_to_create << arate_new
            array_of_values << "('#{arate_new[:duration]}' , '#{arate_new[:price]}' , '#{arate_new[:end_time]}','#{arate_new[:daytype]}' ,'#{arate_new[:from]}' , '#{arate_new[:artype]}' , '#{arate_new[:rate_id]}','#{arate_new[:round]}','#{arate_new[:start_time]}')"
          end
        end
      end
    end
    if !array_of_values.empty?

      sql_insert = "INSERT INTO aratedetails (`duration`, `price`, `end_time`, `daytype`, `from`, `artype`, `rate_id`, `round`, `start_time`)
                  VALUES #{array_of_values.join(',')};"
      logger.fatal "#{sql_insert}"
      ActiveRecord::Base.connection.execute(sql_insert)
    end
    bad_rates_array
  end

  def check_rates_params(rate)

    ret = 0
    ret += 1 if rate[:rate_price] and rate[:rate_price].to_s.length > 0 and rate[:rate_price].to_s !~ /[^0-9.\-\+]/
    ret += 1 if rate[:rate_round_by] and rate[:rate_round_by].to_s !~ /[^0-9]/ and rate[:rate_round_by].to_s.length > 0
    ret += 1 if rate[:rate_type] and ["minute", "event"].include?(rate[:rate_type].to_s)
    ret += 1 if rate[:rate_start_time] and rate[:rate_start_time].to_s !~ /[^0-9.\:]/ and rate[:rate_start_time].to_s.length > 0
    ret += 1 if rate[:rate_end_time] and rate[:rate_end_time].to_s !~ /[^0-9.\:]/ and rate[:rate_end_time].to_s.length > 0
    ret += 1 if rate[:day_type] and ['', "WD", "FD"].include?(rate[:day_type].to_s)
    ret += 1 if rate[:rate_duration] and rate[:rate_duration].to_s !~ /[^0-9.\-]/ and rate[:rate_duration].to_s.length > 0

    if ret < 7
      return true
    else
      return false
    end
  end


  def device_create

    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user
        if check_owner_for_device(params[:user_id], 0, @user)
          coi = @user.usertype == 'accountant' ? 0 : @user.id
          user_u = User.find(:first, :conditions => ["id = ? AND owner_id = ? ", values[:user_id], coi]) if values[:user_id]
          if user_u

            params[:device] = {}
            params[:device][:description] = params[:description]
            params[:device][:devicegroup_id] = params[:devicegroup_id]
            params[:device][:device_type] = params[:type]
            params[:device][:pin] = params[:pin] if  params[:pin]


            az, av = @user.alow_device_types_dahdi_virt

            notice, params2 = Device.validate_before_create(@user, user_u, params, az, av)
            if !notice.blank?
              doc.error(_(notice).gsub('_', ' '))
            else
              if !params2[:device][:device_type] or params2[:device][:device_type].blank?
                params2[:device][:device_type] = Confline.get_value("Default_device_type", @user.id).to_s
              end
              if params2[:device][:device_type].blank?
                params2[:device][:device_type] = "SIP"
              end
              params2[:device][:pin] = new_device_pin if !params2[:device][:pin]
              fextension = free_extension()
              device = user_u.create_default_device({:device_ip_authentication_record => params2[:ip_authentication].to_i, :description => params2[:device][:description], :device_type => params2[:device][:device_type], :dev_group => params2[:device][:devicegroup_id], :free_ext => fextension, :secret => random_password(12), :username => fextension, :pin => params2[:device][:pin]})
              if device.save
                a = Thread.new { configure_extensions(device.id, {:api => 1, :current_user => @user}) }
                doc.status(device.check_callshop_user(_('device_created')))
                doc.id(device.id)
              else
                doc.error("Device was not created")
                device.errors.each { |key, value|
                  doc.message(_(value))
                } if device.respond_to?(:errors)
              end
            end
          else
            doc.error("User was not found")
          end
        else
          dont_be_so_smart(@user.id)
          doc.error("Dont be so smart")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end


  #====================================== Phonebooks =======================================

  def phonebooks
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user
        if @user.usertype == 'user'
          user_u = @user
        else
          if values[:user_id] and values[:user_id].to_i != @user.id
            user_u = User.find(:first, :conditions => ["id = ? AND owner_id = ? ", values[:user_id], @user.get_correct_owner_id])
            MorLog.my_debug @user.get_correct_owner_id
          else
            user_u = @user
          end
        end
        if user_u
          ph = Phonebook.user_phonebooks(user_u)
          if ph and ph.size.to_i > 0
            doc.phonebooks {
              for p in ph
                doc.phonebook {
                  doc.name(p.name)
                  doc.number(p.number)
                  doc.speeddial(p.speeddial)
                }
              end
            }
          else
            doc.error("No Phonebooks")
          end
        else
          doc.error("User was not found")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end


  def phonebook_edit
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user
        ph = Phonebook.find_by_id(params[:phonebook_id])
        if ph
          if ph.user_id != @user.id and @user.usertype != "admin"
            doc.error("Dont be so smart")
          else
            ph.number = params[:number] if params[:number]
            ph.name = params[:name] if params[:name]
            ph.speeddial = params[:speeddial] if params[:speeddial]
            if ph.valid?
              ph.save
              doc.status('Phonebook saved')
            else
              doc.error("Phonebook was not saved")
              ph.errors.each { |key, value|
                doc.message(_(value))
              } if ph.respond_to?(:errors)
            end
          end
        else
          doc.error("Phonebook was not found")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  Lists all credit notes available to to wiev for the user. He can select one
  specific credit note by supplying it's id(credit_note_id=XXX) or filter only
  specific user's credit notes(user_id=YYY). In case user can not see financial
  data it will no be displayed for him.
  If accountant is allow to read invoices, he may list credit notes. but ha can see 
  financial data only if he is also allowed to see financial data.

  for instance these would be valid queries, given there is such user and id's
  are valid:
  /api/credit_notes?u=user&p=user1
  /api/credit_notes?u=user&p=user1&credit_note_id=XXX
  /api/credit_notes?u=user&p=user1&user_id=YYY
=end
  def credit_notes
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user and (@user.is_admin? or @user.is_reseller? or (@user.is_accountant? and @user.accountant_allow_read('invoices_manage')))
        if @user.is_reseller?
          condition = ["users.owner_id = #{@user.id}"]
        elsif @user.is_admin? or @user.is_accountant?
          condition = ['users.owner_id = 0']
        end
        if params[:credit_note_id]
          condition << "credit_notes.id = #{params[:credit_note_id].to_i}"
        elsif values[:user_id]
          condition << "credit_notes.user_id = #{values[:user_id].to_i}"
        end
        notes = CreditNote.find(:all, :include => :user, :conditions => condition.join(' AND '))
        if notes and notes.size.to_i > 0
          can_see_finances = (@user.is_admin? or @user.is_reseller? or (@user.is_accountant? and @user.accountant_allow_read('see_financial_data')))
          doc.credit_notes {
            for note in notes
              doc.credit_note {
                doc.user_id(note.user_id)
                doc.issue_date(note.issue_date)
                doc.number(note.number)
                doc.comment(note.comment)
                if can_see_finances
                  doc.price(note.price)
                  doc.price_with_vat(note.price_with_vat)
                  doc.pay_date(note.pay_date)
                end
              }
            end
          }
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  User can update only his user's credit notes. there is an exception for accountant -
  he can update admin's users credit notes.
  Expecting to get at least one necesary parameter - credit_note_id. if it is not
  provider, id defaults to 0 and nothing wil be found, error message will be send.
  two optional parameters are comment and status. status can be only 'paid' or 'unpaid'
  if none of these parameters are supplied or status is not valid credit note will not
  be updated, but still because everything vent without errors status will be send informing
  that note was updated. if user cannot see financial data he cannot set status.

  for instance these would be valid queries, given there is such user and id's
  are valid, though the last one would not change anything:
  /api/credit_note_update?u=user&p=user1&credit_note_id=XXX&status=paid
  /api/credit_note_update?u=user&p=user1&credit_note_id=XXX&status=unpaid
  /api/credit_note_update?u=user&p=user1&credit_note_id=XXX&comment=AAA
  /api/credit_note_update?u=user&p=user1&credit_note_id=XXX&comment=AAA&status=paid
  /api/credit_note_update?u=user&p=user1&credit_note_id=XXX
=end
  def credit_note_update
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user and (@user.is_admin? or @user.is_reseller? or (@user.is_accountant? and @user.accountant_allow_read('invoices_manage')))
        if @user.is_reseller?
          condition = ['users.owner_id = ? AND credit_notes.id = ?', @user.id, params[:credit_note_id].to_i]
        elsif @user.is_admin? or @user.is_accountant?
          condition = ['users.owner_id = 0 AND credit_notes.id = ?', params[:credit_note_id].to_i]
        end
        note = CreditNote.find(:first, :include => :user, :conditions => condition)
        if note
          if params[:status] and (@user.is_admin? or @user.is_reseller? or (@user.is_accountant? and @user.accountant_allow_edit('see_financial_data')))
            if params[:status] == 'paid'
              note.pay
            elsif params[:status] == 'unpaid'
              note.unpay
            end
          end
          if params[:comment]
            note.comment = params[:comment]
          end
          if note.save
            doc.status("Credit note was updated")
          else
            doc.error("Credit note was not updated")
          end
        else
          doc.error("Credit note was not found")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  User can delete only his user's credit notes. there is an exception for accountant -
  he can delete admin's users credit notes. normal user cannot use this function, it is
  available only for admin, accountant and reseller.

  for instance this would be the only valid query, given there is such user and id's
  are valid:
  /api/credit_note_delete?u=user&p=user1&credit_note_id=XXX
=end
  def credit_note_delete
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user and (@user.is_admin? or @user.is_reseller? or (@user.is_accountant? and @user.accountant_allow_edit('invoices_manage') and @user.accountant_allow_edit('see_financial_data')))
        if @user.is_reseller?
          condition = ['users.owner_id = ? AND credit_notes.id = ?', @user.id, params[:credit_note_id].to_i]
        elsif @user.is_admin? or @user.is_accountant?
          condition = ['users.owner_id = 0 AND credit_notes.id = ?', params[:credit_note_id].to_i]
        end
        note = CreditNote.find(:first, :include => :user, :conditions => condition)
        if note
          note.destroy
          doc.status("Credit note was deleted")
        else
          doc.error("Credit note was not found")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  Credit note may be created only for valid user, that is owned by user who tries
  to create credit note(in accountant's case user has to be owned by admin). normal
  user cannot use this function, it is available only for admin, accountant and reseller,
  though reseller has to be able to see financial data.
  Accountant is allow to create credit notes only if he may edit financial data and manage 
  invoices.

  for instance these would be valid queries, given there is such user and id's
  are valid:
  /api/credit_note_create?u=user&p=user1&user_id=XXX&price=YYY&issue_date=YYYY-MM-DD
  /api/credit_note_create?u=user&p=user1&user_id=XXX&price=YYY&issue_date=YYYY-MM-DD&comment=CCCCC
  /api/credit_note_create?u=user&p=user1&user_id=XXX&price=YYY&issue_date=YYYY-MM-DD&number=NNN
  /api/credit_note_create?u=user&p=user1&user_id=XXX&price=YYY&issue_date=YYYY-MM-DD&comment=CCCCC&number=NNN
  
  note that credit note cannot be created for admin, hance ..and user.id > 0
  note that is issue_date must be specified, if not we dont event try to save note(cause it would crash)
=end
  def credit_note_create
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user and (@user.is_admin? or @user.is_reseller? or (@user.is_accountant? and @user.accountant_allow_read('invoices_manage') and @user.accountant_allow_edit('see_financial_data')))
        if @user.is_reseller?
          condition = ['users.owner_id = ? AND users.id = ?', @user.id, params[:user_id].to_i]
        elsif @user.is_admin? or @user.is_accountant?
          condition = ['users.owner_id = 0 AND users.id = ?', params[:user_id].to_i]
        end
        user = User.find(:first, :include => :tax, :conditions => condition)
        if user and user.id > 0
          note = CreditNote.new
          note.user = user
          note.comment = params[:comment] if params[:comment]

          note.issue_date = Time.at(params[:issue_date].to_i) if params[:issue_date].to_i > 0
          note.number = params[:number].to_i if params[:number].to_i > 0
          note.price = params[:price] || 0
          if params[:issue_date].to_i > 0 and note.save
            doc.status("Credit note was created")
          else
            doc.error("Credit note was not created")
          end
        else
          doc.error("User was not found")
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  If accountant cannot see financial data, manage invoices/payments in read mode,
  he cannot see financial statements. if accountant has suficient permissions or 
  user is so other type, he may view his(user) or his users(admin, reseller) 
  financial statements.
  Accountant and reseller may filter theyr users by sending valid id. 
  Valid date range is mandatory parameter. Dates has to be supplied as unix timestamps. 
  Every user may flter by status. Valid statuses are - paid, unpaid, 'all'. if not 
  supplied defaults to 'all'.

  For instance some posible api commands are:
  /api/financial_statements?u=admin&p=admin&date_from=1231453&date_till=23452&hash=234234
  /api/financial_statements?u=admin&p=admin&status=all&date_from=1231453&date_till=23452&hash=234234
  /api/financial_statements?u=admin&p=admin&status=paid&date_from=1231453&date_till=23452$hash=234234
  /api/financial_statements?u=admin&p=admin&user_id=3&date_from=1231453&date_till=23452$hash=23453
  /api/financial_statements?u=admin&p=admin&status=all&user_id=5&date_from=1231453&date_till=23452&hash=354234
=end
  def financial_statements
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if @current_user and not (@current_user.is_accountant? and (not @current_user.accountant_allow_read('can_see_finances') or not @current_user.allow_read('payments_manage') or not @current_user.accountant_allow_read('invoices_manage')))
      if @values[:date_from] and @values[:date_till]
        date_from = Time.at(@values[:date_from].to_i).to_date.to_s(:db)
        date_till = Time.at(@values[:date_till].to_i).to_date.to_s(:db)
      end
      date_from = Date.today.to_s(:db) if !date_from
      date_till = Time.now.tomorrow.to_s(:db) if !date_till
      if ['paid', 'unpaid', 'all'].include? @values[:status]
        status = @values[:status]
      else
        status = 'all'
      end
      if @current_user.usertype == 'user'
        user_id = @current_user.id
        ordinary_user = @current_user.is_user?
      elsif @values[:user_id] and @values[:user_id].to_i > 0
        user_id = @values[:user_id].to_i
      end
      if @current_user.is_admin? or @current_user.is_accountant?
        owner_id = 0
      else
        owner_id = @current_user.id
      end

      if !@current_user.is_user?
        coi = @current_user.usertype == 'accountant' ? 0 : @current_user.id
        user = User.find(:first, :conditions => ["id = ? AND owner_id = ? ", @values[:user_id], coi]) if @values[:user_id]
      else
        user = @current_user
      end

      if user or !@values[:user_id]

        financial_statements = {}
        financial_statements["invoices"] = Invoice.financial_statements(owner_id, user_id, status, date_from, date_till, ordinary_user)
        financial_statements["credit_notes"] = CreditNote.financial_statements(owner_id, user_id, status, date_from, date_till, ordinary_user)
        default_currency_name = Currency.get_default.name
        financial_statements["payments"] = Payment.financial_statements(owner_id, user_id, status, date_from, date_till, ordinary_user, default_currency_name)

        doc.financial_statement("currency" => default_currency_name) {
          financial_statements.each { |type, statements|
            statements.each { |data|
              doc.statement("type" => type) {
                doc.status(data.status)
                doc.count(data.count)
                if type == 'invoices'
                  doc.price(nice_number(data.price))
                  doc.price_with_vat(nice_number(data.price_with_vat))
                else
                  doc.price(nice_number(data.price * count_exchange_rate(@current_user.currency.name, default_currency_name)))
                  doc.price_with_vat(nice_number(data.price_with_vat * count_exchange_rate(@current_user.currency.name, default_currency_name)))
                end
              }
            }
          }
        }
      else
        doc.error("Dont be so smart")
      end
    else
      doc.error("Bad login")
    end
                         }
    send_xml_data(out_string, params[:test].to_i)
  end


  def create_payment
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      if Confline.get_value("API_Allow_payments_ower_API").to_i == 1
        if !@current_user.is_user?
          coi = @current_user.usertype == 'accountant' ? 0 : @current_user.id
          user = User.find(:first, :conditions => ["id = ? AND owner_id = ? ", values[:user_id], coi]) if values[:user_id]
        end

        if user
          currency = Currency.get_by_name(values[:p_currency])
          if currency

            pttype = "from_api : #{values[:paymenttype]}"
            if values[:tax_in_amount].to_i == 1
              gross = values[:amount].to_f
              amount = user.get_tax.count_amount_without_tax(gross).to_f
            else
              amount = values[:amount].to_f
              gross = user.get_tax.apply_tax(amount).to_f
            end
            tax = gross - amount
            comfirm = Confline.get_value("API_payment_confirmation").to_i
            paym = Payment.create_for_user(user, {:pending_reason => comfirm == 1 ? 'Waiting for confirmation' : "completed", :paymenttype => pttype, :currency => currency.name, :gross => gross.to_f, :tax => tax, :amount => amount.to_f, :transaction_id => values[:transaction], :payer_email => values[:payer_email], :shipped_at => values[:shipped_at], :fee => values[:fee]})
            paym.completed = comfirm == 1 ? 0 : 1
            paym.description = values[:description].to_s
            if paym.save
              if comfirm.to_i == 0
                exchange_rate = Currency.count_exchange_rate(Currency.get_default.name, currency.name)
                curr_amount = amount / exchange_rate.to_f
                userrr = User.current
                User.current = nil
                user.balance += curr_amount
                user.save
                User.current = userrr
                Action.add_action_hash(paym.user_id,
                                       {:action => "payment: #{pttype}",
                                        :data => "User successfully payed using #{pttype}",
                                        :data3 => "#{paym.amount} #{paym.currency} | tax: #{paym.gross - paym.amount} #{paym.currency} | fee: #{paym.fee} #{paym.currency} | sent: #{paym.gross} #{paym.currency}",
                                        :data2 => "payment id: #{paym.id}",
                                        :data4 => "authorization: #{paym.transaction_id}"
                                       })
              else
                Action.add_action_hash(paym.user_id,
                                       {:action => "payment: #{pttype}",
                                        :data => "User successfully created #{pttype}",
                                        :data3 => "#{paym.amount} #{paym.currency} | tax: #{paym.gross - paym.amount} #{paym.currency} | fee: #{paym.fee} #{paym.currency} | sent: #{paym.gross} #{paym.currency}",
                                        :data2 => "payment id: #{paym.id}",
                                        :data4 => "authorization: #{paym.transaction_id}"
                                       })
              end
              doc.response {
                doc.status('ok')
                doc.payment("currency" => currency.name) {
                  doc.payment_id(paym.id)
                  doc.tax(nice_number(paym.tax))
                  doc.amount(nice_number(paym.amount))
                  doc.gross(nice_number(paym.gross))
                }
              }
            else
              doc.error("Payment was not saved") {
                paym.errors.each { |key, value|
                  doc.message(_(value))
                } if paym.respond_to?(:errors)
              }
            end
          else
            doc.error("No currency")
          end
        else
          doc.error("Dont be so smart")
        end
      else
        doc.error("Payments not allow from api")
      end
    else
      doc.error("Incorrect hash")
    end

             }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  *Params*
  +amount+ - float. If amount is not supplied it defaults to 0, and no payment will be added.
=end
  def cc_by_cli_old
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow
      check_user(params[:u], params[:p])
      if @user and @user.usertype != 'user'
        callerid = params[:callerid].to_s
        if callerid.blank?
          doc.error("Callerid must be specified")
        else
          amount = values[:amount].to_f
          pin = values[:pin].to_s
          valid_pin_supplied = (not pin.blank?)
          cardgroup_id = values[:cardgroup_id].to_i
          if cardgroup_id == 0 and valid_pin_supplied
            card_by_pin = Card.find(:first, :include => :cardgroup, :conditions => {:pin => pin, :owner_id => @current_user.get_correct_owner_id})
            if card_by_pin
              cardgroup_id = card_by_pin.cardgroup.id
            else
              cardgroup_id = 0
            end
          end

          #If the Caller_id exists in a device:
          #1. If pin number IS supplied - add card's value to user of the device, and disable card.
          #2. If NO pin number is supplied - do not create new card in cardgroup_id, and add the payment of amount of funds to the user.
          device = Device.find(:first, :include => [:user, :callerids], :conditions => ['callerids.cli = ? OR callerids.cli LIKE ?', callerid, '%' + callerid + '%'])
          if device
            if device.belongs_to_provider?
              doc.error("Callerid belongs to provider")
            elsif device.user.owner_id != @current_user.get_correct_owner_id
              doc.error("Device already has such callerid, but you do not have permission to change user's balance")
            else
              if valid_pin_supplied
                card = Card.find(:first, :conditions => {:pin => pin, :owner_id => @current_user.get_correct_owner_id})
                if card
                  card.disable
                  if card.save
                    if device.user.add_to_balance(card.balance)
                      respond_to_successful_card_operation(doc, card)
                    else
                      doc.error("Failed to make transaction")
                    end
                  else
                    doc.error {
                      card.errors.each { |key, value|
                        doc.error(_(value))
                      } if card.respond_to?(:errors)
                    }
                  end
                else
                  doc.error("Could not find card")
                end
              else
                cardgroup = Cardgroup.find(:first, :conditions => {:id => cardgroup_id, :owner_id => @current_user.get_correct_owner_id})
                if cardgroup
                  cardgroup_excange_rate = Currency.count_exchange_rate(cardgroup.tell_balance_in_currency, Currency.get_default.name)
                  amount *= cardgroup_excange_rate
                  #Note that there is no need to call save on user instance
                  #since it should already be done in add_to_balance methond
                  if device.user.owner_id == @current_user.get_correct_owner_id
                    if device.user.add_to_balance(amount)
                      doc.response {
                        doc.status("ok")
                      }
                    else
                      doc.error("Failed to make transaction")
                    end
                  else
                    doc.error("You do not have permission to add to user's balance")
                  end
                else
                  doc.error("Supplied Cardgroup_id is invalid")
                end
              end
            end
          else
            card = Card.find(:first, :conditions => {:callerid => callerid}) #TODO: issiaiskinti ar ieskoti pagal pina ar callerid????
                                                                             #If pin number IS supplied(ignore the amount of funds to add parameter):
                                                                             #1. If the Caller_id does not exist at all - associate Caller_id to the new card, and mark card as sold.
                                                                             #2. If the Caller_id exists in another card within the same cardgroup_id, add new calling card value to old card, and disable new card.
                                                                             #3. If the Caller_id exists in a card within a different cardgroup_id, transfer Caller_id and balance from old card to new card, mark new card as sold, and disable old card.
            if valid_pin_supplied
              if not card
                card = Card.find(:first, :include => :cardgroup, :conditions => {:pin => pin, :owner_id => @current_user.get_correct_owner_id})
                if card
                  if card.sold?
                    doc.error("PIN number already sold")
                  else
                    card.callerid = callerid
                    card.first_use = Time.now
                    if card.sell
                      respond_to_successful_card_operation(doc, card)
                    else
                      doc.error("Failed to make transaction")
                    end
                  end
                else
                  doc.error("PIN number not found")
                end
              elsif card.cardgroup.id == cardgroup_id
                card_by_pin = Card.find(:first, :include => :cardgroup, :conditions => {:pin => pin, :owner_id => @current_user.get_correct_owner_id})
                if card_by_pin
                  original_balance_in_system_currency = card.balance
                  exchange_rate = Currency.count_exchange_rate(card.cardgroup.tell_balance_in_currency, Currency.get_default)
                  original_balance_in_cardgroup_currency = original_balance_in_system_currency * exchange_rate
                  if card_by_pin.add_to_balance(original_balance_in_cardgroup_currency)
                    card.disable
                    card.save
                    respond_to_successful_card_operation(doc, card)
                  else
                    doc.error("Failed to make transaction")
                  end
                else
                  doc.error("PIN number not found")
                end
              elsif card.cardgroup.id != cardgroup_id
                if card.sold?
                  doc.error("PIN number already sold")
                else
                  card_by_pin = Card.find(:first, :include => :cardgroup, :conditions => {:pin => pin, :owner_id => @current_user.get_correct_owner_id})
                  if card_by_pin and card_by_pin != card
                    card.callerid = card_by_pin.callerid
                    card_by_pin.callerid = nil
                    card_by_pin.save
                    if card.sell
                      original_balance_in_system_currency = card_by_pin.balance
                      exchange_rate = Currency.count_exchange_rate(card.cardgroup.tell_balance_in_currency, Currency.get_default)
                      original_balance_in_cardgroup_currency = original_balance_in_system_currency * exchange_rate
                      if card.add_to_balance(original_balance_in_cardgroup_currency)
                        card_by_pin.disable
                        card_by_pin.save
                        respond_to_successful_card_operation(doc, card)
                      else
                        doc.error("Failed to make tansaction")
                      end
                    else
                      doc.error("Failed to make transaction")
                    end
                  else
                    doc.error("PIN number not found")
                  end
                end
              end
            else
              #If NO pin number is supplied:
              #1. If Caller_id does not exist in callingcard, create a card in cardgroup_id, associate the Caller_id to the card, add a payment of amount of funds to the card, and mark card as sold.
              #2. If Caller_id exists in a card within the cardgroup_id, add a payment of amount of funds to the existing card and do not create a new card.
              #3. If Caller_id exists in another cardg!x!:<Mouse>C!y!:<Mouse>C!z!:

              if not card
                cardgroup = Cardgroup.find(:first, :conditions => {:id => cardgroup_id, :owner_id => @current_user.get_correct_owner_id})
                if cardgroup
                  amount *= Currency.count_exchange_rate(cardgroup.tell_balance_in_currency, Currency.get_default)
                  new_card = cardgroup.create_card({:balance => amount, :callerid => callerid})
                  if new_card.save and new_card.sell
                    respond_to_successful_card_operation(doc, new_card)
                  else
                    doc.error("Failed to make transaction")
                  end
                else
                  doc.error("Supplied Cardgroup_id is invalid")
                end
              elsif card.cardgroup.id == cardgroup_id
                amount *= Currency.count_exchange_rate(card.cardgroup.tell_balance_in_currency, Currency.get_default)
                if card.add_to_balance(amount)
                  respond_to_successful_card_operation(doc, card)
                else
                  doc.error("Failed to make transaction")
                end
              elsif card.cardgroup.id != cardgroup_id
                cardgroup = Cardgroup.find(:first, :conditions => {:id => cardgroup_id, :owner_id => @current_user.get_correct_owner_id})
                if cardgroup
                  card.callerid = nil
                  card.disable
                  original_balance = card.balance.to_f
                  if card.add_to_balance(card.balance * -1)
                    #Note that we do not call card.save method intentionaly, cause card is saved in
                    #add_to_balance method. also note order in wich card methods are called,
                    #add_to_balance has to be last, so that we could save queries to database.
                    amount *= Currency.count_exchange_rate(cardgroup.tell_balance_in_currency, Currency.get_default)
                    new_card = cardgroup.create_card({:balance => original_balance + amount, :callerid => callerid})
                    if new_card.save
                      new_card.sell
                      if new_card.save
                        respond_to_successful_card_operation(doc, card)
                      else
                        doc.error("Failed to make transaction")
                      end
                    else
                      doc.error("Failed to make transaction")
                    end
                  else
                    doc.error("Could not create card")
                  end
                else
                  doc.error("Supplied Cardgroup_id is invalid")
                end
              end
            end
          end
        end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end


  def cc_by_cli
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    values = @values

    if values[:callerid].blank?
      doc.error("Callerid must be specified")
    else

      if values[:pin] and !values[:pin].blank?
        # II
        device = Device.find(:first, :include => [:user, :callerids], :conditions => ['callerids.cli = ? OR callerids.cli LIKE ?', params[:callerid], '%' + params[:callerid] + '%'])
        if !device or (device and device.user and device.user.owner_id == @current_user.get_correct_owner_id)
          if device
            #4 * We find device by callerid and card by PIN, device.user.balance+=card.balance, card.disable
            logger.fatal "II%%%%%%%%%%%%%%%%%%%%%%%%4%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
            logger.fatal values.to_yaml
            card_by_pin = Card.find(:first, :include => :cardgroup, :conditions => {:pin => values[:pin], :owner_id => @current_user.get_correct_owner_id})
            if card_by_pin
              if card_by_pin.balance == 0
                doc.error("PIN number balance is zero")
              else
                card_by_pin.disable
                if card_by_pin.save
                  if device.user.add_to_balance(card_by_pin.balance, 'card_refill')
                    card_by_pin.add_to_balance(card_by_pin.balance * -1, false)
                    doc.response {
                      doc.status("ok")
                      doc.device_id(device.id)
                      doc.user_id(device.user_id)
                      doc.new_balance(nice_number(device.user.balance))
                      doc.new_balance_with_vat(nice_number(device.user.balance_with_vat))
                    }
                  else
                    doc.error("Failed to make transaction")
                  end
                else
                  doc.error {
                    card_by_pin.errors.each { |key, value|
                      doc.error(_(value))
                    } if card_by_pin.respond_to?(:errors)
                  }
                end
              end
            else
              doc.error("PIN number not found")
            end
          else
            card = Card.find(:first, :conditions => {:callerid => values[:callerid]})
            if  !card or (card and (card.cardgroup.owner_id == @current_user.get_correct_owner_id) or card.cardgroup.hidden == 1)
              if card
                card_by_pin = Card.find(:first, :include => :cardgroup, :conditions => ['cards.pin = ? AND cardgroups.owner_id =? AND cards.id <> ?', values[:pin], @current_user.get_correct_owner_id, card.id])
                if  card_by_pin
                  if card.cardgroup_id == card_by_pin.cardgroup_id
                    #2 * We find card2 by callerid and card1 by PIN, then card2.balance += card1.balance, card1.disable.
                    logger.fatal "II%%%%%%%%%%%%%%%%%%%%%%%%2%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
                    logger.fatal values.to_yaml
                    amount = card_by_pin.balance
                    if amount == 0
                      doc.error("PIN number balance is zero")
                    else
                      logger.fatal card.to_yaml
                      logger.fatal card_by_pin.to_yaml
                      card_by_pin.disable
                      card_by_pin.add_to_balance(card.balance * -1, false)
                      if card_by_pin.save
                        card.sell
                        if card.add_to_balance(amount, false)
                          respond_to_successful_card_operation(doc, card)
                        else
                          doc.error("Failed to make transaction")
                        end
                        respond_to_successful_card_operation(doc, card_by_pin)
                      else
                        doc.error {
                          card_by_pin.errors.each { |key, value|
                            doc.error(_(value))
                          } if card_by_pin.respond_to?(:errors)
                        }
                      end
                    end
                  else
                    #3 * We find card2 by callerid and card1 by PIN. card1.callerid=card2.callerid, card2.callerid=nil, card1.balance +=card2.balance, card1.sold, card2.disable
                    logger.fatal "II%%%%%%%%%%%%%%%%%%%%%%%%3%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
                    logger.fatal values.to_yaml
                    amount = card.balance
                    if amount == 0
                      doc.error("PIN number balance is zero")
                    else
                      card.sell
                      card_by_pin.sell
                      card.add_to_balance(card.balance * -1, false)
                      card_by_pin.callerid = card.callerid
                      card.callerid = nil
                      if card.save
                        if card_by_pin.add_to_balance(amount, false)
                          card.disable
                          card.save
                          respond_to_successful_card_operation(doc, card_by_pin)
                        else
                          doc.error("Failed to make transaction")
                        end
                      else
                        doc.error {
                          card.errors.each { |key, value|
                            doc.error(_(value))
                          } if card.respond_to?(:errors)
                        }
                      end
                    end
                  end
                else
                  doc.error("PIN number not found")
                end
              else
                logger.fatal "II%%%%%%%%%%%%%%%%%%%%%%%%1%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
                logger.fatal values.to_yaml
                #1 * We check if callerid_id is free. If it is free then we search cardgroup by card using PIN, then we create card2 in same cardgroup.
                # ** There is no need to create a new card2; just mark the card with the entered PIN number as sold, active, and associate the callerID to it.
                card_by_pin = Card.find(:first, :include => :cardgroup, :conditions => {:pin => values[:pin], :owner_id => @current_user.get_correct_owner_id})
                if  card_by_pin
                  card_by_pin.callerid = values[:callerid]
                  if card_by_pin.sell
                    respond_to_successful_card_operation(doc, card_by_pin)
                  else
                    doc.error {
                      card_by_pin.errors.each { |key, value|
                        doc.error(_(value))
                      } if card_by_pin.respond_to?(:errors)
                    }
                  end
                else
                  doc.error("PIN number not found")
                end
              end
            else
              doc.error("You do not have permission to access card")
            end
          end
        else
          doc.error("You do not have permission to add to user's balance")
        end
      else
        # I
        device = Device.find(:first, :include => [:user, :callerids], :conditions => ['callerids.cli = ? OR callerids.cli LIKE ?', values[:callerid], '%' + values[:callerid] + '%'])
        if !device or (device and device.user.owner_id == @current_user.get_correct_owner_id)
          if device
            #4 * We find device by callerid, device.user.balance+=amount
            logger.fatal "I%%%%%%%%%%%%%%%%%%%%%%%%4%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
            logger.fatal values.to_yaml
            if device.user.add_to_balance(device.user.get_tax.count_amount_without_tax(values[:amount].to_f), 'card_refill')
              doc.response {
                doc.status("ok")
                doc.device_id(device.id)
                doc.user_id(device.user_id)
                doc.new_balance(nice_number(device.user.balance))
                doc.new_balance_with_vat(nice_number(device.user.balance_with_vat))
              }
            else
              doc.error("Failed to make transaction")
            end
          else
            card = Card.find(:first, :conditions => {:callerid => values[:callerid]})
            if  !card or (card and card.cardgroup.owner_id == @current_user.get_correct_owner_id)
              if card
                if values[:cardgroup_id]
                  cardgroup = Cardgroup.find(:first, :conditions => {:id => values[:cardgroup_id], :owner_id => @current_user.get_correct_owner_id})
                else
                  cardgroup = card.cardgroup
                end
                if   cardgroup
                  if  cardgroup.id != card.cardgroup_id
                    #3   * We find card1 by callerid and cardgroup2 by cardgroup_id, then we check If card1.cardgroup != cardgroup2, then we create card_n in cardgroup2 , card_n.callerid = Caller_id, card_n.balance = amount + card1.balance, card_n.sold , card1.disable
                    logger.fatal "I%%%%%%%%%%%%%%%%%%%%%%%%3%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
                    logger.fatal values.to_yaml
                    original_balance = card.balance
                    card.add_to_balance(card.balance * -1, false)
                    card.disable
                    card.callerid = nil
                    amount = values[:amount].to_f * Currency.count_exchange_rate(cardgroup.tell_balance_in_currency, Currency.get_default).to_f
                    amount = cardgroup.get_tax.count_amount_without_tax(original_balance + amount)
                    if card.save
                      card_n = cardgroup.create_card({:balance => amount, :callerid => values[:callerid]})

                      if card_n.sell and card_n.save
                        respond_to_successful_card_operation(doc, card_n)
                      else
                        doc.error {
                          card_n.errors.each { |key, value|
                            doc.error(_(value))
                          } if card.respond_to?(:errors)
                        }
                      end
                    else
                      doc.error {
                        card.errors.each { |key, value|
                          doc.error(_(value))
                        } if card.respond_to?(:errors)
                      }
                    end
                  else
                    #2  * We find card1 by callerid and cardgroup by card1, we check if cardgroup is allowed for user then then card1.balance += amount
                    logger.fatal "I%%%%%%%%%%%%%%%%%%%%%%%%2%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
                    logger.fatal values.to_yaml
                    card.sell
                    amount = values[:amount].to_f * Currency.count_exchange_rate(card.cardgroup.tell_balance_in_currency, Currency.get_default).to_f
                    amount = cardgroup.get_tax.count_amount_without_tax(amount)
                    if card.add_to_balance(amount)
                      respond_to_successful_card_operation(doc, card)
                    else
                      doc.error("Failed to make transaction")
                    end
                  end
                else
                  doc.error("You do not have permission to access cardgroup")
                end
              else
                #1 * We check if callerid_id is free. If it is free then we search cardgroup by cardgroup_id, then we create card_n in cardgroup, card_n.callerid = Caller_id, card_n.balance = amount, card_n.sold
                logger.fatal "I%%%%%%%%%%%%%%%%%%%%%%%%1%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
                logger.fatal values.to_yaml
                cardgroup = Cardgroup.find(:first, :conditions => {:id => values[:cardgroup_id], :owner_id => @current_user.get_correct_owner_id})
                if cardgroup
                  logger.fatal cardgroup.tell_balance_in_currency
                  amount = values[:amount].to_f * Currency.count_exchange_rate(cardgroup.tell_balance_in_currency, Currency.get_default).to_f
                  amount = cardgroup.get_tax.count_amount_without_tax(amount)
                  card_n = cardgroup.create_card({:balance => amount, :callerid => values[:callerid]})

                  if card_n.sell and card_n.save
                    respond_to_successful_card_operation(doc, card_n)
                  else
                    doc.error {
                      card_n.errors.each { |key, value|
                        doc.error(_(value))
                      } if card.respond_to?(:errors)
                    }
                  end
                else
                  doc.error("Supplied Cardgroup_id is invalid")
                end
              end
            else
              doc.error("You do not have permission to access card")
            end
          end
        else
          doc.error("You do not have permission to add to user's balance")
        end

      end

    end
           }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  display info about calling card group

  *Params*
  +id+ - card group id
  +autorization+

  *Returns*
  +xml_object+ - name, image_link, description, price, price_with_tax, currency, pin_length, number_length, groups salable cards size
=end
  def show_calling_card_group
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    cg = Cardgroup.find(:first, :include => [:tariff, :lcr, :location, :tax], :conditions => ["cardgroups.id = ? and cardgroups.owner_id = ?", @values[:id], @current_user.get_correct_owner_id])

    if cg
      doc.cardgroup {
        doc.name(cg.name)
        doc.iamge_link("#{Web_Dir}/cards/#{cg.image}")
        doc.description(cg.description)
        doc.price(nice_number(cg.price))
        doc.price_with_tax(nice_number(cg.price + cg.get_tax.count_tax_amount(cg.price)))
        doc.currency(Currency.get_default.name)
        doc.free_cards_size(cg.free_cards_size)
        doc.pin_length(cg.pin_length)
        doc.number_length(cg.number_length)
      }
    else
      doc = MorApi.return_error("Cardgroup was not found", doc)
    end
            }
    send_xml_data(out_string, params[:test].to_i)
  end

=begin
  display info about calling card group

  *Params*
  +id+ - card group id
  +autorization+
  +buy_size+ - cards quantity to buy

  *Returns*
  +xml_object+ - cards : pin, number, balance, currency, balance_with_tax
=end
  def buy_card_from_callingroup
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    cg = Cardgroup.find(:first, :include => [:tariff, :lcr, :location, :tax], :conditions => ["cardgroups.id = ? and cardgroups.owner_id = ?", @values[:id], @current_user.get_correct_owner_id])
    cards_size = @values[:quantity].to_i < 1 ? 1 : @values[:quantity].to_i
    if cg
      cards = cg.cards.find(:all, :conditions => {:sold => 0}, :limit => cards_size, :order => "rand()")
      if cards
        doc.cards {
          for card in cards
            if card.sell
              if params[:email]
                order = Ccorder.new()
                order.amount = card.balance
                order.currency = Currency.get_default.name
                order.ordertype = 'unspecified'
                order.date_added = Time.now
                order.completed = 1
                order.email = params[:email]
                order.tax_percent = 0
                order.save

                line_item = Cclineitem.new()
                line_item.cardgroup_id = card.cardgroup_id
                line_item.quantity = 1
                line_item.ccorder_id = order.id
                line_item.price = card.balance
                line_item.card_id = card.id
                line_item.save

                thread = Thread.new(order) { |order|
                  EmailsController::send_to_users_paypal_email(order)
                }
              end

              Action.add_action_hash(@current_user, {:action => 'card_sell_over_api', :target_id => card.id, :target_type => 'Card'})
              doc.card {
                doc.pin(card.pin)
                doc.number(card.number)
                doc.balance_without_vat(card.balance)
                doc.currency(Currency.get_default.name)
              }
            else
              doc = MorApi.return_error("Card error", doc)
            end
          end
        }
      else
        doc = MorApi.return_error("Free cards was not found", doc)
      end
    else
      doc = MorApi.return_error("Cardgroup was not found", doc)
    end
               }
    send_xml_data(out_string, params[:test].to_i)
  end

  def send_sms
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow == true
      check_user(params[:u], params[:p])
      if @user
        if @user.sms_service_active == 1
        @lcr = SmsLcr.where({:id=>params[:lcr_id].to_s}).first
        if @user.sms_service_active == 1
          if @lcr
            if params[:dst]
              if params[:src]
                if params[:message]   # atskirai
                  @user_tariff = @user.sms_tariff
                  @number_of_messages = (URI.unescape(params[:message]).size.to_f / 160).ceil
                  sms = SmsMessage.new
                  sms.sending_date = Time.now
                  sms.user_id = @user.id
                  sms.reseller_id  = @user.owner_id
                  sms.number = params[:dst]
                  sms.save
                  begin
                    sms.sms_send(@user, @user_tariff, params[:dst], @lcr, @number_of_messages.to_f, URI.unescape(params[:message]))
                    if sms.status_code.to_s == "0"
                      doc.response {
                        doc.status('ok')
                        doc.message{
                          doc.message_id(sms.id)
                          doc.sms_status_code_tip(sms.sms_status_code_tip)
                          @curr = Currency.find_by_id(@user.currency_id)
                          if @user.usertype.to_s == 'reseller'
                            doc.price(nice_number sms.reseller_price)
                          else
                            doc.price(nice_number sms.user_price)
                          end
                          doc.currency(@curr.name)
                        }
                      }
                    else
                      doc.error(){
                        doc.message{
                          doc.message_id(sms.id)
                          doc.sms_status_code_tip(sms.sms_status_code_tip)
                        }
                      }
                    end
                  rescue Exception => exception 
                    doc.error(){ 
                      doc.message{ 
                        doc.message_id(sms.id) 
                        doc.sms_status_code_tip(sms.sms_status_code_tip) 
                        doc.error_message(exception.message) 
                      } 
                    }
                  end
                else
                  doc.error("There is no message or it is empty")
                end
              else
                doc.error("Wrong source")
              end
            else
              doc.error("Wrong destination")
            end
          else
            doc.error("There is no such LCR")
          end
        else
          doc.error("User is not subscribed to sms service")
        end
      else
        doc.error("You are not subscribed to sms service")
      end
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end


  def get_version
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
    if allow
      check_user(params[:u], params[:p])
      if @user
        version = (mor_11_extend? ? '12' : '11')
        doc.version(version)
      else
        doc.error("Bad login")
      end
    else
      doc.error("Incorrect hash")
    end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def send_email
    allow, values = MorApi.check_params_with_all_keys(params, request)
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
    doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    doc.page {
      if allow == true
        check_user(params[:u], params[:p])
        if @user
          if @user.usertype == 'accountant' or @user.usertype == 'admin' or @user.usertype == 'reseller'
            email = Email.find(:first, :conditions => ['name = ? and owner_id = ?', params[:email_name], @user.get_corrected_owner_id])
            if email
              if @user.address.email
                if !params[:email_to_user_id].blank?
                  user = User.find(:first, :conditions => ['id = ?', params[:email_to_user_id]])
                else
                  user = @user
                end
                if user
                  users = [user]  # hack
                  variables = Email.map_variables_for_api(params)
                  num = EmailsController.send_email(email, @user.address.email, users, variables.merge({:owner => @user.owner_id}))
                  doc.email_sending_status(num.to_s.gsub('<br>', ''))
                else
                  doc = MorApi.return_error("User not found", doc)
                end
              else
                doc = MorApi.return_error("Your email not found", doc)
              end
            else
              doc = MorApi.return_error("Email not found", doc)
            end
          else
            doc = MorApi.return_error("Don't be so smart", doc)
          end
        else
          doc = MorApi.return_error("Bad login", doc)
        end
      else
        doc = MorApi.return_error("Incorrect hash", doc)
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end



  private


  def check_sms_addon
    unless sms_active?
      send_xml_data(MorApi.return_error('Dont be so smart'), params[:test].to_i)
      return false
    end
  end

  def respond_to_successful_card_operation(doc, card)
    doc.response {
      doc.status('ok')
      doc.card {
        doc.id(card.id)
        doc.cardgroup_id(card.cardgroup_id)
        doc.balance(nice_number(card.balance))
        doc.balance_with_vat(nice_number(card.balance_with_vat))
        doc.callerid(card.callerid)
        doc.pin(card.pin)
        doc.number(card.number)
      }
    }
  end

=begin rdoc
 Checks if API is allowed.
=end

  def check_allow_api
    logger.fatal "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
    if Confline.get_value("Allow_API").to_i != 1
      send_xml_data(MorApi.return_error('API Requests are disabled'), params[:test].to_i)
    end
  end

=begin rdoc
 Checks if GET method is allowed.
 *Returns*
 Error message if method is GET and it is not allowed
=end

  def check_send_method
    if request.get? and Confline.get_value("Allow_GET_API").to_i != 1
      send_xml_data(MorApi.return_error('GET Requests are disabled'), params[:test].to_i)
    end
  end

=begin rdoc
 Sends XML or HTML data. Checks confline XML_API_Extension to determin whitch should be sent.
=end

  def send_xml_data(out_string, test = 0, name = "mor_api_response.xml", zip = false)
    if test.to_i == 1
      MorLog.my_debug out_string
      render :text => out_string and return false
    else

      if  !zip #or out_string.length.to_i < Confline.get_value('Api_response_size').to_i
        if confline("XML_API_Extension").to_i == 1
          send_data(out_string, :type => "text/xml", :filename => name)
        else
          send_data(out_string, :type => "text/html", :filename => "mor_api_response.html")
        end
      else
        path = '/tmp'
        `rm -rf #{path}/#{name}`
        ff = File.open('/tmp/'+name, "wb")
        ff.write(out_string)

        ff.close
        `rm -rf #{path}/#{name}.zip`
        `cd #{path}; zip #{name}.zip #{name}`
        `rm -rf #{path}/#{name}`
        fsrc = "#{path}/#{name}.zip"
        send_file(fsrc, :type => "application/zip")
      end
    end
  end

=begin
 Obsolete method. Used in former authentication.
=end
  def check_user(login='', password='')
    @user = User.find(:first, :conditions => ["username = ? and password = ?", login.to_s, Digest::SHA1.hexdigest(password.to_s)])
    if @user
      User.current = @user
    end
    return @user
  end

=begin
 Log method. Used for all API requests.
=end
  def log_access
    MorLog.my_debug(" ********************** API ACCESS : #{params[:action]} **********************", 1)
    MorLog.my_debug request.url.to_s
    MorLog.my_debug request.remote_addr.to_s
    MorLog.my_debug request.remote_ip
  end

  def last_calls_stats_set_variables(options, values)
    options.merge(values.reject { |key, value| value.nil? })
  end


  def last_calls_stats_parse_params

    default = {
        :s_direction => "outgoing",
        :s_call_type => "all",
        :s_device => "all",
        :s_provider => "all",
        :s_hgc => 0,
        :s_user => "all",
        :user => nil,
        :s_did => "all",
        :s_destination => "",
        :order_by => "time",
        :order_desc => 0,
        :s_country => '',
        :only_did => 0
    }
    options = default
    default.each { |key, value| options[key] = params[key] if params[key] }

    options[:order_by_full] = options[:order_by] + (options[:order_desc] == 1 ? " DESC" : " ASC")
    options[:order] = Call.calls_order_by(params, options)
    options[:direction] = options[:s_direction]
    options[:call_type] = options[:s_call_type]
    options[:destination] = (options[:s_destination].to_s.strip.match(/\A[0-9%]+\Z/) ? options[:s_destination].to_s.strip : "")
    options[:column_dem] = "."

    options
  end

  def find_current_user_for_api
    @current_user = check_user(params[:u], params[:p])
    unless @current_user
      send_xml_data(MorApi.return_error('Bad login'), params[:test].to_i)
      return false
    end
  end


  def check_mor_11_extend
    unless mor_11_extend?
      send_xml_data(MorApi.return_error('Dont be so smart'), params[:test].to_i)
      return false
    end
  end

  def check_api_parrams_with_hash
    allow, @values = MorApi.check_params_with_all_keys(params, request)
    if allow != true
      send_xml_data(MorApi.return_error('Incorrect hash'), params[:test].to_i)
      return false
    end
  end

  def check_calling_card_addon
    reseller_cc_permission = (defined?(CC_Active) and (CC_Active == 1) and (!@current_user.is_reseller? or (@current_user.is_reseller? and (@current_user.reseller_allow_edit('calling_cards')))))
    if !reseller_cc_permission or @current_user.is_user? or (@current_user.is_accountant? and !@current_user.accountant_allow_read('callingcard_manage')) or (@current_user.is_reseller? and !@current_user.reseller_allow_read('calling_cards'))
      send_xml_data(MorApi.return_error('Dont be so smart'), params[:test].to_i)
      return false
    end
  end


end
