class ServicesController < ApplicationController

  layout "callc"
  before_filter :check_localization

  before_filter :authorize
  @@susbscription_view = [:subscriptions, :subscriptions_list]
  @@susbscription_edit = [:subscription_new, :subscription_create, :subscription_destroy, :subscription_confirm_destroy, :subscription_edit, :subscription_update]
  @@service_view = [:list]
  @@service_edit = [:new, :create, :update, :edit, :destroy]

  before_filter { |c|
    c.instance_variable_set :@allow_read, true
    c.instance_variable_set :@allow_edit, true
  }

  before_filter(:only => @@susbscription_view+@@susbscription_edit){ |c|
    allow_read, allow_edit = c.check_read_write_permission( @@susbscription_view,  @@susbscription_edit, {:role => "accountant", :right => :acc_manage_subscriptions_opt_1})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter(:only => @@service_view+@@service_edit){ |c|
    allow_read, allow_edit = c.check_read_write_permission( @@service_view,  @@service_edit, {:role => "accountant", :right => :acc_services_manage})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :find_service, :only => [:show, :edit, :update, :destroy, :destination_prefix_find, :destinations, :destination_add, :destination_destroy, :destination_prefix_find, :destination_prefixes]
  before_filter :find_services, :only => [:index, :list, :subscriptions, :subscription_new]
  before_filter :find_user, :only => [:subscriptions_list, :subscription_create]
  before_filter :find_subscription, :only => [:subscription_edit, :subscription_update, :subscription_confirm_destroy]
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
    :redirect_to => { :action => :list }

  # @services in before filter
  def index
    list
    render :action => 'list'
  end

  # @services in before filter
  def list
    @page_title = _('Services')
  end

  # @service in before filter
  def show
    @page_title = _('Service')
  end

  def new
    @page_title = _('New_service')
    @page_icon = "add.png"
    @service = Service.new
  end

  def create
    @service = Service.new(params[:service])
    @service.owner_id = correct_owner_id
    if @service.save
      flash[:status] = _('Service_was_successfully_created')
      redirect_to :action => 'list'
    else
      flash_errors_for(_('Service_was_not_created'), @service)
      render :action => 'new'
    end
  end

  # @service in before filter
  def edit
    @page_title = _('Edit')
    @page_icon = "edit.png"
  end

  # @service in before filter
  def update
    if @service.update_attributes(params[:service])
      flash[:status] = _('Service_was_successfully_updated')
      redirect_to :action => 'list'
    else
      flash_errors_for(_('Service_was_not_updated'), @service)
      render :action => 'edit'
    end
  end

  # @service in before filter
  def destroy
    if @service.destroy
      flash[:status] = _('Service_deleted')
    else
      flash_errors_for(_('Service_was_not_deleted'), @service)
    end
    redirect_to :action => 'list'
  end

  # @service in before filter
  def destinations
    @page_title = _('Flat_rate_destinations')
    @page_icon = "actions.png"
    @flatrate_destinations = FlatrateDestination.find(:all, :include => [:service, :destination], :conditions => ["flatrate_destinations.service_id = ?", params[:id]])
    @flatrate_destinations.each_with_index{|fd, i| fd.destroy and @flatrate_destinations[i] = nil if fd.destination == nil}
    @flatrate_destinations = @flatrate_destinations.compact

    @directions = Direction.find(:all)
    @diff_directions = @flatrate_destinations.map{|dest| dest.destination.direction_code if (dest and dest.destination)}.uniq
    @prefixes = @flatrate_destinations.map{|fl| fl.destination.prefix}
    @destinations = Destination.find(:all, :conditions=>["direction_code = ?", @directions[0].code])
    @destinations = @destinations.map{|d| d if !@prefixes.include?(d.prefix)}.compact
  end

  # @service in before filter
  def destination_add
    if params[:submit_icon] == "prefix_find"
      @destination = Destination.find(:first, :conditions => ["prefix = ?" , params[:search_1]])
      @enabled = params[:enabled_1].to_i
    end

    if params[:submit_icon] == "country_find"
      @destination = Destination.find(:first, :conditions => ["prefix = ?" , params[:pre]])
      @enabled = params[:enabled].to_i
    end

    if @destination
      if FlatrateDestination.find(:first, :conditions => ["destination_id = ? AND service_id = ?", @destination.id, @service.id])
        flash[:notice] = _('Destination_already_in_flatrate')
        redirect_to(:action => :destinations, :id => @service.id) and return false
      end
    else
      flash[:notice] = _('Destination_not_found')
      redirect_to(:action => :destinations, :id => @service.id) and return false
    end

    flatrate_destination = FlatrateDestination.new(:service => @service, :destination => @destination, :active=> @enabled.to_i)

    if flatrate_destination and flatrate_destination.save
      flash[:status] = _('Flatrate_destination_created')
    else
      flash[:notice] = _('Flatrate_destination_not_created')
    end

    redirect_to(:action => :destinations, :id => @service.id)
  end

  # @service in before filter
  def destination_destroy
    @flatrate_destination = @service.flatrate_destinations.find(:first, :conditions => ["flatrate_destinations.id = ?", params[:destination_id]])
    unless @flatrate_destination
      flash[:notice] = _('Flatrate_destination_not_found')
      redirect_to :action => :list and return false
    end

    if @flatrate_destination.destroy
      flash[:status] = _('Flatrate_destination_destroyed')
    else
      flash[:notice] = _('Flatrate_destination_not_destroyed')
    end
    redirect_to :action => :destinations, :id => @flatrate_destination.service_id
  end

  # @service in before filter
  def destination_prefix_find
    @flatrate_destinations = FlatrateDestination.find(:all, :include => [:destination], :conditions => ["service_id = ?", @service.id])
    @prefixes = @flatrate_destinations.map{|fl| fl.destination.prefix}
    if params[:find_by] == "direction"
      @destinations = Destination.find(:all, :conditions=>["direction_code = ?", params[:direction]])
      @destinations = @destinations.map{|d| d if !@prefixes.include?(d.prefix)}.compact
      render(:layout => false) and return false
    end

    if params[:find_by] == "prefix"
      @dest = Destination.find(
        :first,
        :conditions => ["prefix = SUBSTRING(?, 1, LENGTH(destinations.prefix))", params[:direction]],
        :order => "LENGTH(destinations.prefix) DESC"
      ) if @phrase != ''
      @results = ""

      if @dest
        if FlatrateDestination.find(:first, :conditions => ["destination_id = ? AND service_id = ?", @dest.id, @service.id])
          @message = _('Destination_already_in_flatrate')
        else
          @direction = nil
          @direction = @dest.direction
          if @direction
            @results = @direction.name.to_s+" "+@dest.subcode.to_s+" "+@dest.name.to_s
          end
        end
      end
      render(:layout => false)
    end
  end

  # @service in before filter
  def destination_prefixes
    params[:page].to_i > 0 ? @page = params[:page].to_i : @page = 1
    @per_page = Confline.get_value("Items_Per_Page").to_i
    @pos = []
    @neg = []
    @direction = Direction.find(:first,:conditions => ["code = ?", params[:direction]] )
    unless @direction
      @message = _('Direction_not_found')
    end
    @flatrate_destinations = FlatrateDestination.find(:all, :include => [:destination], :joins =>"LEFT JOIN destinations ON (flatrate_destinations.destination_id = destinations.id)", :conditions => ["destinations.direction_code = ? and service_id = ?", params[:direction], params[:id]], :order => "length(destinations.prefix)")
    @destinations = []

    @flatrate_destinations.each{ |dest|
      @dest = Destination.find(:all, :conditions => ["prefix LIKE ?" ,dest.destination.prefix.to_s+"%"])
      dest.active.to_i == 1 ? @destinations += @dest : @destinations -= @dest
    }

    @total_pages = (@destinations.size.to_f / session[:items_per_page].to_f).ceil
    @destinations = @destinations[(@page-1)*session[:items_per_page], session[:items_per_page]].to_a

    render(:layout => "layouts/mor_min")
  end
  # =============== Subscriptions groups =================

  def subscriptions
    @page_title = _('Subscriptions')
    @page_icon = "layers.png"

    @users = User.find_all_for_select(corrected_user_id,{:exclude_owner=>true})

    change_date

    @search_device = -1
    @search_user = -1
    @search_service = -1
    @search_date_from = -1
    @search_date_till = -1
    @search_memo = ""
    @search_user = params[:s_user] if params[:s_user]
    @search_service = params[:s_service] if params[:s_service]
    @search_device = params[:device_id] if params[:device_id]
    @search_memo = params[:s_memo] if params[:s_memo]

    cond=""

    if @search_user.to_i != -1
      cond = "  AND subscriptions.user_id = '#{@search_user}' "
      if @search_device.to_i != -1
        cond += " AND subscriptions.device_id = '#{@search_device}' "
      end
    end

    if @search_service.to_i != -1
      cond += " AND subscriptions.service_id = '#{@search_service}' "
    end
    period_start = "'#{session_from_date } 00:00:00'"
    period_end =  "'#{session_till_date} 23:59:59'"
    cond += " AND (#{period_start} BETWEEN subscriptions.activation_start AND subscriptions.activation_end OR
#{period_end} BETWEEN subscriptions.activation_start AND subscriptions.activation_end OR
(subscriptions.activation_start > #{period_start} AND subscriptions.activation_end < #{period_end}))"

    #cond += " AND subscriptions.activation_end <= '#{session_till_date} 23:59:59' "

    cond += " AND subscriptions.memo = '#{@search_memo}' " if @search_memo.length > 0

    sql = "SELECT services.name as serv_name , users.first_name, users.last_name, users.username, subscriptions.*, devices.device_type,  devices.name, devices.extension, devices.istrunk FROM subscriptions
            LEFT JOIN users ON(users.id = subscriptions.user_id)
            LEFT JOIN devices ON(devices.id = subscriptions.device_id)
            LEFT JOIN services ON(services.id = subscriptions.service_id)
            WHERE subscriptions.id > '0' AND users.owner_id = #{correct_owner_id} #{cond}"
    #MorLog.my_debug sql
    @search = 0
    @search = 1 if cond.length > 93
    @subs = Subscription.find_by_sql(sql)

    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@subs.size.to_f / session[:items_per_page].to_f).ceil
    @all_subs = @subs
    @subs = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_subs.size - 1 if iend > (@all_subs.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @subs << @all_subs[i]
    end
  end

  # @user in before filter
  def subscriptions_list
    @page_title = _('Subscriptions')
    @page_icon = "layers.png"

    @subs = @user.subscriptions(:include => [:service])
    @page = params[:page] if params[:page]
    @back = params[:back] if params[:back]
    @search_user = params[:s_user] if params[:s_user]
    @search_service = params[:s_service] if params[:s_service]
    @search_device = params[:device_id] if params[:device_id]
    @search_memo = params[:s_memo] if params[:s_memo]
    @search_date_from = params[:s_date_from] if params[:s_date_from]
    @search_date_till = params[:s_date_till] if params[:s_date_till]
  end

  # @services in before filter
  def subscription_new
    @page_title = _('New_subscription')
    @page_icon = "add.png"

    @user = User.find(:first, :conditions => ["id = ?", params[:id]])
    @sub = Subscription.new

    if @services.empty?
      flash[:notice] = _('No_services_to_subscribe')
      redirect_to :action => 'subscriptions_list', :id => @user.id
    end
  end

  def subscription_create
    @sub = Subscription.new(params[:subscription])
    @sub.user_id = @user.id
    @sub.activation_start = Time.mktime(params[:activation_start][:year],params[:activation_start][:month],params[:activation_start][:day],params[:activation_start][:hour],params[:activation_start][:minute])
    @sub.activation_end = Time.mktime(params[:activation_end][:year],params[:activation_end][:month],params[:activation_end][:day],params[:activation_end][:hour],params[:activation_end][:minute])

    @sub.added = @sub.added - @sub.added.strftime("%S").to_i.seconds

    service = Service.find(:first, :conditions => ["id = ?", @sub.service_id.to_i])

    if service.servicetype == "flat_rate"
      @sub.activation_start = @sub.activation_start.beginning_of_month.change(:hour => 0, :min => 0, :sec => 0)
      @sub.activation_end = @sub.activation_end.end_of_month.change(:hour => 23, :min => 59, :sec => 59)
    end

    if ((@sub.activation_start < @sub.activation_end) and service.servicetype == "periodic_fee") or service.servicetype == "one_time_fee" or service.servicetype == "flat_rate"
      @sub.save
      Action.add_action_hash(current_user.id, {:action=>'Subscription_added', :target_id => @sub.id, :target_type=>"Subscription", :data=>@sub.user_id, :data2=>@sub.service_id })

      if @user.user_type == "prepaid"
        subscription_price = @sub.price_for_period(Time.now.beginning_of_day, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59))
        if subscription_price.to_f != 0
          if (@user.balance - subscription_price) < 0
            @sub.destroy
            flash[:notice] = _('insufficient_balance')
            redirect_to :action => 'subscriptions_list', :id => @user.id and return false
          else
            MorLog.my_debug("Prepaid user:#{@user.id} Subscription:#{@sub.id} Price:#{subscription_price} Period:#{Time.now.beginning_of_day}-#{Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)}" )
            @user.balance -= subscription_price
            @user.save
            Payment.subscription_payment(@user, subscription_price)
            Action.new(:user_id => @user.id, :target_id => @sub.id, :target_type =>"subscription", :date => Time.now, :action => "subscription_paid", :data => "#{Time.now.year}-#{Time.now.month}", :data2=>subscription_price).save
          end
        end
      end

      flash[:status] = _('Subscription_added')
      redirect_to :action => 'subscriptions_list', :id => params[:id] and return false
    else
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'subscription_new', :id => params[:id] and return false
    end
  end

  # @sub in before filter
  def subscription_edit
    @page_title = _('Edit')
    @page_icon = "edit.png"
    @page = params[:page] if params[:page]
    @back = params[:back] if params[:back]
    @search_user = params[:s_user] if params[:s_user]
    @search_service = params[:s_service] if params[:s_service]
    @search_device = params[:device_id] if params[:device_id]
    @search_memo = params[:s_memo] if params[:s_memo]
    @search_date_from = params[:s_date_from] if params[:s_date_from]
    @search_date_till = params[:s_date_till] if params[:s_date_till]

    @user = @sub.user
    @services = Service.find(:all, :order => "name ASC")
  end

  # @sub in before filter
  def subscription_update
    @page = params[:page] if params[:page]
    @back = params[:back] if params[:back]
    @search_user = params[:s_user] if params[:s_user]
    @search_service = params[:s_service] if params[:s_service]
    @search_device = params[:device_id] if params[:device_id]
    @search_memo = params[:s_memo] if params[:s_memo]
    @search_date_from = params[:s_date_from] if params[:s_date_from]
    @search_date_till = params[:s_date_till] if params[:s_date_till]

    @service = @sub.service
    @sub.memo = params[:memo]
    ld1 = last_day_of_month(params[:activation_start][:year],params[:activation_start][:month]).to_i
    ld2 = last_day_of_month(params[:activation_end][:year],params[:activation_end][:month]).to_i
    params[:activation_start][:day] = ld1 if params[:activation_start][:day].to_i > ld1.to_i
    params[:activation_end][:day] = ld2 if params[:activation_end][:day].to_i > ld2.to_i
    @sub.activation_start = Time.mktime(params[:activation_start][:year],params[:activation_start][:month],params[:activation_start][:day],params[:activation_start][:hour],params[:activation_start][:minute])
    @sub.activation_end = Time.mktime(params[:activation_end][:year],params[:activation_end][:month],params[:activation_end][:day],params[:activation_end][:hour],params[:activation_end][:minute])

    if @service.servicetype == "flat_rate"
      @sub.activation_start = @sub.activation_start.beginning_of_month.change(:hour => 0, :min => 0, :sec => 0)
      @sub.activation_end = @sub.activation_end.end_of_month.change(:hour => 23, :min => 59, :sec => 59)
    end

    if (@sub.activation_start <= @sub.activation_end) #and (@sub.added <= @sub.activation_start)
      @sub.save
      flash[:status] = _('Subscription_updated')
      if @back.to_s == "subscriptions"
        redirect_to :action => 'subscriptions', :s_memo => @search_memo, :s_service => @search_service, :s_user => @search_user, :s_device=>@search_device, :s_date_from=> @search_date_from, :s_date_till=>@search_date_till, :page=>@page
      else
        redirect_to :action => 'subscriptions_list', :id => @sub.user.id
      end

    else
      flash[:notice] = _('Bad_time')
      if @back.to_s == "subscriptions"
        redirect_to :action => 'subscriptions', :s_memo => @search_memo, :s_service => @search_service, :s_user => @search_user, :s_device=>@search_device, :s_date_from=> @search_date_from, :s_date_till=>@search_date_till, :page=>@page
      else
        redirect_to :action => 'subscription_edit', :id => @sub.id
      end
    end
  end

  def subscription_confirm_destroy
    @page_title = _('Subscriptions')
    @page_icon = "delete.png"
    @user = @sub.user
    unless @user
      flash[:notice] = _('User_not_found')
      redirect_to :action => :subscriptions and return false
    end

    @page = params[:page] if params[:page]
    @back = params[:back] if params[:back]
    @search_user = params[:s_user] if params[:s_user]
    @search_service = params[:s_service] if params[:s_service]
    @search_device = params[:device_id] if params[:device_id]
    @search_memo = params[:s_memo] if params[:s_memo]
    @search_date_from = params[:s_date_from] if params[:s_date_from]
    @search_date_till = params[:s_date_till] if params[:s_date_till]
  end

  def subscription_destroy
    @sub = Subscription.find(:first, :include => [:user, :service], :conditions => ["subscriptions.id = ?", params[:id]])
    unless @sub
      flash[:notice] = _('Subscription_not_found')
      redirect_to :action => :subscriptions and return false
    end
    unless @sub.user
      flash[:notice] = _('User_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end
    unless @sub.service
      flash[:notice] = _('Service_not_found')
      redirect_to :controller => :callc, :action => :main and return false
    end

    @page = params[:page] if params[:page]
    @back = params[:back] if params[:back]
    @search_user = params[:s_user] if params[:s_user]
    @search_service = params[:s_service] if params[:s_service]
    @search_device = params[:device_id] if params[:device_id]
    @search_memo = params[:s_memo] if params[:s_memo]
    @search_date_from = params[:s_date_from] if params[:s_date_from]
    @search_date_till = params[:s_date_till] if params[:s_date_till]

    case params[:delete].to_s
    when "delete"
      Action.add_action_hash(current_user.id, {:action=>'Subscription_deleted', :target_id => @sub.id, :target_type=>"Subscription", :data=>@sub.user_id, :data2=>@sub.service_id })
      @sub.destroy
      flash[:status] = _('Subscription_deleted')
    when "disable"
      Action.add_action_hash(current_user.id, {:action=>'Subscription_disabled', :target_id => @sub.id, :target_type=>"Subscription", :data=>@sub.user_id, :data2=>@sub.service_id })
      @sub.disable
      @sub.save
      flash[:status] = _('Subscription_disabled')
    when "return_money_whole"
      Action.add_action_hash(current_user.id, {:action=>'Subscription_deleted_and_return_money_whole', :target_id => @sub.id, :target_type=>"Subscription", :data=>@sub.user_id, :data2=>@sub.service_id })
      @sub.return_money_whole
      @sub.destroy
      flash[:status] = _('Subscription_deleted_and_money_returned')
    when "return_money_month"
      Action.add_action_hash(current_user.id, {:action=>'Subscription_deleted_and_return_money_month', :target_id => @sub.id, :target_type=>"Subscription", :data=>@sub.user_id, :data2=>@sub.service_id })
      @sub.return_money_month
      @sub.destroy
      flash[:status] = _('Subscription_deleted_and_money_returned')
    end

    if @back.to_s == "subscriptions"
      redirect_to :action => 'subscriptions', :s_memo => @search_memo, :s_service => @search_service, :s_user => @search_user, :s_device=>@search_device, :s_date_from=> @search_date_from, :s_date_till=>@search_date_till, :page=>@page
    else
      redirect_to :action => 'subscriptions_list', :id => @sub.user.id
    end
  end

  def user_subscriptions
    @page_title = _('Subscriptions')
    @page_icon = "layers.png"
    @user = User.find(session[:user_id])
    @subs = @user.subscriptions(:include => [:service])
  end

  private

  def find_service
    @service = Service.find(:first, :conditions => ["id = ? AND owner_id = ? ",params[:id], correct_owner_id])
    unless @service
      flash[:notice] = _('Service_was_not_found')
      redirect_to :controller=>:callc, :action =>:main and return false
    end
  end

  def find_services
    @services = Service.find(:all, :conditions => ["services.owner_id = ?", correct_owner_id], :order => "name ASC")
  end

  def find_user
    @user = User.find(:first, :include => [:subscriptions], :conditions => ["users.id = ? AND users.owner_id = ?", params[:id], correct_owner_id])
    unless @user
      flash[:notice] = _('User_Was_Not_Found')
      redirect_to :controller=>:callc, :action =>:main and return false
    end
  end

  def find_subscription
    @sub = Subscription.find(:first, :include => [:user, :service] ,:conditions => ["subscriptions.id = ? ", params[:id]])
    unless @sub
      flash[:notice] = _('Subscription_not_found')
      redirect_to :controller=>:callc, :action =>:main and return false
    end

    service = @sub.service
    unless service and service.owner_id == correct_owner_id
      flash[:notice] = _('Subscription_not_found')
      redirect_to :controller=>:callc, :action =>:main and return false
    end
  end

end
