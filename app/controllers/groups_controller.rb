# -*- encoding : utf-8 -*-
class GroupsController < ApplicationController
  layout "callc"

  before_filter :check_post_method, :only=>[:destroy, :create, :update, :add_member, :remove_member]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_user_type, :only => [:members, :change_member_type, :add_member, :remove_member, :change_position]
  before_filter :find_group, :only => [ :show, :edit, :update, :destroy, :members, :add_member, :remove_member, :manager_members, :callshop_management, :member_stats, :member_stats_update, :change_member_type, :change_position ]
  before_filter :check_addon

  @@callshop_view = []
  @@callshop_edit = [:index, :list, :show, :new,  :create, :edit, :update, :destroy, :members, :change_member_type, :change_position, :add_member, :remove_member, :manager_list, :manager_members, :callshop_management, :member_stats, :member_stats_update, :group_member_devices]
  before_filter(:only =>  @@callshop_view+@@callshop_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@callshop_view, @@callshop_edit, {:role => "reseller", :right => :res_call_shop, :ignore => true})
    c.instance_variable_set :@callshop, allow_read
    c.instance_variable_set :@callshop, allow_edit
    true
  }
  
  def index
    list
    render :action => 'list'
  end

  def list
    @page_title = _('Callshops')
    @groups = Group.find(:all, :include => :translation, :conditions => { :owner_id => current_user.id })
  end

  def show
    @page_title = _('Group_details')
  end

  def new
    @page_title = _('New_callshop')
    @page_icon = "add.png"
    @group = Group.new
  end

  def create
    @group = Group.new(params[:group])
    @group.user = current_user
    @group.grouptype = "callshop"

    if @group.save
      flash[:status] = _('Call_shop_was_successfully_created')
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @page_title = _('Edit_group')
    @page_icon = "edit.png"
  end

  def update
    if @group.update_attributes(params[:group])
      flash[:status] = _('Call_shop_was_successfully_updated')
      redirect_to :action => 'list' #, :id => @group
    else
      render :action => 'edit'
    end
  end

  def destroy
    @group.destroy
    flash[:status] = _('Call_shop_was_successfully_deleted')
    session[:manager_in_groups] = User.find(session[:user_id]).manager_in_groups
    redirect_to :action => 'list'
  end

  def members
    @page_title = _('Callshops')+" '" + @group.name + "' " +_('Phone_booths')
    @users = User.find(:all, :include => [:usergroups], :conditions => ["hidden = 0 and owner_id = ?", current_user.id])
    @free_users = []
    group_users = @group.users
    for user in @users
      @free_users << user if !group_users.include?(user) && user.usergroups.empty? && user != current_user && user.usertype == "user"
    end
    store_location
  end

  def change_member_type
    user = User.find_by_id(params[:user])
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => 'callc', :action=>"main" and return false
    end

    usergroup = Usergroup.find(:first, :conditions => ["user_id = ? AND group_id = ?", user.id, @group.id])
    managers = usergroup.group.manager_users.size

    if usergroup.gusertype == "manager"
      usergroup.update_attribute(:gusertype, "user")
      user.update_attribute(:blocked, 1)
    else
      if managers == 0 and user.usertype == "user"
        usergroup.update_attribute(:gusertype, "manager")
        user.update_attribute(:blocked, 0)
      end
    end

    session[:manager_in_groups] = user.manager_in_groups

    flash[:status] = _('Call_booths_type_was_successfully_changed')
    redirect_to :action => 'members', :id => @group
  end

  def change_position
    member = User.find_by_id(params[:member_id])

    if @group.move_member(member, params[:direction])
      flash[:status] = _('Booth_order_was_updated')
    end

    redirect_back_or_default('/groups/list')
  end


  def add_member
    user = User.find_by_id(params[:new_member])
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => 'callc', :action=>"main" and return false
    end
    if user.usertype == "user" and user.owner_id == correct_owner_id
      usergroup = Usergroup.new({:user_id => user.id, :group_id => @group.id})
      usergroup.gusertype = (params[:as_manager].to_s == "true" ? "manager" : "user")
      usergroup.position = (@group.usergroups.any?) ? @group.usergroups.last.position + 1 : 0
      if usergroup.save
        user.update_attribute(:blocked, 1) if usergroup.gusertype == "user"

        flash[:status] = _('Call_booth_was_successfully_added')
      else
        flash_errors_for(_('Call_booth_was_not_added'), usergroup)
      end
    else
      flash[:notice] = _('Call_booth_was_not_added')
    end
    redirect_to :action => 'members', :id => params[:group]
  end


  def remove_member
    user = User.find_by_id(params[:user])
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => 'callc', :action=>"main" and return false
    end
    member = Usergroup.find(:first, :conditions => ["user_id = ? AND group_id = ?", user.id, @group.id])
    if member
      member.destroy
      session[:manager_in_groups] = user.manager_in_groups

      flash[:status] = _('Call_booth_was_successfully_removed')
    end
    redirect_to :action => 'members', :id => @group
  end

  def manager_list
    @page_title = _('Groups')
    #@group_pages, @groups = paginate :groups, :per_page => 10
    user = User.find_by_id(session[:user_id])
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => 'callc', :action=>"main" and return false
    end
    @groups = user.groups
  end

  def manager_members
    @user = User.find_by_id(session[:user_id])

    authorize_group_manager(@group.id)

    change_date

    @page_title = _('Groups')+" '" + @group.name + "' " +_('members')
    #@users = User.find(:all)
    @calls = []
    @durations = []

    i = 0
    for member in @group.users
      @calls[i] = member.total_calls("answered",session_from_datetime, session_till_datetime) + member.total_calls("answered_inc", session_from_datetime, session_till_datetime)
      @durations[i] = member.total_duration("answered",session_from_datetime, session_till_datetime) + member.total_duration("answered_inc", session_from_datetime, session_till_datetime)
      i+=1
    end

    #changing the state user logged status
    if params[:member]
      user = User.find(params[:member])
      if user.logged == 1 and params[:laction] == "logout"
        user.logged = 0
        add_action(user.id, "logout", "")
      end

      if user.logged == 0 and params[:laction] == "login"
        user.logged = 1
        add_action(user.id, "login", "")
      end
      user.save
      check_devices2(user.id)
    end

    @search = 0
    @search = 1 if params[:search_on]

  end


  def callshop_management
    change_date

    authorize_group_manager(@group.id)

    @page_title = _('Callshop')+": " + @group.name
    #@users = User.find(:all)
    @calls = []
    @durations = []

    @date_from = session_from_datetime
    @date_till = session_till_datetime

    i = 0
    for member in @group.simple_users
      @calls[i] = member.total_calls("answered",@date_from, @date_till)
      #      @durations[i] = member.total_duration("answered",date_from, date_till)
      @durations[i] = member.total_billsec("answered",@date_from, @date_till)
      i+=1
    end

    #changing the state user logged status
    if params[:member]
      user = User.find_by_id(params[:member])
      if user.logged == 1 and params[:laction] == "logout"
        user.logged = 0
        add_action(user.id, "logout", "")
      end

      if user.logged == 0 and params[:laction] == "login"
        user.logged = 1
        add_action(user.id, "login", "")
      end
      user.save
      check_devices2(user.id)
    end

  end

  def member_stats
    @page_title = _('Member_stats')

    authorize_group_manager(@group.id)

    #changing stats
    #    if params[:member]
    #      member = User.find(params[:member])
    #      member.sales_this_month = params[:sales_this_month]
    #      member.sales_this_month_planned = params[:sales_this_month_planned]
    #      member.save
    #   end
  end


  def member_stats_update
    for user in @group.users
      user.sales_this_month = params["sales_this_month_#{user.id}".intern].to_i
      user.sales_this_month_planned = params["sales_this_month_planned_#{user.id}".intern].to_i

      user.calltime_normative = params["calltime_normative_#{user.id}".intern].to_f
      user.show_in_realtime_stats = params["show_in_realtime_stats_#{user.id}".intern].to_i

      #my_debug params["show_in_realtime_stats_#{user.id}".intern].to_i
      #      my_debug params["sales_this_month_#{user.id}".intern]
      #     my_debug params["sales_this_month_planned_#{user.id}".intern]

      user.save
    end

    flash[:notice] = _('Member_stats_updated')
    redirect_to  :action => "member_stats", :id => @group.id

  end


  #manager can only view his groups
  def authorize_group_manager(group_id)
    can_proceed = false
    if session[:manager_in_groups].size > 0
      for group in session[:manager_in_groups]
        can_proceed = true if group.id.to_i == group_id.to_i
      end
    end
    if not can_proceed
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :controller => "callc", :action => "main"
    end
  end


  def group_member_devices
    @page_title = _('Member_devices')
    @page_icon = "device.png"

    @user = User.find_by_id(params[:id])
    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :controller => 'callc', :action=>"main" and return false
    end
    @devices = @user.devices


  end

  private

  def check_user_type
    if session[:usertype] == "user"
      dont_be_so_smart
      redirect_to :controller => 'callc', :action=>"main" and return false
    end
  end

  def find_group
    @group = Group.find_by_id(params[:group]) if params[:group] and !params[:group].kind_of?(Hash)
    @group = Group.find_by_id(params[:id]) if @group.nil?

    unless @group
      flash[:notice] = _('Call_shop_was_not_found')
      redirect_to :controller => 'callc', :action=>"main" and return false
    end

    unless @group.owner_id == current_user.id
      dont_be_so_smart
      redirect_to :controller => 'callc', :action=>"main" and return false
    end
  end

  def check_addon
    unless defined?(CS_Active) && CS_Active == 1
      reset_session
      flash[:notice] = _("Callshop_not_enabled")
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

end
