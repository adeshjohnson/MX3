class LocationsController < ApplicationController

  require "yaml"
  layout "callc"
  before_filter :check_localization
  before_filter :authorize
  #before_filter :check_permsission
  before_filter :find_location, :only=>[:location_rules, :location_devices, :location_destroy]
  before_filter :find_location_rule, :only => [:location_rule_edit, :location_rule_update, :location_rule_change_status, :location_rule_destroy ]


  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [:location_destroy, :location_rule_update, :location_rule_change_status, :location_rule_destroy, :location_change ],
    :redirect_to => { :action => :index },
    :add_flash => { :notice => _('Dont_be_so_smart'),
    :params => {:dont_be_so_smart => true}}

  def index
    flash[:notice] = _('Dont_be_so_smart')
    redirect_to :controller => :callc,  :action => :main and return false
  end

  def localization
    @page_title = _('Localization')
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Manipulation"
    @locations = current_user.locations
  end

  def location_rules
    @page_title = _('Location_rules')
    @page_icon = 'page_white_gear.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Manipulation"

    if current_user.usertype == 'admin'
      @users = User.find(:all, :select=>"users.*, #{SqlExport.nice_user_sql}", :joins=>"JOIN devices ON (users.id = devices.user_id)", :conditions => "hidden = 0 and devices.id > 0 ", :order => "nice_user ASC", :group=>'users.id')
    else
      @users = User.find(:all, :select=>"users.*, #{SqlExport.nice_user_sql}", :joins=>"JOIN devices ON (users.id = devices.user_id)", :conditions => "hidden = 0 and devices.id > 0 AND owner_id = #{correct_owner_id}", :order => "nice_user ASC", :group=>'users.id')
    end
    @rules = @location.locationrules(:all, :include=>[:device])

    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{session[:user_id]}' #{cond} ", :order => "purpose ASC, name ASC")
    #find current users lcr with check what type reseller
    @lcrs = current_user.load_lcrs(:all, :order => "name ASC")

    @grules_dst = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", 1,"dst"], :order => "name ASC")
    @grules_src = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", 1,"src"], :order => "name ASC")
    @rules_dst = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", @location.id,"dst"], :order => "name ASC")
    @rules_src = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", @location.id,"src"], :order => "name ASC")
    cond = ["dids.id > 0"]
    var = []
    cond << "dids.reseller_id = ?" and var << current_user.id if current_user.usertype == 'reseller'
    @dids = Did.find(:all,:include=>[:user, :device, :provider, :dialplan], :conditions => [cond.join(" AND ")].concat(var), :order => "dids.did ASC")
  end

=begin
in before filter : rule (:find_location_rule)
=end
  def location_rule_edit
    @page_title = _('Location_rule_edit')
    @page_icon = 'edit.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Manipulation"
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.find(:all, :conditions => "owner_id = '#{session[:user_id]}' #{cond} ", :order => "purpose ASC, name ASC")
    #find current users lcr with check what type reseller
    @lcrs = current_user.load_lcrs(:all, :order => "name ASC")
    if current_user.usertype == 'admin'
      @users = User.find(:all, :select=>"users.*, #{SqlExport.nice_user_sql}", :joins=>"JOIN devices ON (users.id = devices.user_id)", :conditions => "hidden = 0 and devices.id > 0 ", :order => "nice_user ASC", :group=>'users.id')
    else
      @users = User.find(:all, :select=>"users.*, #{SqlExport.nice_user_sql}", :joins=>"JOIN devices ON (users.id = devices.user_id)", :conditions => "hidden = 0 and devices.id > 0 AND owner_id = #{correct_owner_id}", :order => "nice_user ASC", :group=>'users.id')
    end
    @devices = Device.find(:all, :conditions=>["user_id =?" , @rule.device.user_id]) if @rule.device
    cond = ["dids.id > 0"]
    var = []
    cond << "dids.reseller_id = ?" and var << current_user.id if current_user.usertype == 'reseller'
    @dids = Did.find(:all,:include=>[:user, :device, :provider, :dialplan], :conditions => [cond.join(" AND ")].concat(var), :order => "dids.did ASC")
  end

=begin
in before filter : rule (:find_location_rule)
=end
  def location_rule_update
    if params[:name].blank? #or (params[:cut].length == 0 and params[:add].length ==0)
      flash[:notice] = _('Please_enter_name')
      redirect_to :action => 'location_rule_edit', :id => @rule.id   and return false
    end
    @rule.name = params[:name]
    @rule.cut = params[:cut] if params[:cut]
    @rule.add = params[:add] if params[:add]
    @rule.minlen = params[:minlen] if !params[:minlen].blank?
    @rule.maxlen = params[:maxlen] if !params[:maxlen].blank?
    @rule.tariff_id = params[:tariff] if params[:tariff]
    @rule.lcr_id = params[:lcr] if params[:lcr]
    @rule.did_id = params[:did] if params[:did]
    @rule.device_id = params[:device_id_from_js] if params[:device_id_from_js]
    @rule.save ? flash[:status] = _('Rule_updated') : flash_errors_for(_('Rule_not_updated'), @rule)
    redirect_to :action => 'location_rules', :id => @rule.location_id
  end

=begin
in before filter : rule (:find_location_rule)
=end
  def location_rule_change_status
    if @rule.enabled ==  0
      @rule.enabled = 1; st =_('Rule_enabled')
    else
      @rule.enabled = 0; st = _('Rule_disabled')
    end
    @rule.save ? flash[:status] = st : flash[:notice] = _('Update_Failed')
    redirect_to :action => 'location_rules', :id => @rule.location_id
  end

=begin
in before filter : rule (:find_location_rule)
=end
  def location_rule_destroy
    location_id = @rule.location_id
    @rule.destroy ? flash[:status] = _('Rule_deleted') : flash[:notice] = _('Rule_not_deleted')
    redirect_to :action => 'location_rules', :id => location_id
  end


  def location_rule_add

    rule = Locationrule.new({:name=>params[:name], :enabled=>1, :lr_type=>params[:lr_type]})
    rule.location_id = params[:location_id]
    rule.cut = params[:cut] if params[:cut]
    rule.add = params[:add] if params[:add]
    rule.minlen = params[:minlen] if !params[:minlen].blank?
    rule.maxlen = params[:maxlen] if !params[:maxlen].blank?
    rule.tariff_id = params[:tariff] if params[:tariff]
    rule.lcr_id = params[:lcr] if params[:lcr]
    rule.did_id = params[:did] if params[:did]
    rule.device_id = params[:device_id_from_js] if params[:device_id_from_js] and params[:device_id_from_js].to_i > 0
    if rule.save
      flash[:status] = _('Rule_added')
    else
      flash_errors_for(_('Rule_not_created'), rule)
    end
    redirect_to :action => 'location_rules', :id => params[:location_id]
  end


  def location_devices
    @page_title = _('Location_devices')
    @page_icon = 'device.png'

    @devices = @location.devices
    @locations = current_user.locations
  end

  def location_change
    device = Device.find_by_id(params[:id])
    unless  device
      flash[:notice]=_('Device_was_not_found')
      redirect_to :action=>:localization and return false
    end
    old_loc = device.location_id
    device.location_id = params[:location]
    if device.save
      flash[:notice] = _('Device_location_changed_and_moved_to_another_group')
    else
      flash_errors_for(_('Device_location_dont_changed'), device)
    end
    redirect_to :action => 'location_devices', :id => old_loc and return false
  end

  def location_add
    loc = Location.new({:name=>params[:name]})
    loc.save ? flash[:status] = _('Location_added'): flash_errors_for(_('Please_enter_name'), loc)
    redirect_to :action => 'localization'  and return false
  end

  def location_destroy
    devices = @location.devices.count
    cardgroups = Cardgroup.find(:all,:conditions=>"location_id = #{@location.id}").size

    if devices == 0 and cardgroups == 0 and @location.destroy_all
      flash[:status] = _('Location_deleted')
    elsif devices > 0 or cardgroups >0
      flash[:notice] = _('Location_is_assigned_to_device_or_cardgroup')
    else
      flash_errors_for(_('Location_not_deleted'), @location)
    end
    redirect_to :action => 'localization'
    
  end
  
  #Ticket 3495 ------------
  def import_admins_locations
    @page_title = _('Import_admins_locations_with_rules')
    if reseller?
      @locations = Location.find(:all, :conditions=>{:user_id=>0}, :order => "name ASC")
    else
      dont_be_so_smart
      redirect_to :controller => 'callc', :action => 'main'
    end
  end

  def admins_location_rules
    if reseller?
      @page_title = _('Admins_location_rules')
      @location = Location.find_by_id(params[:id])
      @rules = @location.locationrules

      @grules_dst = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", 1,"dst"], :order => "name ASC")
      @grules_src = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", 1,"src"], :order => "name ASC")
      @rules_dst = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", @location.id,"dst"], :order => "name ASC")
      @rules_src = Locationrule.find(:all, :conditions => ["location_id =? and lr_type =?", @location.id,"src"], :order => "name ASC")
      render :action => :location_rules
    else
      dont_be_so_smart
      redirect_to :controller => 'callc', :action => 'main'
    end
  end
  
  def delete_and_import_admins_location
    if reseller?
      #find all resellers locations and delete them
      @locations = Location.find(:all, :conditions=>{:user_id=>correct_owner_id}, :order => "name ASC")
      for location in @locations
        location.destroy_all
      end
      #create new default location
      current_user.create_reseller_localization
      location_id = Confline.get_value("Default_device_location_id",current_user.id).to_i
      #change all devices and cardgroups locations (providers location id is in his device location_id)
      Device.update_all "location_id = #{location_id}", "user_id IN (SELECT id from users where owner_id = #{current_user.id}) OR id IN (SELECT device_id FROM providers WHERE user_id = #{current_user.id})"
      Cardgroup.update_all "location_id = #{location_id}", "owner_id = #{current_user.id}"
      #get all admins locations with rules
      admins_locations = Location.find(:all,:conditions=>['locations.user_id=? and locations.name != ?',0, 'Global'], :include=>[:locationrules])
    
      for a_location in admins_locations
        loc = Location.new({:name=>a_location.name, :user_id=> a_location.user_id })
        loc.user_id = a_location.user_id
        loc.save
        logger.fatal('Location created')
 
        for a_rules in a_location.locationrules
          rule = Locationrule.new({:name=>a_rules.name, :enabled=>1, :lr_type=>a_rules.lr_type})
          rule.location_id = loc.id
          rule.cut = a_rules.cut if a_rules.cut
          rule.add = a_rules.add if a_rules.add
          rule.minlen = a_rules.minlen if !a_rules.minlen.blank?
          rule.maxlen = a_rules.maxlen if !a_rules.maxlen.blank?
          rule.save
          logger.fatal('rule created')
        end
      end   
      redirect_to :action => 'localization'
      flash[:status] = _('Old_Locations_deleted_and_new_Locations_added')
    end
  end
  #-----------
  private

  def find_location_rule
    @rule = Locationrule.find_by_id(params[:id])
    unless @rule
      flash[:notice]=_('Location_rule_was_not_found')
      redirect_to :action=>:localization and return false
    end
    check_location_rule_owner
  end

  def find_location
    @location = Location.find_by_id(params[:id])
    unless @location
      flash[:notice]=_('Location_was_not_found')
      redirect_to :action=>:localization and return false
    end
    check_location_owner
  end

  def check_location_owner
    unless @location.user_id == correct_owner_id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
  end

  def check_location_rule_owner
    unless @rule.location and @rule.location.user_id == correct_owner_id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
  end

  def check_permsission
    unless allow_manage_providers?
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
  end
end
