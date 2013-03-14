# -*- encoding : utf-8 -*-
class StatsController < ApplicationController
  include PdfGen
  include SqlExport
  require 'uri'
  require 'net/http'

  layout "callc"

  before_filter :check_localization
  before_filter :authorize, :except => [:active_calls_longer_error, :active_calls_longer_error_send_email]
  before_filter :check_if_can_see_finances, :only => [:profit]
  before_filter :check_authentication, :only => [:active_calls, :active_calls_count, :active_calls_order, :active_calls_show]
  before_filter :find_user_from_id_or_session, :only => [:reseller_all_user_stats, :call_list, :index, :user_stats, :missed_calls, :call_list_to_csv, :call_list_from_link, :new_calls_list, :user_logins, :call_list_to_pdf]
  before_filter :find_provider, :only => [:providers_calls]
  before_filter :check_reseller_in_providers, :only => [:providers, :providers_stats, :country_stats]
  before_filter :no_cache, :only => [:active_calls]
  skip_before_filter :redirect_callshop_manager, :only => [:prefix_finder_find, :prefix_finder_find_country]

  before_filter { |c|
    c.instance_variable_set :@allow_read, true
    c.instance_variable_set :@allow_edit, true
  }

  before_filter(:only => [:subscriptions_stats]) { |c|
    allow_read, allow_edit = c.check_read_write_permission( [:subscriptions_stats], [], {:role => "accountant", :right => :acc_manage_subscriptions_opt_1})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to :action => :user_stats and return false
  end

  def show_user_stats
    session[:show_user_stats_options] ? @options = session[:show_user_stats_options] : @options = {:order_by => "nice_user", :order_desc => 0, :page => 1}
    @Show_Currency_Selector=1
    change_date

    @page_title = _('Calls')
    @page_icon = "call.png"


    if session[:usertype] == "accountant"
      @owner_id = "0"
    else
      @owner_id = session[:user_id].to_s
    end

    if session[:usertype] == "reseller"
      if current_user.own_providers.to_i == 0
        caller_type = ""
        provider_prices = "calls.reseller_price"
      else
        caller_type = ""
        provider_prices ="IF(providers.common_use = '0',calls.provider_price,calls.reseller_price)"
      end
    elsif session[:usertype] == "admin"
      caller_type = ""
      provider_prices = "calls.provider_price"
    else
      caller_type = "AND callertype = 'Local'"
      provider_prices = "calls.provider_price"
    end

    sql_get = "SELECT COUNT(A.users_id) as users, SUM(A.balance) as balance, SUM(A.calls) as calls, SUM(sum_duration) as sum_duration, SUM(price) as price, SUM( provider_price)as provider_price, SUM(reseller_price) as reseller_price
    FROM (SELECT users.id as 'users_id', users.balance as 'balance', B.calls as 'calls', B.sum_duration as 'sum_duration', B.price as 'price', B.provider_price as 'provider_price', B.reseller_price as 'reseller_price'
    FROM users
    LEFT JOIN (SELECT users.id as 'users_id', users.balance as 'balance', COUNT( calls.id ) AS 'calls', sum( IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) ) AS 'sum_duration', SUM( calls.user_price ) AS 'price', SUM( #{provider_prices}) AS 'provider_price', SUM( calls.reseller_price ) AS 'reseller_price'
    FROM users
    LEFT JOIN calls ON (calls.user_id = users.id)
    #{'LEFT JOIN providers ON calls.provider_id = providers.id ' if session[:usertype] == "reseller" and current_user.own_providers.to_i == 1}
    WHERE calldate BETWEEN '" + session_from_datetime + "' AND '" + session_till_datetime + "' #{caller_type} AND disposition = 'ANSWERED'
    GROUP BY users.id
    ORDER BY users.first_name ASC) AS B ON (users.id = B.users_id)
    WHERE users.hidden = 0 AND users.owner_id = #{@owner_id}) AS A"

    sum = ActiveRecord::Base.connection.select_all(sql_get)

    @options[:order_by] = params[:order_by] if params[:order_by]
    @options[:order_desc] = params[:order_desc].to_i if params[:order_desc]
    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc] == 1 ? " DESC" : " ASC")

    if @options[:order_by] == "users.first_name"
      @options[:order_by_full] += ", users.last_name" + (@options[:order_desc] == 1 ? " DESC" : " ASC")
    end

    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc] == 1 ? " DESC" : " ASC")
    @options[:order] = User.users_order_by(params, @options)

    user_count = sum[0]["users"].to_i
    @options[:page] = params[:page].to_i if params[:page]
    @page = @options[:page]
    @total_pages = (user_count / session[:items_per_page].to_d).ceil
    istart = (session[:items_per_page] * (@page - 1))

    session[:usertype] == 'admin' ? price_by = "provider_price" : price_by ="reseller_price"

    sql = "SELECT #{SqlExport.nice_user_sql}, users.id, users.first_name, users.last_name, users.username, users.balance, B.calls AS 'calls', B.sum_duration as 'sum_duration', B.price as 'price', B.provider_price as 'provider_price', B.reseller_price as 'reseller_price', A.all_calls,
    IF(sum_duration/calls IS NOT NULL,sum_duration/calls , 0) AS 'acd',
    IF ((calls/all_calls)*100 IS NOT NULL,(calls/all_calls)*100, 0 ) AS 'asr',
    IF (price-#{price_by} IS NOT NULL,price-#{price_by}, 0) AS 'profit',
    IF ((price-#{price_by})/price IS  NOT NULL,(price-#{price_by})/price,0) AS'margin',
    IF (price/#{price_by} IS NOT NULL, (price/#{price_by}*100)-100, 0) as 'markup'
    FROM users
    LEFT JOIN (SELECT calls.user_id AS 'user_id', COUNT(calls.id) as 'calls', sum(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'sum_duration', SUM(calls.user_price) AS 'price', SUM( #{provider_prices}) AS 'provider_price', SUM(calls.reseller_price) AS 'reseller_price'
    FROM calls
    #{'LEFT JOIN providers ON calls.provider_id = providers.id ' if session[:usertype] == "reseller" and current_user.own_providers.to_i == 1}
    WHERE disposition = 'ANSWERED' AND calldate BETWEEN \'" + session_from_datetime + "' AND '" + session_till_datetime + "' #{caller_type}
    GROUP BY calls.user_id) AS B   ON (B.user_id = users.id)

    LEFT JOIN (SELECT calls.user_id as 'user_id', COUNT(calls.id) as 'all_calls'
    FROM calls
    WHERE calldate BETWEEN \'" + session_from_datetime + "' AND '" + session_till_datetime + "' #{caller_type}
    GROUP BY calls.user_id) AS A ON (A.user_id = users.id)
    WHERE users.hidden = 0 AND users.owner_id = '#{@owner_id}'
    ORDER BY #{@options[:order]}
    LIMIT #{istart},#{session[:items_per_page]};"

    res = ActiveRecord::Base.connection.select_all(sql)
    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    @res = res

    @total_balance = 0.0
    @total_calls = 0
    @total_time = 0
    @total_price = 0.0
    @total_prov = 0.0
    @curr_price = []
    @curr_prov_price = []
    @user_price = []
    @prov_price = []
    @profit = []
    @curr_balance = []
    for r in res
      id = r["id"].to_i
      @rate_cur, @rate_cur2 = Currency.count_exchange_prices({:exrate => exrate, :prices => [r["price"].to_d, r["balance"].to_d]})
      @total_balance += @rate_cur2
      @total_calls += r["calls"].to_d
      @total_time += r["sum_duration"].to_d
      @total_price += @rate_cur
      @curr_price[id]=@rate_cur
      @curr_balance[id]=@rate_cur2
      @user_price[id] = r["price"].to_d

      #  if session[:usertype]=='admin'
      @prov_price[id]= r["provider_price"].to_d
      @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [r["provider_price"].to_d]}) if r["provider_price"]
      @curr_prov_price[id] = @rate_cur if r["provider_price"]
      @total_prov += @rate_cur.to_d
      # else
      # @prov_price[id]= r["reseller_price"].to_d
      # @rate_cur = Currency.count_exchange_prices({:exrate=>exrate, :prices=>[provider_price.to_d]}) if provider_price
      # @curr_prov_price[id] =  @rate_cur if provider_price
      # @total_prov += @rate_cur.to_d
      # end
    end

    @all_balance = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["balance"].to_d]})
    @all_time = sum[0]["sum_duration"].to_i
    @all_price = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["price"].to_d]})
    #if session[:usertype]=='admin'
    @all_prov_price = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["provider_price"].to_d]})
    #else
    #  @all_prov_price = Currency.count_exchange_prices({:exrate=>exrate, :prices=>[sum[0]["reseller_price"].to_d]})
    #end
    @all_profit = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["price"].to_d]}) - @all_prov_price.to_d
    @total_profit = @total_price.to_d - @total_prov.to_d
    @all_calls = sum[0]["calls"].to_i
    #========================
    session[:show_user_stats_options] = @options
    if request.xml_http_request?
      render :partial => "list_stats", :layout => false
    end
  end

  def all_users_detailed

    change_date
    @page_title = _('All_users_detailed')
    #@help_link = 'http://wiki.kolmisoft.com/index.php/Last_Calls#Call_information_representation'#conflicts with flash
    @users = User.find(:all, :conditions => "hidden = 0") #, :conditions => "usertype = 'user'") #, :limit => 6)
    @help_link = "http://wiki.kolmisoft.com/index.php/Integrity_Check"

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    call_stats = Call.total_calls_by_direction_and_disposition(session_from_datetime, session_till_datetime)

    @o_answered_calls = 0
    @o_no_answer_calls = 0
    @o_busy_calls = 0
    @o_failed_calls = 0
    @i_answered_calls = 0
    @i_no_answer_calls = 0
    @i_busy_calls = 0
    @i_failed_calls = 0
    for stats in call_stats
      if  stats['direction'] == 'outgoing'
        if stats['disposition'].upcase == 'ANSWERED'
          @o_answered_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'NO ANSWER'
          @o_no_answer_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'BUSY'
          @o_busy_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'FAILED'
          @o_failed_calls = stats['total_calls'].to_i
        end
      elsif stats['direction'] == 'incoming'
        if stats['disposition'].upcase == 'ANSWERED'
          @i_answered_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'NO ANSWER'
          @i_no_answer_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'BUSY'
          @i_busy_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'FAILED'
          @i_failed_calls = stats['total_calls'].to_i
        end
      end
    end
    @outgoing_calls = @o_answered_calls + @o_no_answer_calls + @o_busy_calls + @o_failed_calls
    @incoming_calls = @i_answered_calls + @i_no_answer_calls + @i_busy_calls + @i_failed_calls
    @total_calls = @incoming_calls + @outgoing_calls

    sfd = session_from_datetime
    std = session_till_datetime

    @outgoing_perc = 0
    @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
    @incoming_perc = 0
    @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0

    @o_answered_perc = 0
    @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_no_answer_perc = 0
    @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_busy_perc = 0
    @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_failed_perc = 0
    @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

    @i_answered_perc = 0
    @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_no_answer_perc = 0
    @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_busy_perc = 0
    @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_failed_perc = 0
    @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0

    @t_answered_calls = @o_answered_calls + @i_answered_calls
    @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
    @t_busy_calls = @o_busy_calls + @i_busy_calls
    @t_failed_calls = @o_failed_calls + @i_failed_calls

    @t_answered_perc = 0
    @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_no_answer_perc = 0
    @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_busy_perc = 0
    @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_failed_perc = 0
    @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

    @a_date, @a_calls, @a_billsec, @a_avg_billsec = Call.answered_calls_day_by_day(sfd, std)

    @t_calls = @a_calls.last.to_i
    @t_billsec = @a_billsec.last.to_i
    @t_avg_billsec = @a_avg_billsec.last.to_i

    @a_calls.delete_at(@a_calls.length - 1)
    @a_billsec.delete_at(@a_billsec.length  - 1)
    @a_avg_billsec.delete_at(@a_billsec.length)

    index = @a_date.length - 1

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    #formating graph for INCOMING/OUTGOING calls

    @Out_in_calls_graph = "\""
    if @t_calls > 0
      @Out_in_calls_graph += _('Outgoing') + ";" +@outgoing_calls.to_s + ";" + "false" + "\\n" + _('Incoming') +";" +@incoming_calls.to_s + ";" + "false" + "\\n\""
    else
      @Out_in_calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for Call-type calls

    @Out_in_calls_graph2 = "\""
    if @t_calls > 0

      @Out_in_calls_graph2 += _('ANSWERED') +";" +@t_answered_calls.to_s + ";" + "false" + "\\n"
      @Out_in_calls_graph2 += _('NO_ANSWER') +";" +@t_no_answer_calls.to_s + ";" + "false" + "\\n"
      @Out_in_calls_graph2 += _('BUSY') +";" +@t_busy_calls.to_s + ";" + "false" + "\\n"
      @Out_in_calls_graph2 += _('FAILED') +";" +@t_failed_calls.to_s + ";" + "false" + "\\n"

      @Out_in_calls_graph2 += "\""
    else
      @Out_in_calls_graph2 = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for Calls

    ine=0
    @Calls_graph =""
    i=0
    for i in 0..@a_calls.size-1
      @Calls_graph += @a_date[ine].to_s + ";" + @a_calls[i].to_i.to_s + "\\n"
      ine=ine +1
    end
    #formating graph for Calltime

    i=0
    @Calltime_graph =""
    for i in 0..@a_billsec.size-1
      @Calltime_graph += @a_date[i].to_s + ";" + (@a_billsec[i].to_i / 60).to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Avg.Calltime

    ine=0
    @Avg_Calltime_graph =""
    i=0
    for i in 0..@a_avg_billsec.size-1
      @Avg_Calltime_graph += @a_date[ine].to_s + ";" + @a_avg_billsec[i].to_i.to_s + "\\n"
      ine=ine +1
    end

  end

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def reseller_all_user_stats

    unless session[:usertype] == 'reseller'
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

    @users = User.find_all_for_select(corrected_user_id, {:exclude_owner => true})
    @users << @user
    change_date

    @page_title = _('Detailed_stats_for')+" "+@user.first_name+" "+@user.last_name

    #    @todays_normative = @user.normative_perc(Time.now)
    #    @months_normative = @user.months_normative(Time.now.strftime("%Y-%m"))

    ############

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)


    @a_date = []
    @a_calls = []
    @a_billsec = []
    @a_avg_billsec = []
    @a_normative = []

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    #@new_calls_today =0

    @i_answered_calls=0
    @i_busy_calls=0
    @i_failed_calls=0
    @i_no_answer_calls=0
    @outgoing_calls=0
    @incoming_calls=0
    @total_calls=0
    @o_answered_calls=0
    @o_no_answer_calls=0
    @o_busy_calls=0
    @o_failed_calls = 0

    for user in @users
      #@new_calls_today += user.new_calls(Time.now.strftime("%Y-%m-%d")).size
      @outgoing_calls += user.total_calls("outgoing", session_from_datetime, session_till_datetime)
      @incoming_calls += user.total_calls("incoming", session_from_datetime, session_till_datetime)
      @total_calls += user.total_calls("all", session_from_datetime, session_till_datetime)

      @o_answered_calls += user.total_calls("answered_out", session_from_datetime, session_till_datetime)
      @o_no_answer_calls += user.total_calls("no_answer_out", session_from_datetime, session_till_datetime)
      @o_busy_calls += user.total_calls("busy_out", session_from_datetime, session_till_datetime)
      @o_failed_calls += user.total_calls("failed_out", session_from_datetime, session_till_datetime)

      @i_answered_calls += user.total_calls("answered_inc", session_from_datetime, session_till_datetime)
      @i_no_answer_calls += user.total_calls("no_answer_inc", session_from_datetime, session_till_datetime)
      @i_busy_calls += user.total_calls("busy_inc", session_from_datetime, session_till_datetime)
      @i_failed_calls += user.total_calls("failed_inc", session_from_datetime, session_till_datetime)

      i = 0
      @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
      @edate = Time.mktime(year, month, day)

      while @sdate < @edate
        @start_date = (@sdate - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)
        @a_date[i] = @start_date
        unless @a_calls[i]
          @a_calls[i] = 0
          @a_billsec[i] = 0
          @a_normative[i] = 0
        end

        @end_date = (@a_date[i].to_time + 23.hour + 59.minute + 59.second).to_s(:db)
        @a_calls[i] += user.total_calls("answered_out", @a_date[i], @end_date) + @user.total_calls("answered_inc", @a_date[i], @end_date)
        @a_billsec[i] += user.total_billsec("answered_out", @a_date[i], @end_date) + @user.total_duration("answered_inc", @a_date[i], @end_date)
        @a_normative[i] += user.normative_perc(@start_date).to_i
        @sdate += (60 * 60 * 24)
        i+=1
      end
    end

    @a_calls.each_with_index { |calls, index|
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0
      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]
      @t_normative += @a_normative[index]
      @t_norm_days += 1 if @a_normative[index] > 0
    }

    @outgoing_perc = 0
    @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
    @incoming_perc = 0
    @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0


    @o_answered_perc = 0
    @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_no_answer_perc = 0
    @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_busy_perc = 0
    @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_failed_perc = 0
    @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

    @i_answered_perc = 0
    @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_no_answer_perc = 0
    @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_busy_perc = 0
    @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_failed_perc = 0
    @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0


    @t_answered_calls = @o_answered_calls + @i_answered_calls
    @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
    @t_busy_calls = @o_busy_calls + @i_busy_calls
    @t_failed_calls = @o_failed_calls + @i_failed_calls

    @t_answered_perc = 0
    @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_no_answer_perc = 0
    @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_busy_perc = 0
    @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_failed_perc = 0
    @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

    index = i

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0
    @t_avg_normative = @t_normative / @t_norm_days if @t_norm_days > 0

    #formating graph for INCOMING/OUTGING calls

    @Out_in_calls_graph = "\""
    if @t_calls > 0
      @Out_in_calls_graph += _('Outgoing') + ";" +@outgoing_calls.to_s + ";" + "false" + "\\n" + _('Incoming') +";" +@incoming_calls.to_s + ";" + "true" + "\\n\""
    else
      @Out_in_calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for INCOMING/OUTGING calls

    @Out_in_calls_graph2 = "\""
    if @t_calls > 0
      @Out_in_calls_graph2 += _('ANSWERED') +";" +@t_answered_calls.to_s + ";" + "false" + "\\n" + _('NO_ANSWER') +";" +@t_no_answer_calls.to_s + ";" + "true" + "\\n" + _('BUSY') +";" +@t_busy_calls.to_s + ";" + "false" + "\\n" + _('FAILED') +";" +@t_failed_calls.to_s + ";" + "false" +"\\n\""
    else
      @Out_in_calls_graph2 = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for Calls

    ine=0
    @Calls_graph =""
    while ine <= index - 1
      @Calls_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_calls[ine].to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Calltime

    i=0
    @Calltime_graph =""
    for i in 0..@a_billsec.size-1
      @Calltime_graph +=nice_date(@a_date[i].to_s) + ";" + (@a_billsec[i] / 60).to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Avg.Calltime

    ine=0
    @Avg_Calltime_graph =""
    while ine <= index - 1
      @Avg_Calltime_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_avg_billsec[ine].to_s + "\\n"
      ine=ine +1
    end

  end

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end

  def user_stats

    change_date

    #@active_users =  active_users(Time.now - 0.days).size

    @page_title = _('Detailed_stats_for')+" "+@user.first_name+" "+@user.last_name

    @todays_normative = @user.normative_perc(Time.now)
    @months_normative = @user.months_normative(Time.now.strftime("%Y-%m"))
    @new_calls_today = @user.new_calls(Time.now.strftime("%Y-%m-%d")).size

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    call_stats = Call.total_calls_by_direction_and_disposition(session_from_datetime, session_till_datetime, [@user.id])

    @o_answered_calls = 0
    @o_no_answer_calls = 0
    @o_busy_calls = 0
    @o_failed_calls = 0
    @i_answered_calls = 0
    @i_no_answer_calls = 0
    @i_busy_calls = 0
    @i_failed_calls = 0
    for stats in call_stats
      if  stats['direction'] == 'outgoing'
        if stats['disposition'].upcase == 'ANSWERED'
          @o_answered_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'NO ANSWER'
          @o_no_answer_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'BUSY'
          @o_busy_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'FAILED'
          @o_failed_calls = stats['total_calls'].to_i
        end
      end
      if  stats['direction'] == 'incoming'
        if stats['disposition'].upcase == 'ANSWERED'
          @i_answered_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'NO ANSWER'
          @i_no_answer_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'BUSY'
          @i_busy_calls = stats['total_calls'].to_i
        elsif stats['disposition'].upcase == 'FAILED'
          @i_failed_calls = stats['total_calls'].to_i
        end
      end
    end
    @outgoing_calls = @o_answered_calls + @o_no_answer_calls + @o_busy_calls + @o_failed_calls
    @incoming_calls = @i_answered_calls + @i_no_answer_calls + @i_busy_calls + @i_failed_calls
    @total_calls = @incoming_calls + @outgoing_calls

    @o_answered_perc = 0
    @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_no_answer_perc = 0
    @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_busy_perc = 0
    @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_failed_perc = 0
    @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

    @i_answered_perc = 0
    @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_no_answer_perc = 0
    @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_busy_perc = 0
    @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_failed_perc = 0
    @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0

    @t_answered_calls = @o_answered_calls + @i_answered_calls
    @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
    @t_busy_calls = @o_busy_calls + @i_busy_calls
    @t_failed_calls = @o_failed_calls + @i_failed_calls

    @t_answered_perc = 0
    @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_no_answer_perc = 0
    @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_busy_perc = 0
    @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_failed_perc = 0
    @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

    @outgoing_perc = 0
    @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
    @incoming_perc = 0
    @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0

    ############

    @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])

    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)

    @a_date = []
    @a_calls = []
    @a_billsec = []
    @a_avg_billsec = []
    @a_normative = []

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    sfd = session_from_datetime
    std = session_till_datetime

    @a_date, @a_calls, @a_billsec, @a_avg_billsec = Call.answered_calls_day_by_day(sfd, std, [@user.id])

    @t_calls = @a_calls.last.to_i
    @t_billsec = @a_billsec.last.to_i
    @t_avg_billsec = @a_avg_billsec.last.to_i

    @a_calls.delete_at(@a_calls.length - 1)
    @a_billsec.delete_at(@a_billsec.length - 1)
    @a_avg_billsec.delete_at(@a_billsec.length)

    index = @a_date.length - 1

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0
    @t_avg_normative = @t_normative / @t_norm_days if @t_norm_days > 0

    #formating graph for INCOMING/OUTGING calls

    @Out_in_calls_graph = "\""
    if @t_calls > 0
      @Out_in_calls_graph += _('Outgoing') + ";" +@outgoing_calls.to_s + ";" + "false" + "\\n" + _('Incoming') +";" +@incoming_calls.to_s + ";" + "true" + "\\n\""
    else
      @Out_in_calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for INCOMING/OUTGING calls

    @Out_in_calls_graph2 = "\""
    if @t_calls > 0
      @Out_in_calls_graph2 += _('ANSWERED') +";" +@t_answered_calls.to_s + ";" + "false" + "\\n" + _('NO_ANSWER') +";" +@t_no_answer_calls.to_s + ";" + "true" + "\\n" + _('BUSY') +";" +@t_busy_calls.to_s + ";" + "false" + "\\n" + _('FAILED') +";" +@t_failed_calls.to_s + ";" + "false" +"\\n\""
    else
      @Out_in_calls_graph2 = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for Calls

    i=0
    @Calls_graph =""
    for i in 0..@a_billsec.size-1
      @Calls_graph +=nice_date(@a_date[i].to_s) + ";" + @a_calls[i].to_s + "\\n"
      # ine=ine +1
    end

    #formating graph for Calltime

    i=0
    @Calltime_graph =""
    for i in 0..@a_billsec.size-1
      @Calltime_graph +=nice_date(@a_date[i].to_s) + ";" + (@a_billsec[i] / 60).to_s + "\\n"
      #ine=ine +1
    end

    #formating graph for Avg.Calltime

    i=0
    @Avg_Calltime_graph =""
    for i in 0..@a_billsec.size-1
      @Avg_Calltime_graph +=nice_date(@a_date[i].to_s) + ";" + @a_avg_billsec[i].to_s + "\\n"
      #ine=ine +1
    end
  end

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def user_logins
    change_date
    @Login_graph =[]

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page_title = _('Login_stats_for')+" "+@user.first_name+" "+@user.last_name

    date_start = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
    date_end = Time.mktime(session[:year_till], session[:month_till], session[:day_till])

    @MyDay = Struct.new("MyDay", :date, :login, :logout, :duration)
    @a = [] #day
    @b = [] #login
    @c = [] #logout
    @d = [] #duration

    #making date array
    date_end = Time.now if date_end > Time.now
    if date_start == date_end
      @a << date_start
    else
      date = date_start
      while date < (date_end + 1.day)
        @a << date
        date = date+1.day
      end
    end


    @total_pages = ((@a.size).to_d / 10.to_d).ceil
    @all_date =@a
    @a = []
    iend = ((10 * @page) - 1)
    iend = @all_date.size - 1 if iend > (@all_date.size - 1)
    for i in ((@page - 1) * 10)..iend
      @a << @all_date[i]
    end
    @page_select_header_id = @user.id


    #make state lists for every date
    d = 0
    for date in @a
      bb = [] #login date
      cc = [] #logout date
      dd = [] # duration

      #let's find starting action for the day
      start_action = Action.find(:first, :conditions => ["user_id = ? AND SUBSTRING(date,1,10) < ?", @user.id, date.strftime("%Y-%m-%d")], :order => "date DESC")
      other_actions = Action.find(:all, :conditions => ["user_id = ? AND SUBSTRING(date,1,10) = ?", @user.id, date.strftime("%Y-%m-%d")], :order => "date ASC")

      #form array for actions
      actions = []
      actions << start_action if start_action
      for oa in other_actions
        actions << oa
      end

      #compress array removing spare logins/logouts
      pa = 0 #previous action to compare
      #if actions.size > 0
      for i in 1..actions.size-1
        if actions[i].action == actions[pa].action #and actions[i] != actions.last
          actions[i] = nil
        else
          pa = i
        end
        i+=1
      end
      actions.compact!
      #build array from data
      if actions.size > 0 #fix if we do not have data
        if actions.size == 1
          #all day same state

          if actions[0].action == "login"
            bb << date
            cc << date+1.day-1.second
            dd << (date+1.day - date)

          end

        else
          #we have some state change during day
          i = 1
          i = 0 if actions[0].action == "login"

          (actions.size/2).times do

            #login
            if actions[i].date.day == date.day
              lin = actions[i].date
            else
              lin = date
            end

            #logout
            if actions[i+1] #we have logout
              lout = actions[i+1].date
            else #no logout, login end - end of day
              lout = date+1.day-1.second
            end

            bb << lin
            cc << lout
            dd << lout - lin

            i+=2
          end
        end

      end

      @b << bb
      @c << cc
      @d << dd

      hours = Hash.new

      i=0
      12.times do
        hours[(i*8)] = (i*2).to_s
        i+=1
      end

      #hours = {0 => "0", 2=>"2", 4=>"4", 6=>"6", 8=>"8", 10=>"10",12=>"12",  14=>"14", 16=>"16", 18=>"18", 20=>"20", 22=>"22" }

      #format data array
      #for i in 0..95

      a = []
      96.times do
        a << 0
      end


      for i in 0..(bb.size-1)
        x = (bb[i].hour * 60 + bb[i].min) / 15
        y = (cc[i].hour * 60 + cc[i].min) / 15
        for ii in x..y
          a[ii] = 1
        end
        #        my_debug x
        #        my_debug y
      end

      #formating graph for Log States whit flash
      @Login_graph[d]=""
      rr = 0
      while rr <= 96
        db= rr % 8
        as= rr/4
        if db ==0
          @Login_graph[d] += as.to_s + ";" + a[rr].to_s + "\\n"
        end
        rr=rr+1
      end

      d+=1
    end

    @days = @MyDay.new(@a, @b, @c, @d)
  end


  def new_calls
    change_date
    @page_title = _('New_calls')
    @page_icon = "call.png"
    @users = User.find(:all, :conditions => "hidden = 0")
  end


=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def new_calls_list

    @page_title = _('New_calls')+": "+@user.first_name+" "+@user.last_name+" - "+session_from_date
    @calls = @user.new_calls(session_from_date)


    @select_date = false
    render :action => "new_call_list"
  end

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def call_list_from_link

    @date_from = params[:date_from]
    @date_till = params[:date_till].to_s != 'time_now' ? params[:date_till] : Time.now.strftime("%Y-%m-%d %H:%M:%S")

    @call_type = "all"
    @call_type = params[:call_type] if params[:call_type]

    @page_title = _('all_calls') #if  @call_type == "all"
    @page_title = _('answered_calls') if @call_type == "answered"
    @page_title = _('incoming_calls') if @call_type == "answered_inc"
    @page_title = _('missed_calls') if @call_type == "missed"


    @page_title = @page_title + ": " + @user.first_name + " " + @user.last_name
    @calls = @user.calls(@call_type, @date_from, @date_till)

    @total_duration = 0
    @total_price = 0
    @total_billsec = 0

    @curr_rate= {}
    @curr_rate2= {}
    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    for call in @calls
      @total_duration += call.duration
      if @direction == "incoming"
        @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_price.to_d]}) if call.did_price
        @total_price += @rate_cur if call.did_price
        @curr_rate2[call.id]=@rate_cur
        @total_billsec += call.did_billsec
      else
        @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d]}) if call.user_price
        @total_price += @rate_cur if call.user_price
        @curr_rate[call.id]=@rate_cur
        @total_billsec += call.nice_billsec
      end
    end

    @show_destination = params[:show_dst]
    redirect_to :controller => "stats", :action => "call_list", :id => @user.id, :call_type => @call_type, :date_from_link => @date_from, :date_till_link => @date_till, :direction => "outgoing" #and return false
  end

=begin
in before filter : user (:find_user_from_id_or_session)
=end
  def last_calls_stats
    @page_title = _('Last_calls')
    @page_icon = "call.png"
    change_date
    @Show_Currency_Selector=1
    @options = last_calls_stats_parse_params
    if session[:usertype] == "user"
      unless (@user = current_user)
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
      @devices, @device = last_calls_stats_user(@user, @options)
    end

    if session[:usertype] == "reseller"
      @users, @user, @devices, @device, @hgcs, @hgc, @providers, @provider, @did, @dids = last_calls_stats_reseller(@options)
    end


    if ["admin", "accountant"].include?(session[:usertype])
      @users, @user, @devices, @device, @hgcs, @hgc, @dids, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids = last_calls_stats_admin(@options)
    end
    session[:last_calls_stats] = @options
    options = last_calls_stats_set_variables(@options, {:user => @user, :device => @device, :hgc => @hgc, :did => @did, :current_user => current_user, :provider => @provider, :can_see_finances => can_see_finances?, :reseller => @reseller})

    type = 'html'
    type = 'csv' if params[:csv].to_i == 1
    type = 'pdf' if params[:pdf].to_i == 1

    case type
      when 'html'
        @total_calls_stats = Call.last_calls_total_stats(options)
        @total_calls = @total_calls_stats.total_calls.to_i
        logger.debug " >> Total calls: #{@total_calls}"
        @total_pages = (@total_calls/ session[:items_per_page].to_d).ceil
        options[:page] = @total_pages if options[:page].to_i > @total_pages.to_i
        options[:page] = 1 if options[:page].to_i < 1
        @calls = Call.last_calls(options)
        logger.debug("  >> Calls #{@calls.size}")
        @show_destination = 1
        session[:last_calls_stats] = @options
      #@calls = [@calls[1]]
      when 'pdf'
        options[:column_dem] = '.'
        options[:current_user] = current_user
        calls, test_data = Call.last_calls_csv(options.merge({:pdf => 1}))
        total_calls = Call.last_calls_total_stats(options)
        pdf = PdfGen::Generate.generate_last_calls_pdf(calls, total_calls, current_user, {:direction => '', :date_from => session_from_datetime, :date_till => session_till_datetime, :show_currency => session[:show_currency], :rs_active => rs_active?, :can_see_finances => can_see_finances?})
        logger.debug("  >> Calls #{calls.size}")
        @show_destination = 1
        session[:last_calls_stats] = @options
        if params[:test].to_i == 1
          render :text => "OK"
        else
          send_data pdf.render, :filename => "Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
        end
      when 'csv'
        options[:test] = 1 if params[:test]
        options[:collumn_separator], options[:column_dem] = current_user.csv_params
        options[:current_user] = current_user
        filename, test_data = Call.last_calls_csv(options)
        filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
        if filename
          filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
          if params[:test].to_i != 1
            file = File.open(filename)
            send_data file.read, :filename => filename
          else
            render :text => filename + test_data.to_s
          end
        else
          flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
          redirect_to :controller => :callc, :action => :main and return false
        end
    end

    if !params[:commit].nil?
      @options[:page] = 1
    end

  end

  def call_list
    @page_title = _('Calls')
    @page_icon = "call.png"

    @Show_Currency_Selector=1

    #    (params[:id] and session[:usertype] != "user") ? user_id = params[:id] : user_id = session[:user_id]
    #
    #    unless (@user=User.find(:first,:include => [:devices], :conditions => ["users.id = ?", user_id]))
    #      flash[:notice] = _('User_not_found')
    #      redirect_to :controller => :callc, :action => :main and return false
    #    end
    #
    #    owner = correct_owner_id
    #    if @user.owner_id != owner and @user.id != session[:user_id] and session[:user_id].to_i != 0
    #      dont_be_so_smart
    #      redirect_to :controller => :callc, :action => :main and return false
    #    end
    #
    #    @user = authorize_user(@user)

    MorLog.my_debug @user.id

    @devices = @user.devices

    params[:device] ? @sel_device_id = params[:device].to_i : @sel_device_id = 0
    params[:hgc] ? @sel_hgc_id = params[:hgc].to_i : @sel_hgc_id = 0
    params[:direction] ? @direction = params[:direction] : @direction = "outgoing"
    params[:page] ? @page = params[:page].to_i : @page = 1

    @device = Device.find(:first, :conditions => ['id=?', @sel_device_id]) if @sel_device_id.to_i > 0
    @hgc =Hangupcausecode.where(:id => @sel_hgc_id).first if @sel_hgc_id > 0
    @hgcs = Hangupcausecode.find(:all)
    @search = 0

    if params[:date_from_link]
      @date_from = params[:date_from_link]
      @date_till = params[:date_till_link]
    else
      change_date
      @date_from = session_from_datetime
      @date_till = session_till_datetime
    end

    #changing the state of call processed field
    if params[:processed]
      if processed_call = Call.where(:id => params[:processed]).first
        processed_call.processed == 0 ? processed_call.processed = 1 : processed_call.processed = 0
        processed_call.save
      end
    end

    @call_type = "all"
    @call_type = params[:call_type] if params[:call_type]
    @call_type = params[:calltype] if params[:calltype]

    @orig_call_type = @call_type
    @call_type += "_inc" if @direction == "incoming"

    @calls_per_page = Confline.get_value("Items_Per_Page").to_i
    @page_select_header_id = @user.id

    @total_stats = @user.calls_total_stats(@orig_call_type, @date_from, @date_till, @direction, @device, @user.usertype, @hgc)
    @total_calls = @total_stats.total_calls.to_i
    @total_pages = (@total_calls.to_d / @calls_per_page.to_d).ceil.to_i

    start = @page < 1 ? 1 : (@calls_per_page * (@page-1))
    @calls_per_page2 = @calls_per_page.to_i < 2 ? 1 : @calls_per_page -1
    @calls = @user.calls(@orig_call_type, @date_from, @date_till, @direction, "calldate", "DESC", @device, {:limit => @calls_per_page2, :offset => start, :providers => true, :destinations => true, :hgc => @hgc})

    @calls = [] if not @calls

    @total_duration = @total_stats.total_duration.to_d
    @total_billsec = @total_stats.total_billsec.to_d

    # count Totals

    @total_price = 0
    @total_inc_price = 0
    @total_price2 = 0
    @total_prov_price = 0
    @total_profit = 0
    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency]).to_d
    #outgoing
    if session[:usertype] == "admin" and @user.owner_id != 0
      @total_price = @total_stats.total_reseller_price.to_d * exchange_rate
    else
      @total_price = @total_stats.total_user_price.to_d * exchange_rate
    end

    #incoming
    @total_inc_prov_price = @total_stats.total_did_prov_price.to_d * exchange_rate
    @total_inc_price = @total_stats.total_did_inc_price.to_d * exchange_rate
    @total_price2 = @total_stats.total_did_price.to_d * exchange_rate


    if session[:usertype] == "admin"
      @total_prov_price = @total_stats.total_provider_price.to_d * exchange_rate
      #my_debug @total_prov_price
    else
      # provider price for reseller
      if @user.id == session[:user_id]
        @total_prov_price = @total_stats.total_user_price.to_d * exchange_rate
      else
        @total_prov_price = @total_stats.total_reseller_price.to_d * exchange_rate
      end

    end

    if @direction == "incoming"
      @total_profit = @total_inc_prov_price.to_d + @total_inc_price.to_d + @total_price2.to_d
    else
      @total_profit = @total_price.to_d - @total_prov_price.to_d
    end


    # count separate users values

    @curr_rate = {}
    @curr_rate2 = {}
    @prov_rate = {}
    @curr_prov_rate = {}
    @curr_prov_rate2= {}
    @curr_inc_rate = {}

    for call in @calls
      if @direction == "incoming"
        @curr_rate[call.id]= call.user_price * exchange_rate if call.user_price

        @curr_rate2[call.id] = call.did_price * exchange_rate if call.did_price
        @curr_prov_rate2[call.id] = call.did_prov_price * exchange_rate if call.did_prov_price
        @curr_inc_rate[call.id] = call.did_inc_price * exchange_rate if call.did_inc_price
      else
        # outgoing calls

        if session[:usertype] == "admin"
          @prov_rate[call.id]= call.provider_price if call.provider_price
          @curr_prov_rate[call.id]= call.provider_price * exchange_rate if call.provider_price

          if call.reseller_id.to_i == 0
            # user price for calls made by admin users are calls.user_price
            @curr_rate[call.id] = call.user_price * exchange_rate if call.user_price
          else
            # user price for calls made by resellers users (for admin) is calls.reseller_price
            @curr_rate[call.id] = call.reseller_price * exchange_rate if call.reseller_price
          end
        else
          if call.reseller_id.to_i == 0
            #provider price for resellers own call = price he gets from admin = user_price, profit for such calls = 0
            @prov_rate[call.id] = call.user_price if call.user_price
            @curr_prov_rate[call.id] = call.user_price * exchange_rate if call.user_price
          else
            # provider price for resellers users calls is price reseller buys calls from admin
            @prov_rate[call.id]= call.reseller_price if call.reseller_price
            @curr_prov_rate[call.id] = call.reseller_price * exchange_rate if call.reseller_price
          end
          @curr_rate[call.id] = call.user_price * exchange_rate if call.user_price
        end
      end

    end

    @show_destination = 1

    @old_call_type = @call_type
    @call_type = @orig_call_type
    @search = 1 if params[:search_on]
  end

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def last_calls
    redirect_to :action => "last_calls_stats"
  end

  def cc_call_list
    redirect_to :action => :last_calls_stats, :s_card_id=>params[:id]
  end

  def country_stats
    @page_title = _('Country_Stats')
    @page_icon = "world.png"
    change_date
    default_user_id = -1
    if params[:csv].to_i == 0
      @user_id = params[:user_id] ? params[:user_id].to_i : default_user_id
      session[:stats_country_stats_options] ||= {}
      session[:stats_country_stats_options][:user_id] = @user_id
      @users = User.find_all_for_select(corrected_user_id, {:exclude_owner => true})
      @calls, @longest_time, @profit, @incomes, @calls_all = Call.country_stats({:user_id => params[:user_id], :current_user => current_user, :a1 => session_from_datetime, :a2 => session_till_datetime})
    else
      options = session[:stats_country_stats_options]
      @user_id = (options and options[:user_id]) ? options[:user_id] : default_user_id
      settings_owner_id = (["reseller", "admin"].include?(session[:usertype]) ? session[:user_id] : session[:owner_id])
      filename, test_data = Call.country_stats_csv({:collumn_separator => Confline.get_csv_separator(settings_owner_id), :s_user => @user_id, :current_user => current_user, :from => session_from_datetime, :till => session_till_datetime, :nice_number_digits => session[:nice_number_digits], :test => params[:test].to_i, :hide_finances => !can_see_finances?})
      filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
      if filename
        filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
        if params[:test].to_i != 1
          send_data(File.open(filename).read, :filename => filename)
        else
          render :text => filename + test_data.to_s
        end
      else
        flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
        redirect_to :controller => :callc, :action => :main and return false
      end
    end
  end

  ############ CSV ###############

  def last_calls_stats_admin
    redirect_to :action => "last_calls_stats"
  end

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def call_list_to_csv
    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @sel_device_id = 0
    @sel_device_id = params[:device].to_i if params[:device]

    @device = Device.find(:first, :conditions => ["id = ?", @sel_device_id]) if @sel_device_id > 0

    @hgcs = Hangupcausecode.find(:all)
    @sel_hgc_id = 0
    @sel_hgc_id = params[:hgc].to_i if params[:hgc]

    @hgc = Hangupcausecode.where(:id => @sel_hgc_id).first if @sel_hgc_id > 0

    if session[:usertype].to_s != 'admin' and params[:reseller]
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
    res = session[:usertype] == 'admin' ? params[:reseller].to_i : 0

    date_from = params[:date_from] ? params[:date_from] : session_from_datetime
    date_till = params[:date_till] ? params[:date_till] : session_till_datetime
    call_type = params[:call_type] ? params[:call_type].to_s : 'answered'


    session[:usertype] == "accountant" ? user_type = "admin" : user_type = session[:usertype]
    filename = @user.user_calls_to_csv({:tz => current_user.time_offset, :device => @device, :direction => @direction, :call_type => call_type, :date_from => date_from, :date_till => date_till, :default_currency => session[:default_currency], :show_currency => session[:show_currency], :show_full_src => session[:show_full_src], :hgc => @hgc, :usertype => user_type, :nice_number_digits => session[:nice_number_digits], :test => params[:test].to_i, :reseller => res.to_i, :hide_finances => !can_see_finances?})
    filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
    if filename
      filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
      if params[:test].to_i != 1
        send_data(File.open(filename).read, :filename => filename)
      else
        render :text => filename
      end
    else
      flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  ############ PDF ###############

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def call_list_to_pdf
    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @sel_device_id = 0
    @sel_device_id = params[:device].to_i if params[:device]

    @device = Device.find(@sel_device_id) if @sel_device_id > 0


    @hgcs = Hangupcausecode.all
    @sel_hgc_id = 0
    @sel_hgc_id = params[:hgc].to_i if params[:hgc]

    @hgc = Hangupcausecode.where(:id => @sel_hgc_id).first if @sel_hgc_id > 0

    date_from = params[:date_from]
    date_till = params[:date_till]
    call_type = params[:call_type]
    user = @user

    calls = user.calls(call_type, date_from, date_till, @direction, "calldate", "DESC", @device, {:hgc => @hgc})


    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    pdf.text(_('CDR_Records') + ": #{user.first_name} #{user.last_name}", {:left => 40, :size => 16})
    pdf.text(_('Period') + ": " + date_from + "  -  " + date_till, {:left => 40, :size => 10})
    pdf.text(_('Currency') + ": #{session[:show_currency]}", {:left => 40, :size => 8})
    pdf.text(_('Total_calls') + ": #{calls.size}", {:left => 40, :size => 8})

    total_price = 0
    total_billsec = 0
    total_prov_price = 0
    total_prfit = 0
    total_did_provider = 0
    total_did_inc = 0
    total_did_own = 0
    total_did_prof = 0

    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    items = []
    for call in calls
      item = []
      @rate_cur3 = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d]})
      @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.provider_price.to_d]}) if session[:usertype] == "admin"
      if session[:usertype] == "reseller"
        if call.reseller_id == 0
          # selfcost for reseller himself is user price, so profit always = 0 for his own calls
          @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d]})
        else
          @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.reseller_price.to_d]})
        end
      end

      @rate_did_pr = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_prov_price.to_d]})
      @rate_did_ic = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_inc_price.to_d]})
      @rate_did_ow = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_price.to_d]})

      item << call.calldate.strftime("%Y-%m-%d %H:%M:%S")
      item << call.src
      item << hide_dst_for_user(current_user, "pdf", call.dst.to_s)

      if @direction == "incoming"
        billsec = call.did_billsec
      else
        billsec = call.nice_billsec
      end

      item << nice_time(billsec)
      item << call.disposition

      if session[:usertype] == "admin"
        if @direction == "incoming"
          item << nice_number(@rate_did_pr)
          item << nice_number(@rate_did_ic)
          item << nice_number(@rate_did_ow)
          item << nice_number(@rate_did_pr + @rate_did_ic + @rate_did_ow)
          item << nice_number(@rate_did_pr + @rate_did_ow)
        else
          item << nice_number(@rate_cur3)
          item << nice_number(@rate_prov)
          item << nice_number(@rate_cur3.to_d - @rate_prov.to_d)
          item << nice_number(@rate_cur3.to_d != 0.to_d ? ((@rate_cur3.to_d - @rate_prov.to_d)/ @rate_cur3.to_d) *100 : 0) + " %"
          item << nice_number(@rate_prov.to_d != 0.to_d ? ((@rate_cur3.to_d / @rate_prov.to_d) *100)-100 : 0) + " %"
        end
      end

      if session[:usertype] == "reseller"
        if @direction == "incoming"
          item << nice_number(@rate_did_ow)
        else
          item << nice_number(@rate_cur3)
          item << nice_number(@rate_prov)
          item << nice_number(@rate_cur3.to_d - @rate_prov.to_d)
          item << nice_number(@rate_cur3.to_d != 0.to_d ? ((@rate_cur3.to_d - @rate_prov.to_d)/ @rate_cur3.to_d) *100 : 0) + " %"
          item << nice_number(@rate_prov.to_d != 0.to_d ? ((@rate_cur3.to_d / @rate_prov.to_d) *100)-100 : 0) + " %"
        end
      end

      if session[:usertype] == "user" or session[:usertype] == "accountant"
        if @direction != "incoming"
          item << nice_number(@rate_cur3)
        else
          item << nice_number(@rate_did_ow)
        end
      end


      if @direction == "incoming"
        total_price += @rate_did_ow
      else
        total_price += @rate_cur3 if call.user_price
      end
      #total_price += @rate_cur3 if call.user_price
      total_prov_price += @rate_prov.to_d
      total_prfit += @rate_cur3.to_d - @rate_prov.to_d
      total_billsec += call.nice_billsec
      total_did_provider += @rate_did_pr
      total_did_inc += @rate_did_ic
      total_did_own += @rate_did_ow
      total_did_prof += @rate_did_pr.to_d + @rate_did_ic.to_d + @rate_did_ow.to_d

      items << item
    end
    item = []
    #Totals
    item << {:text => _('Total'), :colspan => 3}
    item << nice_time(total_billsec)
    item << ' '
    if session[:usertype] == "admin" or session[:usertype] == "reseller"
      if @direction == "incoming"
        item << nice_number(total_did_provider)
        item << nice_number(total_did_inc)
        item << nice_number(total_did_own)
        item << nice_number(total_did_prof)
      else
        item << nice_number(total_price)
        item << nice_number(total_prov_price)
        item << nice_number(total_prfit)
        if total_price.to_d != 0
          item << nice_number(total_price.to_d != 0.to_d ? (total_prfit / total_price.to_d) * 100 : 0) + " %"
        else
          item << nice_number(0) + " %"
        end
        if total_prov_price.to_d != 0
          item << nice_number(total_prov_price.to_d != 0 ? ((total_price.to_d / total_prov_price.to_d) *100)-100 : 0) + " %"
        else
          item << nice_number(0) + " %"
        end
      end
    else
      if @direction != "incoming"
        item << nice_number(total_price)
      end
    end

    items << item

    headers, h = PdfGen::Generate.call_list_to_pdf_header(pdf, @direction, session[:usertype], 0, {})

    pdf.table(items,
              :width => 550, :border_width => 0,
              :font_size => 7,
              :headers => headers) do
    end

    string = "<page>/<total>"
    opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
    pdf.number_pages string, opt

    send_data pdf.render, :filename => "Calls_#{user.first_name}_#{user.last_name}_#{date_from}-#{date_till}.pdf", :type => "application/pdf"
  end

  def users_finances
    default = {:page => "1", :s_completed => '', :s_username => "", :s_fname => "", :s_lname => "", :s_balance_min => "", :s_balance_max => "", :s_type => ""}
    @page_title = _('Users_finances')
    @page_icon = "money.png"

    @options = ((params[:clear] || !session[:users_finances_options]) ? default : session[:users_finances_options])
    default.each { |key, value| @options[key] = params[key] if params[key] }

    owner_id = (session[:usertype] == "accountant" ? 0 : session[:user_id])
    cond = ['users.hidden = ?', 'users.owner_id = ?']
    var = [0, owner_id]

    if ['postpaid', 'prepaid'].include?(@options[:s_type])
      cond << 'users.postpaid = ?'
      var << (@options[:s_type] == "postpaid" ? 1 : 0)
    end
    add_contition_and_param(@options[:s_username], @options[:s_username] + '%', "users.username LIKE ?", cond, var)
    add_contition_and_param(@options[:s_fname], @options[:s_fname] + '%', "users.first_name LIKE  ?", cond, var)
    add_contition_and_param(@options[:s_lname], @options[:s_lname] + '%', "users.last_name LIKE ?", cond, var)
    add_contition_and_param(@options[:s_balance_min], @options[:s_balance_min].to_d, "users.balance >= ?", cond, var)
    add_contition_and_param(@options[:s_balance_max], @options[:s_balance_max].to_d, "users.balance <= ?", cond, var)
    @total_users = User.count(:all, :conditions => [cond.join(' AND ').to_s] + var).to_i

    items_per_page, total_pages = item_pages(@total_users)
    page_no = valid_page_number(@options[:page], total_pages)
    offset, limit = query_limit(total_pages, items_per_page, page_no)

    @total_pages = total_pages
    @options[:page] = page_no

    @users = User.find(:all,
                       :conditions => [cond.join(' AND ').to_s] + var,
                       :limit => limit,
                       :offset => offset)

    cond.size.to_i > 2 ? @search = 1 : @search = 0
    @total_balance = @total_credit = @total_payments = @total_amount =0
    @amounts = []
    @payment_size = []
    hide_uncompleted_payment = Confline.get_value("Hide_non_completed_payments_for_user", current_user.id).to_i

    @users.each_with_index { |user, i|

      payments = user.payments
      amount = 0
      pz = 0
      payments.each { |p|
        if hide_uncompleted_payment == 0 or (hide_uncompleted_payment == 1 and (p.pending_reason != 'Unnotified payment' or p.pending_reason.blank?))
          if p.completed.to_i == @options[:s_completed].to_i or @options[:s_completed].blank?
            pz += 1
            pa = p.payment_amount
            amount += get_price_exchange(pa, p.currency)
          end
        end
      }
      @amounts[user.id] = amount
      @payment_size[user.id] = pz
      @total_balance += user.balance
      @total_credit += user.credit if user.credit != (-1) and user.postpaid.to_i != 0
      @total_payments += pz
      @total_amount += amount
    }
    session[:users_finances_options] = @options
  end


  def providers
    change_date
    @Show_Currency_Selector=1

    @page_title = _('Providers_stats')
    @s_prefix = params[:search].to_s.strip
    unless  @s_prefix.blank?
      @dest = Destination.find(
          :first,
          :conditions => "prefix LIKE '#{@s_prefix}'",
          :order => "LENGTH(destinations.prefix) DESC"
      )
      @flag = nil
      if @dest == nil
        @results = ""
      else
        @flag = @dest.direction_code
        direction = @dest.direction
        @results = @dest.subcode.to_s+" "+@dest.name.to_s
        @results = direction.name.to_s+" "+ @results if direction
      end
    end

    @providers = Provider.find_all_with_calls_for_stats(current_user, {:date_from => session_from_datetime, :date_till => session_till_datetime, :s_prefix => @s_prefix, :show_currency => session[:show_currency], :default_currency => session[:default_currency]})
  end

  def providers_stats

    @page_title = _('Providers_stats')
    @page_icon = "chart_pie.png"

    p = Provider.where(:id => params[:id].to_s).first

    if !p
      flash[:notice] = _("Provider_not_found")
      redirect_to :controller => "callc", :action => 'main' and return false
    end

    change_date

    @s_prefix = ""
    @s_prefix = params[:search] if params[:search]
    cond =""

    if  @s_prefix.to_s != ""
      cond += " AND calls.prefix = '#{@s_prefix}' "
      @dest = Destination.find(
          :first,
          :conditions => "prefix = SUBSTRING('#{@s_prefix}', 1, LENGTH(destinations.prefix))",
          :order => "LENGTH(destinations.prefix) DESC"
      )
      @flag = nil
      if @dest == nil
        @results = ""
      else
        @flag = @dest.direction_code
        direction = @dest.direction
        @results = @dest.subcode.to_s+" "+@dest.name.to_s
        @results = direction.name.to_s+" "+ @results if direction
      end
    end

    @provider = Provider.find_all_with_calls_for_stats(current_user, {:date_from => session_from_datetime, :date_till => session_till_datetime, :s_prefix => @s_prefix, :p_id => params[:id]})[0]
    if @provider
      @asr_calls = nice_number((@provider.answered.to_d / @provider.pcalls.to_d) * 100)
      @no_answer_calls_pr = nice_number((@provider.no_answer.to_d / @provider.pcalls.to_d) * 100)
      @busy_calls_pr = nice_number((@provider.busy.to_d / @provider.pcalls.to_d) * 100)
      @failed_calls_pr = nice_number((@provider.failed.to_d / @provider.pcalls.to_d) * 100)

      @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])

      year, month, day = last_day_month('till')
      @edate = Time.mktime(year, month, day)

      @a_date = []
      @a_calls = []
      @a_billsec = []
      @a_avg_billsec = []
      @a_calls2 = []
      @a_ars = []
      @a_ars2 = []

      @_billsec2=[]
      @a_user_price2 = []
      @a_provider_price2 = []

      @t_calls = 0
      @t_billsec = 0
      @t_avg_billsec = 0
      @t_normative = 0
      @t_norm_days = 0
      @t_avg_normative = 0

      i = 0
      cond += current_user.is_reseller? ? " AND (calls.reseller_id = #{current_user.id} OR calls.user_id = #{current_user.id} )" : ''
      s = []
      if current_user.is_admin?
        s << "SUM(provider_price) as 'selfcost_price'"
        s << "SUM(IF(reseller_id > 0, reseller_price, user_price)) AS 'sel_price'"
        s << "SUM(IF(reseller_id > 0, reseller_price, user_price) - provider_price ) AS 'profit'"
      else
        s << "SUM(IF(providers.common_use = 1, reseller_price,provider_price)) as 'selfcost_price'"
        s << "SUM(user_price) AS 'sel_price'"
        s << "SUM(user_price - IF(providers.common_use = 1, reseller_price,provider_price)) AS 'profit'"
      end

      while @sdate < @edate
        @a_date[i] = @sdate.strftime("%Y-%m-%d")

        @a_calls[i] = 0
        @a_billsec[i] = 0
        @a_calls2[i] = 0
        @a_user_price =0
        @a_provider_price=0
        @a_user_price2[i] =0
        @a_provider_price2[i]=0
        @_billsec2[i]=0

        sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as \'billsec\' FROM calls WHERE ((calls.provider_id = '#{params[:id].to_i}' and calls.callertype = 'Local') OR (calls.did_provider_id = '#{params[:id].to_i}' and calls.callertype = 'Outside'))" +
            "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'" +
            "AND disposition = 'ANSWERED' #{cond}"
        res = ActiveRecord::Base.connection.select_all(sql)
        @a_calls[i] = res[0]["calls"].to_i
        @a_billsec[i] = res[0]["billsec"].to_i

        if @a_billsec[i] != 0

          @a_profit=0
          @a_user_price=0
          @a_user_price2[i]=0
          @a_provider_price=0
          @a_provider_price2[i]=0

          @calls3 = Call.find(:all,
                              :select => s.join(' , '),
                              :joins => "LEFT JOIN providers ON (providers.id = calls.provider_id)",
                              :conditions => ["((calls.provider_id = ? and calls.callertype = 'Local') OR (calls.did_provider_id = ? and calls.callertype = 'Outside')) AND disposition = 'ANSWERED' AND calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59' #{cond}", params[:id], params[:id]],
                              :group => "calls.provider_id",
                              :order => "calldate DESC")
          @a_user_price2[i]= nice_number @calls3[0].sel_price
          @a_provider_price2[i]= nice_number @calls3[0].selfcost_price
        end

        @a_avg_billsec[i] = 0
        @a_avg_billsec[i] = @a_billsec[i] / @a_calls[i] if @a_calls[i] > 0


        @t_calls += @a_calls[i]
        @t_billsec += @a_billsec[i]

        sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM calls WHERE ((calls.provider_id = '#{params[:id].to_i}' and calls.callertype = 'Local') OR (calls.did_provider_id = '#{params[:id].to_i}' and calls.callertype = 'Outside'))" +
            "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59' #{cond}"
        res2 = ActiveRecord::Base.connection.select_all(sqll)
        @a_calls2[i] = res2[0]["calls2"].to_i

        @a_ars2[i] = (@a_calls[i].to_d / @a_calls2[i]) * 100 if @a_calls[i] > 0
        @a_ars[i] = nice_number @a_ars2[i]

        @sdate += (60 * 60 * 24)
        i+=1
      end

      index = i

      @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0


      #===== Graph =====================

      @Calls_graph = "\""
      if @provider.pcalls.to_i > 0

        @Calls_graph += _('ANSWERED') +";" +@provider.answered.to_s + ";" + "false" + "\\n"
        @Calls_graph += _('NO_ANSWER') +";" +@provider.no_answer.to_s + ";" + "false" + "\\n"
        @Calls_graph += _('BUSY') +";" +@provider.busy.to_s+ ";" + "false" + "\\n"
        @Calls_graph += _('FAILED') +";" +@provider.failed.to_s + ";" + "false" + "\\n"

        @Calls_graph += "\""
      else
        @Calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
      end


      #formating graph for Avg.Calltime

      ine=0
      @Avg_Calltime_graph =""
      while ine <= index - 1
        @Avg_Calltime_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_avg_billsec[ine].to_s + "\\n"
        ine=ine +1
      end

      #formating graph for Asr calls

      ine=0
      @Asr_graph =""
      while ine <= index - 1
        @Asr_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_ars[ine].to_s + "\\n"
        ine=ine +1
      end

      #formating graph for Profit calls
      ine=0
      @Profit_graph =""
      while ine <= index - 1
        @Profit_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_user_price2[ine].to_s + ";"+@a_provider_price2[ine].to_s + "\\n"
        ine=ine +1
      end
    end
  end


  def hangup_calls

    @page_title = _('Hang_up_cause_codes_calls')
    @page_icon = "call.png"

    change_date

    cond=""
    des = ''
    descond=''
    @prov =-1
    @coun = -1
    @direction = -1
    @s_provider = -1

    @user_id = -1
    @user_id = params[:s_user].to_i if params[:s_user]

    if @user_id.to_i != -1
      cond+= "calls.user_id = #{@user_id} AND "
      @user = User.where(:id => @user_id).first
    else
      @user = nil
    end

    @device_id = -1
    @device_id = params[:s_device].to_i if params[:s_device]

    if @device_id.to_i != -1
      @device_id = params[:s_device].to_i
      cond+= " (calls.src_device_id = #{@device_id} OR calls.dst_device_id = #{@device_id}) AND "
    end

    if params[:provider_id]
      if params[:provider_id].to_i != -1
        @provider = Provider.find(params[:provider_id])
        cond +=" ((calls.provider_id = '#{params[:provider_id].to_i}' and calls.callertype = 'Local') OR (calls.did_provider_id = '#{params[:provider_id].to_i}' and calls.callertype = 'Outside')) AND "
        @prov = @provider.id
        @s_provider = @prov
      end
    end
    @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => 'name ASC')
    @users = User.find_all_for_select(corrected_user_id)


    if params[:direction]
      if params[:direction].to_i != -1
        @country = Direction.find(params[:direction])
        @coun = @country.id
        @direction = @coun
        des+= 'destinations, '
        descond +=" AND calls.prefix = destinations.prefix AND destinations.direction_code ='#{@country.code}' "
      end
    end
    @countries = Direction.order("name ASC").all

    if params[:hid] == nil and !session[:hangup_call]
      flash[:notice] = _('Hangupcausecode_not_found')
      redirect_to :action => :hangup_cause_codes_stats and return false
    end

    if params[:hid] != nil
      @hangup = Hangupcausecode.where(:id => params[:hid].to_i).first
    else
      @hangup = Hangupcausecode.where(:id => session[:hangup_call].to_i).first
    end

    unless @hangup
      flash[:notice] = _('Hangupcausecode_not_found')
      redirect_to :action => :hangup_cause_codes_stats and return false
    end
    @total_duration = 0
    @page = 1
    @page = params[:page].to_i if params[:page]

    sql ="SELECT calls.*  FROM  #{des} calls
    WHERE #{cond} calls.calldate BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:23:59' #{descond}
    AND calls.hangupcause = '#{(@hangup.code).to_s}' ORDER BY calldate DESC"

    @calls = Call.find_by_sql(sql)
    @size = @calls.size.to_i
    session[:hangup_call]= @hangup.id

    @total_pages = (@calls.size.to_d / session[:items_per_page].to_d).ceil

    @all_calls = @calls
    @calls = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_calls.size - 1 if iend > (@all_calls.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @calls << @all_calls[i]
    end

    for call in @calls
      @total_duration += call.duration.to_i
    end
  end

  def hangup_calls_to_csv

    cond=""
    des = ''
    descond=''

    if params[:provider_id].to_i != -1
      cond +=" ((calls.provider_id = '#{params[:provider_id].to_i}' and calls.callertype = 'Local') OR (calls.did_provider_id = '#{params[:provider_id].to_i}' and calls.callertype = 'Outside')) AND "
    end
    @user_id = -1
    @user_id = params[:s_user].to_i if params[:s_user]

    if @user_id.to_i != -1
      cond+= "calls.user_id = #{@user_id} AND "
      @user = User.where(:id => @user_id).first
    else
      @user = nil
    end

    @device_id = -1
    @device_id = params[:device_id].to_i if params[:device_id]

    if @device_id.to_i != -1
      @device_id = params[:device_id].to_i
      cond+= " (calls.src_device_id = #{@device_id} OR calls.dst_device_id = #{@device_id}) AND "
    end

    if params[:direction]
      if params[:direction].to_i != -1
        @country = Direction.where(:id => params[:direction]).first
        @coun = @country.id
        @direction = @coun
        des+= 'destinations, '
        descond +=" AND calls.prefix = destinations.prefix AND destinations.direction_code ='#{@country.code}' "
      end
    end

    sql ="SELECT calls.*, directions.name as dname, destinations.name, destinations.subcode FROM  #{des} calls
    left join destinations on (destinations.prefix = calls.prefix)
    left Join directions on (destinations.direction_code = directions.code)
    WHERE #{cond} calls.calldate BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:23:59' #{descond}
    AND calls.hangupcause = '#{(params[:code]).to_s}' ORDER BY calldate DESC"
    # MorLog.my_debug sql
    sep = Confline.get_value("CSV_Separator", 0).to_s
    dec = Confline.get_value("CSV_Decimal", 0).to_s

    csv_string = "#{_('date')}#{sep}#{ _('called_from')}#{sep}#{_('called_to')}#{sep}#{_('Destination')}#{sep}#{_('User')}#{sep}#{_('duration')}#{sep}#{_('hangup_cause')}%#{sep}#{_('Provider')}\n"

    #@total_duration = 0.to_i
    @calls = Call.find_by_sql(sql)
    for call in @calls
      dname=""
      name=""
      subcode =""
      pname=""
      n_user=""
      if call.dname
        dname =call.dname
      end
      if call.subcode
        subcode =call.subcode
      end
      if call.name
        name=call.name
      end
      if call.provider
        pname = call.provider.name
      end
      if call.user
        n_user = nice_user call.user
      end
      csv_string += "#{nice_date_time(call.calldate)}#{sep}#{call.clid}#{sep}#{call.localized_dst}#{sep}#{dname.to_s + " "+subcode.to_s + " "+name.to_s}#{sep}#{n_user}#{sep}#{nice_time call.duration}#{sep}#{call.disposition}#{sep}#{pname.to_s}\n"
      #  @total_duration += call.duration.to_i
    end
    #csv_string += "#{_('Total')}#{sep}#{sep}#{sep}#{sep}#{sep}#{@total_duration.to_s.gsub(".", dec).to_s}#{sep}#{sep}\n"

    filename = "Hangup-#{params[:code]}--#{session_from_date}_00:00:00--#{session_till_date}_00:00:00.csv"
    if params[:test].to_i == 1
      render :text => csv_string
    else
      send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
    end
  end

  def max_hangup(max, max1)
    @max2 = max1
    for r in @res
      if  r != nil
        if    r['calls'] != nil
          if  r['calls'].to_i < max.to_i and r["calls"].to_i > @max2.to_i
            if r['calls'] != max
              @max2 = r['calls'].to_i
              @code = r["code"]
            end
          end
        end
      end

    end
  end


  def loss_making_calls
    @page_title = _('Loss_making_calls')
    @page_icon = "money_delete.png"

    change_date

    condition = ""
    if params[:reseller_id]
      if params[:reseller_id].to_i != -1
        @reseller = User.find(:first, :conditions => ["id = ?", params[:reseller_id]])
        condition =" AND calls.reseller_id = '#{@reseller.id}' "
        @reseller_id = @reseller.id
      else
        condition = ""
      end
    end
    @resellers = User.find(:all, :conditions => 'usertype = "reseller"', :order => 'first_name ASC')

    @calls = Call.find(:all, :include => [:user, :provider, :device], :conditions => "provider_price > user_price AND calldate BETWEEN \'" + session_from_date + " 00:00:00\' AND \'" + session_till_date + " 23:59:59\' AND disposition = \'ANSWERED\'"+ condition, :order => "calldate DESC")

    @total_calls = Call.find(:all,
                             :select => 'COUNT(*), SUM(IF((billsec IS NULL OR billsec = 0), IF(real_billsec IS NULL, 0, real_billsec), billsec)) AS total_duration, SUM(provider_price-user_price) AS total_loss',
                             :conditions => 'provider_price > user_price AND calldate BETWEEN \'' + session_from_date + ' 00:00:00\' AND \'' + session_till_date + ' 23:59:59\' AND disposition = \'ANSWERED\''+ condition)
  end

  def get_rs_user_map
    @responsible_accountant_id = params[:responsible_accountant_id] ? params[:responsible_accountant_id].to_i : -1
    @responsible_accountant_id.to_s != "-1" ? cond = ['responsible_accountant_id = ?', @responsible_accountant_id] : ""
    output = []
    output << "<option value='-1'>All</option>"
    output << User.where(cond).map { |u| ["<option value='"+u.id.to_s+"'>"+nice_user(u)+"</option>"] }
    render :text => output.join 
  end

  def profit
    @page_title = _('Profit')
    @page_icon = "money.png"
    change_date
    @sub_vat = 0
    @sub_price = 0
    @did_owner_cost = 0
    owner = correct_owner_id
    @users = User.find_all_for_select(corrected_user_id)

    if current_user.is_admin? 
      @responsible_accountants = User.find(:all, :select => 'accountants.*', :joins => ['JOIN users accountants ON(accountants.id = users.responsible_accountant_id)'], :conditions => "accountants.hidden = 0 and accountants.usertype = 'accountant'", :group => 'accountants.id', :order => 'accountants.username')
    end
    up, rp, pp = current_user.get_price_calculation_sqls
    params[:user_id] ? @user_id = params[:user_id].to_i : @user_id = -1
    @responsible_accountant_id = params[:responsible_accountant_id] ? params[:responsible_accountant_id].to_i : -1

    conditions = []
    cond_did_owner_cost = []
    user_sql2 = ""
    if session[:usertype] == "reseller"
      conditions << "calls.reseller_id = #{session[:user_id].to_i}"
      if params[:user_id] and params[:user_id] != "-1"
        conditions << "calls.user_id = '#{params[:user_id].to_i}'"
        #user_sql2 = " AND subscriptions.user_id = '#{@user_id}' "
      end
      cond_did_owner_cost << conditions
    else
      if params[:user_id] and params[:user_id] != "-1"

        conditions << "calls.user_id IN (SELECT id FROM users WHERE id = '#{params[:user_id].to_i}' OR owner_id = #{params[:user_id].to_i})"
        cond_did_owner_cost << "calls.dst_user_id IN (SELECT id FROM users WHERE id = '#{params[:user_id].to_i}' OR owner_id = #{params[:user_id].to_i})"
        user_sql2 = " AND subscriptions.user_id = '#{@user_id}' "
      elsif params[:responsible_accountant_id] and params[:responsible_accountant_id] != "-1"
        conditions << "calls.user_id IN (SELECT id FROM users WHERE id IN (SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) WHERE tmp.id = '#{@responsible_accountant_id}') OR owner_id IN (SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) WHERE tmp.id = '#{@responsible_accountant_id}'))"
        cond_did_owner_cost << "calls.dst_user_id IN (SELECT id FROM users WHERE id IN (SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) WHERE tmp.id = '#{@responsible_accountant_id}') OR owner_id IN (SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) WHERE tmp.id = '#{@responsible_accountant_id}'))"
        user_sql2 = " AND subscriptions.user_id IN (SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) WHERE tmp.id = '#{@responsible_accountant_id}')"
      end
    end

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    conditions << "calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
    cond_did_owner_cost << "calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
    select = ["SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'billsec'"]
    select += [SqlExport.replace_price("SUM(#{up})", {:reference => 'user_price'}), SqlExport.replace_price("SUM(#{pp})", {:reference => 'provider_price'})]
    if session[:usertype] == "reseller"
      conditions << "calls.reseller_id = #{session[:user_id].to_i}"
      cond_did_owner_cost << "calls.reseller_id = #{session[:user_id].to_i}"
    end
    total = Call.find(:all, :select => select.join(", "), :joins => "LEFT JOIN users ON (users.id = calls.user_id) #{ SqlExport.left_join_reseler_providers_to_calls_sql}", :conditions => (conditions +["disposition = 'ANSWERED'"]).join(" AND "))[0]
    @total_duration = (total["billsec"]).to_i
    @total_call_price = (total["user_price"]).to_d
    @total_call_selfprice = (total["provider_price"]).to_d
    select_total = ["COUNT(*) AS 'total_calls'"]
    select_total << "SUM(IF(calls.disposition = 'ANSWERED', 1, 0)) AS 'answered_calls'"
    select_total << "SUM(IF(calls.disposition = 'BUSY', 1, 0)) AS 'busy_calls'"
    select_total << "SUM(IF(calls.disposition = 'NO ANSWER', 1, 0)) AS 'no_answer_calls'"
    select_total << "SUM(IF(calls.disposition = 'FAILED', 1, 0)) AS 'failed_calls'"
    total = Call.find(:all, :select => select_total.join(", "), :conditions => conditions.join(" AND "), :joins => SqlExport.left_join_reseler_providers_to_calls_sql)
    if total and total[0] and total[0]["total_calls"].to_i != 0
      @total_calls = total[0]["total_calls"].to_i
      @total_answered_calls = total[0]["answered_calls"].to_i
      @total_not_ans_calls = total[0]["no_answer_calls"].to_i
      @total_busy_calls = total[0]["busy_calls"].to_i
      @total_error_calls = total[0]["failed_calls"].to_i
      if @total_calls != 0
        @total_answer_percent = @total_answered_calls.to_d * 100 / @total_calls.to_d
        @average_call_duration = @total_duration.to_d / @total_answered_calls.to_d
        @total_not_ans_percent = @total_not_ans_calls.to_d * 100 / @total_calls.to_d
        @total_busy_percent = @total_busy_calls.to_d * 100 / @total_calls.to_d
        @total_error_percent = @total_error_calls.to_d * 100 / @total_calls.to_d
      else
        @total_answer_percent = 0
        @average_call_duration = 0
        @total_not_ans_percent = 0
        @total_busy_percent = 0
        @total_error_percent = 0
      end
    else
      @total_calls = @total_answered_calls = 0
      @total_answer_percent = @total_not_ans_percent = @total_busy_percent = @total_error_percent = 0
      @average_call_duration = @total_not_ans_calls = @total_busy_calls = @total_error_calls = 0
    end
    @total_profit = @total_call_price - @total_call_selfprice

    if @total_call_price != 0 && @total_answered_calls != 0
      select = [""]
      res = Call.find(:all,
                      :select => "#{SqlExport.replace_price("SUM(#{up})", {:reference => 'price'})}, SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'duration', COUNT(DISTINCT(calls.user_id)) AS 'users', SUM(did_price) AS did_price",
                      :joins => "LEFT JOIN users ON (users.id = calls.user_id) #{ SqlExport.left_join_reseler_providers_to_calls_sql}",
                      :conditions => (conditions + ["calls.disposition = 'ANSWERED'"]).join(" AND "))
      if session[:usertype] != "reseller"
        @did_owner_cost = Call.find(:first,
                      :select => "SUM(did_price) AS did_price",
                      :joins => "LEFT JOIN users ON (users.id = calls.user_id) #{ SqlExport.left_join_reseler_providers_to_calls_sql}",
                      :conditions => (cond_did_owner_cost + ["calls.disposition = 'ANSWERED'"]).join(" AND ")).did_price
      end

      resu = Call.find(:all,
                       :select => "COUNT(DISTINCT(calls.user_id)) AS 'users'",
                       :joins => "LEFT JOIN users ON (users.id = calls.user_id) #{ SqlExport.left_join_reseler_providers_to_calls_sql}",
                       :conditions => (conditions + ["calls.disposition = 'ANSWERED' and card_id < 1"]).join(" AND "))
      @total_users = resu[0]["users"].to_i if resu and resu[0]

      @total_percent = 100
      @total_profit_percent = @total_profit.to_d * 100 / @total_call_price.to_d
      @total_selfcost_percent = @total_percent - @total_profit_percent
      #average
      @total_duration_min = @total_duration.to_d / 60
      @avg_profit_call_min = @total_profit.to_d / @total_duration_min
      @avg_profit_call = @total_profit.to_d / @total_answered_calls.to_d
      days = (session_till_date.to_date - session_from_date.to_date).to_d
      days = 1.0 if days == 0;
      @avg_profit_day = @total_profit.to_d / (session_till_date.to_date - session_from_datetime.to_date + 1).to_i
      @total_users != 0 ? @avg_profit_user = @total_profit.to_d / @total_users.to_d : @avg_profit_user = 0
    else
      #profit
      @total_percent = 0
      @total_profit_percent = 0
      @total_selfcost_percent = 0
      #avg
      @avg_profit_call_min = 0
      @avg_profit_call = 0
      @avg_profit_day = 0
      @avg_profit_user = 0
    end
    a1 = session_from_datetime
    a2 = session_till_datetime
    @sub_price_vat =0

    if session[:usertype] != "reseller"
      price =0
      sql = "SELECT users.id, subscriptions.*, Count(calls.id) as calls_size, services.servicetype, services.periodtype, services.quantity, #{SqlExport.replace_price('(services.price - services.selfcost_price)', {:reference => 'price'})} FROM subscriptions
      left join calls on (calls.user_id = subscriptions.user_id)
      join services on (services.id = subscriptions.service_id)
      join users on (users.id = subscriptions.user_id)
      WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end >'#{a2}') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) #{user_sql2} group by subscriptions.id"
      res = ActiveRecord::Base.connection.select_all(sql)
    else
      res = []
    end

    if res and res.size > 0

      for r in res

        sub_days = r['activation_end'].to_time - r['activation_start'].to_time
        sub_days = (((sub_days / 60) / 60) / 24)

        @date = r['activation_start']

        if  @date.to_date > a1.to_date and r['activation_end'].to_date < a2.to_date
          price = 0
          if r['periodtype'].to_s == 'day'
            quantity = sub_days / r['quantity'].to_d
            days = sub_days % r['quantity'].to_d

            if r['servicetype'].to_s == "activation_from_registration"
              price = r['price'].to_d * quantity.to_i
            end

            if r['servicetype'].to_s == "one_time_fee"
              price = r['price'].to_d
            end

            if r['servicetype'].to_s == "periodic_fee" or r['servicetype'].to_s == "flat_rate"
              price = ((r['price'].to_d / r['quantity'].to_d) * days.to_i).to_d + ((r['price'].to_d * quantity.to_d)).to_d
            end
          end
          if r['periodtype'].to_s == 'month'
            y = r['activation_end'].to_time.year - r['activation_start'].to_time.year
            m = r['activation_end'].to_time.month - r['activation_start'].to_time.month
            months = y.to_i * 12 + m.to_i
            quantity = months / r['quantity'].to_d
            days = r['activation_end'].to_time.day - r['activation_start'].to_time.day + 1

            if r['servicetype'].to_s == "activation_from_registration"
              price = r['price'].to_d * quantity.to_i
            end

            if r['servicetype'].to_s == "one_time_fee"
              price = r['price'].to_d
            end

            if r['servicetype'].to_s == "periodic_fee" or r['servicetype'].to_s == "flat_rate"
              if days < 0
                quantity = quantity -1
                days = r['activation_start'].to_time.day + days
              end
              price = ((r['price'].to_d / r['activation_end'].to_time.end_of_month().day.to_i.to_d) * days.to_i).to_d + ((r['price'].to_d * quantity.to_d)).to_d
            end
          end
          @sub_price2 = price
        else
          price = 0
          if @date.to_date <= a1.to_date
            use_start = a1.to_date
          else
            use_start = @date.to_date
          end
          if r['activation_end'].to_date >= a2.to_date
            use_end = a2.to_date
          else
            use_end = r['activation_end'].to_date
            @amount2=1
          end

          sub_days = use_end.to_time - use_start.to_time
          sub_days = (((sub_days / 60) / 60) / 24)

          if r['periodtype'].to_s == 'day'
            quantity = sub_days / r['quantity'].to_d
            days = sub_days % r['quantity'].to_d

            if r['servicetype'].to_s == "activation_from_registration"
              price = r['price'].to_d * quantity.to_i
            end

            if r['servicetype'].to_s == "one_time_fee"
              price = r['price'].to_d
            end

            if r['servicetype'].to_s == "periodic_fee" or r['servicetype'].to_s == "flat_rate"
              price = ((r['price'].to_d / r['quantity'].to_d) * days.to_i).to_d + ((r['price'].to_d * quantity.to_d)).to_d
            end
          end

          if r['periodtype'].to_s == 'month'
            # my_debug "menuo"
            y = use_end.to_time.year - use_start.to_time.year
            m = use_end.to_time.month - use_start.to_time.month
            months = y.to_i * 12 + m.to_i
            quantity = months / r['quantity'].to_d
            days = use_end.to_time.day - use_start.to_time.day + 1

            if r['servicetype'].to_s == "activation_from_registration"
              price = r['price'].to_d * quantity.to_i
            end

            if r['servicetype'].to_s == "one_time_fee"
              price = r['price'].to_d
            end

            if r['servicetype'].to_s == "periodic_fee" or r['servicetype'].to_s == "flat_rate"
              if days < 0
                quantity = quantity -1
                days = use_start.to_time.day + days
              end
              price = ((r['price'].to_d / use_end.to_time.end_of_month().day.to_i.to_d) * days.to_i).to_d + ((r['price'].to_d * quantity.to_d)).to_d
            end
          end
          # my_debug price
          @sub_price2 = price
        end
        @sub_price += @sub_price2.to_d
      end
    end
    @s_total_profit = @total_profit
    if session[:usertype] != "reseller"
      @s_total_profit += @did_owner_cost.to_d
    end
    @s_total_profit += @sub_price
  end


=begin
 Generates profit report in PDF
=end

  def generate_profit_pdf
    @user_id = -1
    user_name = ""
    if params[:user_id]
      if params[:user_id] != "-1"
        @user_id = params[:user_id]
        user = User.find_by_sql("SELECT * FROM users WHERE users.id = '#{@user_id}'")
        user_name = user[0]["username"] + " - " + user[0]["first_name"] + " " + user[0]["last_name"]
      else
        user_name = "All users"
      end
    end

    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font_families.update("arial" => {
        :bold => "#{Prawn::BASEDIR}/data/fonts/Arialb.ttf",
        :italic => "#{Prawn::BASEDIR}/data/fonts/Ariali.ttf",
        :bold_italic => "#{Prawn::BASEDIR}/data/fonts/Arialbi.ttf",
        :normal => "#{Prawn::BASEDIR}/data/fonts/Arial.ttf"})

    #pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf.text(_('PROFIT_REPORT'), {:left => 40, :size => 14, :style => :bold})
    pdf.text(_('Time_period') + ": " + session_from_date.to_s + " - " + session_till_date.to_s, {:left => 40, :size => 10, :style => :bold})
    pdf.text(_('Counting') + ": " + user_name.to_s, {:left => 40, :size => 10, :style => :bold})

    pdf.move_down 60
    pdf.stroke do
      pdf.horizontal_line 0, 550, :fill_color => '000000'
    end
    pdf.move_down 20

    items = []

    item = [_('Total_calls'), {:text => params[:total_calls], :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Answered_calls'), {:text => params[:total_answered_calls], :align => :left}, {:text => nice_number(params[:total_answer_percent]) + " %", :align => :left}, _('Duration') + ": " + nice_time(params[:total_duration]), _('Average_call_duration') + ": " + nice_time(params[:average_call_duration])]
    items << item

    item = [_('No_Answer'), {:text => params[:total_not_ans_calls], :align => :left}, {:text => nice_number(params[:total_not_ans_percent]) + " %", :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Busy_calls'), {:text => params[:total_busy_calls], :align => :left}, {:text => nice_number(params[:total_busy_percent]) + " %", :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Error_calls'), {:text => params[:total_error_calls], :align => :left}, {:text => nice_number(params[:total_error_percent]) + " %", :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    # bold
    item = [' ', {:text => _('Price'), :align => :left, :style => :bold}, {:text => _('Percent'), :align => :left, :style => :bold}, {:text => _('Call_time'), :align => :left, :style => :bold}, {:text => _('Active_users'), :align => :left, :style => :bold}]
    items << item

    item = [_('Total_call_price'), {:text => nice_number(params[:total_call_price]), :align => :left}, {:text => nice_number(params[:total_percent]), :align => :left}, {:text => nice_time(params[:total_duration]), :align => :left}, {:text => params[:active_users].to_i.to_s, :align => :left}]
    items << item

    item = [_('Total_call_self_price'), {:text => nice_number(params[:total_call_selfprice]), :align => :left}, {:text => nice_number(params[:total_selfcost_percent]), :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Calls_profit'), {:text => nice_number(params[:total_profit]), :align => :left}, {:text => nice_number(params[:total_percent_percent]), :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Average_profit_per_call_min'), {:text => nice_number(params[:avg_profit_call_min]), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_call'), {:text => nice_number(params[:avg_profit_call]), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_day'), {:text => nice_number(params[:avg_profit_day]), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_active_user'), {:text => nice_number(params[:avg_profit_user]), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    if session[:usertype] != 'reseller'
      # bold
      item = [' ', {:text => _('Price'), :align => :left, :style => :bold}, {:text => ' ', :colspan => 3}]
      items << item

      # bold  1 collumn
      item = [{:text => _('Subscriptions_profit'), :align => :left, :style => :bold}, {:text => nice_number(params[:sub_price]), :align => :left}, {:text => ' ', :colspan => 3}]
      items << item

      # bold  1 collumn
      item = [{:text => _('Total_profit'), :align => :left, :style => :bold}, {:text => nice_number(params[:s_total]), :align => :left}, {:text => ' ', :colspan => 3}]
      items << item

    end

    logger.fatal items.to_yaml
    pdf.table(items,
              :width => 550, :border_width => 0,
              :font_size => 9) do
      column(0).style(:align => :left)
      column(1).style(:align => :left)
      column(2).style(:align => :left)
      column(3).style(:align => :left)
      column(4).style(:align => :left)
    end

    pdf.move_down 20
    pdf.stroke do
      pdf.horizontal_line 0, 550, :fill_color => '000000'
    end

    send_data pdf.render, :filename => "Profit-#{user_name}-#{session_from_date.to_s}_#{session_till_date.to_s}.pdf", :type => "application/pdf"
  end

  def providers_calls

    #type checking looks a bit nasty but cant figure out how session[:stats_providers_calls]                                     
    #becomes integer although it should allways be hash                                                                          
    providers_calls = session[:stats_providers_calls]                                                                            
    session[:stats_providers_calls] = nil if (not providers_calls.kind_of?(Hash)) or (providers_calls[:direction] == 0)          

    session[:stats_providers_calls].nil? ? @options = {} : @options = session[:stats_providers_calls]
    @Show_Currency_Selector=1

    @user = current_user

    if !@provider
      flash[:notice] = _('Cannot_find_provider_with_id')+" : " + params[:id].to_s
      redirect_to :controller => "providers", :action => "list" and return false
    end

    @page_title = _('Providers_calls')
    @page_title = @page_title + ": " + @provider.name
    @page_icon = "call.png"
    change_date

    my_debug @options.to_yaml

    @options[:direction] = params[:direction] || @options[:direction] || "outgoing"
    @options[:call_type] = params[:call_type] if params[:call_type]  
    @options[:call_type] = "all" if !@options[:call_type] 
    conditions = []
    if @options[:direction] == "incoming"
      conditions << "(calls.did_provider_id = '#{@provider.id}' OR calls.src_device_id = '#{@provider.device_id}')"
    else
      conditions << "calls.provider_id = '#{@provider.id}'"
    end

    conditions << "disposition = '#{@options[:call_type]}' " if @options[:call_type] != "all"
    conditions << "calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
    #    @total_calls = Call.count(:conditions => conditions.join(" AND "))
    #    @calls = Call.find(:all, :conditions => conditions.join(" AND "), :order => "calldate DESC")

    select = []
    select << "COUNT(*) AS 'total_calls'"
    select << "SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'duration'"
    select << "SUM(IF(calls.reseller_id > 0, calls.reseller_price, calls.user_price)) as 'user_price'"
    select << "SUM(IF(calls.provider_price IS NOT NULL, calls.provider_price, 0)) as 'provider_price'"

    total_data = Call.find(:first,
                           :select => select.join(", "),
                           :conditions => conditions.join(" AND ")
    )
    @total_calls = total_data["total_calls"].to_i

    items_per_page, total_pages = item_pages(@total_calls)
    page_no = valid_page_number(params[:page], total_pages)
    offset, limit = query_limit(total_pages, items_per_page, page_no)

    @options[:total_pages] = total_pages
    @options[:page] = page_no

    @calls = Call.find(:all,
                       :conditions => conditions.join(" AND "),
                       :limit => limit,
                       :offset => offset,
                       :order => " calldate DESC"
    )
    @exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @total_duration = total_data["duration"].to_i
    @total_user_price = total_data["user_price"].to_d * @exchange_rate
    @total_provider_price = total_data["provider_price"].to_d * @exchange_rate
    @total_profit = @total_user_price - @total_provider_price


    session[:stats_providers_calls] = @options
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

  ############ PDF ###############

  def providers_calls_to_pdf
    #require "pdf/wrapper"
    if params[:id]
      provider = Provider.find(params[:id])
    end

    date_from = params[:date_from]
    date_till = params[:date_till]
    call_type = params[:call_type]
    params[:direction] ? @direction = params[:direction] : @direction = "outgoing"
    params[:call_type] ? @call_type = params[:call_type] : @call_type = "all"
    @orig_call_type = @call_type
    if @direction == "incoming"
      disposition = " (calls.did_provider_id = '#{params[:id].to_i}' OR calls.src_device_id = '#{provider.device_id}' )"
    else
      disposition = " calls.provider_id = '#{params[:id].to_i}' "
    end
    disposition += " AND disposition = '#{@call_type}' " if @call_type != "all"
    disposition += " AND calldate BETWEEN '#{date_from}' AND '#{date_till}'"
    calls = Call.find(:all, :conditions => "#{disposition}", :order => "calldate DESC")
    options = {
        :date_from => date_from,
        :date_till => date_till,
        :call_type => call_type,
        :nice_number_digits => session[:nice_number_digits],
        :currency => session[:show_currency],
        :default_currency => session[:default_currency],
        :direction => @direction
    }

    a = MorLog.my_debug("Genetare_start", true)
    pdf = PdfGen::Generate.providers_calls_to_pdf(provider, calls, options)
    b = MorLog.my_debug("Genetare_end", true)
    MorLog.my_debug("Generate_time : #{b - a}")
    send_data pdf.render, :filename => "CDR-#{provider.name}-#{date_from}_#{date_till}.pdf", :type => "application/pdf"
  end

  ############ CSV ###############

  def providers_calls_to_csv

    provider = Provider.where(:id => params[:id]).first
    unless provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    date_from = params[:date_from]
    date_till = params[:date_till]

    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @call_type = "all"
    @call_type = params[:call_type] if params[:call_type]

    @orig_call_type = @call_type

    filename = provider.provider_calls_csv({:tz => current_user.time_offset, :direction => @direction, :call_type => @call_type, :date_from => date_from, :date_till => date_till, :default_currency => session[:default_currency], :show_currency => session[:show_currency], :show_full_src => session[:show_full_src], :nice_number_digits => session[:nice_number_digits], :test => params[:test].to_i})
    filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
    if params[:test].to_i != 1
      send_data(File.open(filename).read, :filename => filename)
    else
      render :text => filename
    end
  end


  def faxes
    @page_title = _('Faxes')
    @page_icon = "printer.png"
    change_date
    if session[:usertype] == "admin"
      @users = User.find(:all, :conditions => "hidden = 0", :order => "username ASC ")
    else
      @users = User.find(:all, :conditions => ["hidden = 0 AND owner_id = ?", correct_owner_id], :order => "username ASC ")
    end

    @search = 0

    @received = []
    @corrupted = []
    @mistaken = []
    @total = []
    @size_on_hdd = []

    @t_received = 0
    @t_corrupted = 0
    @t_mistaken = 0
    @t_total = 0
    @t_size_on_hdd = 0

    i = 0
    for user in @users
      sql = "SELECT COUNT(pdffaxes.id) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND status = 'good'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @received[i] = res.to_i

      sql = "SELECT COUNT(pdffaxes.id) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND status = 'pdf_size_0'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @corrupted[i] = res.to_i

      sql = "SELECT COUNT(pdffaxes.id) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND status = 'no_tif'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @mistaken[i] = res.to_i

      @total[i] = @received[i] + @corrupted[i] + @mistaken[i]

      sql = "SELECT SUM(pdffaxes.size) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @size_on_hdd[i] = res.to_d / (1024 * 1024)

      @t_received += @received[i]
      @t_corrupted += @corrupted[i]
      @t_mistaken += @mistaken[i]
      @t_total += @total[i]
      @t_size_on_hdd += @size_on_hdd[i]


      i += 1
    end

  end


  def faxes_list
    @page_title = _('Faxes')
    @page_icon = "printer.png"
    change_date


    if session[:usertype] == "admin"
      @user = User.find(:first, :conditions => ["id = ?", params[:id].to_i])
      if params[:id].to_i >= 0 and @user == nil
        flash[:notice] = _('User_not_found')
        redirect_to :controller => "callc", :action => "main" and return false
      end
    else
      @user = User.find(session[:user_id])
    end

    @devices = @user.fax_devices

    @Fax2Email_Folder = Confline.get_value("Fax2Email_Folder", 0)
    if @Fax2Email_Folder.to_s == ""
      @Fax2Email_Folder = Web_URL + Web_Dir + "/fax2email/"
    end

    @sel_device = "all"
    @sel_device = params[:device_id] if params[:device_id]
    device_sql = ""
    device_sql = " AND device_id = '#{@sel_device}' " if @sel_device != "all"

    @fstatus = "all"
    @fstatus = params[:fstatus] if params[:fstatus]
    status_sql = ""
    status_sql = " AND status = '#{@fstatus}' " if @fstatus != "all"

    @search = 0
    @search = 1 if params[:search_on]

    sql = "SELECT pdffaxes.* FROM pdffaxes, devices WHERE pdffaxes.device_id = devices.id AND devices.user_id = #{@user.id} AND receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{status_sql} #{device_sql}"
    @faxes = Pdffax.find_by_sql(sql)


  end

  #================= ACTIVE CALLS ====================

  def active_calls_count
    user = User.new(:usertype => session[:usertype])
    user.id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @acc = Activecall.count_for_user(user)
    render(:layout => false)
  end

  def active_calls
    unless ["admin", "accountant"].include?(session[:usertype]) or session[:show_active_calls_for_users].to_i == 1 or (current_user and current_user.reseller_allow_providers_tariff?)
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :controller => :callc, :action => :main and return false
    end
    user = User.new(:usertype => session[:usertype])
    user.id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @acc = Activecall.count_for_user(user)
    @page_title = _('Active_Calls')
    @page_icon = "call.png"
    @refresh_period = session[:active_calls_refresh_interval].to_i
    active_calls_order
  end

  def active_calls_order
    sort_options = ["status", "answer_time", "duration", "src", "localized_dst", "provider_name", "server_id", "did"]
    session[:active_calls_options] ? @options = session[:active_calls_options] : @options = {:order_by => "duration", :order_desc => 1, :update => "active_calls", :controller => :stats, :action => :active_calls_order}
    @options[:order_by] = params[:order_by] if params[:order_by] and sort_options.include?(params[:order_by].to_s)
    @options[:order_desc] = params[:order_desc].to_i if params[:order_desc] and [0, 1].include?(params[:order_desc].to_i)
    session[:active_calls_options] = @options
    active_calls_show
    render(:partial => "active_calls_show") if params[:action].to_s == "active_calls_order"
  end

  def active_calls_show
    session[:active_calls_options] ? @options = session[:active_calls_options] : @options = {:order_by => "duration", :order_desc => 1, :update => "active_calls", :controller => :stats, :action => :active_calls_order}
    @time_now = Time.now

    # this code selects correct calls for admin/reseller/user
    user_sql = " "
    user_id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @user_id = user_id
    if user_id != 0
      #reseller or user
      if session[:usertype] == "reseller"
        #reseller
        user_sql = " WHERE activecalls.user_id = #{user_id} OR dst_usr.id = #{user_id} OR  activecalls.owner_id = #{user_id} OR dst_usr.owner_id = #{user_id}"
      else
        #user
        user_sql = " WHERE activecalls.user_id = #{user_id} OR dst_usr.id = #{user_id} "
      end
    end

    @show_did = current_user.active_calls_show_did?

    #@active_calls = Activecall.find(:all, :order => "id")
    sql = "
    SELECT
    activecalls.id as ac_id, activecalls.channel as channel, activecalls.prefix, activecalls.server_id as server_id,
    activecalls.answer_time as answer_time, activecalls.src as src, activecalls.localized_dst as localized_dst, activecalls.uniqueid as uniqueid,
    activecalls.lega_codec as lega_codec,activecalls.legb_codec as legb_codec,activecalls.pdd as pdd,
    #{SqlExport.replace_price('activecalls.user_rate', {:reference => 'user_rate'})}, tariffs.currency as rate_currency,
    users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, users.username as user_username, users.owner_id as user_owner_id,
    devices.id as 'device_id',devices.device_type as device_type, devices.name as device_name, devices.username as device_username, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.ani as device_ani, devices.user_id as device_user_id,
    dst.id as dst_device_id,  dst.device_type as dst_device_type, dst.name as dst_device_name, dst.username as dst_device_username, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.ani as dst_device_ani, dst.user_id as dst_device_user_id,
    dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name, dst_usr.username as dst_user_username, dst_usr.owner_id as dst_user_owner_id,
    destinations.direction_code as direction_code, directions.name as direction_name, destinations.subcode as destination_subcode, destinations.name as destination_name,
    providers.id as provider_id, providers.name as provider_name, providers.common_use, providers.user_id as 'providers_owner_id', activecalls.did_id as did_id, dids.did as did, g.direction_code as did_direction_code,
    NOW() - activecalls.answer_time AS 'duration',
    IF(activecalls.answer_time IS NULL, 0, 1 ) as 'status',
    activecalls.card_id as cc_id, cards.number as cc_number, cards.owner_id as cc_owner_id
    FROM activecalls
    LEFT JOIN providers ON (providers.id =activecalls.provider_id)
    LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
    LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
    LEFT JOIN users ON (users.id = devices.user_id)
    LEFT JOIN cards ON (cards.id = activecalls.card_id)
    LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
    LEFT JOIN tariffs ON (tariffs.id = users.tariff_id)
    LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
    LEFT JOIN directions ON (directions.code = destinations.direction_code)
    LEFT JOIN dids ON (activecalls.did_id = dids.id)
    LEFT JOIN (SELECT * FROM (SELECT dids.did, destinations.direction_code FROM  dids
                  JOIN destinations on (prefix=SUBSTRING(dids.did, 1, LENGTH(prefix)))
                  WHERE dids.id IN (SELECT did_id FROM activecalls)
                  ORDER BY LENGTH(destinations.prefix) DESC) AS v
                  GROUP BY did) AS g ON (g.did = dids.did)
    #{user_sql}
    ORDER BY #{@options[:order_by]} #{@options[:order_desc] == 1 ? "DESC" : "ASC"}
    "

    if user_id.to_s.blank?
      @active_calls = []
    else
      @active_calls = ActiveRecord::Base.connection.select_all(sql)
    end

    @chanspy_disabled = Confline.chanspy_disabled?

    @spy_device = Device.find(:first, :conditions => "id = #{current_user.spy_device_id}")

    #    sql2 = "SELECT activecalls.id, activecalls.server_id as server_id, activecalls.provider_id as provider_id, activecalls.user_id as user_id  FROM activecalls
    #    WHERE start_time < '#{nice_date_time(Time.now() - 7200)}'"
=begin
    sql2 = "SELECT activecalls.id, activecalls.server_id as server_id, activecalls.provider_id as provider_id, activecalls.user_id as user_id  FROM activecalls
    WHERE start_time < '#{Time.now() - 7200}'"


    calls = ActiveRecord::Base.connection.select_all(sql2)

    if calls
      MorLog.my_debug(sql2)
      sql3 = "DELETE activecalls.* FROM activecalls WHERE start_time < '#{nice_date_time(Time.now() - 7200)}'"
      ActiveRecord::Base.connection.delete(sql3)
      bt = Thread.new {active_calls_longer_error(calls)}
      #bt.join << kam kurt threada jei jo pabaigos yra laukiama ir nieko nedaroma laukimo metu?
    end
=end

    session[:active_calls_options] = @options
    render(:partial => "active_calls_show") if params[:action].to_s == "active_calls_show"
  end

=begin

SELECT activecalls.start_time as start_time, activecalls.src as src, activecalls.dst as dst, users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, devices.device_type as device_type, devices.name as device_name, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.ani as device_ani, dst.id as dst_id, dst.device_type as dst_device_type, dst.name as dst_device_name, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.ani as dst_device_ani, dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name
FROM activecalls
LEFT JOIN providers ON (providers.id =activecalls.provider_id)
LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
LEFT JOIN users ON (users.id = devices.user_id)
LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
LEFT JOIN directions ON (directions.code = destinations.direction_code)

=end

  #================= MISSED CALLS ====================

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def missed_calls

    change_date

    #my_debug params[:processed]

    #changing the state of call processed field
    if params[:processed]
      call = Call.find(params[:processed])
      if call.processed == 0
        call.processed = 1
      else
        call.processed = 0
      end
      call.save
    end

    @page_title = _('Missed_calls')
    @page_icon = "call.png"

    #count missed calls
    @all_calls = @calls = @user.calls("missed_not_processed_plus_inc", session_from_datetime, session_till_datetime)
    params[:search_on] ? @search = 1 : @search = 0
  end

  #=================== DIDs ===============================
  def dids
    @page_title = _('DIDs')
    @page_icon = "did.png"
    change_date

    change_date_to_present if params[:clear]

    @users = User.find_all_for_select(corrected_user_id)
    @providers = Provider.find(:all, :order => "name ASC", :conditions => ['hidden=?', 0])

    #@user_id2 = -1
    (params[:user_id]) ? (@user_id = params[:user_id].to_i) : (@user_id = -1)
    user_sql = ""
    #my_debug @user_id2
    @provider_id = -1
    provider_sql = ""

    #  my_debug params[:user_id].to_i
    if session[:usertype] == "admin"
      if params[:user_id]
        if params[:user_id].to_i != -1
          #@user_id2 = params[:user_id].to_i
          user_sql = " AND dids.user_id = '#{@user_id}' "
        end
      end
      if params[:user_id]
        if params[:provider_id].to_i != -1
          @provider_id = params[:provider_id]
          provider_sql = " AND dids.provider_id = '#{@provider_id}' "
        end
      end
    end

    #if params[:direction]
    #if params[:direction].to_s == "outgoing"
    # dir = "Local"
    #else
    dir = "Outside"
    #end
    #@direction = params[:direction]
    direction = '' #" AND calls.callertype = '#{dir}'"
    # end
    sql = "SELECT dids.*, SUM(calls.did_price) as did_price , SUM(calls.did_prov_price) as did_prov_price, SUM(calls.did_inc_price) as did_inc_price, COUNT(calls.id) as 'calls_size', providers.name, users.username, users.first_name, users.last_name, actions.date FROM dids
    JOIN calls on (calls.did_id = dids.id)
    JOIN providers on (dids.provider_id = providers.id)
    JOIN users on (dids.user_id = users.id)
    left JOIN actions on (dids.id = actions.data AND actions.action like 'did_assigned%')
    WHERE calls.calldate BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' #{user_sql.to_s + provider_sql.to_s + direction.to_s}  GROUP BY dids.id ORDER BY dids.user_id"
    # my_debug sql
    @res = ActiveRecord::Base.connection.select_all(sql)
    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@res.size.to_d / session[:items_per_page].to_d).ceil
    @all_res = @res
    @res = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @res << @all_res[i]
    end
    if @direction.to_s == "outgoing"
      @dids_total_price = 0
      @dids_total_price_provider = 0
      @dids_total_profit = 0
      @dids_total_calls = 0
      for r in @res
        @dids_total_price += r['did_price'].to_d
        @dids_total_price_provider += r['did_prov_price'].to_d
        @dids_total_profit += r['did_price'].to_d - r['did_prov_price'].to_d
        @dids_total_calls += r['calls_size'].to_i
      end
    else
      @dids_total_price = 0
      @dids_total_price_provider = 0
      @dids_total_inc_price = 0
      @dids_total_profit = 0
      @dids_total_calls = 0
      for r in @res
        @dids_total_price += r['did_price'].to_d
        @dids_total_price_provider += r['did_prov_price'].to_d
        @dids_total_inc_price += r['did_inc_price'].to_d
        @dids_total_profit += r['did_price'].to_d + r['did_prov_price'].to_d # + r['did_inc_price'].to_d
        @dids_total_calls += r['calls_size'].to_i
      end
    end

  end

  #======================== SYSTEM STATS ======================================

  def system_stats
    @page_title = _('System_stats')
    @page_icon = "chart_pie.png"


    sql = "SELECT COUNT(users.id) as \'users\' FROM users"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_users = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'admin'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_admin = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'reseller'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_resellers = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'accountant'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_accountant = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'user'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_t_user = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.postpaid = '1'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_pospaid = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.postpaid = '0'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_prepaid = res[0]["users"].to_i

    sql = "SELECT COUNT(devices.id) as \'devices\' FROM devices"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_devices = res[0]["devices"].to_i

    @device_types = Devicetype.find(:all)

    @dev_types = []
    for type in @device_types
      sql = "SELECT COUNT(devices.id) as \'devices\' FROM devices WHERE devices.device_type = '#{type.name.to_s}'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @dev_types[type.id] = res[0]["devices"].to_i
    end

    sql = "SELECT COUNT(devices.id) as \'devices\' FROM devices WHERE devices.device_type = 'FAX'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @dev_types_fax = res[0]["devices"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs = res[0]["tariffs"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'provider'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs_provider = res[0]["tariffs"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'user'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs_user = res[0]["tariffs"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'user_wholesale'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs_user_wholesale = res[0]["tariffs"].to_i


    sql = "SELECT COUNT(providers.id) as \'providers\' FROM providers"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_providers = res[0]["providers"].to_i


    @provider_types = Providertype.find(:all)

    @prov_type =[]
    for type in @provider_types
      sql = "SELECT COUNT(providers.id) as \'providers\' FROM providers WHERE providers.tech = '#{type.name.to_s}'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @prov_type[type.id] = res[0]["providers"].to_i
    end

    sql = "SELECT COUNT(lcrs.id) as \'lcrs\' FROM lcrs"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_lrcs = res[0]["lcrs"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'free'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_free = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'active'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_active = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'reserved'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_reserved = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'closed'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_closed = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'terminated'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_terminated = res[0]["dids"].to_i

    sql = "SELECT COUNT(directions.id) as \'directions\' FROM directions"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_directions = res[0]["directions"].to_i

    sql = "SELECT COUNT(destinations.id) as \'destinations\' FROM destinations"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_destinations = res[0]["destinations"].to_i

    sql = "SELECT COUNT(destinationgroups.id) as \'destinationgroups\' FROM destinationgroups"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dg = res[0]["destinationgroups"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls'
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls = res[0]["calls"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'ANSWERED\' '
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls_anws = res[0]["calls"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'BUSY\' '
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls_busy = res[0]["calls"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'NO ANSWER\' '
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls_no_answ = res[0]["calls"].to_i

    @total_failet = @total_calls - @total_calls_anws - @total_calls_busy - @total_calls_no_answ

    sql = 'SELECT COUNT(cards.id) as \'cards\' FROM cards'
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_cards = res[0]["cards"].to_i

    sql = 'SELECT COUNT(cardgroups.id) as \'cardgroups\' FROM cardgroups'
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_cards_grp = res[0]["cardgroups"].to_i


  end


  def dids_usage

    @page_title = _('DIDs_usage')
    @page_icon = "did.png"
    change_date

    sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_closed'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_closed = res[0]["actions"].to_i

    sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_made_available'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_made_available = res[0]["actions"].to_i

    sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_reserved' AND actions.data2 = '0'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_reserved = res[0]["actions"].to_i

    sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_created'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_created = res[0]["actions"].to_i

    sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_assigned_to_dp'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_assigned1 = res[0]["actions"].to_i

    sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_assigned'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_assigned2 = res[0]["actions"].to_i

    @did_assigned= @did_assigned1 + @did_assigned2

    sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_deleted'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_deleted = res[0]["actions"].to_i

    sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_terminated'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @did_terminated = res[0]["actions"].to_i


    @free = Did.free.count
    @reserved = Did.reserved.count
    @active = Did.active.count
    @closed = Did.closed.count
    @terminated = Did.terminated.count


  end


  # Prefix Finder ################################################################
  def prefix_finder
    @page_title = _('Dynamic_Search')
    @page_icon = "magnifier.png"
  end


  def prefix_finder_find
    @phrase = params[:prefix].gsub(/[^\d]/, '') if params[:prefix]
    @callshop = params[:callshop].to_i
    @dest = Destination.find(
        :first,
        :conditions => ["prefix = SUBSTRING(?, 1, LENGTH(destinations.prefix))", @phrase],
        :order => "LENGTH(destinations.prefix) DESC"
    ) if @phrase != ''
    @flag = nil
    if @dest == nil
      @results = ""
    else
      @flag = @dest.direction_code
      direction = @dest.direction
      @dg = @dest.destinationgroup
      @results = @dest.subcode.to_s+" "+@dest.name.to_s
      @results = direction.name.to_s+" "+ @results if direction
      @flag2 = @dg.flag if @dg
      @results2 = "#{_('Destination_group')} : " + @dg.name.to_s if @dg
      if @callshop.to_i > 0
        sql = "SELECT position, user_id , users.tariff_id, gusertype from usergroups
               left join users on users.id = usergroups.user_id
                left join tariffs on tariffs.id = users.tariff_id where group_id = #{@callshop.to_i}"
        @booths = Usergroup.find_by_sql(sql)
        @rates = @dest.find_rates_and_tariffs(correct_owner_id, @callshop)
      else
        @rates = @dest.find_rates_and_tariffs(correct_owner_id)
      end

    end
    render(:layout => false)
  end

  def prefix_finder_find_country
    @phrase = params[:prefix].gsub(/['"]/, '') if params[:prefix]
    @dirs = Direction.find(
        :all,
        :conditions => ["SUBSTRING(name, 1, LENGTH(?)) = ?", @phrase, @phrase]
    ) if @phrase and @phrase.length > 1
    render(:layout => false)
  end

  def rate_finder_find
    if params[:prefix]
      @phrase = params[:prefix].to_s.gsub(/[^\d]/, '') if params[:prefix]
      phrase = []
      arr = @phrase.to_s.split('') if   @phrase
      arr.size.times { |i| phrase << arr[0..i].join() }

      @dest = Destination.find(:all, :conditions => "prefix in (#{phrase.join(",")})", :order => "prefix desc") if phrase.size>0
      id_string = []
      @dest.each { |d| id_string << d.id } if @dest
      @rates = Stat.find_rates_and_tariffs_by_number(correct_owner_id, id_string, phrase) if id_string.size>0
    end
    render(:layout => false)
  end

  # /Prefix Finder ###############################################################


  # GOOGLE MAPS ##################################################################

  def google_maps

    @page_title = _('Google_Maps')
    @page_icon = "world.png"

    @devices = Device.joins(:user).where("users.owner_id = #{current_user.id} AND name NOT LIKE 'mor_server%' AND ipaddr > 0 AND ipaddr != '0.0.0.0' AND user_id > -1
    AND '192.168.' != SUBSTRING(ipaddr, 1, LENGTH('192.168.'))
    AND '10.' != SUBSTRING(ipaddr, 1, LENGTH('10.'))
    AND ((CAST(SUBSTRING(ipaddr, 1,6) AS DECIMAL(6,3)) > 172.31)
    or (CAST(SUBSTRING(ipaddr, 1,6) AS DECIMAL(6,3)) < 172.16))").all
    @providers = Provider.where("user_id = #{current_user.id} AND server_ip > 0 AND server_ip != '0.0.0.0' AND hidden = 0").all
    @servers = Server.where("server_ip > 0 AND server_ip != '0.0.0.0'").all
    session[:google_active] = 0
  end

  def google_active
    if session[:usertype] == "admin"
      @calls = Activecall.includes(:provider).all
    else
      @calls = Activecall.includes(:provider).where("owner_id = #{current_user.id}").all
    end
  end

  def hangup_cause_codes_stats

    #ticket 5672 only if reseller pro addon is active, reseller that has own providers can access 
    #hangup cause statistics page.
    if current_user.is_reseller? and !current_user.reseller_allowed_to_view_hgc_stats?
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end

    @page_title = _('Hangup_cause_codes_stats')
    @page_icon = "chart_pie.png"

    change_date

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    if params[:back]
      @back = params[:back]
      if params[:back].to_i == 2
        @direction = Direction.find(:first, :conditions => ["code=?", params[:country_code]])
        @country_id = @direction.id
      end
    end

    @user_id = params[:s_user] ? params[:s_user].to_i : -1
    @device_id = params[:s_device] ? params[:s_device].to_i : -1
    @provider_id = params[:provider_id] ? params[:provider_id].to_i : -1
    @country_id = params[:country_id] ? params[:country_id].to_i : -1

    if params[:provider_id] and params[:provider_id].to_i != -1
      @provider = current_user.providers.find(:first, :conditions => {:id => params[:provider_id]})
      unless @provider
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end

    if params[:s_user] and params[:s_user].to_i != -1
      @user = User.find(:first, :conditions => {:id => params[:s_user]})
      unless @user
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end

    @country = Direction.find(:first, :conditions => ["id = ?", @country_id]) if @country_id.to_i > -1
    if params[:direction_code]
      @country = Direction.find(:first, :conditions => ["code = ?", params[:direction_code]])
    end
    @code = @country.code if @country

    @providers = current_user.load_providers(:all, :conditions => 'hidden=0', :order => 'name ASC')
    @users = User.find_all_for_select(corrected_user_id)
    @countries = Direction.find(:all, :order => "name ASC")

    @calls, @Calls_graph, @hangupcusecode_graph, @calls_size = Call.hangup_cause_codes_stats({:provider_id => @provider_id, :device_id => @device_id, :country_code => @code, :user_id => @user_id, :current_user => current_user, :a1 => session_from_datetime, :a2 => session_till_datetime})

  end

  def calls_by_scr

    @page_title = _('Calls_by_src')
    @page_icon = "chart_pie.png"

    cond=""
    des = ''
    descond=''
    descond1=''
    @prov = -1
    @coun = -1

    if params[:country_id]
      @country_id = params[:country_id]
    end

    if params[:provider_id]
      if params[:provider_id].to_i != -1
        @provider = Provider.find(params[:provider_id])
        cond +=" ((hcalls.provider_id = #{q params[:provider_id]} and hcalls.callertype = 'Local') OR (hcalls.did_provider_id = #{q params[:provider_id]} and hcalls.callertype = 'Outside')) AND "
        @prov = @provider.id
      end
    end
    @providers = Provider.find(:all, :conditions => ['hidden=?', 0], :order => 'name ASC')


    if @country_id
      if @country_id.to_i != -1
        @country = Direction.find(@country_id)
        @coun = @country.id
        des+= 'destinations, '
        descond +=" AND directions.code ='#{@country.code}' "
        descond1 +=" AND destinations.direction_code ='#{@country.code}' "
      end
    end
    @countries = Direction.find(:all, :order => "name ASC")

    change_date


    sql= "SELECT directions.name, des.direction_code, des.name as 'des_name',  des.prefix, des.subcode, count(hcalls.id) as 'calls' FROM directions
    JOIN destinations as des on (des.direction_code = directions.code)
    JOIN calls as hcalls on (hcalls.prefix = des.prefix)
    WHERE #{cond} hcalls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{descond} AND LENGTH(src) >= 10 group by des.id"
    @res = ActiveRecord::Base.connection.select_all(sql)
    #   my_debug sql

    sql= "SELECT directions.name, directions.code, count(hcalls.id) as 'calls' FROM directions
    JOIN destinations as des on (des.direction_code = directions.code)
    JOIN calls as hcalls on (hcalls.prefix = des.prefix)
    WHERE #{cond} hcalls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{descond} AND LENGTH(src) >= 10 group by directions.id"
    @res3 = ActiveRecord::Base.connection.select_all(sql)

    #    my_debug sql
    sql= "SELECT count(hcalls.id) as 'calls' FROM destinations

    JOIN calls as hcalls on (hcalls.prefix = destinations.prefix)
    WHERE #{cond} hcalls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{descond1} AND LENGTH(src) < 10 "
    @res2 = ActiveRecord::Base.connection.select_all(sql)
    # my_debug @res2
    #      my_debug sql

  end

  def resellers

    @page_title = _('Resellers')
    @page_icon = "user_gray.png"

    sql = "select users.id, users.username, users.first_name, users.last_name, s_calls.calls as 'f_calls', s_tariffs.tariffs as 'f_tariffs', s_cardgroups.cardgroups as 'f_cardgroups', s_cards.cards as 'f_cards', s_users.users as 'f_users', s_devices.devices as 'f_devices', acc_groups.name as 'group_name', acc_groups.id as 'group_id', s_dids.dids as f_dids, #{SqlExport.nice_user_sql}
        from users
        LEFT JOIN acc_groups ON (users.acc_group_id = acc_groups.id)
        left join (SELECT COUNT(calls.id) as 'calls', reseller_id FROM calls group by calls.reseller_id) as s_calls on(s_calls.reseller_id = users.id)
        left join (SELECT COUNT(tariffs.id) as 'tariffs', owner_id FROM tariffs group by tariffs.owner_id) as s_tariffs on(s_tariffs.owner_id = users.id)
        left join (SELECT COUNT(cardgroups.id) as 'cardgroups', owner_id FROM cardgroups group by cardgroups.owner_id) as s_cardgroups on(s_cardgroups.owner_id = users.id)
        left join (SELECT COUNT(cards.id) as 'cards', owner_id FROM cards group by cards.owner_id) as s_cards on(s_cards.owner_id = users.id)
        left join (SELECT COUNT(users.id) as 'users', owner_id FROM users group by users.owner_id) as s_users on(s_users.owner_id = users.id)
        left join (SELECT COUNT(devices.id) as 'devices', users.owner_id FROM devices
                          left join users on (devices.user_id = users.id)
                          where users.owner_id > 0 group by users.owner_id) as s_devices on(s_devices.owner_id = users.id)
        left join (SELECT COUNT(dids.id) AS 'dids', reseller_id FROM dids GROUP BY dids.reseller_id) AS s_dids ON(s_dids.reseller_id = users.id)
        where users.usertype = 'reseller' and users.hidden = 0
        ORDER BY nice_user ASC"
    #my_debug sql
    @resellers = User.find_by_sql(sql)
  end


  def calls_per_day
    @page_title = _('Calls_per_day')
    @page_icon = "chart_bar.png"

    cond=""
    des = ''
    des2 = ''
    des3 = ''
    @prov = -1
    @coun = -1
    @user_id = -1
    @directions = -1

    up, rp, pp = current_user.get_price_calculation_sqls
    if params[:country_id]
      @country_id = params[:country_id]
    end

    if params[:provider_id]
      if params[:provider_id].to_i != -1
        @provider = Provider.where(:id => params[:provider_id]).first
        @prov = @provider.id
        cond +=" (calls.provider_id = '#{params[:provider_id].to_i}' OR calls.did_provider_id = '#{params[:provider_id].to_i}') AND "
      end
    end
    @providers = Provider.where(:hidden => 0).order('name ASC').all

    if params[:user_id]
      if params[:user_id].to_i != -1
        @user = User.where(:id => params[:user_id]).first
        cond +=" calls.user_id = '#{@user.id}' AND "
        @user_id = @user.id
      end
    end
    @users = User.find_all_for_select(corrected_user_id)

    if params[:reseller_id]
      if params[:reseller_id].to_i != -1
        @reseller = User.where(:id => params[:reseller_id]).first
        cond +=" calls.reseller_id = '#{@reseller.id}' AND "
        @reseller_id = @reseller.id
      end
    end
    @resellers = User.where(:usertype => "reseller").order('first_name ASC').all

    if params[:direction]
      if params[:direction].to_i != -1
        if params[:direction].to_s == "Incoming"
          cond +=" calls.did_id > 0 AND "
        else
          cond +=" calls.did_id = 0 AND "
        end
        @direction = params[:direction]
      end
    end
    owner_id = correct_owner_id
    if owner_id != 0
      cond += " reseller_id ='#{owner_id}' AND "
    end

    if @country_id
      if @country_id.to_i != -1
        @country = Direction.where(:id => @country_id).first
        @coun = @country.id
        des3 += "destinations JOIN"
        des2 += "ON (calls.prefix = destinations.prefix)"
        des +=" AND destinations.direction_code ='#{@country.code}' "
      end
    end
    @countries = Direction.order("name ASC").all

    change_date


    #    logger.fatal current_user.time_zone.to_i
    #     logger.fatal  User.system_time_offset.to_i
    calldate = "(calls.calldate + INTERVAL #{current_user.time_offset} SECOND)"

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    sql = "SELECT EXTRACT(YEAR FROM #{calldate}) as year, EXTRACT(MONTH FROM #{calldate}) as month, EXTRACT(day FROM #{calldate}) as day, Count(calls.id) as 'calls' , SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'duration', SUM(#{up}) as 'user_price', SUM(#{rp}) as 'resseler_price', SUM(#{pp}) as 'provider_price', SUM(IF(disposition!='ANSWERED',1,0)) as 'fail'  FROM
    #{des3} calls #{des2} #{SqlExport.left_join_reseler_providers_to_calls_sql}
    WHERE #{cond} calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{des}
    GROUP BY year, month, day"
    @res = ActiveRecord::Base.connection.select_all(sql)

    sql_total = "SELECT  Count(calls.id) as 'calls' , SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'duration', SUM(#{up}) as 'user_price', SUM(#{rp}) as 'resseler_price', SUM(#{pp}) as 'provider_price', SUM(IF(disposition!='ANSWERED',1,0)) as 'fail'  FROM
    #{des3} calls #{des2} #{SqlExport.left_join_reseler_providers_to_calls_sql}
    WHERE #{cond} calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{des}"
    @res_total = ActiveRecord::Base.connection.select_all(sql_total)
  end

  def first_activity
    @page_title = _('First_activity')
    @page_icon = "chart_bar.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/First_Activity"

    change_date

    @size = Action.set_first_call_for_user(session_from_date, session_till_date)

    @total_pages = (@size.to_d / session[:items_per_page].to_d).ceil

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page = @total_pages.to_i if params[:page].to_i > @total_pages
    @page = 1 if params[:page].to_i < 0

    @fpage = ((@page -1) * session[:items_per_page]).to_i


=begin
    sql = "SELECT calldate, user_id, card_id, c.sb, users.first_name, users.last_name, users.username
           FROM calls
              LEFT JOIN
                (SELECT COUNT(subscriptions.id) AS sb, subscriptions.user_id AS su_id
                  FROM subscriptions WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < '#{a2}') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) GROUP BY subscriptions.user_id) AS c on (c.su_id = calls.user_id )
              LEFT JOIN users on (users.id = calls.user_id)
           WHERE calldate < '#{session_till_datetime}' AND calls.user_id != -1
           GROUP BY user_id
           ORDER BY calldate ASC
           LIMIT #{@fpage}, #{@tpage}"
=end
    #my_debug sql

    #    sql3 = "SELECT actions.date as 'calldate', actions.data2 as 'card_id', c.sb, users.first_name, users.last_name, users.username, users.id, actions.user_id FROM users
    #              JOIN actions ON  (actions.user_id = users.id)
    #              LEFT JOIN
    #                (SELECT COUNT(subscriptions.id) AS sb, subscriptions.user_id AS su_id
    #                  FROM subscriptions WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < '#{a2}') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) GROUP BY subscriptions.user_id) AS c on (c.su_id = users.id )
    #              WHERE actions.action = 'first_call' and actions.date BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'
    #              GROUP BY user_id
    #           ORDER BY date ASC
    #           LIMIT #{@fpage}, #{session[:items_per_page].to_i}"

    sql3= "SELECT actions.date as 'calldate', actions.data2 as 'card_id', users.first_name, users.last_name, users.username, users.id, actions.user_id FROM users
                  JOIN actions ON  (actions.user_id = users.id)
           WHERE actions.action = 'first_call' and actions.date BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'
           GROUP BY user_id
           ORDER BY date ASC
           LIMIT #{@fpage}, #{session[:items_per_page].to_i}"
    @res = ActiveRecord::Base.connection.select_all(sql3)


    #    @all_res = @res
    #    @res = []
    #
    #    iend = ((session[:items_per_page] * @page) - 1)
    #    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    #    for i in ((@page - 1) * session[:items_per_page])..iend
    #      @res << @all_res[i]
    #    end
    #
    #
    #    @subscriptions = 0
    #    @user = []
    #    for r in @res
    #      @subscriptions+= r['sb'].to_i
    #      if (r['user_id'].to_i != -1) and (r['user_id'].to_s != "") and (r['card_id'].to_i == 0 )
    #        user = User.find(:first, :conditions => "id = #{r['user_id']}") if r['user_id'].to_s.length >= 0
    #        @user[r['user_id'].to_i] = user if r['user_id'].to_i >= 0
    #      end
    #    end
  end


  def subscriptions_stats
    @page_title = _('Subscriptions')
    @page_icon = "chart_bar.png"

    session[:subscriptions_stats_options] ? @options = session[:subscriptions_stats_options] : @options = {}
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "user" if !@options[:order_by])
    @options[:order] = Subscription.subscriptions_stats_order_by(@options)

    change_date
    a1 = session_from_date
    a2 = session_till_date
    @date_from = session_from_date
    sql = "SELECT COUNT(subscriptions.id) AS sub_size  FROM subscriptions
    WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < 'a2') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}'))"
    @res = ActiveRecord::Base.connection.select_all(sql)
    sql = "SELECT COUNT(subscriptions.id) AS sub_size  FROM subscriptions
    WHERE activation_start = '#{a1}'"
    @res2 = ActiveRecord::Base.connection.select_all(sql)
    sql = "SELECT users.id, users.username, users.first_name, users.last_name, activation_start, activation_end, added, subscriptions.id AS subscription_id, memo, services.name AS service_name, services.price AS service_price, services.servicetype AS servicetype, #{SqlExport.nice_user_sql} FROM subscriptions
    JOIN users on (subscriptions.user_id = users.id)
    JOIN services on (services.id = subscriptions.service_id)
    WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < 'a2') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) ORDER BY #{@options[:order]}"
    @res3 = ActiveRecord::Base.connection.select_all(sql)

    params[:page] ? @page = params[:page].to_i : (@options[:page] ? @page = @options[:page] : @page = 1)
    @total_pages = (@res3.size.to_d / session[:items_per_page].to_d).ceil

    @all_res = @res3
    @res3 = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @res3 << @all_res[i]
    end
    @options[:page] = @page
    session[:subscriptions_stats_options] = @options
  end

  def subscriptions_first_day
    @page_title = _('First_day_subscriptions')
    @page_icon = "chart_bar.png"

    @date = session_from_date
    sql = "SELECT users.id, users.username, users.first_name, users.last_name FROM users
    JOIN (SELECT users.id AS suser_id, subscriptions.id as sub_id FROM users
    JOIN subscriptions ON (subscriptions.user_id = users.id AND subscriptions.activation_start BETWEEN '#{@date} 01:01:01' AND '#{@date} 23:59:59')
    GROUP BY users.id) as a on (users.id != a.suser_id )
    where users.owner_id='#{session[:user_id]}' and users.hidden = 0"
    @res = ActiveRecord::Base.connection.select_all(sql)
    if @res.size.to_i == 0
      sql = "SELECT users.id, users.username, users.first_name, users.last_name FROM users
      where users.owner_id='#{session[:user_id]}' and users.hidden = 0"
      @res = ActiveRecord::Base.connection.select_all(sql)
    end
    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@res.size.to_d / session[:items_per_page].to_d).ceil

    @all_res = @res
    @res = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @res << @all_res[i]
    end

  end

  def action_log
    @page_title = _('Action_log')
    @page_icon = "chart_bar.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Action_log"

    if session[:usertype] == 'user'
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end

    change_date



    a1 = session_from_datetime
    a2 = session_till_datetime

    session[:action_log_stats_options] ? @options = session[:action_log_stats_options] : @options = {:order_by => "action", :order_desc => 0, :page => 1}

    # search paramaters
    params[:page] ? @options[:page] = params[:page].to_i : (params[:clean]) ? @options[:page] = 1 : (@options[:page] = 1 if !@options[:page])
    params[:action_type] ? @options[:s_type] = params[:action_type].to_s : (params[:clean]) ? @options[:s_type] = "all" : (@options[:s_type]) ? @options[:s_type] = session[:action_log_stats_options][:s_type] : @options[:s_type] = "all"
    (params[:user_id] and !params[:user_id].blank?) ? @options[:s_user] = params[:user_id].to_s : (params[:clean]) ? @options[:s_user] = -1 : (@options[:s_user]) ? @options[:s_user] = session[:action_log_stats_options][:s_user] : @options[:s_user] = -1
    params[:processed] ? @options[:s_processed] = params[:processed].to_s : (params[:clean]) ? @options[:s_processed] = -1 : (@options[:s_processed]) ? @options[:s_processed] = session[:action_log_stats_options][:s_processed] : @options[:s_processed] = -1
    #params[:s_int_ch]   ? @options[:s_int_ch] = params[:s_int_ch].to_i     : (params[:clean]) ? @options[:s_int_ch] = 0   : (@options[:s_int_ch])? @options[:s_int_ch] = session[:action_log_stats_options][:s_int_ch] : @options[:s_int_ch] = 0
    params[:target_type] ? @options[:s_target_type] = params[:target_type].to_s : (params[:clean]) ? @options[:s_target_type] = '' : (@options[:s_target_type]) ? @options[:s_target_type] = session[:action_log_stats_options][:s_target_type] : @options[:s_target_type] = ''
    params[:target_id] ? @options[:s_target_id] = params[:target_id].to_s : (params[:clean]) ? @options[:s_target_id] = '' : (@options[:s_target_id]) ? @options[:s_target_id] = session[:action_log_stats_options][:s_target_id] : @options[:s_target_id] = ''
    params[:did] ? @options[:s_did] = params[:did].to_s : (params[:clean]) ? @options[:s_did] = '' : (@options[:s_did]) ? @options[:s_did] = session[:action_log_stats_options][:s_did] : @options[:s_did] = ''

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"
    order_by = Action.actions_order_by(@options)

    @users = User.find_all_for_select(corrected_user_id)
    @dids = Did.find(:all)
    @res = Action.find(:all, :select => "DISTINCT(actions.action)", :order => "actions.action")

    cond, cond_arr, join = Action.condition_for_action_log_list(current_user, a1, a2, params[:s_int_ch], @options)
    # page params
    @ac_size = Action.count(:all, :conditions => [cond.join(" AND ")] + cond_arr, :joins => join, :select => "actions.id")
    @not_reviewed_actions = Action.find(:all, :conditions => [(['processed = 0'] + cond).join(" AND ")] + cond_arr, :joins => join, :limit => 1).size.to_i == 1
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@ac_size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    fpage = ((@options[:page] -1) * session[:items_per_page]).to_i
    @search = 1
    logger.fatal cond_arr
    # search
    @actions = Action.find(:all,
                           :select => " actions.*, users.username, users.first_name, users.last_name ",
                           :conditions => [cond.join(" AND ")] + cond_arr,
                           :joins => join,
                           :order => order_by,
                           :limit => "#{fpage}, #{session[:items_per_page].to_i}")

    session[:action_log_stats_options] = @options
  end

  def action_log_mark_reviewed
    a1 = session_from_date
    a2 = session_till_date
    session[:action_log_stats_options] ? @options = session[:action_log_stats_options] : @options = {:order_by => "action", :order_desc => 0, :page => 1}
    cond, cond_arr, join = Action.condition_for_action_log_list(current_user, a1, a2, 0, @options)
    @actions = Action.find(:all,
                           :select => " actions.*",
                           :conditions => [cond.join(" AND ")] + cond_arr,
                           :joins => join)

    if @actions
      @actions.each { |a|
        if a.processed == 0
          a.processed = 1
          a.save
        end
      }
    end
    flash[:status] = _('Actions_marked_as_reviewed')
    redirect_to :action => :action_log
  end

  def action_processed
    action = Action.find(params[:id])
    if action.processed.to_i == 1
      action.processed = 0
    else
      action.processed = 1
    end
    action.save
    @user = params[:user].to_s
    @action = params[:s_action]
    @processed = params[:procc]
    flash[:status] = _('Action_marked_as_reviewed')
    redirect_to :action => "action_log", :user_id => @user, :processed => @processed, :action_type => @action
  end

  def load_stats
    @page_title = _('Load_stats')
    @page_icon = "chart_bar.png"

    change_date

    @providers = current_user.providers.find(:all, :conditions => ['hidden=?', 0])
    @users = User.find_all_for_select(correct_owner_id, {:exclude_owner => true})
    @resellers = User.find(:all, :conditions => 'usertype = "reseller"')
    if current_user.usertype != 'reseller'
      @dids = Did.find(:all)
      @servers = Server.find(:all)
    end

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    @default = {:s_user => -1, :s_provider => -1, :s_did => -1, :s_device => -1, :s_direction => -1, :s_server => -1, :s_reseller => -1}
    session[:stats_load_stats_options] ? @options = session[:stats_load_stats_options] : @options = @default

    @options[:s_user] = params[:s_user] if params[:s_user]
    @options[:s_reseller] = params[:s_reseller] if params[:s_reseller]
    @options[:s_did] = params[:s_did] if params[:s_did] and current_user.usertype != 'reseller'
    @options[:s_device] = params[:device_id] if params[:device_id]
    @options[:s_provider] = params[:s_provider] if params[:s_provider]
    @options[:s_direction] = params[:s_direction] if params[:s_direction]
    @options[:s_server] = params[:s_server] if params[:s_server] and current_user.usertype != 'reseller'
    @options[:a1] ="#{(session_from_datetime.to_s)}"
    @options[:a2] ="#{(session_till_datetime.to_s)}"
    @options[:current_user] = current_user
    @calls_answered, @calls_all =Call.calls_for_laod_stats(@options)

    #    logger.info @calls_answered.size.to_i
    #    logger.info @calls_all.size.to_i
    n = 1440
    min1 =[]
    min2 =[]
    i=0
    n.times do
      min1[i]=0
      min2[i]=0
      i+=1
    end

    if  @calls_all.size.to_i >0
      for cal in @calls_all
        h = cal.calldate.strftime("%H")
        m = cal.calldate.strftime("%M")
        h = h.to_i * 60
        m = h.to_i + m.to_i
        min2[m.to_i]+=1
      end
    end

    if @calls_answered.size.to_i >0
      for cal in @calls_answered
        h = cal.calldate.strftime("%H")
        m = cal.calldate.strftime("%M")
        h = h.to_i * 60
        m = h.to_i + m.to_i
        #min2[m]+=1
        d = cal.duration.to_i / 60
        if (cal.duration.to_i % 60) > 0
          d+= 1
        end
        i = m.to_i
        d.times do
          if i.to_i < 1440
            min1[i.to_i]+=1
            i=i+1
          end
        end
      end
    end


    @Call_answered_graph=""
    i=0
    n.times do
      h2 = (i / 60)
      m2 = (i % 60)
      time = Time.mktime(session[:year_from], session[:month_from], session[:day_from], h2, m2, 0).strftime("%H:%M")
      @Call_answered_graph += time.to_s + ";" + min1[i].to_s + ";"+ min2[i].to_s + "\\n"
      i+=1
    end

  end


  def check_owner_for_user(user_id)
    user = User.find(user_id)
    if user.owner_id != session[:user_id].to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def nice_user(user)
    nu = user.username
    nu = user.first_name + " " + user.last_name if user.first_name.length + user.last_name.length > 0
    nu
  end

  def link_nice_user(user)
    link_to nice_user(user), :controller => "users", :action => "edit", :id => user.idd
  end

  def truncate_active_calls
    if current_user.is_admin?
      Activecall.delete_all
      redirect_to :controller => "stats", :action => "active_calls" and return false
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  private

  def no_cache
    response.headers["Last-Modified"] = Time.now.httpdate
    response.headers["Expires"] = '0'
    # HTTP 1.0
    response.headers["Pragma"] = "no-cache"
    # HTTP 1.1 'pre-check=0, post-check=0' (IE specific)
    response.headers["Cache-Control"] = 'no-store, no-cache, must-revalidate, max-age=0, pre-check=0, post-check=0'
  end

  def active_calls_longer_error(calls)
    for call in calls
      ba = Thread.new { active_calls_longer_error_send_email(call["user_id"].to_s, call["provider_id"].to_s, call["server_id"].to_s) }
      # ba.join #kam ji cia joininti?
      MorLog.my_debug "active_calls_longer_error"
    end
  end

  def active_calls_longer_error_send_email(user, provider, server)
    address = Confline.get_value("Exception_Support_Email").to_s
    subject = "Active calls longer error on : #{Confline.get_value("Company")}"
    message = "URL:            #{Web_URL}\n"
    message += "User ID:        #{user.to_s}\n"
    message += "Provider ID:    #{provider.to_s}\n"
    message += "Server ID:      #{server.to_s}\n"
    message += "----------------------------------------\n"

    # disabling for now
    #`/usr/local/mor/sendEmail -f 'support@kolmisoft.com' -t '#{address}' -u '#{subject}' -s 'smtp.gmail.com' -xu 'crashemail1' -xp 'crashemail199' -m '#{message}' -o tls='auto'`
    MorLog.my_debug('Crash email sent')
  end

  def check_authentication
    redirect_to :controller => "callc", :action => "main" if current_user.nil?
  end

  def check_reseller_in_providers
    if current_user.is_reseller? and (current_user.own_providers.to_i == 0 or !reseller_pro_active?)
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_user_from_id_or_session
    params[:id] ? user_id = params[:id] : user_id = session[:user_id]
    @user=User.find(:first, :conditions => ["id = ?", user_id])

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    if session[:usertype] == 'reseller'
      if @user.id != session[:user_id] and @user.owner_id != session[:user_id]
        dont_be_so_smart
        redirect_to :controller => :callc, :action => :main and return false
      end
    end

    if session[:usertype] == 'user' and @user.id != session[:user_id]
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def last_calls_stats_parse_params

    default = {
        :items_per_page => session[:items_per_page].to_i,
        :page => "1",
        :s_direction => "outgoing",
        :s_call_type => "all",
        :s_device => "all",
        :s_provider => "all",
        :s_hgc => 0,
        :search_on => 1,
        :s_user => "all",
        :user => nil,
        :s_did => "all",
        :s_did_pattern => "",
        :s_destination => "",
        :order_by => "time",
        :order_desc => 0,
        :s_country => '',
        :s_reseller => "all",
        :s_source => nil,
        :s_reseller_did => nil,
        :s_card_number => nil, 
        :s_card_pin => nil, 
        :s_card_id => nil
    }
    options = ((params[:clear] || !session[:last_calls_stats]) ? default : session[:last_calls_stats])
    options[:items_per_page] = session[:items_per_page] if session[:items_per_page].to_i > 0 
    default.each { |key, value| options[key] = params[key] if params[key] }

    change_date_to_present if params[:clear]

    options[:from] = session_from_datetime
    options[:till] = session_till_datetime

    options[:order_by_full] = options[:order_by] + (options[:order_desc] == 1 ? " DESC" : " ASC")
    options[:order] = Call.calls_order_by(params, options)
    options[:direction] = options[:s_direction]
    options[:call_type] = options[:s_call_type]
    options[:destination] = (options[:s_destination].to_s.strip.match(/\A[0-9%]+\Z/) ? options[:s_destination].to_s.strip : "")
    options[:source] = options[:s_source] if  options[:s_source]

    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency]).to_d
    options[:exchange_rate] = exchange_rate

    options
  end

  def last_calls_stats_user(user, options)
    devices = user.devices(:conditions => "device_type != 'FAX'")
    device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
    return devices, device
  end

  def last_calls_stats_reseller(options)
    user = User.where(:id => options[:s_user]).first if options[:s_user] != "all" and !options[:s_user].blank?
    device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
    if user
      devices = user.devices(:conditions => "device_type != 'FAX'")
    else
      devices = Device.find_all_for_select(corrected_user_id)
    end
    users = User.select("id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}").where("users.usertype = 'user' AND users.owner_id = #{corrected_user_id} AND hidden=0").order("nice_user")
    if Confline.get_value('Show_HGC_for_Resellers').to_i == 1
      hgcs = Hangupcausecode.find_all_for_select
      hgc = Hangupcausecode.where(:id => options[:s_hgc]).first if options[:s_hgc].to_i > 0
    end

    if current_user.reseller_allow_providers_tariff?
      providers = current_user.load_providers(:all, :select => "id, name", :order => 'providers.name ASC')

      if options[:s_provider].to_i > 0
        #KRISTINA ticket number 3276
        #provider = Provider.find(:first, :conditions => ["providers.id = ? OR common_use = 1", options[:s_provider]])
        provider = Provider.find(:first, :conditions => ["providers.id = ?", options[:s_provider]])
        unless provider
          dont_be_so_smart
          redirect_to :controller => :callc, :action => :main and return false
        end
      end
    else
      providers = nil; provider = nil
    end
    did = Did.where(:id => options[:s_did]).first if options[:s_did] != "all" and !options[:s_did].blank?
    dids = Did.find_all_for_select

    return users, user, devices, device, hgcs, hgc, providers, provider, did, dids
  end

  def last_calls_stats_admin(options)
    user = User.where(:id => options[:s_user]).first if options[:s_user] != "all" and !options[:s_user].blank?
    device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
    did = Did.where(:id => options[:s_did]).first if options[:s_did] != "all" and !options[:s_did].blank?
    hgc = Hangupcausecode.where(:id => options[:s_hgc]).first if options[:s_hgc].to_i > 0
    users = User.select("id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}").where("users.usertype = 'user'").order("nice_user")
    dids = Did.find_all_for_select
    hgcs = Hangupcausecode.find_all_for_select
    providers = Provider.find_all_for_select
    provider = Provider.where(:id => options[:s_provider]).first if options[:s_provider].to_i > 0
    resellers = User.where(:usertype => "reseller").all
    resellers_with_dids = User.find(:all, :joins => 'JOIN dids ON (users.id = dids.reseller_id)', :conditions => 'usertype = "reseller"', :group => 'users.id')
    resellers = [] if !resellers
    reseller = User.where(:id => options[:s_reseller]).first if options[:s_reseller] != "all" and !options[:s_reseller].blank?
    if user
      devices = user.devices(:conditions => "device_type != 'FAX'")
    else
      devices = Device.find_all_for_select
    end
    return users, user, devices, device, hgcs, hgc, dids, did, providers, provider, reseller, resellers, resellers_with_dids
  end

  def last_calls_stats_set_variables(options, values)
    options.merge(values.reject { |key, value| value.nil? })
  end

  def get_price_exchange(price, cur)
    exrate = Currency.count_exchange_rate(cur, current_user.currency.name)
    rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [price.to_d]})
    return rate_cur.to_d
  end
end
