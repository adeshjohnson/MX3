class QuickforwardsRulesController < ApplicationController

  layout "callc"

  before_filter :check_localization
  before_filter :authorize
  before_filter :find_quickforwards_rule, :only => [:edit, :update, :destroy, :show]


  # GETs should be safe (see http://www.w3.dorg/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
    :redirect_to => { :action => :list },
    :add_flash => { :notice => _('Dont_be_so_smart'),
    :params => {:dont_be_so_smart => true}}

  def list
    @page_title = _('Quickforwards_Rules')
    @quickforwards_rules = current_user.quickforwards_rules(:all, :order => "name")
    
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
      render  :action => 'new'
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

  private

  def find_quickforwards_rule
    @quickforwards_rule = QuickforwardsRule.find(:first, :conditions=>{:id=>params[:id], :user_id=>current_user.id}, :include=>[:users])
    unless @quickforwards_rule
      flash[:notice]=_('Quickforwards_Rule_was_not_found')
      redirect_to :controller=>:callc, :action=>:main and return false
    end
  end

end
