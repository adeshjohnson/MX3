# -*- encoding : utf-8 -*-
class QuickforwardsRulesController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_quickforwards_rule, :only => [:edit, :update, :destroy, :show]


  def list
    @page_title = _('Quickforwards_Rules')
    @quickforwards_rules = current_user.quickforwards_rules.order("name").all

  end

  def new
    @page_title = _('Create_new_Quickforwards_Rule')
    @page_icon = "add.png"
    @quickforwards_rule = QuickforwardsRule.new
  end

  def create
    @page_title = _('Create_new_Quickforwards_Rule')
    @quickforwards_rule = QuickforwardsRule.new(params[:quickforwards_rule])

    if @quickforwards_rule.save
      flash[:status] = _('Quickforwards_Rule_was_successfully_created')
      redirect_to :action => 'list'
    else
      flash_errors_for(_('Quickforwards_Rule_was_not_created'), @quickforwards_rule)
      render :action => 'new'
    end
  end

  def edit
    @page_title = _('Edit_Quickforwards_Rule') + ": " + @quickforwards_rule.name
    @page_icon = "edit.png"
  end

  def update
    if @quickforwards_rule.update_attributes(params[:quickforwards_rule])
      flash[:status] = _('Quickforwards_Rule_was_successfully_updated')
      redirect_to :action => 'list', :id => @quickforwards_rule
    else
      flash_errors_for(_('Quickforwards_Rule_was_not_created'), @quickforwards_rule)
      render :action => 'edit'
    end
  end

  def show
    @page_title = _('Users') + ": " + @quickforwards_rule.name
    @page_icon = "user.png"
    @users = @quickforwards_rule.users
  end

  def destroy
    @quickforwards_rule.destroy
    flash[:status] = _('Quickforwards_Rule_was_successfully_deleted')
    redirect_to :action => 'list'
  end

=begin
  dummy method, nothing to do here
=end
  def settings
    @page_title = _('Quickforward_settings') 
    @tell_balance = Confline.get_value('Tell_Balance').to_i
    @tell_time = Confline.get_value('Tell_Time').to_i
  end

=begin
  Update conflines and set tell time/balance settings, update same every quickforwarddids
  dialplan's settings. and redirect back to settings page.
=end
  def update_settings
    tell_balance = Confline.get_value('Tell_Balance').to_i
    tell_time = Confline.get_value('Tell_Time').to_i
    Confline.set_value('Tell_Balance', params[:tell_balance].to_i)
    Confline.set_value('Tell_Time', params[:tell_time].to_i)
    Dialplan.change_tell_balance_value(params[:tell_balance].to_i) if tell_balance != params[:tell_balance].to_i
    Dialplan.change_tell_time_value(params[:tell_time].to_i) if tell_time != params[:tell_time].to_i
    redirect_to :action => :settings
  end

  private

  def find_quickforwards_rule
    @quickforwards_rule = QuickforwardsRule.find(:first, :conditions => {:id => params[:id], :user_id => current_user.id}, :include => [:users])
    unless @quickforwards_rule
      flash[:notice]=_('Quickforwards_Rule_was_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

end
