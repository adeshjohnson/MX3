# -*- encoding : utf-8 -*-
class IvrTimePeriodsController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_time_periods, :only => [:destroy, :edit, :update]
  before_filter :check_reseller


  def index
    @page_title = _('IVR_Timeperiods')
    @page_icon = "play.png"
    @periods = current_user.ivr_timeperiods
  end

  def new
    @page_title = _('New_IVR_Timeperiods')
    @page_icon = "add.png"
  end

  def create
    @period = IvrTimeperiod.new(params[:period])

    @period.name = params[:period][:name] if params[:period] and params[:period][:name]
    @period.start_month = params[:period][:start_month] if params[:period] and params[:period][:start_month]
    @period.start_day = params[:period][:start_day] if params[:period] and params[:period][:start_day]
    @period.start_weekday = params[:period][:start_weekday] if params[:period][:start_weekday]
    @period.start_hour = params[:period][:start_hour]
    @period.start_minute = params[:period][:start_minute]
    @period.end_month = params[:period][:end_month] if params[:period] and params[:period][:end_month]
    @period.end_day = params[:period][:end_day] if params[:period] and params[:period][:end_day]
    @period.end_weekday = params[:period][:end_weekday] if params[:period][:end_weekday]
    @period.end_hour = params[:period][:end_hour]
    @period.end_minute = params[:period][:end_minute]
    if params[:period][:name] and params[:period][:name].size > 0
      if @period.save
        flash[:status] = _("Timeperiod_Created")
      else
        flash[:notice] = _("Error_While_Creating_Timeperiod")
      end
    else
      flash[:notice] = _("Cannot_Create_Timeperdiod_Without_Name")
      render(:action => :new) and return false
    end
    redirect_to :action => :index
  end

  def destroy
    if !current_user.dialplans.find(:first, :conditions => ["dptype = 'ivr' and (data1= ? or data3 = ? or data5 = ?)", @period.id, @period.id, @period.id])
      @period.destroy
      flash[:status] = _("IVR_Timeperiod_Deleted")
    else
      flash[:notice] = _("IVR_Timeperiod_Is_In_Use")
    end
    redirect_to :action => :index
  end

  def edit

    @page_title = _('Edit_IVR_Timeperiods')
    @page_icon = "edit.png"

    @start_date = {}
    @end_date = {}

    @start_date["month"] = @period.start_month
    @start_date["day"] = @period.start_day
    @end_date["month"]=@period.end_month
    @end_date["day"]=@period.end_day
  end

  def update
    @period.name = params[:period][:name]
    @period.start_month = params[:period][:start_month] if params[:period] and params[:period][:start_month]
    @period.start_day = params[:period][:start_day] if params[:period] and params[:period][:start_day]
    #    period.start_month = start_year["month"] if start_year and start_year["month"]
    #    period.start_day = start_year["day"] if start_year and start_year["day"]
    @period.start_weekday = params[:period][:start_weekday] if params[:period][:start_weekday]
    @period.start_hour = params[:period][:start_hour]
    @period.start_minute = params[:period][:start_minute]

    @period.end_month = params[:period][:end_month] if params[:period] and params[:period][:end_month]
    @period.end_day = params[:period][:end_day] if params[:period] and params[:period][:end_day]
    #    period.end_month = end_year["month"] if  end_year and end_year["month"]
    #    period.end_day = end_year["day"] if end_year and end_year["day"]
    @period.end_weekday = params[:period][:end_weekday] if params[:period][:end_weekday]
    @period.end_hour = params[:period][:end_hour]
    @period.end_minute = params[:period][:end_minute]

    if @period.save
      critical_update(@period)
      flash[:status] = _("Timeperiod_Updated")
    else
      flash[:notice] = _("Error")
    end
    redirect_to :action => :index

  end

  private

  def find_ivr_time_periods
    @period = current_user.ivr_timeperiods.find(:first, :conditions => ["id = ?", params[:id]])
    unless @period
      flash[:notice] = _('IVR_Timeperiod_Not_Found')
      redirect_to :action => :index and return false
    end
  end

=begin
  Is called when some value is changed and there is need to regenerate coresponding extlines.
  +object+ - IvrAction, IvrBlock, IvrExtension, IvrTimeperiod and of those objects are accepted as params. Finds IvrBlock and regenerates Extlines for this block.
=end

  def critical_update(object)

    plans = current_user.dialplans.find(:all, :conditions => ["dptype = 'ivr' and (data1 = ? or data3 = ? or data5 = ?)", object.id, object.id, object.id])
    for plan in plans do
      plan.regenerate_ivr_dialplan
    end

  end

  def check_reseller
    if reseller? and current_user.own_providers.to_i == 0
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main
    end
  end

end
