# -*- encoding : utf-8 -*-
class CronActionsController < ApplicationController


  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_setting, :only => [:edit, :update, :destroy]

  def index
    @page_title = _('Cron_settings')
    @page_icon = "clock.png"
    
    @cron_settings = current_user.cron_settings.all
  end

  def new
    @page_title = _('New_Cron_setting')
    @page_icon = "clock.png"

    @cron_setting = CronSetting.new({:user_id => current_user.id, :valid_from => Time.now, :valid_till => Time.now})
    @users = User.find_all_for_select(current_user.id)
    @tariffs = current_user.load_tariffs
    @providers = Provider.where(:user_id => current_user.id)
    @provider_tariffs = Tariff.where(purpose:"provider", owner_id: current_user.id)
    @lcrs = Lcr.where("user_id = ? ", current_user.id).all
  end

  def create
    #logger.fatal(params.to_yaml)
    @cron_setting = CronSetting.new(params[:cron_setting].merge!({:user_id => current_user.id}))
    @cron_setting.valid_from = current_user.system_time(Time.mktime(params[:activation_start][:year], params[:activation_start][:month], params[:activation_start][:day], params[:activation_start][:hour], '0', '0'))
    @cron_setting.valid_till = current_user.system_time(Time.mktime(params[:activation_end][:year], params[:activation_end][:month], params[:activation_end][:day], params[:activation_end][:hour], '59', '59'))

    lcr = Lcr.where("id = #{params[:cron_setting][:lcr_id].to_i} and user_id = #{current_user.id}").first
    if lcr.blank?
      flash_errors_for(_('Lcr_was_not_found'), @cron_setting)
      @tariffs = current_user.load_tariffs
      @users = User.find_all_for_select(current_user.id)
      @providers = Provider.all
      @provider_tariffs = Tariff.where('purpose = "provider"').all
      @lcrs = Lcr.where("user_id = ? ", current_user.id).all
      render :action => :new and return false
    end

    if @cron_setting.save
      flash[:status]=_('Setting_saved')
      redirect_to :action => :index
    else
      flash_errors_for(_('Setting_not_created'), @cron_setting)
      @tariffs = current_user.load_tariffs
      @users = User.find_all_for_select(current_user.id)
      @providers = Provider.all
      @provider_tariffs = Tariff.where('purpose = "provider"').all
      @lcrs = Lcr.where("user_id = ? ", current_user.id).all
      render :action => :new
    end

  end

  def edit
    @page_title = _('Edit_Cron_Setting')
    @page_icon = "clock.png"

    @users = User.find_all_for_select(current_user.id)
    @tariffs = current_user.load_tariffs
    @providers = Provider.all
    @provider_tariffs = Tariff.where('purpose = "provider"').all
    @lcrs = Lcr.where("user_id = ? ", current_user.id).all
  end

  def update
    @cron_setting.update_attributes(params[:cron_setting])
    @cron_setting.valid_from = current_user.system_time(Time.mktime(params[:activation_start][:year], params[:activation_start][:month], params[:activation_start][:day], params[:activation_start][:hour], '0', '0'))
    @cron_setting.valid_till = current_user.system_time(Time.mktime(params[:activation_end][:year], params[:activation_end][:month], params[:activation_end][:day], params[:activation_end][:hour], '59', '59'))

    lcr = Lcr.where("id = #{params[:cron_setting][:lcr_id].to_i} and user_id = #{current_user.id}").first
    if lcr.blank?
      flash_errors_for(_('Lcr_was_not_found'), @cron_setting)
      @tariffs = current_user.load_tariffs
      @users = User.find_all_for_select(current_user.id)
      @providers = Provider.all
      @provider_tariffs = Tariff.where('purpose = "provider"').all
      @lcrs = Lcr.where("user_id = ? ", current_user.id).all
      render :action => :new and return false
    end

    if @cron_setting.save
      flash[:status]=_('Setting_updated')
      redirect_to :action => :index
    else
      flash_errors_for(_('Setting_not_updated'), @cron_setting)
      @tariffs = current_user.load_tariffs
      @users = User.find_all_for_select(current_user.id)
      @providers = Provider.all
      @provider_tariffs = Tariff.where('purpose = "provider"').all
      @lcrs = Lcr.where("user_id = ? ", current_user.id).all
      render :action => :edit
    end
  end

  def destroy
    @cron_setting.destroy
    flash[:status]=_('Setting_deleted')
    redirect_to :action => :index
  end

  private

  def find_setting
    @cron_setting = current_user.cron_settings.find(:first, :conditions => {:id => params[:id]})
    unless @cron_setting
      flash[:notice] =_('Setting_not_found')
      redirect_to :action => :index
    end
  end
end
