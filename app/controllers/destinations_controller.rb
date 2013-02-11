# -*- encoding : utf-8 -*-
class DestinationsController < ApplicationController
  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_destination, :only => [:edit, :update, :destroy]
  before_filter :find_direction, :only => [:list, :create, :stats, :new, :create]

  def list
    @page_title = _('Destinations')

    @page = 1
    @page = params[:page].to_i if params[:page]
    items_per_page = session[:items_per_page]
    @destinations2 = @direction.destinations_with_groups
    @total_pages = (@destinations2.size.to_d / items_per_page).ceil

    if @page > @total_pages
      redirect_to :action => :list, :page => @total_pages
    end

    @destinations = []
    iend = items_per_page * @page - 1
    iend = (@destinations2.size - 1) if iend > (@destinations2.size - 1)
    for i in (items_per_page * @page - items_per_page)..iend
      @destinations << @destinations2[i] if @destinations2[i]
    end

    @page_select_header_id = @direction.id

    store_location
  end

  def new
    @page_title = _('Add_new_destination')
    @page_icon = "add.png"

    @destination = Destination.new({:subcode => 'FIX'})
  end

  def create
    @page_title = _('Add_new_destination')

    params[:destination]["direction_code"] = @direction.code
    dest = Destination.find(:first, :conditions => ["prefix = ?", params[:destination][:prefix]])
    if dest
      flash[:notice] = _('Destination_exist_and_belong_to_Direction') + " : " + dest.direction.name.to_s
      redirect_to :action => 'new', :id => @direction and return false
    end

    params[:destination]["direction_code"] = @direction.code
    @dest = Destination.new(params[:destination])

#    dg =  Destinationgroup.find(:first, :conditions=>{:desttype=>@dest.subcode, :flag=>@direction.code.downcase})
#    @dest.destinationgroup_id = dg.id if dg
    if @dest.save
      flash[:status] = _('Destination_was_successfully_created')
    else
      flash[:notice] = _('Destination_was_not_successfully_created')
    end
    redirect_to :action => 'list', :id => @direction
  end

  def edit
    @page_title = _('Edit_destination')
    @page_icon = "edit.png"
    @direction = @destination.direction
    @page = params[:page]
  end

  def update
    params[:destination][:destinationgroup_id] = nil if params[:destination] and params[:destination][:destinationgroup_id] and params[:destination][:destinationgroup_id].to_s == "none"
    if @destination.update_attributes(params[:destination])
      @direction = @destination.direction
      flash[:status] = _('Destination_was_successfully_updated')
      redirect_to :action => 'list', :id => @direction
    else
      flash[:notice] = _('Such_destination_exists_already')
      redirect_to :action => 'edit', :id => @destination
    end
  end


  def destroy

    dd_id = @destination.direction.id
    if @destination.destroy
      flash[:status] = _('Destination_was_deleted')
    else
      flash_errors_for(_('Cant_delete_destination'), @destination)
    end
    redirect_back_or_default("/destinations/list/#{dd_id}")
  end


  #========================================= Destinations stats ======================================================

  def stats
    @page_title = _('Destination_stats')
    @page_icon = "chart_bar.png"
    @destination = Destination.where(:id => params[:des_id]).first
    unless @destination
      flash[:notice]=_('Destination_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
    change_date

    @html_flag = @direction.code
    @html_name = @direction.name
    @html_prefix_name = _('Prefix') + " : "
    @html_prefix = @destination.prefix

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({:a1 => session_from_date, :a2 => session_till_date, :destination => @destination.prefix, :code => @direction.code})

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

      sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = #{q(@destination.prefix)}) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[i] = res[0]["calls"].to_i
      @a_billsec[i] = res[0]["billsec"].to_i


      @a_avg_billsec[i] = 0
      @a_avg_billsec[i] = @a_billsec[i] / @a_calls[i] if @a_calls[i] > 0


      @t_calls += @a_calls[i]
      @t_billsec += @a_billsec[i]

      sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = #{q(@destination.prefix)}) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[i] = res2[0]["calls2"].to_i

      @a_ars2[i] = (@a_calls[i].to_d / @a_calls2[i]) * 100 if @a_calls2[i] > 0
      @a_ars[i] = nice_number @a_ars2[i]
      @sdate += (60 * 60 * 24)
      i+=1
    end

    index = i

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    # Tariff and rate

    @rate = Rate.find(:all, :conditions => ["destination_id=?", @destination.id])

    @rate_details = []
    @rate1 = []
    @rate2 = []
    for rat in @rate
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

    #===== Graph=====================
    #formating graph for Calls

    ine=0
    @Calls_graph2 =""
    while ine <= index - 1
      @Calls_graph2 +=@a_date[ine].to_s + ";" + @a_calls[ine].to_s + "\\n"
      ine= ine + 1
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
    while ine <= index - 1
      @Avg_Calltime_graph +=@a_date[ine].to_s + ";" + @a_avg_billsec[ine].to_s + "\\n"
      ine=ine +1
    end

    #formating graph for Asr calls

    ine=0
    @Asr_graph =""
    while ine <= index - 1
      @Asr_graph +=@a_date[ine].to_s + ";" + @a_ars[ine].to_s + "\\n"
      ine=ine +1
    end

  end

=begin
  If at least one destination found redirect to confirmation page, else
  redirect back to /destination_groups/list and inform user that nothing was found
=end
  def bulk_rename_confirm
    @prefix = params[:prefix]
    begin
      @destinations = Destination.dst_by_prefix(@prefix)
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to :controller => :directions, :action =>:list and return false
    end
    if @destinations.size > 0
      @destination_count = @destinations.size
      @destination_name = params[:destination]
    else
      flash[:notice] = _('No_destinations_found')
      redirect_to :controller => :destination_groups, :action => :list
    end
  end

=begin
  Update destination names by prefix that matches supplied pattern
  redirect back to /destination_groups/list and inform user that nothing was found
=end
  def bulk_rename
    Destination.rename_by_prefix(params[:destination], params[:prefix])
    flash[:status] = _('Destinations_were_renamed')
    redirect_to :controller => :destination_groups, :action => :list
  end

  private

  def find_direction
    @direction = Direction.find(:first, :conditions => {:id => params[:id]})
    unless @direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_destiantion
    @destination=Destination.find(:first, :conditions => {:id => params[:id]})
    unless @destination
      flash[:notice]=_('Destination_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end
end
