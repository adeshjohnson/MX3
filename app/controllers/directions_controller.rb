# -*- encoding : utf-8 -*-
class DirectionsController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_destination, :only => [:destination_edit, :destination_update]
  before_filter :find_direction, :only => [:edit, :update, :destroy, :stats]

  def list
    @page_title = _('Directions')
    @directions = Direction.find(:all, :order => "name")
    respond_to do |format|
      format.html {}
      format.json {
        render :json => @directions.map { |d| [d.code.to_s, d.name.to_s] }.to_json
      }
    end
    store_location
  end

  def new
    @page_title = _('Create_new_direction')
    @page_icon = "add.png"
    @direction = Direction.new
  end

  def create
    @page_title = _('Create_new_direction')
    @direction = Direction.new(params[:direction])
    @direction.code = @direction.code.to_s.upcase
    if @direction.save
      flash[:status] = _('Direction_was_successfully_created')
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @page_title = _('Edit_direction') + ": " + @direction.name
    @page_icon = "edit.png"
  end

  def update
    if @direction.update_attributes(params[:direction])
      flash[:status] = _('Direction_was_successfully_updated')
      redirect_to :action => 'list', :id => @direction
    else
      render :action => 'edit'
    end
  end

  def destroy
    name = @direction.name.to_s
    if @direction.destinations.size > 0
      flash[:notice] = _('Cant_delete_direction_destinations_exist') + ": " + @direction.name
      redirect_to :action => 'list' and return false
    end

    @direction.destroy_everything
    flash[:status] = _('Direction') + " : #{name.to_s} " + _('deleted')
    redirect_to :action => 'list'
  end

  #========================================= Directions stats ======================================================
  def stats
    @page_title = _('Directions_stats')
    @page_icon = "chart_bar.png"

    change_date

    @html_flag = @direction.code
    @html_name = @direction.name
    @html_prefix_name = ""
    @html_prefix = ""

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({:a1 => session_from_date, :a2 => session_till_date, :code => @direction.code})

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

      sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[i] = res[0]["calls"].to_i
      @a_billsec[i] = res[0]["billsec"].to_i

      @a_avg_billsec[i] = 0
      @a_avg_billsec[i] = @a_billsec[i] / @a_calls[i] if @a_calls[i] > 0

      @t_calls += @a_calls[i]
      @t_billsec += @a_billsec[i]

      sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = calls.prefix) "+
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

  def find_direction
    @direction = Direction.find(:first, :conditions => {:id => params[:id]})
    unless @direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

end
