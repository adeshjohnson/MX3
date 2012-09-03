# -*- encoding : utf-8 -*-
class CommonUseProvidersController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_rs_pro_addon
  before_filter :find_data, :only => [:edit, :update, :destroy]

  def index
    @page_title = _('Common_use_providers')
    @page_icon = "provider.png"

    session[:common_use_providers_list_options] ? @options = session[:common_use_providers_list_options] : @options = {}
    # page number is an exception because it defaults to 1
    if params[:page] and params[:page].to_i > 0
      @options[:page] = params[:page].to_i
    else
      @options[:page] = 1 if !@options[:page] or @options[:page] <= 0
    end
    # same goes for order descending
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"
    if !@options[:order_by]
      order_by = " "
    else
      if @options[:order_desc] == 0
        order = "asc"
      else
        order = "desc"
      end
      order_by = "ORDER BY #{(@options[:order_by])+ ' '+ order}"
    end

    @total_pages = (CommonUseProvider.count.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages and @total_pages > 0
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i
    limit = " LIMIT #{@fpage}, #{session[:items_per_page].to_i}"
    #select records, common use providers, resellers pro, retail and wholesale tariffs
    @data = CommonUseProvider.find_by_sql("SELECT common_use_providers.id,  concat(providers.name,' ', providers.tech,'/', providers.server_ip, ':',providers.port) as provider_name,tariffs.name as tariff_name, #{SqlExport.nice_user_sql} from common_use_providers LEFT JOIN users ON (users.id = common_use_providers.reseller_id) LEFT JOIN providers ON (providers.id = common_use_providers.provider_id) LEFT JOIN tariffs ON (tariffs.id = common_use_providers.tariff_id) #{order_by} #{limit}")


    #@data = CommonUseProvider.find(:all, :include => [:user,:provider,:tariff], :order => (@options[:order_by]) + ' ' + order)
    @common_use_providers = Provider.find(:all, :conditions => 'common_use = 1', :order => 'name asc')
    @resellers = User.find(:all, :conditions => 'usertype = "reseller" AND own_providers = 1')
    @tariffs = Tariff.find(:all, :conditions => "purpose != 'provider' AND owner_id = 0", :order => "purpose ASC, name ASC")
    session[:common_use_providers_list_options] = @options
  end

  def create
    #check params, must be selected all
    if params[:select_provider].to_i != 0 and params[:select_reseller].to_i != 0 and params[:select_tariff].to_i != 0
      #check record, must not be duplicate
      if check_record(params[:select_reseller], params[:select_provider])
        flash[:notice] = _('Record_exists')
      else
        #create record
        data = CommonUseProvider.new({:provider_id => params[:select_provider].to_i, :reseller_id => params[:select_reseller].to_i, :tariff_id => params[:select_tariff].to_i})
        data.save
        flash[:status] = _('Record_created')
      end
    else
      flash[:notice] = _("You_must_select_all_three_parameters")
    end
    #redirect to list
    redirect_to :action => :index

  end

  def edit
    @page_title = _('Common_use_providers_edit')
    @page_icon = "edit.png"

    @data = @commmon_use_provider
    @common_use_providers = Provider.find(:all, :conditions => 'common_use = 1', :order => 'name asc')
    @resellers = User.find(:all, :conditions => 'usertype = "reseller" AND own_providers = 1')
    @tariffs = Tariff.find(:all, :conditions => "purpose != 'provider' AND owner_id = 0", :order => "purpose ASC, name ASC")
  end

  def update
    #check record, must not be duplicate
    if check_record(params[:select_reseller], params[:select_provider], params[:id].to_i)
      flash[:notice] = _('Record_exists')
      #redirect to edit
      redirect_to :action => :edit, :id => params[:id].to_i
    else
      #update record
      data = @commmon_use_provider
      data.reseller_id = params[:select_reseller]
      data.provider_id = params[:select_provider]
      data.tariff_id = params[:select_tariff]
      data.save
      flash[:status] = _('Record_updated')
      #redirect to list
      redirect_to :action => :index
    end
  end

  def destroy
    #remove record
    data = @commmon_use_provider
    data.destroy ? flash[:status] = _('Record_deleted') : flash[:notice] = _('Record_not_deleted')
    #redirect to list
    redirect_to :action => :index
  end

  def let_resellers_use_all_common_use_providers
    if admin?
      providers = Provider.find(:all, :conditions => 'common_use = 1 and user_id = 0', :order => 'name asc')
      resellers = User.find(:all, :conditions => 'usertype = "reseller" AND own_providers = 1')
      #create record
      if resellers
        resellers.each do |reseller|
          #for reseller add all common use providers with default resellers tariff
          if providers
            providers.each do |provider|
              if !check_record(reseller.id, provider.id)
                data = CommonUseProvider.new({:provider_id => provider.id, :reseller_id => reseller.id, :tariff_id => reseller.tariff.id})
                data.save
              end
            end
          end
        end
        flash[:status] = _('Record_created')
        redirect_to :action => :index
      end
    else
      dont_be_so_smart
      redirect_to :controller => 'callc', :action => 'main'
    end

  end

  private

  def check_record(reseller, provider, id = nil)
    #check record if exists
    cond = ""
    #for update with no changes
    cond = "AND id != #{id}" if id

    if CommonUseProvider.find(:first, :conditions => ["reseller_id = ? AND provider_id = ? "+cond, reseller, provider])
      return true
    end

  end

  def find_data
    @commmon_use_provider = CommonUseProvider.find(:first, :conditions => {:id => params[:id]})
    unless @commmon_use_provider
      flash[:notice] =_('Commmon_Use_Provider_not_found')
      redirect_to :action => :index
    end
  end

  def check_rs_pro_addon
    unless reseller_pro_active?
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end
end
