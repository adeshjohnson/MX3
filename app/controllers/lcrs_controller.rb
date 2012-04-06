# -*- encoding : utf-8 -*-
class LcrsController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:remove_provider, :destroy, :create, :update, :lcrpartial_destroy, :update_lcrpartial]


  before_filter :check_localization
  before_filter :authorize
  before_filter :providers_enabled_for_reseller?
  before_filter :find_lcr_from_id, :only => [:lcr_clone, :make_tariff, :details, :provider_change_status, :remove_provider, :try_to_add_provider, :providers_sort_save, :providers_sort, :providers_percent, :provider_change_status, :edit, :update, :destroy, :details_by_destinations, :providers_list, :try_to_add_failover_provider]
  before_filter :find_lcr_partial_from_id, :only => [:lcrpartial_destroy, :lcrpartial_edit, :update_lcrpartial]
  before_filter :check_owner, :only => [:make_tariff, :details, :provider_change_status, :remove_provider, :try_to_add_provider, :providers_sort_save, :providers_sort, :providers_percent, :provider_change_status, :edit, :update, :destroy, :details_by_destinations, :providers_list, :try_to_add_failover_provider]

  def list
    @page_title = _('LCR')
    @page_icon = "arrow_switch.png"

    @Show_Currency_Selector=1

    session[:lcrs_list_options] ? @options = session[:lcrs_list_options] : @options = {}

    # search
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:s_name] ? @options[:s_name] = params[:s_name].to_s : (params[:clean]) ? @options[:s_name] = "" : (@options[:s_name]) ? @options[:s_name] = session[:lcrs_list_options][:s_name] : @options[:s_name] = ""

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"

    order_by = current_user.lcrs.lcrs_order_by(params, @options)

    cond =[]; var =[]
    if !@options[:s_name].blank?
      cond << 'lcrs.name LIKE ?'; var << ["%" +@options[:s_name] + "%"]
    end
    arr = {}
    arr[:conditions] =[cond.join(' AND ')] + var if cond.size.to_i > 0

    # page params
    @lcrs_size = current_user.load_lcrs(:all, arr).size.to_i
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@lcrs_size.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @search = @options[:s_name].blank? ? 0 : 1

    arr[:order] = order_by
    arr[:limit] = "#{@fpage}, #{session[:items_per_page].to_i}"
    @lcrs = current_user.load_lcrs(:all, arr)

    session[:lcrs_list_options] = @options
  end

  def new
    @page_title = _('LCR_new')
    @page_icon = "add.png"
    @lcr = Lcr.new
  end

  def create
    @page_title = _('LCR_new')
    @page_icon = "add.png"

    @lcr = Lcr.new(params[:lcr].merge!({:user_id => current_user.id}))
    if @lcr.save
      flash[:status] = _('Lcr_was_successfully_created')
      redirect_to :action => 'list'
    else
      flash_errors_for(_('Lcr_not_created'), @lcr)
      render :action => 'new'
    end
  end

  #in before filter : @lcr
  def edit
    @page_title = _('LCR_edit')
    @page_icon = "edit.png"
  end

  #in before filter : @lcr
  def update
    @page_title = _('LCR_edit')
    @page_icon = "edit.png"

    @old_lcr = @lcr.clone
    @lcr.no_failover = params[:lcr][:no_failover].to_i
    if @lcr.update_attributes(params[:lcr].reject { |k, v| k == 'user_id' })
      if  @old_lcr.order != @lcr.order and @lcr.order == "priority"
        Lcrprovider.find(:all, :select => "lcrproviders.*", :joins => "RIGHT JOIN providers ON (providers.id = lcrproviders.provider_id)", :conditions => ["lcr_id = ?", @lcr.id]).each_with_index { |provider, i|
          provider.priority = i
          provider.save
        }
      end
      flash[:status] = _('Lcr_was_successfully_updated')
      redirect_to :action => 'list', :id => @lcr
    else
      flash_errors_for(_('Lcr_not_updeited'), @lcr)
      render :action => 'edit'
    end
  end

  #in before filter : @lcr
  def destroy
    if @lcr.destroy
      flash[:status] = _('Lcr_deleted')
    else
      flash_errors_for(_('Lcr_not_deleted'), @lcr)
    end
    redirect_to :action => 'list'
  end

  def details
    @page_title = _('LCR_Details')
    @page_icon = "view.png"
    @lcrs = @lcr
    owner_id = correct_owner_id
    if ['reseller', 'accountant', 'admin'].include?(current_user.usertype) and (@lcr.user_id != current_user.id and @lcr.id != current_user.lcr_id)
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
    @user = User.find(:all, :conditions => ["lcr_id = ? AND owner_id =?", @lcrs.id, owner_id])
    @cardgroup = Cardgroup.find(:all, :conditions => ["lcr_id = ? AND owner_id =?", @lcrs.id, owner_id])
  end

  #in before filter : @lcr
  def details_by_destinations
    @page_title = _('Routing_by_destinations')
    @page_icon = "view.png"
    @dest_new = 0
    @lcr_partials = @lcr.lcr_partials_destinations
    @lcrs = current_user.load_lcrs(:all, :order => "name ASC")
    @countrys = Direction.find(:all, :order => "name ASC")
    @phrase = request.raw_post || request.query_string
    @phrase = @phrase.gsub("=", "")
    if  @phrase.to_s != "no_directiontrue" and @phrase != nil
      @direction = Direction.find(:first, :conditions => ["code= ?", params[:dir]])
    else
      @direction = Direction.find(:first)
    end
  end

  def create_prefix_lcr_partials
    if params[:search].to_s.length > 0
      @dest = Destination.find(:first, :conditions => ["prefix = ? ", params[:search].to_s])
      unless @dest
        flash[:notice] = _("Prefix_not_found")
        redirect_to :action => 'details_by_destinations', :id => params[:id], :no_direction => true and return false
      end
      @lp = LcrPartial.new({:prefix => params[:search], :main_lcr_id => params[:id], :lcr_id => params[:lcr], :user_id => current_user.id})

      if @lp.duplicate_partials == 0 #search for same prefix in lcr_partials
        @lp.save
        flash[:status] = _("Saved")
      else
        flash[:notice] = _("Such_prefix_allready_exists_in_this_LCR")
      end

    else
      flash[:notice] = _("Prefix_error")
    end

    redirect_to :action => :details_by_destinations, :id => params[:id], :no_direction => true
  end

  def prefix_finder_find
    @phrase = params[:prefix]
    @dest = Destination.find(
        :first,
        :conditions => ["prefix = SUBSTRING(? , 1, LENGTH(destinations.prefix))", @phrase],
        :order => "LENGTH(destinations.prefix) DESC"
    ) if @phrase != ''
    @results = ""
    @direction = nil
    @direction = @dest.direction if @dest
    if @dest and @direction
      @results = @direction.name.to_s+" "+@dest.subcode.to_s+" "+@dest.name.to_s
    end
    render(:layout => false)
  end

  def prefix_finder_find_country
    @phrase = params[:prefix]
    @direction = Direction.find(:first, :conditions => ["code= ?", @phrase])
    render(:layout => false)
  end

  def lcrpartial_destinations
    @lcrp = LcrPartial.find(:first, :conditions => ['id=? AND user_id =?', params[:lcrp], current_user.id])
    unless @lcrp
      flash[:notice] = _('LcrPartial_was_not_found')
      redirect_to :action => :list and return false
    end
    # collect lower partials
    lp_str = ""
    for lp in @lcrp.lower_partials
      lp_str += " AND prefix NOT LIKE '#{lp.prefix}%'"
    end

    @direction = Direction.find(:first, :conditions => ["id = ?", params[:id].to_i])
    unless @direction
      flash[:notice] = _('Direction_was_not_found')
      redirect_to :action => :list and return false
    end
    @prefix = params[:prefix]
    sql= "SELECT destinations.* FROM destinations
            WHERE prefix LIKE '#{params[:prefix]}%' #{lp_str}"
    #my_debug sql
    @res = ActiveRecord::Base.connection.select_all(sql)
    render(:layout => "layouts/mor_min")
  end

  #in before filter : @lp
  def lcrpartial_edit
    @page_title = _('Edit_lcrpartial')
    @page_icon = "edit.png"
    @lcrs = current_user.lcrs.find(:all, :order => "name ASC")
    @countrys = Direction.find(:all)
    flash[:notice] = flash[:notice] if flash[:notice]
  end

  #in before filter : @lp
  def update_lcrpartial
    @dest = Destination.find(
        :first,
        :conditions => "prefix = '#{params[:prefix]}'"
    )
    unless @dest
      flash[:notice] = _("Prefix_not_found")
      redirect_to :action => 'lcrpartial_edit', :id => @lp.id and return false
    end
    @lp.main_lcr_id = params[:main_lcr]
    @lp.lcr_id = params[:lcr]
    @lp.prefix = params[:prefix]
    if @lp.save
      flash[:status] = _('Lcrpartial_saved')
    else
      flash[:notice] = _('Lcrpartial_not_saved')
    end
    redirect_to :action => 'lcrpartial_edit', :id => @lp.id
  end

  #in before filter : @lp
  def lcrpartial_destroy
    lcr_id = @lp.main_lcr_id
    @lp.destroy
    flash[:status] = _('Destination_deleted')
    redirect_to :action => 'details_by_destinations', :id => lcr_id, :no_direction => true
  end

  #in before filter : @lcr
  def providers_list
    @page_title = _('Providers_for_LCR') # + ": " + @lcr.name
    @page_icon = "provider.png"

    @providers = @lcr.providers("asc")

    @all_providers = current_user.providers.find(:all, :include => [:device, :tariff])
    if current_user.usertype == 'reseller'
      if @all_providers
        #ticket 3906
        #@all_providers += Provider.find(:all, :conditions => "common_use = 1", :order => "name ASC")
        @all_providers += Provider.find(:all, :conditions => "common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id})", :order => "name ASC")
      else
        # @all_providers = Provider.find(:all, :conditions => "common_use = 1", :order => "name ASC")
        @all_providers = Provider.find(:all, :conditions => "common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id})", :order => "name ASC")
      end
    end
    @other_providers = []
    for prov in @all_providers
      @other_providers << prov if !@providers.include?(prov) and prov.hidden == 0
    end
    flash[:notice] = _('No_provaiders_available') if @all_providers.empty?
  end

  #in before filter : @lcr
  def providers_percent
    @page_title = _('Providers_for_LCR') # + ": " + @lcr.name
    @page_icon = "provider.png"

    @providers = @lcr.providers("asc")
    sum = 0.to_f
    if params[:pr].to_i == 2
      params.each { |key, value| sum += value.to_f.abs if key.match("prov_") }
      if sum.to_i == 100.to_i
        params.each { |key, value|
          if key.match("prov_")
            @lcrpr = Lcrprovider.find(:first, :conditions => ["provider_id = ? AND lcr_id= ?", key.to_s.strip.delete("prov_").to_i, @lcr.id])
            if @lcrpr
              @lcrpr.percent = value.to_f.abs * 100
              @lcrpr.save
            end
          end
        }
        flash[:status] = _('Percent_changed')
        redirect_to :action => 'providers_list', :id => @lcr.id
      else
        flash[:notice] = _('Is_not_100%')
      end


    end
    #

  end

  #in before filter : @lcr
  def providers_sort
    @page_title = _('Change_Order') + ": " + @lcr.name
    @page_icon = "arrow_switch.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Change_Provider_order_by_Drag%26Drop_video"


    if (@lcr.order.to_s != 'priority')
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main'
    end

    @items = @lcr.providers("asc")
  end

  #in before filter : @lcr
  def providers_sort_save
    params[:sortable_list].each_index do |i|
      item = Lcrprovider.find(:first, :conditions => "provider_id = #{params[:sortable_list][i]} AND lcr_id = #{@lcr.id}")
      unless item
        flash[:notice] = _('Lcrprovider_was_not_found')
        redirect_to :action => :list and return false
      end
      item.priority = i
      item.save
    end
    @page_title = _('Change_Order') + ": " + @lcr.name
    @items = @lcr.providers("asc")
    #    @translations = Translation.find(:all, :order => 'position ASC')
    render :layout => false, :action => :providers_sort
  end

  #in before filter : @lcr
  def try_to_add_provider
    prov_id = params[:select_prov]

    if prov_id != "0"
      @prov = Provider.find(:first, :conditions => ['id = ? AND (user_id = ? OR common_use = 1)', prov_id, current_user.id])
      unless @prov
        flash[:notice] = _('Provider_was_not_found')
        redirect_to :action => :list and return false
      end
      @lcr.add_provider(@prov)
      @lcr.save
      flash[:status] = _('Provider_added')
    else
      flash[:notice] = _('Please_select_provider_from_the_list')
    end

    redirect_to :action => 'providers_list', :id => @lcr
  end

  def try_to_add_failover_provider
    prov_id = params[:select_prov]

    if prov_id != "0"
      @prov = Provider.find(:first, :conditions => ['id = ? AND (user_id = ? OR common_use = 1)', prov_id, current_user.id])
      unless @prov
        flash[:notice] = _('Provider_was_not_found')
        redirect_to :action => :list and return false
      end
      @lcr.failover_provider = @prov
      @lcr.save
      flash[:status] = _('Failover_provider_added')
    else
      @lcr.failover_provider = nil
      @lcr.save
      flash[:notice] = _('Failover_provider_unassigned')
    end

    redirect_to :action => 'providers_list', :id => @lcr
  end

  #in before filter : @lcr
  def remove_provider
    prov_id = params[:prov]
    @lcr.remove_provider(prov_id)
    flash[:status] = _('Provider_removed')
    redirect_to :action => 'providers_list', :id => @lcr
  end

  #in before filter : @lcr
  def provider_change_status
    prov_id = params[:prov]
    flash[:status] = @lcr.provider_change_status(prov_id).to_i == 0 ? _('Provider_disabled') : _('Provider_enabled')
    redirect_to :action => 'providers_list', :id => @lcr.id
  end

  def make_tariff

    if !@lcr.providers and @lcr.providers.size.to_i < 1
      flash[:notice] = _('Providers_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    options={}
    options[:test] = 1 if params[:test]
    options[:collumn_separator], options[:column_dem] = current_user.csv_params
    options[:current_user] = current_user
    options[:curr] = session[:show_currency]
    options[:rand] = random_password(10).to_s
    filename = @lcr.make_tariff(options)
    filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
    if filename
      filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_f)
      if params[:test].to_i != 1
        send_file(filename)
      else
        render :text => filename
      end
    else
      flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
      redirect_to :controller => :callc, :action => :main and return false
    end

  end

  def clone_lcrs
    if current_user.is_admin?
      if params[:resellerA].to_i > 0 and params[:resellerB].to_i > 0 and params[:lcr] and params[:lcr].size > 0
        resellerA = User.find(:all, :conditions => ["id = #{params[:resellerA].to_i} AND usertype = 'reseller'"])
        resellerB = User.find(:all, :conditions => ["id = #{params[:resellerB].to_i} AND usertype = 'reseller'"])
        if not resellerA or not resellerB
          flash[:notice] = _('Specify_both_resellers')
          redirect_to :controller => "lcrs", :action => "clone_options" and return false
        end
        selected_lcrs = params[:lcr].map { |key, value| key.to_i }
        selected_lcrs.reject! { |lcr_id| lcr_id == 0 }
        if selected_lcrs.size > 0
          if Lcr.clone_lcrs(resellerA[0], resellerB[0], selected_lcrs)
            flash[:status] = _('Selecte_LCRs_cloned')
          else
            flash[:notice] = _("Failed_to_clone_LCR's")
          end
          redirect_to :controller => "lcrs", :action => "clone_options" and return false

        else
          flash[:notice] = _('Specify_at_least_one_LCR')
          redirect_to :controller => "lcrs", :action => "clone_options" and return false
        end
      else
        flash[:notice] = _('Specify_both_resellers_and_at_least_one_LCR')
        redirect_to :controller => "lcrs", :action => "clone_options" and return false
      end
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def clone_options
    if current_user.is_admin?
      @resellers = User.find(:all, :conditions => ["usertype = 'reseller' AND hidden = 0"])
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def clone_resellers_lcrs
    if current_user.is_admin?
      @resellers = User.find(:all, :conditions => ["usertype = 'reseller' AND hidden = 0"])
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def resellers_lcrs
    if current_user.is_admin?
      reseller_id = params[:id].to_i
      @lcrs = Lcr.find(:all, :conditions => ["user_id = #{reseller_id}"])
      render :layout => false
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def resellers_with_common_providers
    if current_user.is_admin?
      reseller_id = params[:id]
      resellerA = User.find(:all, :conditions => ["id = #{reseller_id}"])[0]
      @resellers = resellerA.resellers_with_common_providers
      render :layout => false
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def lcr_clone
    if mor_11_extend?
      ln = @lcr.clone
      ln.name = 'Clone: ' + ln.name + ' ' + Time.now.to_s(:db)
      if ln.save
        for p in @lcr.lcrproviders
          pn = p.clone
          pn.lcr_id = ln.id
          pn.save
        end
        for l in @lcr.lcr_partials
          lp = l.clone
          lp.lcr_id = ln.id
          lp.save
        end
        flash[:status] = _('Lcr_copied')
      else
        flash_errors_for(_('Lcr_not_copied'), ln)
      end
      redirect_to :action => 'list' and return false
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end

  end

  private

  def check_owner
    if ['reseller', 'admin', 'accountant'].include?(current_user.usertype) and @lcr.user_id != correct_owner_id
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

  def find_lcr_from_id
    @lcr =Lcr.find(:first, :conditions => ['id=?', params[:id]])
    unless @lcr
      flash[:notice] = _('Lcr_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_lcr_partial_from_id
    @lp = LcrPartial.find(:first, :conditions => ['id=? AND user_id =?', params[:id], current_user.id])
    unless @lp
      flash[:notice] = _('LcrPartial_was_not_found')
      redirect_to :action => :list and return false
    end
  end
end
