# -*- encoding : utf-8 -*-
class RecordingsController < ApplicationController

  layout "callc"


  @@view = [:index, :list, :play_rec]
  @@edit = [:edit, :update, :setup, :update_recordings, :calls2recordings_disabled, :destroy, :destroy_recording]

  before_filter { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@view, @@edit, {:role => "accountant", :right => :acc_recordings_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :check_localization
  before_filter :authorize
  before_filter :check_post_method, :only => [:destroy_recording, :destroy, :update, :update_recordings, :list_users_update]

  def index
    redirect_to :action => :list_recordings and return false
  end

  def setup
    @page_title = _('Recordings')
    @page_icon = "music.png"
    @devices = Device.find_by_sql("SELECT devices.* FROM devices JOIN users ON (devices.user_id = users.id) WHERE user_id > 0 AND users.hidden = 0 ORDER BY extension ASC")
  end

  def update_recordings
    for dev in Device.find(:all, :order => "extension ASC")
      dev.record_forced = 0
      dev.record_forced = 1 if params[dev.id.to_s] == "1"
      dev.save
    end
    redirect_to :action => 'setup' and return false
  end

  #maps calls to recordings
  def calls2recordings_disabled
    #cdr2calls
    recs = Recording.find(:all, :conditions => "call_id = '0'")

    temp = []
    for rec in recs
      date_before = Time.at(rec.datetime.to_f-2).strftime("%Y-%m-%d %H:%M:%S")
      date_after = Time.at(rec.datetime.to_f+2).strftime("%Y-%m-%d %H:%M:%S")
      #        my_debug date_before.to_s+date_after.to_s
      if call=Call.find(:first, :conditions => ["src_device_id = ? AND dst_device_id = ? AND calldate BETWEEN ? AND ?", rec.src_device_id, rec.dst_device_id, date_before, date_after])
        rec.call_id = call.id
        rec.save
        temp << call
      end
    end
    temp
  end

  def show
    @device = Device.find_by_id(params[:show_rec])
    unless @device
      flash[:notice] = _('Device_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end


    @user = @device.user

    @page_title = _('Recordings')
    @page_icon = "music.png"

    #calls2recordings
    change_date

    from_t = session[:current_user_time_from]
    till_t = session[:current_user_time_till]

    @page = 1
    @page = params[:page].to_i if params[:page]
    @from = ((@page-1) * session[:items_per_page]).to_i
    @to = (session[:items_per_page]).to_i
    @s_dev = @device.id
    #@recs = Recording.find(:all, :conditions => ["SUBSTRING(datetime,1,10) BETWEEN ? AND ? AND (src_device_id = ? OR dst_device_id = ?)",session_from_date,session_till_date, @device.id, @device.id], :order => "datetime DESC")

    #    sql = "SELECT * FROM recordings WHERE SUBSTRING(datetime,1,10) BETWEEN '#{session_from_date}' AND '#{session_till_date}' AND (src_device_id = '#{@device.id}' OR dst_device_id = '#{@device.id}') ORDER BY datetime DESC "
    sql = "SELECT recordings.*, providers.name AS provider_name FROM recordings LEFT JOIN calls ON recordings.call_id = calls.id LEFT JOIN providers ON providers.id = calls.provider_id WHERE recordings.datetime BETWEEN '#{from_t}' AND '#{till_t}' AND (recordings.src_device_id = '#{@device.id}' OR recordings.dst_device_id = '#{@device.id}') ORDER BY recordings.datetime DESC LIMIT #{@from}, #{@to}"

    my_debug sql

    @recs = Recording.find_by_sql(sql)
    @total_pages = Recording.count(:all, :conditions => "datetime BETWEEN '#{from_t}' AND '#{till_t}' AND (src_device_id = '#{@device.id}' OR dst_device_id = '#{@device.id}')")
    (@total_pages % session[:items_per_page] > 0) ? (@rest = 1) : (@rest = 0)
    @total_pages = @total_pages / session[:items_per_page] + @rest
    @page_select_options = {:action => 'show', :controller => "recordings", :show_rec => @s_dev}
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1 && mor_11_extend?)
  end

  def play_rec
    @page_title = ""
    @rec = Recording.find_by_id(params[:rec])
    unless @rec
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    @title = Confline.get_value("Admin_Browser_Title")
    @call = @rec.call
    render(:layout => "play_rec")
  end

=begin rdoc
 Plays recording in new popup window.
 
 *Params*:
 
 +id+ - Recording ID.
=end

  def play_recording
    @page_title = ""
    @rec = Recording.find_by_id(params[:id])
    unless @rec
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    @recording = ""
    if @rec
      server_path = get_server_path(@rec.local)
      a=check_user_for_recording(@rec)
      return false if !a

      @title = Confline.get_value("Admin_Browser_Title")
      @call = @rec.call

      @recording = server_path.to_s + @rec.mp3
    end
    render(:layout => "play_rec")
  end

=begin rdoc
 Lists recordings for admin and reseller. 
=end

  def list
    @page_title = _('Recordings')
    @page_icon = "music.png"

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)

    if session[:usertype] == "admin" or session[:usertype] == "reseller"
      id = params[:id]
    else
      id = session[:user_id]
    end
    @user = User.find_by_id(id)

    change_date
    params[:page] ? @page = params[:page].to_i : @page = 1
    params[:search_on] ? @search = params[:search_on].to_i : @search = 0
    params[:s_source] ? @search_source = params[:s_source] : @search_source = ""
    params[:s_destination] ? @search_destination = params[:s_destination] : @search_destination = ""
    params[:date_from_link] ? @date_from = params[:date_from_link] : @date_from = session_from_datetime
    params[:date_till_link] ? @date_till = params[:date_till_link] : @date_till = session_till_datetime

    conditions_str = []
    conditions_var = []

    conditions_str << "recordings.datetime BETWEEN ? AND ?"
    conditions_var += [@date_from, @date_till]

    if !@search_source.blank?
      conditions_str << "recordings.src LIKE ?"
      conditions_var << @search_source
    end

    if !@search_destination.blank?
      conditions_str << "recordings.dst LIKE ?"
      conditions_var << @search_destination
    end
    if @user
      conditions_str << "recordings.user_id = ?"
      conditions_var << @user.id
    end

    @size = Recording.count(:conditions => [conditions_str.join(' AND ')] +conditions_var).to_i
    @items_per_page = Confline.get_value("Items_Per_Page").to_i
    @total_pages = (@size.to_f / @items_per_page.to_f).ceil
    @recordings = Recording.find(:all, :include => :call, :conditions => [conditions_str.join(' AND ')] +conditions_var, :limit => @items_per_page, :offset => (@page-1)*@items_per_page, :order => "datetime DESC")
    @page_select_params = {
        :s_source => @search_source,
        :s_destination => @search_destination
    }
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1 && mor_11_extend?)
  end


=begin rdoc
 Lists recordings for user.
=end

  def list_recordings
    @page_title = _('Recordings')
    @page_icon = "music.png"
    @user = User.find_by_id(session[:user_id])

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)

    change_date
    params[:page] ? @page = params[:page].to_i : @page = 1
    params[:search_on] ? @search = params[:search_on].to_i : @search = 0
    params[:s_source] ? @search_source = params[:s_source] : @search_source = ""
    params[:s_destination] ? @search_destination = params[:s_destination] : @search_destination = ""
    params[:date_from_link] ? @date_from = params[:date_from_link] : @date_from = session_from_datetime
    params[:date_till_link] ? @date_till = params[:date_till_link] : @date_till = session_till_datetime

    conditions_str = []
    conditions_var = []

    conditions_str << "recordings.datetime BETWEEN ? AND ?"
    conditions_var += [@date_from, @date_till]
    conditions_str << "deleted = ?"
    conditions_var << 0

    if @search_source != "" and @search_destination != ""
      conditions_str << "(recordings.src LIKE ? OR recordings.dst LIKE ? )"
      conditions_var += [@search_source, @search_destination]
    else
      if !@search_source.blank?
        conditions_str << "recordings.src LIKE ?"
        conditions_var << @search_source
      end

      if !@search_destination.blank?
        conditions_str << "recordings.dst LIKE ?"
        conditions_var << @search_destination
      end
    end

    conditions_str << "((recordings.user_id = ? AND visible_to_user = 1) OR (recordings.dst_user_id = ? AND visible_to_dst_user = 1))"
    conditions_var += [@user.id, @user.id]


    @size = Recording.where([conditions_str.join(' AND ')] +conditions_var).count.to_i
    @items_per_page = Confline.get_value("Items_Per_Page").to_i
    @total_pages = (@size.to_f / @items_per_page.to_f).ceil
    @recordings = Recording.includes(:call).where([conditions_str.join(' AND ')] +conditions_var).limit(@items_per_page).offset((@page-1)*@items_per_page).order("calls.calldate DESC").all
    @page_select_params = {
        :s_source => @search_source,
        :s_destination => @search_destination
    }
    @search = params[:clear].to_i if params[:clear]
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1 && mor_11_extend?)
  end

=begin rdoc
  Recording edit action for admin and reseller.
=end

  def edit
    @page_title = _('Edit_Recording')
    @page_icon = "edit.png"
    @recording = Recording.find_by_id(params[:id])
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    a=check_user_for_recording(@recording)
    return false if !a
  end


=begin rdoc
  Recording edit action for user.
=end

  def edit_recording
    @page_title = _('Edit_Recording')
    @page_icon = "edit.png"
    @recording = Recording.find_by_id(params[:id])
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    a=check_user_for_recording(@recording)
    return false if !a
  end

=begin rdoc
 Recording update action for admin and reseller.
=end

  def update
    @recording = Recording.find_by_id(params[:id])
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    a=check_user_for_recording(@recording)
    return false if !a

    @recording.comment = params[:recording][:comment].to_s
    if @recording.save
      flash[:notice] = _('Recording_was_updated')
    else
      flash[:notice] = _('Recording_was_not_updated')
    end
    redirect_to(:action => "list_recordings") and return false
  end

=begin rdoc
 Recording update action for user
=end

  def update_recording
    @recording = Recording.find_by_id(params[:id])
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    a=check_user_for_recording(@recording)
    return false if !a

    @recording.comment = params[:recording][:comment].to_s
    if @recording.save
      flash[:notice] = _('Recording_was_updated')
    else
      flash[:notice] = _('Recording_was_not_updated')
    end
    redirect_to(:action => :recordings) and return false
  end

=begin rdoc
  
=end

  def list_users
    @page_title = _('Users')
    @page_icon = 'vcard.png'
    @roles = Role.find(:all, :conditions => ["name !='guest'"])

    params[:search_on] ? @search = params[:search_on].to_i : @search = 0
    params[:page] ? @page = params[:page].to_i : @page = 1
    params[:s_username] ? @search_username = params[:s_username] : @search_username = ""
    params[:s_first_name] ? @search_fname = params[:s_first_name] : @search_fname = ""
    params[:s_last_name] ? @search_lname = params[:s_last_name] : @search_lname = ""
    params[:s_agr_number] ? @search_agrnumber = params[:s_agr_number] : @search_agrnumber = ""
    params[:sub_s] ? @search_sub = params[:sub_s] : @search_sub = -1
    params[:user_type] ? @search_type = params[:user_type] : @search_type = -1
    params[:s_acc_number] ? @search_account_number = params[:s_acc_number] : @search_account_number = ""
    params[:s_clientid] ? @search_clientid = params[:s_clientid] : @search_clientid = ""
    if session[:usertype] == "accountant"
      owner = User.find(session[:user_id].to_i).get_owner.id.to_i
    else
      owner = session[:user_id]
    end
    cond = " hidden = 0 AND owner_id = '#{owner}' "
    cond += " AND users.username LIKE '#{@search_username}%' " if @search_username.length > 0

    cond += " AND first_name LIKE '#{@search_fname}%' " if @search_fname.length > 0

    cond += " AND " if cond.length > 0 and @search_lname.length > 0
    cond += " last_name LIKE '#{@search_lname}%' " if @search_lname.length > 0

    cond += " AND " if cond.length > 0 and @search_agrnumber.length > 0
    cond += " agreement_number LIKE '#{@search_agrnumber}%' " if @search_agrnumber.length > 0

    cond += " AND accounting_number LIKE '#{@search_account_number}%' " if @search_account_number.length > 0
    cond += " AND usertype = '#{@search_type}' " if @search_type.to_i != -1

    cond += " AND clientid LIKE '#{@search_clientid}%' " if @search_clientid.length > 0

    @items_per_page = Confline.get_value("Items_Per_Page").to_i
    @users = []
    if @search_sub.to_i > -1
      cond2 = ""
      cond2 = " subs = 0" if @search_sub.to_i == 0
      cond2 = " subs > 0" if @search_sub.to_i == 1
      @size = User.find_by_sql("select count(*) as number from (SELECT count(subscriptions.id) as subs , users.id AS users_id FROM users LEFT OUTER JOIN subscriptions ON subscriptions.user_id = users.id WHERE (#{cond}) GROUP BY users.id) as temp_table WHERE #{cond2}")[0]["number"].to_i
      @users = User.find_by_sql("
      SELECT * FROM(
      SELECT users.*, count(subscriptions.id) as subs
      FROM users LEFT JOIN subscriptions ON subscriptions.user_id = users.id
      WHERE (#{cond}) GROUP BY users.id ORDER BY users.first_name ASC) AS temp_table WHERE (#{cond2})
      LIMIT #{(@page-1)*@items_per_page}, #{@items_per_page}")
    else
      @size = User.count(:conditions => cond)
      @users = User.find(:all, :conditions => cond, :order => "users.first_name ASC", :limit => @items_per_page, :offset => (@page-1)*@items_per_page) if cond.length > 0
    end

    @total_pages = (@size / @items_per_page.to_f).ceil
    @page_select_params = {
        :s_username => @search_username,
        :s_first_name => @search_fname,
        :s_last_name => @search_lname,
        :s_agr_number => @search_agrnumber,
        :sub_s => @search_sub,
        :user_type => @search_type,
        :s_acc_number => @search_account_number,
        :s_clientid => @search_clientid
    }
  end


  def recordings
    @page_title = _('Recordings')
    @page_icon = "music.png"
    change_date
    owner_id = correct_owner_id

    params[:page].to_i > 0 ? @page = params[:page].to_i : @page = 1
    params[:search_on] ? @search = params[:search_on].to_i : @search = 0
    params[:s_source] ? @search_source = params[:s_source] : @search_source = ""
    params[:s_destination] ? @search_destination = params[:s_destination] : @search_destination = ""
    params[:date_from_link] ? @date_from = params[:date_from_link] : @date_from = session_from_datetime
    params[:date_till_link] ? @date_till = params[:date_till_link] : @date_till = session_till_datetime

    params[:user_id] ? @user = params[:user_id] : @user = "all"
    params[:device_id] ? @device = params[:device_id].to_i : @device = "all"

    conditions_str = ["?"]
    conditions_var = ["1"]

    #    conditions_str = ["users.owner_id = ?"]
    #    conditions_var = [owner_id]

    conditions_str << "recordings.datetime BETWEEN ? AND ?"
    conditions_var += [@date_from, @date_till]

    if !@search_source.blank?
      conditions_str << "recordings.src LIKE ?"
      conditions_var << @search_source
    end

    if !@search_destination.blank?
      conditions_str << "recordings.dst LIKE ?"
      conditions_var << @search_destination
    end

    if !@user.blank? and @user != "all"
      conditions_str << "recordings.user_id = ?"
      conditions_var << @user.to_i
      @devices = Device.find(:all, :select => "devices.*", :joins => "LEFT JOIN users ON (users.id = devices.user_id)", :conditions => ["users.owner_id = ? AND device_type != 'FAX' AND user_id = ? AND name not like 'mor_server_%'", owner_id, @user])
    else
      @devices = Device.find(:all, :select => "devices.*", :joins => "LEFT JOIN users ON (users.id = devices.user_id)", :conditions => ["users.owner_id = ? AND device_type != 'FAX' AND name not like 'mor_server_%'", owner_id])
    end

    if !@device.blank? and @device != 'all' and @device.to_i != 0
      conditions_str << "(recordings.src_device_id  = ? OR recordings.dst_device_id  = ?)"
      conditions_var += [@device, @device]
    end

    @users = User.find_all_for_select(corrected_user_id, {:exclude_owner => true})

    @recordings = Recording.find(:all, :select => "recordings.*", :joins => "LEFT JOIN users ON (users.id = recordings.user_id)", :conditions => [conditions_str.join(' AND ')] +conditions_var, :limit => session[:items_per_page], :offset => (@page-1)*session[:items_per_page], :order => "datetime DESC")

    @size = Recording.count(:joins => "LEFT JOIN users ON (users.id = recordings.user_id)", :conditions => [conditions_str.join(' AND ')] +conditions_var)
    @total_pages = @size / session[:items_per_page]

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1 && mor_11_extend?)
  end

=begin  rdoc
  
=end

  def list_users_update
    params[:search_on] ? @search = params[:search_on].to_i : @search = 0
    params[:fs_page] ? @page = params[:fs_page].to_i : @page = 1
    params[:fs_username] ? @search_username = params[:fs_username] : @search_username = ""
    params[:fs_first_name] ? @search_fname = params[:fs_first_name] : @search_fname = ""
    params[:fs_last_name] ? @search_lname = params[:fs_last_name] : @search_lname = ""
    params[:fs_agr_number] ? @search_agrnumber = params[:fs_agr_number] : @search_agrnumber = ""
    params[:fsub_s] ? @search_sub = params[:fsub_s] : @search_sub = -1
    params[:fuser_type] ? @search_type = params[:fuser_type] : @search_type = -1
    params[:fs_acc_number] ? @search_account_number = params[:fs_acc_number] : @search_account_number = ""
    params[:fs_clientid] ? @search_clientid = params[:fs_clientid] : @search_clientid = ""
    users = {}
    params.each { |key, value|
      if key.scan(/recording_enabled_|recording_forced_enabled_|recording_hdd_quota_|recordings_email_/).size > 0
        num = key.gsub(/recording_enabled_|recording_forced_enabled_|recording_hdd_quota_|recordings_email_/, "")
        if !users[num]
          users[num] = User.find_by_id(num)
        end
      end
    }
    users.each { |num, user|
      new = params[:"recording_enabled_#{num}"].to_i.to_s+params[:"recording_forced_enabled_#{num}"].to_i.to_s+params[:"recording_hdd_quota_#{num}"].to_s+params[:"recordings_email_#{num}"].to_s
      old = user.recording_enabled.to_s + user.recording_forced_enabled.to_s + user.recording_hdd_quota.to_s + user.recordings_email.to_s
      if new != old
        user.recording_enabled = params[:"recording_enabled_#{num}"].to_i
        user.recording_forced_enabled = params[:"recording_forced_enabled_#{num}"].to_i
        user.recording_hdd_quota = params[:"recording_hdd_quota_#{num}"].to_f * 1048576
        user.recordings_email = params[:"recordings_email_#{num}"]
        user.save
      end
    }
    flash[:status] = _("Users_have_been_updated")
    redirect_to :action => :list_users, :page => @page, :s_username => @search_username, :s_first_name => @search_fname, :s_last_name => @search_lname, :s_agr_number => @search_agrnumber, :sub_s => @search_sub, :user_type => @search_type, :s_acc_number => @search_account_number, :s_clientid => @search_clientid and return false
  end

=begin rdoc
 Destroys recording. Action for user.
=end

  def destroy_recording
    @recording = Recording.find_by_id(params[:id])
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    a=check_user_for_recording(@recording)
    return false if !a
    if @recording.destroy_all
      flash[:notice] = _("Recording_was_destroyed")
    else
      flash[:notice] = _("Recording_was_not_destroyed")
    end
    redirect_to(:action => "recordings") and return false
  end


=begin rdoc
 Destroys recording. 
=end

  def destroy
    rec = Recording.find_by_id(params[:id])
    unless rec
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :controller => "callc", :action => 'main' and return false
    end
    a=check_user_for_recording(rec)
    return false if !a

    if rec.user_id != session[:user_id] and rec.dst_user_id != session[:user_id]
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    # allow to delete when src/dst matches otherwise -> do invisible
    if rec.user_id == rec.dst_user_id or (rec.user_id == session[:user_id] and rec.visible_to_dst_user == 0) or (rec.dst_user_id == session[:user_id] and rec.visible_to_user == 0)

      if rec.destroy_all
        flash[:notice] = _("Recording_was_destroyed")
      else
        flash[:notice] = _("Recording_was_not_destroyed")
      end

    else

      # hide recording for src user because dst user still can see it
      if (rec.user_id == session[:user_id] and rec.visible_to_dst_user == 1)
        rec.visible_to_user = 0
        rec.save
        flash[:notice] = _("Recording_was_destroyed")
      end

      # hide recording for dst user because src user still can see it
      if (rec.dst_user_id == session[:user_id] and rec.visible_to_user == 1)
        rec.visible_to_dst_user = 0
        rec.save
        flash[:notice] = _("Recording_was_destroyed")
      end

    end

    redirect_to :action => :list_recordings
  end

  def bulk_management
    @page_title = _('Bulk_management')
    @page_icon = "music.png"
    @find_rec_size = -1
    session[:recordings_delete_cond] = nil
    if params[:rec_action].to_i == 0
      @devices = Device.find(:all, :include => [:user], :conditions => ["users.owner_id = ? AND name not like 'mor_server_%'", correct_owner_id])
    else
      cond = 'id = -1'
      @type = params[:rec_action].to_i
      if params[:rec_action].to_i == 1
        @device = Device.find(:first, :conditions => {:id => params[:s_device]})
        unless @device
          flash[:notice] = _('Device_was_not_found')
          redirect_back_or_default("/callc/main")
        end
        cond = "src_device_id = #{q(@device.id)}"
      end
      if params[:rec_action].to_i == 2
        change_date
        cond = "datetime BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
      end
      session[:recordings_delete_cond] = cond
      @find_rec_size = Recording.count(:all, :conditions => cond)
    end

  end

  def bulk_delete
    recordings = Recording.find(:all, :conditions => session[:recordings_delete_cond])
    for r in recordings
      unless r
        flash[:notice] = _('Recording_was_not_found')
        redirect_to :controller => "callc", :action => 'main' and return false
      end
      a=check_user_for_recording(r)
      return false if !a
      if r.destroy_all
        flash[:notice] = _("Recordings_was_destroyed")
      else
        flash[:notice] = _("Recordings_was_not_destroyed")
        redirect_to(:action => "recordings") and return false
      end
    end
    redirect_to(:action => "recordings") and return false
  end


  private

=begin rdoc

=end

  def get_server_path(local = 1)

    if local == 0
      server = Confline.get_value("Recordings_addon_IP")
      #server_port = Confline.get_value("Recordings_addon_Port")
      #server_port.to_s != "" ? server_path = "http://"+ server + ":" + server_port : server_path = "http://"+ server
      server_path = "http://#{server.to_s}/recordings/"
    else
      server_path = Web_URL + Web_Dir + "/recordings/"
    end

    server_path

  end

=begin rdoc

=end

  def check_user_for_recording(recording)
    if ((recording.user_id != session[:user_id] and recording.dst_user_id != session[:user_id])) and (session[:usertype] != "admin" and session[:usertype] != "reseller")
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    if session[:usertype] == "reseller" and ((recording.user and recording.user.owner_id != session[:user_id]) and (recording.dst_user and recording.dst_user.owner_id != session[:user_id]))
      if recording.user_id != session[:user_id]
        dont_be_so_smart
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end
    return true
  end
end
