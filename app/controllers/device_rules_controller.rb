class DeviceRulesController < ApplicationController
  layout "callc"

  before_filter :allow_to_use
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_device, :only => [:list, :create]
  before_filter :find_device_rule, :only => [:change_status, :destroy, :edit, :update]


  def list
    @page_title = _('Device_rules')
    @page_icon = 'page_white_gear.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Device_Rules"
    @rules = @device.devicerules
    @rules_dst = Devicerule.find(:all, :conditions => ["device_id = ? and pr_type = ?", @device.id, "dst"])
    @rules_src = Devicerule.find(:all, :conditions => ["device_id = ? and pr_type = ?", @device.id, "src"])
  end

  def change_status

    if @devicerule.enabled == 0
      @devicerule.enabled = 1
      flash[:status] = _('Rule_enabled')
    else
      @devicerule.enabled = 0
      flash[:status] = _('Rule_disabled')
    end
    @devicerule.save
    redirect_to :action => :list, :id => @devicerule.device_id
  end

  def create
    if params[:name].blank? or (params[:cut].blank? and params[:add].blank?)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to :action => :list, :id => params[:id] and return false
    end

    rule = Devicerule.new({
                              :device_id => @device.id,
                              :name => params[:name].to_s.strip,
                              :enabled => 1,
                              :pr_type => params[:pr_type].to_s.strip
                          })
    rule.cut = params[:cut].to_s.strip if params[:cut]
    rule.add = params[:add].to_s.strip if params[:add]
    rule.minlen = params[:minlen].to_s.strip if params[:minlen].length > 0
    rule.maxlen = params[:maxlen].to_s.strip if params[:maxlen].length > 0
    if rule.save
      flash[:status] = _('Rule_added')
    else
      if rule.cut == rule.add
        flash[:notice] = _('Add_Failed')+" : "+_('Cut_Equals_Add')
      else
        flash[:notice] = _('Add_Failed')
      end
    end
    redirect_to :action => :list, :id => @device.id
  end

  def destroy
    dev_id = @devicerule.device_id
    @devicerule.destroy
    flash[:status] = _('Rule_deleted')
    redirect_to :action => :list, :id => dev_id
  end

  def edit
    @page_title = _('Device_rule_edit')
    @page_icon = 'edit.png'
  end

  def update
    if params[:name].length == 0 or (params[:cut].length == 0 and params[:add].length ==0)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to :action => :list, :id => @devicerule.device_id and return false
    end

    @devicerule.name = params[:name].to_s.strip
    @devicerule.cut = params[:cut].to_s.strip if params[:cut]
    @devicerule.add = params[:add].to_s.strip if params[:add]
    @devicerule.minlen = params[:minlen].to_s.strip if params[:minlen].length > 0
    @devicerule.maxlen = params[:maxlen].to_s.strip if params[:maxlen].length > 0
    if @devicerule.save
      flash[:status] = _('Rule_updated')
    else
      flash[:notice] = _('Update_Failed')
    end
    redirect_to :action => :list, :id => @devicerule.device_id

  end

  private

  def find_device
    @device = Device.find(:first, :conditions => ['devices.id=?', params[:id]], :include => [:user, :dids])

    unless @device
      flash[:notice] = _('Device_was_not_found')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    if @device.user.owner_id.to_i != current_user.id.to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def find_device_rule
    @devicerule = Devicerule.find(:first, :conditions => ['devicerules.id=?', params[:id]], :include => [:device])

    unless @devicerule
      flash[:notice] = _('Devicerule_was_not_found')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    unless Device.where(:id => @devicerule.device_id).first
      flash[:notice] = _('Database_corruption_device_rule_does_not_have_device')
      redirect_to :controller => "callc", :action => "main" and return false
    end

    if @devicerule.device.user.owner_id.to_i != current_user.id.to_i
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def allow_to_use
    if ['user', 'accountant'].include?(current_user.usertype.to_s)
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end
end
