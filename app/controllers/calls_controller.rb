# -*- encoding : utf-8 -*-
class CallsController < ApplicationController
  include SqlExport
  layout "callc"
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_call, :only => [ :call_info ]
=begin rdoc
 Agregated call summary. Bu user/provider/destination.
=end
  def index
    redirect_to :controller=>"callc", :action => 'main'
  end
=begin redoc

 *Performance*

 * 2009-09-03 - 1105427 calls - 85.85609 sec
 * 2009-09-03 - 1105427 calls - 79.46851 sec
   Added "LEFT JOIN devices" for accurate results.
=end

  def aggregate
    @page_title = _('Aggregate')
    @help_link = 'http://wiki.kolmisoft.com/index.php/Last_Calls#Call_information_representation'
    change_date

    #if we have some options preset in session we can retreave them if not new options hash is created.
    session[:aggregate_list_options] ? @options = session[:aggregate_list_options] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:destination_grouping] ? @options[:destination_grouping] = params[:destination_grouping].to_i : (@options[:destination_grouping] = 1 if ! @options[:destination_grouping])

    # default values for first collumn (selects and fields)
    if !session[:aggregate_list_options] or params[:search].to_i == 1
      (params[:originator] and params[:originator].to_s != "") ? @options[:originator] = params[:originator] :  @options[:originator] = "any"
      (params[:terminator] and params[:terminator].to_s != "") ? @options[:terminator] = params[:terminator] :  @options[:terminator] = "any"
      (params[:prefix] and params[:prefix].to_s != "") ? @options[:prefix] = params[:prefix].gsub(/[^0-9]/, "") :  @options[:prefix] = ""

      #default values for show/do not show checkboxes and collumns
      (params[:unique_id_show] and params[:unique_id_show].to_s != "") ? @options[:unique_id_show] = params[:unique_id_show].to_i :  @options[:unique_id_show] = 1
      (params[:destination_show] and params[:destination_show].to_s != "") ? @options[:destination_show] = params[:destination_show].to_i :  @options[:destination_show] = 1
      (params[:customer_orig_show] and params[:customer_orig_show].to_s != "") ? @options[:customer_orig_show] = params[:customer_orig_show].to_i :  @options[:customer_orig_show] = 1
      (params[:customer_term_show] and params[:customer_term_show].to_s != "") ? @options[:customer_term_show] = params[:customer_term_show].to_i :  @options[:customer_term_show] = 1
      (params[:ip_address_orig_show] and params[:ip_address_orig_show].to_s != "") ? @options[:ip_address_orig_show] = params[:ip_address_orig_show].to_i :  @options[:ip_address_orig_show] = 1
      (params[:ip_address_term_show] and params[:ip_address_term_show].to_s != "") ? @options[:ip_address_term_show] = params[:ip_address_term_show].to_i :  @options[:ip_address_term_show] = 1
      if can_see_finances?
        (params[:price_orig_show] and params[:price_orig_show].to_s != "") ? @options[:price_orig_show] = params[:price_orig_show].to_i :  @options[:price_orig_show] = 1
        (params[:price_term_show] and params[:price_term_show].to_s != "") ? @options[:price_term_show] = params[:price_term_show].to_i :  @options[:price_term_show] = 1
      end
      (params[:billed_time_orig_show] and params[:billed_time_orig_show].to_s != "") ? @options[:billed_time_orig_show] = params[:billed_time_orig_show].to_i :  @options[:billed_time_orig_show] = 1
      (params[:billed_time_term_show] and params[:billed_time_term_show].to_s != "") ? @options[:billed_time_term_show] = params[:billed_time_term_show].to_i :  @options[:billed_time_term_show] = 1
    end

    @options[:order_by], order_by = agregate_order_by(params, @options)
    if (@options[:destination_grouping].to_i == 1 and @options[:order_by] == "directions.name") or (@options[:destination_grouping].to_i == 2 and @options[:order_by] == "destinations.name")
      order_by = ""
      @options[:order_by] = ""
    end
    @options[:terminator] != "any" ? terminator_cond = @options[:terminator] : terminator_cond = ""

    # groups by those params that are not in search conditions
    group_by = []
    @options[:destination_grouping].to_i == 1 ? group_by << "destinations.direction_code, destinations.prefix" : group_by << "destinations.direction_code, destinations.subcode"
    
    if @options[:customer_orig_show].to_i == 1 or @options[:customer_term_show].to_i == 1
      group_by << "devices.user_id" if @options[:originator] == "any"
      group_by << "providers.terminator_id" if @options[:terminator] == "any"
    end

    # form condition array for sql
    cond = ["calldate BETWEEN '" + session_from_datetime + "' AND '" + session_till_datetime + "'"]
    cond << "users.owner_id = #{current_user.id}" if reseller?
    #cond << "calls.user_id != -1" # This allows to filter invalid calls
    cond << "(usrs.id = #{q(@options[:originator].to_i)} OR users.owner_id = #{q(@options[:originator].to_i)})"  if @options[:originator] != "any"
    cond << "calls.prefix LIKE '#{@options[:prefix].gsub(/[^0-9]/, "")}%'" if  @options[:prefix].to_s != ""
    if terminator_cond.to_s != ''
      cond << "providers.terminator_id = #{terminator_cond.to_s}"
    else
      cond << "providers.terminator_id > 0"
    end
    #limit terminators to allowed ones.
    term_ids = current_user.load_terminators_ids
    if term_ids.size == 0
      cond << "providers.terminator_id = 0"
    else
      cond << "providers.terminator_id IN (#{term_ids.join(", ")})"
    end
    
    cond << "NOT (billsec = 0 AND disposition = 'ANSWERED')"
    # terminator requires other conditions

    if reseller?
      originating_billed = SqlExport.replace_price("SUM(IF(calls.disposition = 'ANSWERED', if(calls.user_price is NULL, 0, calls.user_price), 0))", {:reference=> 'originating_billed'})
      originating_billsec = "SUM(IF(calls.disposition = 'ANSWERED', IF(calls.user_billsec IS NULL, 0, calls.user_billsec), 0)) AS 'originating_billsec'" 

      terminator_billed = SqlExport.replace_price("SUM(IF(calls.disposition = 'ANSWERED', calls.reseller_price, 0))", {:reference=> 'terminating_billed'})
      terminator_billsec = "SUM(IF(calls.disposition = 'ANSWERED', calls.reseller_billsec, 0)) AS 'terminating_billsec'"
    else
      # Check if call belongs to resellers user if yes then admins income is reseller perice
      originating_billed = SqlExport.replace_price("SUM(IF(users.owner_id = 0 AND calls.disposition = 'ANSWERED', if(calls.user_price is NULL, 0, calls.user_price), if(calls.reseller_price IS NULL, 0, calls.reseller_price)))", {:reference=> 'originating_billed'})
      originating_billsec = "SUM(IF(users.owner_id = 0 AND calls.disposition = 'ANSWERED', IF(calls.user_billsec IS NULL, 0, calls.user_billsec), if(calls.reseller_billsec IS NULL, 0, calls.reseller_billsec))) AS 'originating_billsec'"
      
      terminator_billed = SqlExport.replace_price("SUM(IF(calls.disposition = 'ANSWERED', calls.provider_price, 0))", {:reference=> 'terminating_billed'})
      terminator_billsec = "SUM(IF(calls.disposition = 'ANSWERED', calls.provider_billsec, 0)) AS 'terminating_billsec'"
    end

    sql = "
    SELECT
    #{SqlExport.nice_user_sql},
    calls.prefix,
    destinations.direction_code AS 'code',
    destinations.subcode AS 'subcode',
    destinations.name AS 'dest_name',
    users.username AS 'username',
    users.first_name AS 'first_name',
    users.last_name AS 'last_name',
    providers.terminator_id AS 'terminator_id',

    #{[originating_billed, terminator_billed, originating_billsec, terminator_billsec].join(",\n")},

    SUM(IF(calls.disposition = 'ANSWERED', calls.billsec, 0)) AS 'duration',
    COUNT(*) AS 'total_calls',
    SUM(IF(calls.disposition = 'ANSWERED', 1,0)) AS 'answered_calls',
    SUM(IF(calls.disposition = 'ANSWERED', 1,0))/COUNT(*)*100 AS 'asr',
    SUM(IF(calls.disposition = 'ANSWERED', calls.billsec, 0))/SUM(IF(calls.disposition = 'ANSWERED', 1,0)) AS 'acd',
    #{SqlExport.nice_user_sql}
    FROM calls FORCE INDEX (calldate)
    LEFT JOIN devices ON (calls.src_device_id = devices.id)
    LEFT JOIN users ON (users.id = devices.user_id)
    INNER JOIN providers ON (providers.id = calls.provider_id)
    #{"LEFT JOIN terminators ON (terminators.id = providers.terminator_id)" if @options[:order_by] == "terminators.name"}
    #{"JOIN users usrs ON usrs.id = calls.user_id" if @options[:originator] != "any"}
    LEFT JOIN destinations ON (destinations.prefix = calls.prefix)
    WHERE(" + cond.join(" AND ")+ ")
    #{group_by.size > 0 ? 'GROUP BY ' +group_by.join(", ") : ''}
    #{order_by.size > 0 ? 'ORDER BY ' +order_by : ''}"

    # my_debug sql

    @result_full = Call.find_by_sql(sql)
    @result = []
    @total_calls = @result_full.size
    # calculate total values of dataset.
    @total = {:billed_orig => 0, :billed_term => 0, :billsec_orig => 0, :billsec_term => 0, :duration => 0, :total_calls => 0, :asr => 0, :acd =>0, :answered_calls => 0}
    @result_full.each { |row|
      @total[:billed_orig] += row.originating_billed.to_f
      @total[:billed_term] += row.terminating_billed.to_f
      @total[:billsec_orig] +=row.originating_billsec.to_f
      @total[:billsec_term] += row.terminating_billsec.to_f
      @total[:duration] += row.duration.to_f
      @total[:total_calls] += row.total_calls.to_i
      @total[:answered_calls] += row.answered_calls.to_i
    }
    @total[:total_calls] == 0 ? @total[:asr] = 0 : @total[:asr] = @total[:answered_calls].to_f/@total[:total_calls].to_f*100
    @total[:answered_calls] == 0 ? @total[:acd] = 0 : @total[:acd] = @total[:duration].to_f / @total[:answered_calls].to_f

    # fetch required number of items.
    @result = []
    @total_pages = (@total_calls.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page] > @total_pages
    start = session[:items_per_page]*(@options[:page]-1)
    (start..(start+session[:items_per_page])-1).each {|i|
      @result <<  @result_full[i] if @result_full[i]
    }

    session[:aggregate_list_options] = @options
    # no need to store these 2 in session as they are not options but values from database.
    @options = load_parties(@options)

    if @options[:terminator] == "any"
       @terminator_providers_count = any_terminator_providers_count(@options[:terminators])
    else
       @terminator_providers_count = terminator_providers_count(@options[:terminators], @options[:terminator])
    end
  end

=begin rdoc
 Call summary.
=end

  def summary
    @page_title = _('Summary')
    change_date

    session[:summary_list_options] ? @options = session[:summary_list_options] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])

    params[:term_order_desc] ? @options[:term_order_desc] = params[:term_order_desc].to_i : (@options[:term_order_desc] = 1 if !@options[:order_desc])
    params[:order_desc] ? @options[:order_desc] =  params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:order_by] ?   @options[:order_by_name] = params[:order_by].to_s : (@options[:order_by_name] = "" if !@options[:order_by_name])

    if !session[:summary_list_options] or params[:search].to_i == 1
      (params[:originator] and params[:originator].to_s != "") ? @options[:originator] = params[:originator] :  @options[:originator] = "any"
      (params[:terminator] and params[:terminator].to_s != "") ? @options[:terminator] = params[:terminator] :  @options[:terminator] = "any"
      (params[:prefix] and params[:prefix].to_s != "") ? @options[:prefix] = params[:prefix].gsub(/[^0-9]/, "") :  @options[:prefix] = ""
    end

    @options[:terminator] != "any" ? terminator_cond = @options[:terminator] : terminator_cond = ""

    cond = ["calldate BETWEEN '" + session_from_datetime + "' AND '" + session_till_datetime + "'"]
    #cond << "calls.user_id != -1"
    cond << "calls.user_id IN (SELECT id FROM users WHERE id = #{@options[:originator].to_i} OR users.owner_id = #{@options[:originator].to_i})"  if @options[:originator] != "any"
    cond << "calls.prefix LIKE '#{@options[:prefix].gsub(/[^0-9]/, "")}%'" if  @options[:prefix].to_s != ""
    
    @options[:order_by], order_by = summary_order_by(params, @options)

    (@options[:order_by_name].to_s.scan(/term_/).size > 0) ? order_by_desc = order_by : order_by_desc = ""
    @terminator_lines = Call.summary_by_terminator(cond, terminator_cond, order_by_desc, current_user)

    @total_items_term = @terminator_lines.size

    @total = {:term_calls => 0, :term_min => 0, :term_exact_min => 0, :term_amount => 0,
      :orig_calls => 0, :orig_min => 0, :orig_exact_min => 0, :orig_amount => 0}
    @terminator_lines.each { |row|
      @total[:term_calls] += row.total_calls.to_i
      @total[:term_exact_min] += row.exact_billsec.to_f
      @total[:term_min] += row.provider_billsec.to_f
      @total[:term_amount] += row.provider_price.to_f
    }

    (@options[:order_by_name].to_s.scan(/orig_/).size > 0) ? order_by_orig = order_by : order_by_orig = ""
    @originator_lines_full = Call.summary_by_originator(cond, terminator_cond, order_by_orig, current_user)
    @originator_lines_full.each { |row|
      @total[:orig_calls] += row.total_calls.to_i
      @total[:orig_exact_min] += row.exact_billsec.to_f
      @total[:orig_min] += row.originator_billsec.to_f
      @total[:orig_amount] += row.originator_price.to_f
    }

    @total_items_orig = @originator_lines_full.size
    @total_pages = (@total_items_orig.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page] > @total_pages

    @originator_lines = []
    start = session[:items_per_page]*(@options[:page]-1)
    (start..(start+session[:items_per_page]-1)).each {|i|
      @originator_lines <<  @originator_lines_full[i] if @originator_lines_full[i]
    }

    session[:summary_list_options] = @options
    @options = load_parties(@options)

    if @options[:terminator] == "any"
       @terminator_providers_count = any_terminator_providers_count(@options[:terminators])
    else
       @terminator_providers_count = terminator_providers_count(@options[:terminators], @options[:terminator])
    end

  end

  def active_call_soft_hangup
    server_id = params[:server_id]
    channel = params[:channel]

    if server_id.to_i > 0 and channel.to_s.length > 0
      server = Server.find(:first, :conditions => "id = #{server_id.to_i}")

      if server
        server.ami_cmd("soft hangup #{channel}")
      end

    end
    MorLog.my_debug "Hangup channel: #{channel} on server: #{server_id}"
    render(:layout => "layouts/mor_min")
  end


  # before_filter
  #   find_call
  def call_info
    @page_title = _('Call_info')
    @page_icon = "information.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Call_Info"


    @did = nil
    @did = Did.find(:first, :conditions => ["id = ?", @call.did_id.to_i])   if @call.did_id.to_i > 0

    @user = nil
    @user = User.find(:first, :conditions => ["id = ?", @call.user_id.to_i])   if @call.user_id.to_i >= 0

    @src_device = nil
    @src_device = Device.find(:first, :conditions => ["id = ?", @call.src_device_id.to_i])   if @call.src_device_id.to_i >= 0

    @reseller = nil
    @reseller = User.find(:first, :conditions => ["id = ?", @call.reseller_id.to_i])   if @call.reseller_id.to_i > 0

    @provider = nil
    @provider = Provider.find(:first, :conditions => ["providers.id = ?", @call.provider_id.to_i], :include => :user)   if @call.provider_id.to_i > 0

    @card = nil
    @card = Card.find(:first, :conditions => ["id = ?", @call.card_id.to_i])   if @call.card_id.to_i > 0

    @call_log = @call.call_log

  end

  private

  def terminator_providers_count(terminators, terminator_id)
    count = 0
    terminators.each do |terminator|
      count = terminator.providers_size.to_i if terminator.id.to_s == terminator_id
    end
    return count
  end

  def any_terminator_providers_count(terminators)
    count = 0
    terminators.each { |terminator| count += terminator.providers_size.to_i }
    return count
  end

  def load_parties(options)
    options[:originators] = current_user.load_users(:all)
    options[:terminators] = current_user.load_terminators
    options
  end

=begin rdoc
 Transaltes order_by param to database fields for agregate report.
=end

  def agregate_order_by(params, options)
    case params[:order_by].to_s
    when "direction" then      order_by = "destinations.direction_code"
    when "destination" then    order_by = "destinations.name"
    when "customer_orig" then  order_by = "nice_user"
    when "customer_term" then  order_by = "terminators.name"
    when "billed_orig" then    order_by = "originating_billed"
    when "billed_term" then    order_by = "terminating_billed"
    when "billsec_orig" then   order_by = "originating_billsec"
    when "billsec_term" then   order_by = "terminating_billsec"
    when "duration" then       order_by = "duration"
    when "answered_calls" then order_by = "answered_calls"
    when "total_calls" then    order_by = "total_calls"
    when "asr" then            order_by = "asr"
    when "acd" then            order_by = "acd"
    else
      options[:order_by] ? order_by = options[:order_by] : order_by = ""
    end

    without = order_by
    order_by = "users.first_name " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", users.last_name" if order_by.to_s == "users.first_name"
    order_by = "destinations.direction_code " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", destinations.name" if order_by.to_s == "destinations.name"
    order_by = "destinations.direction_code " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", destinations.subcode" if order_by.to_s == "destinations.name"

    order_by += " ASC" if options[:order_desc] == 0 and order_by != ""
    order_by += " DESC"if options[:order_desc] == 1 and order_by != ""
    return without, order_by
  end


=begin rdoc
 Transaltes order_by param to database fields for summary report.
=end

  def summary_order_by(params, options)
    case params[:order_by].to_s
    when "orig_name"         then order_by = "users.first_name"
    when "orig_calls"        then order_by = "total_calls"
    when "orig_exec_billsec" then order_by = "exact_billsec"
    when "orig_billsec"      then order_by = "originator_billsec"
    when "orig_price"        then order_by = "originator_price"

    when "term_name"         then order_by = "provider_name"
    when "term_calls"        then order_by = "total_calls"
    when "term_exec_billsec" then order_by = "exact_billsec"
    when "term_billsec"      then order_by = "provider_billsec"
    when "term_price"        then order_by = "provider_price"
    else
      options[:order_by] ? order_by = options[:order_by] : order_by = ""
    end
    without = order_by

    order_by = "users.first_name " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", users.last_name" if order_by.to_s == "users.first_name"

    order_by += " ASC" if options[:order_desc] == 0 and order_by != ""
    order_by += " DESC"if options[:order_desc] == 1 and order_by != ""
    return without, order_by
  end

  def find_call
    @call = Call.find(:first, :conditions => ["id = ?", params[:id]])
    unless @call
      flash[:notice] = _("Call_not_found")
      redirect_to :controller => "callc", :action => "main" and return false
    end

    # only admin and accountant can view call info
    if current_user and current_user.is_not_admin? and current_user.is_not_accountant?
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to :controller => :callc, :action => :main and return false
    end

  end

end
