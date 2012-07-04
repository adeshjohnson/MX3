# -*- encoding : utf-8 -*-
class DestinationGroupsController < ApplicationController
  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update, :dg_add_destinations, :dg_destination_delete]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_destination, :only => [:dg_destination_delete, :dg_destination_stats]
  before_filter :find_destination_group, :only => [:bulk_management_confirmation, :bulk_assign, :edit, :update, :destroy, :destinations, :dg_new_destinations, :dg_add_destinations, :dg_list_user_destinations, :stats]

  def list
    @page_title = _('Destination_groups')
    @help_link = "http://wiki.kolmisoft.com/index.php/Destinations_Groups"

    @st = "A"
    @st = params[:st].upcase if params[:st]
    @destinationgroups = Destinationgroup.find(:all, :conditions => ["name like ?", @st+'%'], :order => "name ASC, desttype ASC")
    store_location
  end

  def list_json
    groups = Destinationgroup.find(:all, :select => "id, name, desttype", :order => "name ASC, desttype ASC").map { |dg| [dg.id.to_s, [dg.name.to_s, dg.desttype.to_s].join(" ")] }
    render :json => ([["none", _('Not_assigned')]] + groups).to_json
  end

  def new
    @page_title = _('New_destination_group')
    @dg = Destinationgroup.new
  end

  def create
    @dg = Destinationgroup.new(params[:dg])
    if @dg.save
      flash[:status] = _('Destination_group_was_successfully_created')
      redirect_to :action => 'list', :st => @dg.name[0, 1]
    else
      flash[:notice] = _('Destination_group_was_not_created')
      redirect_to :action => 'new'
    end
  end

  def edit
    @page_title = _('Edit_destination_group')
  end

  def update
    if @dg.update_attributes(params[:dg])
      flash[:status] = _('Destination_group_was_successfully_updated')
      redirect_to :action => 'list', :st => @dg.name[0, 1]
    else
      flash[:notice] = _('Destination_group_was_not_updated')
      redirect_to :action => 'new'
    end
  end

  def destroy
    if @dg.rates.size > 0 or @dg.customrates.size > 0
      flash[:notice] = _('Cant_delete_destination_group_rates_exist') + ": #{@dg.name} #{@dg.desttype}"
      redirect_to :action => 'list', :st => @dg.name[0, 1] and return false
    end

    sql = "UPDATE destinations SET destinationgroup_id = 0 WHERE destinationgroup_id = '#{@dg.id}'"
    res = ActiveRecord::Base.connection.update(sql)

    @dg.destroy
    flash[:status] = _('Destination_group_deleted') + ": #{@dg.name} #{@dg.desttype}"
    redirect_to :action => 'list', :st => @dg.name[0, 1]
  end

  def destinations
    @page_title = _('Destinations')
    @destinations = @destgroup.destinations
  end

  def dg_new_destinations

    @free_dest_size = Destination.count(:all, :conditions => ['destinationgroup_id < ?', 1])

    @page_title = _('New_destinations')

    @st = params[:st].blank? ? "A" : params[:st].upcase

    @page = 1
    @page = params[:page].to_i if params[:page]
    items_per_page = session[:items_per_page]
    @free_destinations = @destgroup.free_destinations_by_st(@st)
    @total_pages = (@free_destinations.size.to_f / session[:items_per_page].to_f).ceil

    @destinations = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = (@free_destinations.size - 1) if iend > (@free_destinations.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @destinations << @free_destinations[i]
    end

    @letter_select_header_id = @destgroup.id
    @page_select_header_id = @destgroup.id
  end


  def dg_add_destinations

    @st = params[:st].upcase if params[:st]

    @free_destinations = @destgroup.free_destinations_by_st(@st)

    #my_debug @free_destinations.size

    for fd in @free_destinations
      if params[fd.prefix.intern] == "1"
        sql = "UPDATE destinations SET destinationgroup_id = '#{@destgroup.id}' WHERE id = '#{fd.id}'"
        #  INSERT INTO destgroups (destinationgroup_id, prefix) VALUES ('#{@destgroup.id}', '#{fd.prefix.to_s}')"
        res = ActiveRecord::Base.connection.update(sql)
      end
    end

    flash[:status] = _('Destinatios_added')
    redirect_to :action => :destinations, :id => @destgroup.id
  end


  def dg_destination_delete
    @destgroup = Destinationgroup.find_by_id(params[:dg_id])
    unless @destgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :index and return false
    end
    sql = "UPDATE destinations SET destinationgroup_id = 0 WHERE id = '#{@destination.id}' "
    #    DELETE FROM destgroups WHERE destinationgroup_id = '#{@destgroup.id}' AND prefix = '#{@dest.prefix.to_s}'"
    res = ActiveRecord::Base.connection.update(sql)

    flash[:status] = _('Destination_deleted')
    redirect_to :action => :destinations, :id => @destgroup.id
  end

  #for final user

  def dg_list_user_destinations
    @page_title = _('Destinations')
    @destinations = @destgroup.destinations
    render(:layout => "layouts/mor_min")
  end


  def dest_mass_update
    @page_title = _('Destination_mass_update')
    @page_icon = "application_edit.png"

    @prefix_s = params[:prefix_s].blank? ? "%" : params[:prefix_s]
    @subcode_s = params[:subcode_s].blank? ? '%' : params[:subcode_s]
    @name_s = params[:name_s].blank? ? '%' : params[:name_s]
    @name = params[:name].blank? ? '' : params[:name]
    @subcode = params[:subcode].blank? ? '' : params[:subcode]


    if (@name != "" || @subcode != "")

      @prefix_s = session[:prefix_s]
      @subcode_s = session[:subcode_s]
      @name_s = session[:name_s]

      @destinations = Destination.find(:all,
                                       :conditions => "prefix LIKE '" + @prefix_s + "' and subcode LIKE '" + @subcode_s + "' and name LIKE '" + @name_s + "'")
      for destination in @destinations
        if (@name != "" and @subcode != "")
          destination.update_attributes(:subcode => @subcode, :name => @name)
        else
          if @subcode != ""
            destination.update_attributes(:subcode => @subcode)
          else
            if (@name != "")
              destination.update_attributes(:name => @name)
            end
          end
        end
      end
      flash[:status] = _('Destinations_updated')
    end

    @destinations = Destination.find(:all,
                                     :conditions => "prefix LIKE '" + @prefix_s + "' and subcode LIKE '" + @subcode_s + "' and name LIKE '" + @name_s + "'")

    session[:prefix_s] = @prefix_s
    session[:subcode_s] = @subcode_s
    session[:name_s] = @name_s
  end


  def destinations_to_dg

    @page_title = _('Destinations_without_Destination_Groups')
    @page_icon = 'wrench.png'

    session[:destinations_destinations_to_dg_options] ? @options = session[:destinations_destinations_to_dg_options] : @options = {}
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page] or @options[:page] <= 0)

    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "country" if !@options[:order_by])

    @options[:order] = Destinationgroup.destinationgroups_order_by(params, @options)

    @total_pages = (Destination.count(:all, :conditions => "destinationgroup_id = 0").to_f/session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages.to_i if @total_pages.to_i < @options[:page].to_i and @total_pages > 0
    page = @options[:page]

    @destinations_without_dg = Destination.select_destination_assign_dg(page, @options[:order])
    dgs = Destinationgroup.find(:all, :select => "id, CONCAT(name, ' ', desttype) as gname", :order => "name ASC, desttype ASC")
    @dgs = dgs.map { |d| [d.gname.to_s, d.id.to_s] }

    session[:destinations_destinations_to_dg_options] = @options
  end

  def destinations_to_dg_update
    @options = session[:destinations_destinations_to_dg_options]
    ds = Destination.select_destination_assign_dg(session[:destinations_destinations_to_dg_options][:page], "name")
    dgs = []
    ds.each { |d| dgs << d.id.to_s }
    if dgs and dgs.size.to_i > 0
      @destinations_without_dg = Destination.find(:all, :conditions => "id IN (#{dgs.join(',')})")
      counter = 0
      if @destinations_without_dg and @destinations_without_dg.size.to_i > 0
        size = @destinations_without_dg.size
        for dest in @destinations_without_dg
          if params[("dg" + dest.id.to_s).intern] and params[("dg" + dest.id.to_s).intern].length > 0
            dest.destinationgroup_id = params[("dg" + dest.id.to_s).intern]
            dest.subcode = params[("subcode" + dest.id.to_s).intern]
            dest.save
            counter += 1
          end
        end

        session[:integrity_check] = FunctionsController.integrity_recheck

        not_updated = size - counter
      end
      if not_updated == 0
        flash[:status] = _('Destinations_updated')
      else
        flash[:notice] = "#{not_updated} " + _('Destinations_not_updated')
        flash[:status] = "#{counter} " +_('Destinations_updated_successfully')
      end
    else
      flash[:notice] = _('No_Destinations')
    end

    redirect_to :action => 'destinations_to_dg' and return false
  end

  def auto_assign_warning
    @page_title = _('Destinations_Auto_assign_warning')
    @page_icon = 'exclamation.png'
  end

  def auto_assign_destinations_to_dg
    Destination.auto_assignet_to_dg
    flash[:status] = _('Destinations_assigned')
    redirect_to :controller => "functions", :action => 'integrity_check' and return false
  end

  def bulk_management_confirmation
    @page_title = _('Bulk_management')
    @page_icon = "edit.png"
    search = params[:prefix].to_s.include?('%') ? params[:prefix].to_s.delete("%") : params[:prefix].to_s + '$'
    @destinations = Destination.find(:all, :conditions => ['prefix REGEXP ?', '^' + search], :include => [:destinationgroup], :order => 'prefix ASC')
    begin
      @destinations = Destination.find(:all, :conditions=>['prefix REGEXP ?', '^' + search], :include=>[:destinationgroup], :order=>'prefix ASC')
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to :controller => :directions, :action =>:list and return false
    end
    @prefix = params[:prefix]
    @type = params[:type]
  end

  def bulk_assign
    search = params[:prefix].to_s.include?('%') ? params[:prefix].to_s.delete("%") : params[:prefix].to_s + '$'
    begin
      @destinations = Destination.find(:all, :conditions=>['prefix REGEXP ?', '^' + search], :include=>[:destinationgroup], :order=>'prefix ASC')
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to :controller => :directions, :action =>:list and return false
    end
    @prefix = params[:prefix]
    @type = params[:type]
    for d in @destinations
      d.destinationgroup_id = @dg.id
      d.subcode = q(@type) if @type and !@type.blank?
      d.save
    end
    pr = _('assigned_to')
    flash[:status] = _('Destinations') + ': ' + @destinations.size.to_s + ' ' + pr + ' - ' + @dg.name
    redirect_back_or_default('/callc/main')
  end

  #========================================= Destinations group stats ======================================================

  def stats
    @page_title = _('Destination_group_stats')
    @page_icon = "chart_bar.png"

    change_date

    @html_flag = @destinationgroup.flag
    @html_name = @destinationgroup.name + " " + @destinationgroup.desttype
    @html_prefix_name = ""
    @html_prefix = ""

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({:a1 => session_from_date, :a2 => session_till_date, :code => @destinationgroup.flag})

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

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    i = 0
    while @sdate < @edate
      @a_date[i] = @sdate.strftime("%Y-%m-%d")

      @a_calls[i] = 0
      @a_billsec[i] = 0
      @a_calls2[i] = 0

      sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{@destinationgroup.flag}' ) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[i] = res[0]["calls"].to_i
      @a_billsec[i] = res[0]["billsec"].to_i


      @a_avg_billsec[i] = 0
      @a_avg_billsec[i] = @a_billsec[i] / @a_calls[i] if @a_calls[i] > 0


      @t_calls += @a_calls[i]
      @t_billsec += @a_billsec[i]

      sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{@destinationgroup.flag}' ) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[i] = res2[0]["calls2"].to_i

      @a_ars2[i] = (@a_calls[i].to_f / @a_calls2[i]) * 100 if @a_calls[i] > 0
      @a_ars[i] = nice_number @a_ars2[i]


      @sdate += (60 * 60 * 24)
      i+=1
    end

    index = i

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0


    #formating graph for Calls

    ine=0
    @Calls_graph2 =""
    while ine <= index
      -1
      @Calls_graph2 +=@a_date[ine].to_s + ";" + @a_calls[ine].to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Calltime

    i=0
    @Calltime_graph =""
    for i in 0..@a_billsec.size-1
      @Calltime_graph +=@a_date[i].to_s + ";" + (@a_billsec[i] / 60).to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Avg.Calltime

    ine=0
    @Avg_Calltime_graph =""
    while ine <= index
      -1
      @Avg_Calltime_graph +=@a_date[ine].to_s + ";" + @a_avg_billsec[ine].to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Asr calls

    ine=0
    @Asr_graph =""
    while ine <= index
      -1
      @Asr_graph +=@a_date[ine].to_s + ";" + @a_ars[ine].to_s + "\\n"
      ine=ine +1
    end

  end

  #========================================= Dg destination stats ======================================================

  def dg_destination_stats
    @page_title = _('Dg_destination_stats')
    @page_icon = "chart_bar.png"
    @destinationgroup = Destinationgroup.find_by_id(params[:dg_id])
    unless @destinationgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :index and return false
    end

    change_date
    @dest = @destination
    @html_flag = @destinationgroup.flag
    @html_name = @destinationgroup.name + " " + @destinationgroup.desttype
    @html_prefix_name = _('Prefix') + " : "
    @html_prefix = @dest.prefix

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({:a1 => session_from_date, :a2 => session_till_date, :destination => @dest.prefix, :code => @destinationgroup.flag})

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

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    i = 0
    while @sdate < @edate
      @a_date[i] = @sdate.strftime("%Y-%m-%d")

      @a_calls[i] = 0
      @a_billsec[i] = 0
      @a_calls2[i] = 0

      sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{@destinationgroup.flag}' ) AND (destinations.prefix = '#{@dest.prefix}') AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[i] = res[0]["calls"].to_i
      @a_billsec[i] = res[0]["billsec"].to_i


      @a_avg_billsec[i] = 0
      @a_avg_billsec[i] = @a_billsec[i] / @a_calls[i] if @a_calls[i] > 0


      @t_calls += @a_calls[i]
      @t_billsec += @a_billsec[i]

      sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{@destinationgroup.flag}' ) AND (destinations.prefix = '#{@dest.prefix}') AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[i] = res2[0]["calls2"].to_i

      @a_ars2[i] = (@a_calls[i].to_f / @a_calls2[i]) * 100 if @a_calls[i] > 0
      @a_ars[i] = nice_number @a_ars2[i]


      @sdate += (60 * 60 * 24)
      i+=1
    end

    index = i

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    # Tariff and rate

    @rate = Rate.find(:all, :conditions => ["destination_id=?", @dest.id])

    @rate_details = []
    @rate1 = []
    @rate2 = []
    for rat in @rate
      unless rat.tariff.nil?
        if rat.tariff.purpose == "provider"
          @rate1[rat.id]=rat.tariff.name
          @rate_details[rat.id] = Ratedetail.find(:first, :conditions => ["rate_id=?", rat.id])
        else
          if rat.tariff.purpose == "user_wholesale"
            @rate2[rat.id]=rat.tariff.name
            @rate_details[rat.id] = Ratedetail.find(:first, :conditions => ["rate_id=?", rat.id])
          end
        end
      end
    end

    #===== Graph =====================

    #formating graph for Calls

    ine=0
    @Calls_graph2 =""
    while ine <= index
      -1
      @Calls_graph2 +=@a_date[ine].to_s + ";" + @a_calls[ine].to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Calltime

    i=0
    @Calltime_graph =""
    for i in 0..@a_billsec.size-1
      @Calltime_graph +=@a_date[i].to_s + ";" + (@a_billsec[i] / 60).to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Avg.Calltime

    ine=0
    @Avg_Calltime_graph =""
    while ine <= index
      -1
      @Avg_Calltime_graph +=@a_date[ine].to_s + ";" + @a_avg_billsec[ine].to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Asr calls

    ine=0
    @Asr_graph =""
    while ine <= index
      -1
      @Asr_graph +=@a_date[ine].to_s + ";" + @a_ars[ine].to_s + "\\n"
      ine=ine +1
    end

  end

  private

  def find_destination_group
    @dg = Destinationgroup.find(:first, :conditions => ['id=?', params[:id]])
    unless @dg
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
    @destgroup = @dg
    @destinationgroup = @dg
  end

  def find_destiantion
    @destination=Destination.find(:first, :conditions => ['id=?', params[:id]])
    unless @destination
      flash[:notice]=_('Destination_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
    @dest = @destination
  end
end
