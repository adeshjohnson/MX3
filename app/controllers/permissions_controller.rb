# -*- encoding : utf-8 -*-
class PermissionsController < ApplicationController
  layout "callc"
  before_filter :check_localization
  before_filter :authorize_admin
  before_filter :check_group_type
  before_filter :find_permissions_group, :only => [:destory, :edit, :update]

=begin rdoc
 Lists accountant groups.
=end

  def index
    redirect_to :controller => :callc, :action => :main
  end

  def list
    if params[:group_type].to_s == "accountant"
      @page_title = _('Accountant_Groups')
      @help_link = "http://wiki.kolmisoft.com/index.php/Accountant_permissions"
    else
      @page_title = _('Reseller_Groups')
      @help_link = "http://wiki.kolmisoft.com/index.php/Reseller_permissions"
    end
    @page_icon = "group.png"
    @groups = AccGroup.find(:all, :conditions => ["group_type = ?", params[:group_type]])
  end

=begin rdoc
 Creates a accountant group.

 *Params*:

 * +name+ - goup name

 *Flash*:

 * +Group_was_created+ - if group was successfully created.
 * +Group_was_not_created+ - if group was not successfully created.

 *Redirect*

 * +groups_list+
=end

  def create
    group = AccGroup.new(:name => params[:name].to_s)
    group.group_type = params[:group_type]
    group.description = params[:description].to_s
    if group.save
      group.create_empty_permissions
      flash[:status] = _('Group_was_created')
    else
      flash_errors_for(_('Group_was_not_created'), group)
    end
    redirect_to :action => 'list', :group_type => params[:group_type] and return false
  end

=begin rdoc
 Destroys group

 *Params*:

 * +id+ - group id

 *Flash*:

 * Group_was_destroyed - if group was successfully destroyed
 * Group_was_not_destroyed - if group was not successfully destroyed

 *Redirect*

 * +groups_list+
=end
  def destory
    if @group.destroy
      User.update_all("acc_group_id = NULL", ["acc_group_id = ?", @group.id])
      flash[:status] = _('Group_was_destroyed')
    else
      flash_errors_for(_('Group_was_not_destroyed'), @group)
    end
    redirect_to :action => 'list', :group_type => params[:group_type] and return false
  end

=begin rdoc
 Opens edit form for accountant group.

 *Params*:

 * +id+ - group id

=end

  def edit
    @page_title = _('group_edit') + ": " + @group.name
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Accountant_permissions"
    cond = ["right_type = ?"]; var = [@group.group_type]
    permis = []
    if @group.group_type == 'reseller'
      permis << "'Call_Shop'" if call_shop_active?
      permis << "'Payment_Gateways'" if payment_gateway_active?
      permis << "'Calling_Cards'" if calling_cards_active?
      permis << "'SMS'" if sms_active?
      permis << "'Monitorings'" if monitorings_addon_active?
      permis << "'Webphone'" if web_phone_active?
      permis << "'Autodialer'" if ad_active?

      cond << " nice_name IN (#{permis.join(' , ')})" if permis.size.to_i > 0
    elsif @group.group_type != 'reseller'
      permis << "'Callingcard'" unless calling_cards_active?
      permis << "'Webphone'" unless web_phone_active?

      cond << "permission_group NOT IN (#{permis.join(' , ')})" if permis.size.to_i > 0
    end

    if (permis and permis.size.to_i > 0) or @group.group_type != 'reseller'
      @rights = AccRight.find(:all, :conditions => [cond.join(" AND ")].concat(var), :order => "permission_group, id DESC")
    else
      @rights = []
    end
  end

=begin rdoc
 Updates accountant group.
=end

  def update
    @group.name = params[:name].to_s
    @group.only_view = params[:only_view].to_i
    @group.description = params[:group][:description].to_s
    if @group.save
      acc_group_rights = @group.acc_group_rights
      rights = AccRight.find(:all, :conditions => ["right_type = ?", @group.group_type])
      rights.each { |right|
        gr = acc_group_rights.select { |r| r.acc_right_id == right.id }[0]
        gr = AccGroupRight.new(:acc_group => @group, :acc_right => right) if gr.nil?

        if (params["right_#{right.id}".to_sym] and params["right_#{right.id}".to_sym].to_i != gr.value) or gr.new_record? or @group.only_view == true
          params["right_#{right.id}".to_sym] ? gr.value = params["right_#{right.id}".to_sym].to_i : gr.value = 0
          gr.value = 1 if gr.value > 1 and @group.only_view
          gr.save
        end
      }
      flash[:status] = _('Group_was_updated')
    else
      flash_errors_for(_('Group_was_not_updated'), @group)
    end
    redirect_to :action => 'edit', :id => params[:id], :group_type => params[:group_type] and return false
  end

  private

  def find_permissions_group
    @group = AccGroup.find(:first, :conditions => ["id = ? AND group_type = ?", params[:id], params[:group_type]])
    unless @group
      flash[:notice] = _("Group_was_not_found")
      redirect_to :action => :groups_list and return false
    end
  end


  def check_group_type
    unless ["reseller", "accountant"].include?(params[:group_type])
      flash[:notice] = _("Group_was_not_found")
      redirect_to :controller => :callc, :action => :main and return false
    end
  end
end
