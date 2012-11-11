# -*- encoding : utf-8 -*-
class RinggroupsController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]

  before_filter :check_localization
  before_filter :authorize
  before_filter :find_ringgroup, :only => [:show, :edit, :destroy, :assign_device, :show_dids, :show_devices, :show_extlines, :device_sort, :update, :free_user_devices, :delete_device]

  def index
    @page_title = _('Ring_groups')

    session[:ringgroups_list_options] ? @options = session[:ringgroups_list_options] : @options = {}

    # search
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"

    order_by = current_user.ringgroups.ringgroups_order_by(params, @options)

    cond =[]; var =[]
    arr = {}
    arr[:conditions] =[cond.join(' AND ')] + var if cond.size.to_i > 0

    # page params
    @ringgroups_size = current_user.ringgroups.find(:all, arr).size.to_i
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@ringgroups_size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @search = @options[:s_name].blank? ? 0 : 1

    arr[:order] = order_by
    arr[:limit] = "#{@fpage}, #{session[:items_per_page].to_i}"

    @ringgroups = current_user.ringgroups.find(:all, arr)

    session[:ringgroups_list_options] = @options
  end

  def new
    @page_title = _('Ring_group_new')
    @page_icon = "add.png"

    @ringgroup = Ringgroup.new()
    @ringgroup.timeout = 60
    @dialplan = Dialplan.new
    @dids = current_user.dids_for_select('assigned')
  end

  def create

    #check if extension entered
    ext = params[:dialplan][:data2]

    params[:ringgroup][:did_id] = Did.where(['did = ?', params[:ringgroup][:did_id]]).first.id rescue 0
    logger.fatal params[:ringgroup][:did_id].to_yaml + "DERP DERP DERP DERP"
    @ringgroup = Ringgroup.new(params[:ringgroup].merge({:name=>params[:dialplan][:name]}))
    @dialplan = Dialplan.new(params[:dialplan].merge({:dptype => "ringgroup"}))


    if not ext or ext.length == 0
      @page_title = _('Ring_group_new')
      @page_icon = "add.png"

      @dids = current_user.dids_for_select('assigned')
      flash[:notice] = _('Enter_extension')
      render :action => :new and return false
    end

    # check if such extension exist
    extline = Extline.find(:first, :conditions => "exten = '#{ext}'")

    if extline
      @page_title = _('Ring_group_new')
      @page_icon = "add.png"

      @dids = current_user.dids_for_select('assigned')
      flash[:notice] = _('Such_extension_exists')
      render :action => :new and return false
    end

    if !params[:dialplan] or params[:dialplan][:name].blank?
      @page_title = _('Ring_group_new')
      @page_icon = "add.png"

      @dids = current_user.dids_for_select('assigned')
      flash[:notice] = _('Name_cannot_be_blank')
      render :action => :new and return false
    end

    if @ringgroup.save
      @dialplan.data1 = @ringgroup.id
      @dialplan.save
      @ringgroup.update_exline(ext)
      flash[:status] = _('Ring_Group_was_successfully_created')
      redirect_to :action => :edit, :id => @ringgroup.id
    else
      @page_title = _('Ring_group_new')
      @page_icon = "add.png"

      @dids = current_user.dids_for_select('assigned')
      flash_errors_for(_('Ring_Group_not_created'), @ringgroup)
      render :action => :new and return false
    end

  end


  def edit
    @page_title = _('Ring_group_edit')
    @page_icon = "edit.png"

    @dids = current_user.dids_for_select('assigned')
    @free_dids = Did.free_dids_for_select(@ringgroup.did_id)
    @devices = @ringgroup.devices
    @dialplan = @ringgroup.dialplan
    @users = User.find(:all)
    @extlines = Extline.find(:all, :conditions => ['exten = ? AND app IN ("Set", "Dial", "Goto")', @dialplan.data2], :order => "priority ASC")
  end

  def update
    params[:ringgroup][:did_id] = Did.where(['did = ?', params[:ringgroup][:did_id]]).first.id rescue 0
    if !params[:dialplan] or params[:dialplan][:name].blank?
      @page_title = _('Ring_group_edit')
      @page_icon = "edit.png"

      @dids = current_user.dids_for_select('assigned')
      @free_dids = Did.free_dids_for_select(@ringgroup.did_id)
      @devices = @ringgroup.devices
      @dialplan = @ringgroup.dialplan
      @users = User.find(:all)
      @extlines = Extline.find(:all, :conditions=>['exten = ? AND app IN ("Set", "Dial", "Goto")', @dialplan.data2], :order=>"priority ASC")
      flash[:notice] = _('Name_cannot_be_blank')
      @ringgroup.attributes = params[:ringgroup].reject{|k,v| k == 'user_id'}
      render :action => :edit and return false
    end

    if @ringgroup.update_attributes(params[:ringgroup].reject{|k,v| k == 'user_id'})
      @dialplan = @ringgroup.dialplan
      ext = @dialplan.data2.to_s
      @dialplan.update_attributes(params[:dialplan])
      @ringgroup.update_exline(ext)
      flash[:status] = _('Ring_Group_was_successfully_updated')
      redirect_to :action=>:index
    else
      @page_title = _('Ring_group_edit')
      @page_icon = "edit.png"

      @dids = current_user.dids_for_select('assigned')
      @free_dids = Did.free_dids_for_select(@ringgroup.did_id)
      @devices = @ringgroup.devices
      @dialplan = @ringgroup.dialplan
      @users = User.find(:all)
      @extlines = Extline.find(:all, :conditions=>['exten = ? AND app IN ("Set", "Dial", "Goto")', @dialplan.data2], :order=>"priority ASC")
      flash_errors_for(_('Ring_Group_not_updated'), @ringgroup)
      render :action => :edit and return false
    end

  end

  def destroy
    if @ringgroup.dialplan
      @ringgroup.delete_exline
      @ringgroup.dialplan.destroy
    end
    @ringgroup.ringgroups_devices.destroy_all()
    if @ringgroup.destroy
      flash[:status] = _('Ring_Group_was_successfully_deleted')
    else
      flash_errors_for(_('Ring_Group_not_deleted'), @ringgroup)
    end
    redirect_to :action => :index
  end

  def assign_device
    r = RinggroupsDevice.new({:device_id => params[:device_id].to_i, :ringgroup_id => @ringgroup.id})
    r_old = RinggroupsDevice.find(:first, :conditions => {:ringgroup_id => @ringgroup.id}, :order => 'priority DESC')
    r.priority = r_old ? r_old.priority.to_i + 1 : 0
    r.save
    @ringgroup.update_exline
    @devices = @ringgroup.devices
    @users = User.find(:all)
    render :layout => false
  end

  def delete_device
    r = RinggroupsDevice.find(:first, :conditions => {:device_id => params[:device_id].to_i, :ringgroup_id => @ringgroup.id})
    r.destroy
    @ringgroup.update_exline
    @devices = @ringgroup.devices
    @users = User.find(:all)
    render :layout => false
  end


  def device_sort
    params[:sortable_list].each_index do |i|
      item = RinggroupsDevice.find(:first, :conditions => {:device_id => params[:sortable_list][i], :ringgroup_id => @ringgroup.id})
      item.update_attributes(:priority => i)
    end
    @ringgroup.update_exline
    @devices = @ringgroup.devices
    @users = User.find(:all)
    @dids = current_user.dids_for_select('free')
    @free_dids = Did.free_dids_for_select(@ringgroup.did_id)
    render :layout => false, :action => :edit, :id => @ringgroup
  end

  def free_user_devices
    @free_devices = @ringgroup.free_devices(params[:user_id].to_i)
    render :layout => false
  end

  def show_dids
    @dialplan = @ringgroup.dialplan
    render :layout => false
  end

  def show_devices
    @devices = @ringgroup.devices
    render :layout => false
  end

  def show_extlines
    devices = @ringgroup.devices
    appdata = ''
    if devices
      devices.each_with_index { |d, i|
        if d.device_type.to_s == 'Virtual'
          if i > 0
            appdata += "&Local/#{d.name}@mor_local"
          else
            appdata += "Local/#{d.name}@mor_local"
          end
        else
          if i > 0
            appdata += "&#{d.device_type}/#{d.name}"
          else
            appdata += "#{d.device_type}/#{d.name}"
          end
        end
      }
    end

    appdata += "|#{params[:timeout]}|#{params[:options]}"
    @set, @dial, @goto = ''
    @set = "exten => #{params[:exten]},1,Set(CALLERID(NAME) = \"#{params[:prefix]}\"+${CALLERID(NAME)})" if !params[:prefix].blank?
    @dial = "exten => #{params[:exten]},2,Dial(#{appdata})"
    @goto = "exten => #{params[:exten]},3,Goto(mor|#{params[:did]}|1)" if params[:did].to_i > 0
    render :layout => false
  end


  private

  def find_ringgroup
    @ringgroup = current_user.ringgroups.find(:first, :conditions => {:id => params[:id]}, :include => [:dialplan])
    unless @ringgroup
      flash[:notice] = _('Ringgroup_was_not_found')
      redirect_to :controller => "ringgroups" and return false
    end
  end

end
