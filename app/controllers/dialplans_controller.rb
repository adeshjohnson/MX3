# -*- encoding : utf-8 -*-
class DialplansController < ApplicationController
  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update, :did_assign_to_dp]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_dialplan, :only => [:list_extlines, :edit, :update, :destroy, :did_assign_to_dp]

  @@CC_End_ivr = ['End IVR #1', 'End IVR #2', 'End IVR #3', 'End IVR #4', 'End IVR #5']
  @@ANI_End_ivr = ['End IVR #1', 'End IVR #2', 'End IVR #3']

  def dialplans
    @page_title = _('Dial_Plans')

    @ccdps = []
    @ccdps = current_user.dialplans.find(:all, :select => 'dialplans.*, ivrs.name AS balance_ivr', :joins => "LEFT JOIN ivrs ON dialplans.data12 = ivrs.id", :conditions => "dptype = 'callingcard'", :order => "name ASC") if cc_active?

    @abpdps = current_user.dialplans.find(:all, :conditions => "dptype = 'authbypin'", :order => "name ASC")
    @cbdps = current_user.dialplans.find(:all, :conditions => "dptype = 'callback'", :order => "name ASC") if callback_active?
    @ivr_dialplans = current_user.dialplans.find(:all, :conditions => "dptype = 'ivr'", :order => "name ASC")
    @cc_end_ivr = @@CC_End_ivr
    @ani_end_ivr = @@ANI_End_ivr

    @quickforward_dialplans = current_user.dialplans.find(:all, :select => "dialplans.*, users.username AS user_name, devices.username AS device_name, devices.device_type", :joins => "LEFT JOIN devices ON dialplans.data3 = devices.id LEFT JOIN users ON users.id = devices.user_id", :conditions => "dptype = 'quickforwarddids' and dialplans.id != 1", :order => "dialplans.name ASC")
  end

  def list_extlines
    @page_title = _('Extlines')
    @page_icon = "asterisk.png"

    @extlines = Extline.find(:all, :conditions => "exten = 'dialplan#{@dp.id}'", :order => "exten ASC, priority ASC")

    @ivr1 = current_user.ivrs.find(:first, :conditions => "id = #{@dp.data2}") if @dp.data2 and @dp.data2.to_s.size > 0
    @ivr2 = current_user.ivrs.find(:first, :conditions => "id = #{@dp.data4}") if @dp.data4 and @dp.data4.to_s.size > 0
    @ivr3 = current_user.ivrs.find(:first, :conditions => "id = #{@dp.data6}") if @dp.data6 and @dp.data6.to_s.size > 0
    @ivr4 = current_user.ivrs.find(:first, :conditions => "id = #{@dp.data7}") if @dp.data7 and @dp.data7.to_s.size > 0

    @ivr1_blocks = @ivr1.ivr_blocks if @ivr1
    @ivr2_blocks = @ivr2.ivr_blocks if @ivr2
    @ivr3_blocks = @ivr3.ivr_blocks if @ivr3
    @ivr4_blocks = @ivr4.ivr_blocks if @ivr4

  end

  def edit
    @page_title = _('Dial_Plan_edit')
    @page_icon = "edit.png"

    @cbdids = Did.find_by_sql("SELECT dids.* FROM dids JOIN dialplans ON (dids.dialplan_id = dialplans.id) WHERE dialplans.dptype != 'callback' AND reseller_id = #{current_user.id}")
    @cbdevices = Device.find(:all, :conditions => "user_id != -1 AND users.owner_id = #{current_user.id} AND name not like 'mor_server_%'", :include => [:user], :order => "name ASC")
    @cardgroups = Cardgroup.find_by_sql("SELECT cardgroups.id, cardgroups.number_length, cardgroups.pin_length FROM cardgroups WHERE owner_id = #{current_user.id} group by number_length , pin_length ")
    if @dp.dptype == "ivr"
      @dialplan = @dp
      @ivrs = current_user.ivrs.find(:all)
      @timeperiods = current_user.ivr_timeperiods.find(:all)
      @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system"
    end

    if @dp.dptype == "callback" and callback_active?
      @free_dids = Did.find(:all, :conditions => ['status = "free" AND reseller_id = ?', current_user.id], :order => 'did ASC')
      @help_link = "http://wiki.kolmisoft.com/index.php/Callback"
    end
    if @dp.dptype == 'authbypin'
      @users = current_user.find_all_for_select
      if @dp.data5.blank?
        @user_id = ""
      else
        device_used = Device.find_by_id(@dp.data5.to_i)
        @user_id = device_used.user_id
      end
      @cc_dialplans = Dialplan.find(:all, :conditions => {:dptype => 'callingcard', :user_id => current_user.get_corrected_owner_id})
    end
    if @dp.dptype == 'callingcard' and mor_11_extend?
      @balance_ivrs = current_user.ivrs.find(:all)
    end

    if @dp.dptype == 'quickforwarddids'
      @users = current_user.find_all_for_select
      if @dp.data3.to_s.length > 0 and @selected_device = Device.find(:first, :select => 'users.id user_id, devices.id device_id', :joins => "JOIN users ON users.id = devices.user_id", :conditions => "users.owner_id = #{current_user.id} AND devices.id = #{@dp.data3.to_i}")
        @devices = Device.find(:all, :conditions => "user_id = #{@selected_device.user_id}")
        @selected_user_id = @selected_device.user_id
        @selected_device_id = @selected_device.id
        logger.fatal @selected_device
      else
        @devices = []
        @selected_user_id = ''
      end
    end
    @cc_end_ivr = @@CC_End_ivr
    @ani_end_ivr = @@ANI_End_ivr
  end

  def dialplans_device_ajax
    @device_selected = params[:device_id].to_i
    @device = []
    if params[:id]
      @device = Device.find(:all, :conditions => ['user_id =? AND name not like "mor_server_%"', params[:id]])
    end
    render :layout => false
  end

  def did_assign_to_dp
    did = Did.find_by_id(params[:did_id])
    unless did
      flash[:notice]=_('Did_was_not_found')
      redirect_to :action => :dialplans and return false
    end
    did.dialplan_id = @dp.id
    did.status = "active"
    did.save
    add_action2(session[:user_id], 'did_assigned_to_dp', did.id, @dp.id)
    @free_dids = Did.free_dids_for_select
    @ringgroup = params[:ringgroup].to_i
    render :layout => false
  end

  def update

    unless params[:dialplan]
      flash[:notice] = _('Dont_Be_So_Smart')
      redirect_to :action => 'dialplans' and return false
    end

    if params[:dialplan][:name].length == 0
      flash[:notice] = _('Please_enter_name')
      redirect_to :action => 'edit', :id => @dp.id and return false
    end

    @dp.name = params[:dialplan][:name].strip
    if @dp.dptype == "callingcard"

      @cardgroup = Cardgroup.find_by_id(params[:dialplan_number_pin_length])
      unless @cardgroup
        flash[:notice]=_('Cardgroup_was_not_found')
        redirect_to :action => :dialplans and return false
      end
      @dp.data1=@cardgroup.number_length
      @dp.data2=@cardgroup.pin_length

      #tell time - data3

      @dp.data3 = @dp.tell_time_status(params[:dialplan][:data3], params[:tell_seconds])

      @dp.data4 = params[:dialplan][:data4] ? 1 : 0
      @dp.data7 = params[:dialplan][:data7] ? 1 : 0
      @dp.data8 = params[:dialplan][:data8] ? 1 : 0

      @dp.data5 = params[:dialplan][:data5].strip if params[:dialplan][:data5].to_i > 0
      @dp.data6 = params[:dialplan][:data6].strip if params[:dialplan][:data6].to_i > 0
      @dp.data9 = params[:end_ivr].to_i + 1
      @dp.data10 = params[:dialplan][:data10].to_i
      @dp.data11 = params[:dialplan][:data11].to_d
      if @dp.data11.to_i == 0
        @dp.data12 = ''
      else
        @dp.data12 = params[:dialplan][:data12].to_i
      end
    end

    if @dp.dptype == "authbypin"
      if params[:dialplan][:data1].to_i > 0 or (params[:dialplan][:data3].to_i == 1 and params[:dialplan][:data1].to_i >= 0)
        @dp.data1 = params[:dialplan][:data1].strip
      elsif params[:dialplan][:data3].to_i == 0 and params[:dialplan][:data1].to_i == 0
        @dp.data1 = 1
      end
      @dp.data2 = params[:dialplan][:data2].strip if params[:dialplan][:data2].to_i > 0

      @dp.data3 = params[:dialplan][:data3] ? 1 : 0
      @dp.data4 = params[:dialplan][:data4] ? 1 : 0
      @dp.data6 = params[:dialplan][:data6].to_i == 1 ? "1" : "0"
      if params[:dialplan][:data3].to_i != 0
        @dp.data5 = params[:users_device]
      else
        @dp.data5 = ""
      end
      if Dialplan.find(:first, :conditions => {:id => params[:dialplan][:data7].to_i, :user_id => current_user.get_corrected_owner_id})
        @dp.data7 = params[:dialplan][:data7].to_i
      else
        @dp.data7 = 0
      end
      @dp.data8 = params[:dialplan][:data8].to_i + 1 
    end

    if callback_active? and @dp.dptype == "callback" and params[:dialplan]
      @dp.data1 = params[:dialplan][:data1].strip if params[:dialplan][:data1]
      @dp.data2 = params[:dialplan][:data2].strip
      @dp.data3 = params[:dialplan][:data3].strip
      @dp.data4 = params[:dialplan][:data4] ? params[:dialplan][:data4].to_i : 0
      @dp.data5 = params[:dialplan][:data5].strip
      @dp.data6 = params[:dialplan][:data6].strip
    end

    if @dp.dptype == "ivr"
      @dp.update_attributes(params[:dialplan])
    end

    if @dp.dptype == "quickforwarddids"
      @dp.data10 = (params[:dialplan][:data10].to_i == 1 ? 1 : 0)
      if params[:users_device].to_i != 0 and not User.find(:first, :joins => "JOIN devices ON devices.user_id = users.id", :conditions => "devices.id = #{params[:users_device].to_i} AND users.owner_id = #{current_user.get_corrected_owner_id}")
        flash[:notice] = _('Device_was_not_found')
        redirect_to :action => 'edit', :id => @dp.id and return false
      else
        @dp.data3 = params[:users_device].to_i
      end
    end


    if @dp.save
      add_action(session[:user_id], 'dp_edited', @dp.id)
      if @dp.dptype == "ivr"
        session[:integrity_check] = DidsController::reformat_dialplans
      end
      if @dp.dptype == "ivr"
        @dp.regenerate_ivr_dialplan
      end
      flash[:status] = _('Dialplan_was_successfully_updated')
    else
      flash[:notice] = _('Dialplan_was_not_updated')
    end

    redirect_to :action => 'dialplans' and return false
  end

  def new
    @page_title = _('Dial_Plan_new')
    @page_icon = "add.png"
    @dp = Dialplan.new({:data2 => 5})

    @cbdids = Did.find_by_sql("SELECT dids.* FROM dids JOIN dialplans ON (dids.dialplan_id = dialplans.id) WHERE dialplans.dptype != 'callback' AND dids.reseller_id = #{current_user.id}")
    @cardgroups = Cardgroup.find_by_sql("SELECT cardgroups.id, cardgroups.number_length, cardgroups.pin_length FROM cardgroups WHERE owner_id = #{current_user.id} group by number_length , pin_length ")
    @cbdevices = Device.find(:all, :conditions => "user_id != -1 AND users.owner_id = #{current_user.id} AND name not like 'mor_server_%'", :include => [:user], :order => "name ASC")
    @cc_dialplans = Dialplan.find(:all, :conditions => {:dptype => 'callingcard', :user_id => current_user.get_corrected_owner_id})
    @balance_ivrs = current_user.ivrs.find(:all)


    @ivrs = current_user.ivrs.find(:all)
    @timeperiods = current_user.ivr_timeperiods.find(:all)

    @dp_data5 = 3
    @dp_data6 = 3
    @dp_data1 = 3
    @dp_data2 = 3
    @dp_data7 = false
    @cc_end_ivr = @@CC_End_ivr
    @ani_end_ivr = @@ANI_End_ivr
    @users = current_user.find_all_for_select
    @users_used = ""
  end


  def create

    if !params[:dialplan] or params[:dialplan][:name].blank?
      flash[:notice] = _('Please_enter_name')
      redirect_to :action => :new and return false
    end
    params[:dialplan][:name]=params[:dialplan][:name].strip

    dp = Dialplan.new(params[:dialplan])
    if params[:dialplan][:dptype] == "callingcard"
      @cardgroup = Cardgroup.find(:first, :conditions => "id = #{params[:dialplan_number_pin_length]}")
      unless @cardgroup
        flash[:notice]=_('Cardgroup_was_not_found')
        redirect_to :action => :dialplans and return false
      end
      if @cardgroup
        dp.data1=@cardgroup.number_length
        dp.data2=@cardgroup.pin_length
      else
        redirect_to :action => 'dialplans' and return false
      end
    end


    if dp.dptype == "callingcard"
      dp.data7 = 0 if not dp.data7

      #tell time - data3
      dp.data3 = dp.tell_time_status(dp.data3, params[:tell_seconds])

      dp.data4 = 0 if not dp.data4
      dp.data5 = 3 if dp.data5.length == 0
      dp.data6 = 3 if dp.data6.length == 0
      dp.data9 = params[:end_ivr].to_i + 1
      dp.data11 = params[:dialplan][:data11].to_d
      if dp.data11.to_i == 0
        dp.data12 = ''
      else
        dp.data12 = params[:dialplan][:data12].to_i
      end
    end

    if dp.dptype == "quickforwarddids"
      dp.data10 = (params[:dialplan][:data10].to_i == 1 ? 1 : 0)
      if params[:users_device].to_i != 0 and not User.find(:first, :joins => "JOIN devices ON devices.user_id = users.id", :conditions => "devices.id = #{params[:users_device].to_i} AND users.owner_id = #{current_user.get_corrected_owner_id}")
        flash[:notice] = _('Device_was_not_found')
        redirect_to :action => 'new' and return false
      else
        dp.data3 = params[:users_device].to_i
      end
    end


    if dp.dptype == "authbypin"
      if params[:dialplan][:data1].to_i > 0 or (params[:dialplan][:data3].to_i == 1 and params[:dialplan][:data1].to_i >= 0)
        dp.data1 = params[:dialplan][:data1].strip
      elsif params[:dialplan][:data3].to_i == 0 and params[:dialplan][:data1].to_i == 0
        dp.data1 = 3
      end
      dp.data2 = 3 if dp.data2.length == 0
      dp.data3 = 0 if not dp.data3
      dp.data4 = 0 if not dp.data4
      dp.data5 = params[:users_device]
      dp.data6 = params[:dialplan][:data6].to_i == 1 ? "1" : "0"
      dp.data7 = params[:dialplan][:data7].to_i
      dp.data8 = params[:dialplan][:data8].to_i + 1 
    end

    if callback_active? and dp.dptype == "callback"
      dp.data2 = 5 if dp.data2.length == 0
    end

    if dp.save
      if dp.dptype == "ivr"
        dp.regenerate_ivr_dialplan
      end
      add_action(session[:user_id], 'dp_created', dp.id)
      flash[:status] = _('Dialplan_was_successfully_created')
    else
      flash[:notice] = _('Dialplan_was_not_created')
    end

    redirect_to :action => 'dialplans' and return false
  end


  def destroy
    if @dp.dptype != "ivr"
      if not @dp.dids.empty?
        flash[:notice] = _('Dialplan_is_assigned_to_did_cant_delete')
        redirect_to :action => 'dialplans' and return false
      end
      if @dp.dptype == 'authbypin' and @dp.data7.to_i > 0
        flash[:notice] = _('Calling_card_dialplan_is_assigned_to_this_dialpan')
        redirect_to :action => 'dialplans' and return false
      end
      if @dp.dptype == 'callingcard'
        if Dialplan.count(:all, :conditions => {:dptype => 'authbypin', :data7 => @dp.id}).to_i > 0
          flash[:notice] = _('Dialplan_is_associated_with_other_dialplans')
          redirect_to :action => 'dialplans' and return false
        end
      end
    end
    add_action(session[:user_id], 'dp_deleted', @dp.id)
    name = @dp.name
    @dp.destroy_all
    flash[:status] = _('Dialplan_deleted') + ": " + name
    redirect_to :action => 'dialplans' and return false
  end

  private

  def find_dialplan
    @dp = Dialplan.find(:first, :conditions => {:id => params[:id]})
    unless @dp
      flash[:notice]=_('Dialplan_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    unless @dp.user_id.to_i == current_user.id.to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

end
