class MonitoringsController < ApplicationController
  layout "callc"

  before_filter :authorize
  before_filter :check_localization
  before_filter :check_if_enabled
  before_filter :set_icon_and_title

  before_filter :find_user, :only => [ :for_user ]
  before_filter :find_monitoring, :only => [ :edit, :destroy, :update ]

  @@monitorings_view = [ :index, :for_user ]
  @@monitorings_edit = [ :create, :edit, :destroy, :update ]
  before_filter(:only =>  @@monitorings_view+@@monitorings_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@monitorings_view, @@monitorings_edit, {:role => "accountant", :right => :acc_monitorings_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  # monitorings global window, here we show all active monitorings
  def index
    @monitorings = Monitoring.find(:all, :include => [:users])
    @users = User.find_all_for_select(correct_owner_id)
    @monitoring = Monitoring.new

    store_location
  end

  def create
    if params[:monitoring] and params[:monitoring][:user_type].to_s == 'single'
      params[:for_user]=true
      params[:monitoring][:user] = params[:user][:id]
      params[:monitoring].delete(:user_type)
    end
    @monitoring = Monitoring.new_or_existent_from_params(params[:monitoring])

    # if we have monitoring like this, just associate user/users with it
    if @monitoring.existent?
      @monitoring.associate
      @monitoring.reload

      flash[:status] = "#{_("Such_monitoring_already_exists_users_associated")}. #{_("Applied_to_n_users", ( @monitoring.users.any? ) ? @monitoring.users.count : _(@monitoring.user_type.capitalize).downcase)}."

      redirect_back_or_default("/monitorings")
      # otherwisde create a new monitoring and associate users
    else
      if @monitoring.save
        #        # associate with users in the system
        #        @monitoring.associate
        #        @monitoring.reload

        flash[:status] = "#{_("Monitoring_created_succesfully")}. #{_("Applied_to_n_users", ( @monitoring.users.any? ) ? @monitoring.users.count : _(@monitoring.user_type.capitalize).downcase)}."

        redirect_back_or_default("/monitorings")
      else
        flash_errors_for(_("Failed_to_create_monitoring"), @monitoring)
        if for_user?
          @user = User.find_by_id(@monitoring.user)
          render :action => "for_user"
        else
          @users = User.find(:all, :conditions=>['users.hidden = 0 AND users.owner_id = ?', correct_owner_id])
          @monitorings = Monitoring.find(:all, :include => [:users])
          render :action => "index"
        end
      end
    end
  end

  def edit
    @m_users = @monitoring.users if @monitoring.user_type.blank? #User.find_by_id(params[:user_id].to_i) if params[:user_id]

  end

  def destroy
    @monitoring.add_monitoring_action('destroy')
    @monitoring.destroy_or_deassociate(params[:user])

    flash[:status] = _('Monitoring_deleted_successfully')
    redirect_back_or_default("/callc/main")
  end

  def update
    if @monitoring.update_attributes(params[:monitoring])
      flash[:status] = "#{_('Monitoring_updated_successfully')}. #{_("Applied_to_n_users", ( @monitoring.users.any? ) ? @monitoring.users.count : _(@monitoring.user_type.capitalize).downcase)}."
      redirect_back_or_default("/monitorings")
    else
      if @monitoring.is_duplicate?
        flash[:notice] = "#{_("Such_monitoring_already_exists_users_associated")}. #{_("Applied_to_n_users", ( @monitoring.users.any? ) ? @monitoring.users.count : _(@monitoring.user_type.capitalize).downcase)}."
      else
        flash_errors_for(_("Failed_to_update_monitoring"), @monitoring)
      end
      render :action => "edit"
    end
  end

  def for_user
    @monitoring = Monitoring.new(:user => @user.id)
    store_location
  end

  private

  def find_user
    @user = User.find_by_id(params[:id])

    unless @user
      flash[:notice] = _('User_not_found')
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def find_monitoring
    @monitoring = Monitoring.find_by_id(params[:id])

    unless @monitoring
      flash[:notice] = _('Monitoring_not_found')
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def check_if_enabled
    redirect_to :controller => "callc", :action => "main" and return false if !defined?(MA_Active) || MA_Active != 1

    if !current_user || !["accountant", "admin"].include?(current_user.usertype)
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def for_user?; params[:for_user]; end

  def set_icon_and_title
    @page_title = _('Monitorings')
    @page_icon = "magnifier.png"
  end

end
