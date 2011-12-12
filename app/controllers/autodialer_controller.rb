class AutodialerController < ApplicationController

  layout "callc"

  before_filter :check_localization
  #before_filter :authorize_admin, :only => [:campaigns]
  before_filter :authorize
  before_filter :find_campaign, :only=>[:campaign_destroy, :view_campaign_actions, :campaign_update,:redial_all_failed_calls, :action_add, :campaign_actions, :import_numbers_from_file, :campaign_edit, :campaign_change_status, :campaign_numbers, :delete_all_numbers]
  before_filter :find_campaign_action, :only=>[:play_rec, :action_update, :action_edit, :action_destroy]
  before_filter :find_adnumber, :only=>[:reactivate_number]
  before_filter :check_params_campaign, :only=>[:campaign_create, :campaign_update]

  verify :method => :post, :only => [ :redial_all_failed_calls, :campaign_update, :campaign_create, :campaign_destroy, :action_destroy, :action_add, :action_update ],
    :redirect_to => { :action => :index },
    :add_flash => { :notice => _('Dont_be_so_smart'),
    :params => {:dont_be_so_smart => true}}

  def index
    if session[:usertype] == 'admin'
      campaigns
      render :action => :campaigns and return false
    else
      user_campaigns
      render :action => :user_campaigns and return false
    end
  end

  # --------- Admin campaigns -------------

  def campaigns
    @page_title = _('Campaigns')

    @users = []

    @all_users = User.find(:all, :conditions => "hidden = 0")
    for user in @all_users
      @users << user if user.campaigns.size > 0
    end

  end


  def view_campaign_actions
    @page_title = _('Actions_for_campaign') + ": " + @campaign.name
    @page_icon = "actions.png"
    @actions = @campaign.adactions
  end

  # ------------ User campaigns -------------

  def user_campaigns
    @page_title = _('Campaigns')
    @user = current_user
    @campaigns = @user.campaigns
  end


  def campaign_new
    @user = current_user

    if current_user.usertype == 'user' or current_user.usertype == 'accountant'
      @devices = current_user.devices.find(:all, :conditions => "device_type != 'FAX'")
    else
      @devices = Device.find_all_for_select(corrected_user_id)
    end

    if @devices.size == 0
      flash[:notice] = _('Please_create_device_for_campaign')
      redirect_to :action => 'user_campaigns' and return false
    end

    @page_title = _('New_campaign')
    @page_icon = "add.png"

    @campaign = Campaign.new

    @ctypes = ["simple"]

    t0 = Time.mktime(Time.now.year, Time.now.month, Time.now.day, "00", "00")
    t1 = Time.mktime(Time.now.year, Time.now.month, Time.now.day, "23", "59")

    @from_hour = t0.hour
    @from_min = t0.min
    @till_hour = t1.hour
    @till_min = t1.min
  end


  def campaign_create
    @campaign = Campaign.new(params[:campaign])
    @campaign.user_id = session[:user_id]
    @campaign.status = "disabled"

    time_from = params[:time_from][:hour] + ":" + params[:time_from][:minute] + ":00"
    time_till = params[:time_till][:hour] + ":" + params[:time_till][:minute] + ":59"

    @campaign.start_time = time_from
    @campaign.stop_time = time_till
    #
    #    @campaign.retry_time = 60 if params[:campaign][:retry_time].to_i < 60
    #    @campaign.wait_time = 30 if params[:campaign][:wait_time].to_i < 30

    if @campaign.save
      flash[:status] = _('Campaign_was_successfully_created')
      redirect_to :action => 'user_campaigns'
    else
      flash_errors_for(_('Campaign_was_not_created'), @campaign)
      redirect_to :action => 'campaign_new'
    end
  end


  def campaign_destroy
    @campaign.destroy
    flash[:notice] = _('Campaign_deleted')
    redirect_to :action => 'user_campaigns'
  end


  def campaign_edit
    @page_title = _('Edit_campaign')
    @page_icon = "edit.png"
    @ctypes = ["simple"]
    @from_hour = @campaign.start_time.hour
    @from_min = @campaign.start_time.min
    @till_hour = @campaign.stop_time.hour
    @till_min = @campaign.stop_time.min
    @user = current_user
    if current_user.usertype == 'user' or current_user.usertype == 'accountant'
      @devices = current_user.devices.find(:all, :conditions => "device_type != 'FAX'")
    else
      @devices = Device.find_all_for_select(corrected_user_id)
    end
  end


  def campaign_update
    @campaign.update_attributes(params[:campaign])
    time_from = params[:time_from][:hour] + ":" + params[:time_from][:minute] + ":00"
    time_till = params[:time_till][:hour] + ":" + params[:time_till][:minute] + ":59"

    @campaign.start_time = time_from
    @campaign.stop_time = time_till

    #    @campaign.retry_time = 60 if params[:campaign][:retry_time].to_i < 60
    #    @campaign.wait_time = 30 if params[:campaign][:wait_time].to_i < 30

    if @campaign.save
      flash[:status] = _('Campaigns_details_was_successfully_changed')
      redirect_to :action => 'user_campaigns'
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      redirect_to :action => 'campaign_edit', :id => @campaign.id
    end
  end


  def campaign_change_status
    if @campaign.status == "enabled"
      @campaign.status = "disabled"
      flash[:notice] = _('Campaign_stopped') + ": " + @campaign.name
    else
      flash[:notice] = _('No_actions_for_campaign') + ": " + @campaign.name         if @campaign.adactions.size == 0
      flash[:notice] = _('No_free_numbers_for_campaign') + ": " + @campaign.name         if @campaign.new_numbers_count == 0

      if @campaign.adactions.size > 0 and @campaign.new_numbers_count > 0
        @campaign.status = "enabled"
        flash[:status] = _('Campaign_started') + ": " + @campaign.name
      end
    end
    if @campaign.save
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
    end
    redirect_to :action => 'user_campaigns'
  end

  # --------- Numbers ---------

  def campaign_numbers
    @page_title = _('Numbers_for_campaign') + ": " + @campaign.name
    @page_icon = "details.png"

    fpage, @total_pages, options = pages_validator(params, @campaign.adnumbers.size.to_f)
    @page = options[:page]
    @numbers = @campaign.adnumbers.find(:all, :offset=>fpage, :limit=>session[:items_per_page])
  end


  def delete_all_numbers
    for num in @campaign.adnumbers
      num.destroy
    end

    flash[:notice] = _('All_numbers_deleted')
    redirect_to :action => 'campaign_numbers', :id => params[:id]
  end


  def import_numbers_from_file

    @page_title = _('Number_import_from_file')
    @page_icon = "excel.png"

    @step = 1
    @step = params[:step].to_i if params[:step]


    if @step == 2
      if params[:file] or session[:file]
        if  params[:file].size.to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_numbers_from_file", :id => @campaign.id, :step => "1" and return false
        end
        if params[:file]
          @file = params[:file]
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            #MorLog.my_debug(@file.class.to_s)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_numbers_from_file", :id => @campaign.id, :step => "1" and return false
          end
          @file.rewind
          session[:file] = @file.read if @file.size > 0
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_numbers_from_file", :id => @campaign.id, :step => "1" and return false
        end

        @file = session[:file]


        arr = @file.split("\n")
        @total_numbers, imported_numbers = arr.size, 0

        for line in arr
          if line.strip =~ /\A(\+|\#){0,1}\d+\Z/
            num = Adnumber.new
            num.number = line.strip
            num.status = 'new'
            num.campaign_id = @campaign.id
            num.save
            imported_numbers += 1
          end
        end

        if @total_numbers == imported_numbers
          flash[:status] = _('Numbers_imported')
        else
          flash[:notice] = _('M_out_of_n_numbers_imported', imported_numbers, @total_numbers)
        end
      else
        flash[:notice] = _('Numbers_not_imported')
      end



      redirect_to :action => 'campaign_numbers', :id => @campaign.id

    end

  end


  def reactivate_number
    @number.status = "new"
    @number.save
    flash[:status] = _('Number_reactivated') + ": " + @number.number
    redirect_to :action => 'campaign_numbers', :id => @number.campaign_id

  end

  #-------------- Actions --------------

  def campaign_actions
    @page_title = _('Actions_for_campaign') + ": " + @campaign.name
    @page_icon = "actions.png"
    @actions = @campaign.adactions
  end


  def action_add
    action_type = params[:action_type]
    action = Adaction.new({:priority => @campaign.adactions.size + 1, :campaign_id => @campaign.id, :action => action_type})
    action.data = "silence1" if action_type == "PLAY"
    action.data = "1" if action_type == "WAIT"
    action.save
    flash[:status] = _('Action_added')
    redirect_to :action => 'campaign_actions', :id => @campaign.id
  end


  def action_destroy
    campaign_id = @action.campaign_id
    if @action.action == "PLAY"
      path , final_path = @action.campaign.final_path
      Audio.rm_sound_file("#{final_path}/#{@action.file_name}.wav")
    end
    @action.destroy
    flash[:notice] = _('Action_deleted')
    redirect_to :action => 'campaign_actions', :id => campaign_id
  end


  def action_edit
    @page_title = _('Edit_action')
    @page_icon = "edit.png"
    @campaign = @action.campaign
    @ivrs = current_user.ivrs if allow_manage_providers?
  end

  def action_update
    path , final_path = @action.campaign.final_path

    if @action.action == "WAIT"
      @action.data = params[:wait_time].to_i
      @action.data = 1 if @action.data < 1
      @action.save
    end

    if @action.action == "IVR" and allow_manage_providers?
      if current_user.ivrs(params[:ivr].to_i)
        @action.data = params[:ivr].to_i
        @action.save
      else
        dont_be_so_smart
      end
    end

    if @action.action == "PLAY"
      notice, name = Audio.create_file(params[:file], @action.campaign, "/var/lib/asterisk/sounds/mor/ad/")
      if notice.blank?
        @action.data = name
        @action.save
      else
        flash[:notice] = notice
      end
    end

    redirect_to :action => 'campaign_actions', :id => @action.campaign_id

  end


  def play_rec
    @filename2 = @action.file_name
    @page_title = ""
    @Adaction_Folder = Web_Dir + "/ad_sounds/"
    @title = confline("Admin_Browser_Title")
    render(:layout => "play_rec")
  end



  def redial_all_failed_calls
    if Adnumber.update_all(" status = 'new' , executed_time = NULL", "status = 'executed' and campaign_id = #{@campaign.id}")
      flash[:status] = _('All_calls_failed_redial_was_successful')
    else
      flash[:notice] = _('All_calls_failed_redial_was_not_successful')
    end
    redirect_to :action => :index and return false
  end

  def campaign_statistics

    @page_title = _('Campaign_Stats')
    change_date
    @date = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
    year, month, day = last_day_month('till')
    @edate = Time.mktime(year,month,day)
    @campaign_id = params[:campaign_id] ? params[:campaign_id].to_i : -1
    @campaigns = Campaign.find(:all)
    @Calltime_graph =""
    @answered_percent = @no_answer_percent = @failed_percent = @busy_percent = 0
    @calls_busy = @calls_failed = @calls_no_answer = @calls_answered = 0
    @numbers = []
    @channels = []
    @channels_number = []

    #if selected campaign
    if @campaign_id != -1
      @campaing_stat = Campaign.find_by_id(@campaign_id)
      data = Adnumber.find(:all, :conditions=>['campaign_id = ?',@campaign_id])
      data.each do |numbers|
        @numbers << numbers.number
        @channels << numbers.channel
      end
      
      #if there are numbers
      if @numbers and !@numbers.compact.empty?
        #count dialed, completed, total call time, total call time longer than 10s
        @dialed = @campaing_stat.executed_numbers_count.to_s
        @complete = @campaing_stat.completed_numbers_count
        #if there are channels in db
        if @channels and !@channels.compact.empty?
          # create regexp ('Local/number@|..')
          @channels.each do |channel|@channels_number << channel.scan(/(.*@)/).flatten.first if channel end
          @channels_number = @channels_number.join('|')
          #find device
          @scr_device =  @campaing_stat.device_id
          @total = @campaing_stat.count_completed_user_billsec(@scr_device, @channels_number, session_from_date, session_till_date)
          @total_longer_than_10 = @campaing_stat.count_completed_user_billsec_longer_than_ten(@scr_device, @channels_number, session_from_date, session_till_date)
          country_times_pie= "\""
          if @channels and @channels_number != ""
            @calls = Call.find_by_sql("select count(*) as counted_calls, disposition from calls where src_device_id = #{@scr_device} AND channel REGEXP '#{@channels_number}' AND disposition in ('ANSWERED', 'NO ANSWER','FAILED','BUSY') AND calldate BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' group by disposition")
            #count percent
            @calls.each do |call|
              @calls_answered =  call.counted_calls.to_i if call.disposition == 'ANSWERED'
              @calls_no_answer = call.counted_calls.to_i if call.disposition == 'NO ANSWER'
              @calls_failed  = call.counted_calls.to_i if call.disposition == 'FAILED'
              @calls_busy = call.counted_calls.to_i if call.disposition == 'BUSY'
            end
            @calls_all = @calls_answered+@calls_no_answer+@calls_failed+@calls_busy
            
            if  @calls_all.to_i > 0
              @answered_percent = @calls_answered*100/ @calls_all.to_i
              @no_answer_percent = @calls_no_answer*100/ @calls_all.to_i
              @failed_percent = @calls_failed*100/ @calls_all.to_i
              @busy_percent = @calls_busy*100/ @calls_all.to_i
            end
            #create string fo pie chart
            country_times_pie += "ANSWERED" + ";" + @calls_answered.to_s+ ";true\\n"
            country_times_pie += "NO ANSWER" +";" + @calls_no_answer.to_s+ ";false\\n"
            country_times_pie += "BUSY" +";" + @calls_busy.to_s+ ";false\\n"
            country_times_pie += "FAILED" + ";" +@calls_failed.to_s+ ";false\\n"
          else
            country_times_pie += _('No_result') + ";1;false\\n"
          end
          country_times_pie += "\""
          @pie_chart = country_times_pie

          i = 0
          @a_date = []
          @a_calls = []

          while @date < @edate
            @a_date[i] = @date.strftime("%Y-%m-%d")
            @a_calls[i] = 0
            sql = 'SELECT COUNT(calls.id) as \'calls\', SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as \'billsec\' FROM calls ' +
              'WHERE (calls.calldate BETWEEN \'' + @a_date[i] + ' 00:00:00\' AND \'' + @a_date[i] + " 23:59:59\' AND src_device_id = #{@scr_device} AND channel REGEXP '#{@channels_number}' )"
            res = ActiveRecord::Base.connection.select_all(sql)
            @a_calls[i] = res[0]["calls"].to_i
            @date += (60 * 60 * 24)
            i+=1
          end
          
          index = i
          ine = 0
          #create string fo column chart
          @Calls_graph = ""
          while ine <= index -1
            @Calls_graph +=@a_date[ine].to_s  + ";" + @a_calls[ine].to_s + "\\n"
            ine=ine +1
          end
        else
          flash[:notice] = _('No_calls_with_campaign') + @campaing_stat.name
        end
      else
        flash[:notice] = _('No_numbers_in_campaign') + @campaing_stat.name
        redirect_to :action => :campaign_statistics and return false
      end
    end
    
  end

  private

  def find_campaign
    if current_user.is_admin?
      @campaign = Campaign.find(:first, :conditions=>{:id=>params[:id]})
    else
      @campaign = current_user.campaigns.find(:first, :conditions=>{:id=>params[:id]})
    end

    unless @campaign
      flash[:notice] = _('Campaign_was_not_found')
      if current_user.is_admin?
        redirect_to :action => :campaigns and return false
      else
        redirect_to :action => :user_campaigns and return false
      end
    end
  end

  def find_campaign_action
    @action = Adaction.find(:first, :conditions=>{:id=>params[:id]}, :include=>[:campaign])
    unless @action
      flash[:notice] = _('Action_was_not_found')
      if current_user.is_admin?
        redirect_to :action => :campaigns and return false
      else
        redirect_to :action => :user_campaigns and return false
      end
    end

    a=check_user_id_with_session(@action.campaign.user_id)
    return false if !a
  end

  def find_adnumber
    @number = Adnumber.find(:first, :conditions=>{:id=>params[:id]}, :include=>[:campaign])
    unless @number
      flash[:notice] = _('Number_was_not_found')
      redirect_to :action => :index and return false
    end
    a=check_user_id_with_session(@number.campaign.user_id)
    return false if !a
  end

  def check_params_campaign
    if !params[:campaign] or !params[:time_from] or !params[:time_till]
      dont_be_so_smart
      redirect_to(:controller => "callc", :action => "main") and return false
    end
  end
end
