# -*- encoding : utf-8 -*-
class CreditNoteController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :link_to_user?, :only => [:list, :edit]
  before_filter :link_to_financial_operations?, :only => [:list, :edit]
  before_filter :can_edit_financial_data?, :only => [:pay, :unpay, :destroy, :new, :create]
  before_filter :can_view_financial_data?, :only => [:list, :edit]
  before_filter :can_view_credit_notes?

  def list
    @page_title = _('Credit_notes')

    items_per_page = session[:items_per_page]
    @total_pages = (credit_notes_count.to_d / items_per_page.to_d).ceil
    page_no = current_page
    page_no = @total_pages if page_no.to_i > @total_pages.to_i and @total_pages.to_i > 0
    page_no = 1 if page_no < 1
    offset = ((page_no -1) * items_per_page).to_i

    @notes = credit_notes(items_per_page, offset)

    #set issue and paid dates that will be visible for user as default search options
    @issue_date_from, @issue_date_till = date_from_till(search_options[:issue_date_from], search_options[:issue_date_till])
    @paid_date_from, @paid_date_till = date_from_till(search_options[:paid_date_from], search_options[:paid_date_till])

    @options = search_options
    @show_search = show_search? @options
    @options[:page] = page_no
    @options[:order_by], @options[:order_desc] = order_by
    session[:credit_note_list_opt] = @options
  end

  def new
    @page_title = _('New_credit_note')
    @page_icon = "add.png"

    @users = User.find_all_for_select(correct_owner_id, {:exclude_owner => true})
    unless @users
      flash[:notice] = _("There_is_no_users")
    end
    issue_date = params[:issue_date] ? Date.new(params[:issue_date][:year], params[:issue_date][:month], params[:issue_date][:day]) : Time.now
    @note = CreditNote.new
    @note.issue_date = Time.now
  end

  def create
    if current_user.is_accountant?
      condition = ["owner_id = 0 AND id = #{params[:user][:id].to_i}"]
    elsif current_user.is_reseller? or current_user.is_admin?
      condition = ["owner_id = #{current_user.id} AND id = #{params[:user][:id].to_i}"]
    end
    user = User.find(:first, :conditions => condition)
    if user
      @note = CreditNote.new
      @note.user = user
      issue_date = params[:issue_date]
      if issue_date
        @note.issue_date = Time.mktime(issue_date[:year].to_i, issue_date[:month].to_i, issue_date[:day].to_i, issue_date[:hour].to_i, issue_date[:minute].to_i)
      else
        @note.issue_date = Time.now
      end
      @note.number = params[:number]
      @note.price = params[:price].to_d
      @note.comment = params[:comment]
      if @note.save
        flash[:status] = _('Credit_note_created')
        redirect_to :controller => :credit_note, :action => :edit, :id => @note.id
      else
        flash[:notice] = _('Failed_to_save_credit_note')
        @users = User.find_all_for_select(correct_owner_id, {:exclude_owner => true})
        render :action => :new
      end
    else
      flash[:notice] = _('User_not_found')
      redirect_to :controller => :credit_note, :action => :list
    end
  end

=begin
  User can edit, delete, update only his own users credit notes. If failed to 
  find such credit note does redirect to list.
=end
  def edit
    @page_title = _('Credit_note')
    @page_icon = "edit.png"
    @note = find_credit_note(params[:id])
    unless @note
      flash[:notice] = _('Credit_note_not_found')
      redirect_to :controller => :credit_note, :action => :list
    end
  end

  def destroy
    note = find_credit_note(params[:id])
    if note
      note.destroy
      flash[:status] = _('Credit_note_deleted')
    else
      flash[:notice] = _('Credit_note_not_found')
    end
    redirect_to :controller => :credit_note, :action => :list
  end

  def update
    @note = find_credit_note(params[:id])
    if @note
      @note.comment = params[:comment]
      if @note.save
        flash[:status] = _('Credit_note_changed')
      else
        flash[:notice] = _('Failed_to_save_credit_note')
      end
      redirect_to :controller => :credit_note, :action => :edit, :id => @note.id
    else
      flash[:notice] = _('Credit_note_not_found')
      redirect_to :controller => :credit_note, :action => :list
    end
  end

  def pay
    @note = find_credit_note(params[:id])
    if @note
      @note.pay
      redirect_to :controller => :credit_note, :action => :edit, :id => @note.id
    else
      flash[:notice] = _('Credit_note_not_found')
      redirect_to :controller => :credit_note, :action => :list
    end
  end

  def unpay
    @note = find_credit_note(params[:id])
    if @note
      @note.unpay
      redirect_to :controller => :credit_note, :action => :edit, :id => @note.id
    else
      flash[:notice] = _('Credit_note_not_found')
      redirect_to :controller => :credit_note, :action => :list
    end
  end

  private

=begin
  Makes from/till date from passed parameter, but if one of them was not passed
  defaults to from/till date that is saved in session

  *Params*
  +from+ hash containing :year, :month and :day
  +till+ hash containing :year, :month and :day

  *Returns*
  +[from, till]+ array containing date from and date till
=end
  def date_from_till(from, till)
    if from and till
      till = Time.mktime(till[:year], till[:month], till[:day])
      from = Time.mktime(from[:year], from[:month], from[:day])
    else
      from = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
      till = Time.mktime(session[:year_till], session[:month_till], session[:day_till])
    end
    return from, till
  end

=begin
  Count number of credit notes filtered by conditons supplied option hash. All
  conditions are joined with AND.

  *Params*
  +options+ hash of user specified search options

  *Returns*
  +credit_note_count+ number of notes that were found for current user
=end
  def credit_notes_count
    CreditNote.includes(:user).where(credit_note_conditions.join(' AND ')).all.size
  end

=begin
  *Params*
  +limit+ limit of maximum credit notes that should be returned
  +offset+ number of credit notes that should be skipped
  +options+ hash of user specified options

  *Returns*
  *credit_notes* list of credit notes that current user can view or edit, filtered
    by supplied search conditions
=end
  def credit_notes(limit, offset)
    condition = credit_note_conditions
    order, desc = order_by
    desc = (desc == 1 ? 'ASC' : 'DESC')
    CreditNote.find(:all, :select => "credit_notes.*, #{SqlExport.nice_user_sql}, users.username, users.last_name, users.first_name", :joins => 'LEFT JOIN users ON (users.id = credit_notes.user_id)', :conditions => condition.join(' AND '), :limit => limit, :offset => offset, :order => order + ' ' + desc)

  end

=begin
  Based on user specified search conditions creates an array of conditions from
  whitch we may construct sql query. One of the most important things it does is
  that it creates condition so that current user can select only his users credit
  notes

  *Returns*
  +conditios+ array of conditions for sql query
=end
  def credit_note_conditions
    if current_user.is_accountant?
      condition = ["users.owner_id IN (0, #{current_user.id})"]
    elsif current_user.is_reseller? or current_user.is_admin?
      condition = ["users.owner_id = #{current_user.id}"]
    end

    options = search_options
    condition << "status = '#{options[:status]}'" if ['paid', 'unpaid'].include? options[:status]
    condition << "first_name LIKE '#{options[:first_name].strip}%'" if options[:first_name]
    condition << "last_name LIKE '#{options[:last_name].strip}%'" if options[:last_name]
    condition << "username LIKE '#{options[:username].strip}%'" if options[:username]
    condition << "price >= #{current_user.to_system_currency(options[:amount_min].to_d)}" if options[:amount_min]
    condition << "price <= #{current_user.to_system_currency(options[:amount_max].to_d)}" if options[:amount_max]
    if options[:status] == 'paid' and options[:paid_date_from] and options[:paid_date_till]
      from = options[:paid_date_from]
      from = current_user.system_time(from[:year] + '-' + from[:month] + '-' + from[:day] + ' 00:00:00')
      till = options[:paid_date_till]
      till = current_user.system_time(till[:year] + '-' + till[:month] + '-' + till[:day] + ' 23:59:59')
      condition << "pay_date BETWEEN '#{from}' AND '#{till}'"
    end
    if options[:issue_date_from] and options[:issue_date_till]
      from = options[:issue_date_from]
      from = current_user.system_time(from[:year] + '-' + from[:month] + '-' + from[:day] + ' 00:00:00')
      till = options[:issue_date_till]
      till = current_user.system_time(till[:year] + '-' + till[:month] + '-' + till[:day] + ' 23:59:59')
      condition << "issue_date BETWEEN '#{from}' AND '#{till}'"
    end
    return condition
  end

=begin
  Find certain current user's credit note. User can wiev, edit only his users 
  credit notes, hence owner_id = current_user.id

  *Params*
  +credit_note_id+ valid credit note's id

  *Returns*
  +credit_note+ instance of CreditNote or nil if no credit note were found
=end
  def find_credit_note(credit_note_id)
    if current_user.is_accountant?
      CreditNote.find(:first, :include => :user, :conditions => ['users.owner_id IN (0, ?) AND credit_notes.id = ?', current_user.id, credit_note_id.to_i])
    elsif current_user.is_reseller? or current_user.is_admin?
      CreditNote.find(:first, :include => :user, :conditions => ['users.owner_id = ? AND credit_notes.id = ?', current_user.id, credit_note_id.to_i])
    end
  end

=begin
  Options set in params hash override parameters saved in session.
  Clear all search parameters if user set :clear. 
  Return only parameters that have some meaning
  This method is very specific for CreditNoteController.list method, i doubt anyone
  else should ever use it and especialy(!) edit it for any other purposes.
  Note that not all users can view financial data, so they cannot supply search params
  involving financial data.

  *Returns*
  +options+ hash of user specified(or system default) parameters
=end
  def search_options
    session[:credit_note_list_opt] ? options = session[:credit_note_list_opt] : options = {}
    valid_options = [:nice_user, :first_name, :last_name, :issue_date_from, :issue_date_till]
    if can_view_finances?
      valid_options += [:status, :amount_min, :amount_max, :paid_date_from, :paid_date_till]
    end
    valid_options.each { |key|
      if params[:clear].to_i == 1 or meaningless? params[key]
        options.delete(key)
      elsif params[key]
        options[key] = params[key]
      end
    }
    logger.fatal options.to_yaml
    return options
  end

=begin
  parameter is meaningless if it is nil or if it is string and when striped it is blank

  *Params*
  +param+ at this moment expected to be nil, hash or string

  *Returns*
  +meaningless+ boolean, true if parameter it is meaningless
=end
  def meaningless?(param)
    (param.is_a?(String) and param.strip.blank?)
  end

=begin
  Get current page. if page number was passed in params then return it, else
  page number may be saved in session, if so return it, else default to first_page.
  This method is very specific for CreditNoteController.list method, i doubt anyone
  else should ever use it and especialy(!) edit it for any other purposes.

  *Returns*
  +page_number+ page number in credit note list
=end
  def current_page
    first_page = 1
    if params[:page]
      params[:page].to_i
    elsif session[:credit_note_list_opt] and session[:credit_note_list_opt][:page]
      session[:credit_note_list_opt][:page].to_i
    else
      first_page
    end
  end

=begin
  If search options contains any non default values of paid_date/issue_date from/till,
  status or there are more search options than these, this means that user specified some
  search parameters and we should show search menu.
  Default for paid_date/issue_date from/till is today, default for status is all.
  If none of these params are specified theres no need to show search menu.
=end
  def show_search? search_options
    if search_options
      [:issue_date_from, :issue_date_till, :paid_date_from, :paid_date_till].each { |key|
        date = search_options[key]
        if date
          date = Date.new(date[:year].to_i, date[:month].to_i, date[:day].to_i)
          return true if date != Date.today
        end
      }
      if ['paid', 'unpaid'].include? search_options[:status]
        return true
      elsif ([:username, :first_name, :last_name, :amount_min, :amount_max] & search_options.keys).size > 0
        return true
      else
        return false
      end
    else
      false
    end
  end


=begin
  get information by whitch columns list should be ordered. if order_by in
  params is specified return it, else check whether order_by was saved in session,
  if not return default(first_name). if :desc is not specified in any hash(session, params)
  return default(1).
  This method is very specific for CreditNoteController.list method, i doubt anyone
  else should ever use it and especialy(!) edit it for any other purposes.

  *Returns*
  +[order_by, order_desc]+  array containing by whitch column to order and in what order(asc/desc)
=end
  def order_by
    valid_params = ['number', 'nice_user', 'issue_date']
    if can_view_finances?
      valid_params += ['status', 'pay_date', 'price']
    end
    order_by = 'first_name'
    desc = 1
    if params[:order_by] and valid_params.include? params[:order_by]
      desc = params[:order_desc].to_i if params[:order_desc]
      return params[:order_by], desc
    elsif session[:credit_note_list_opt] and session[:credit_note_list_opt][:order_by] and valid_params.include? session[:credit_note_list_opt][:order_by]
      desc = session[:credit_note_list_opt][:order_desc].to_i if session[:credit_note_list_opt][:order_desc]
      return session[:credit_note_list_opt][:order_by], desc
    else
      return order_by, desc
    end
  end

=begin
  If user can edit other user's data and he can see credit note of that user
  it means that we can create link(in the view) to that user.
  But no matter what we should not halt filter chain, hence return true
=end
  def link_to_user?
    @link_to_user = can_edit_users?
    return true
  end

=begin
  Accountant without manage invoices privilege cannot see any credit note information.
  Neither can ordinary users. If user has no rights to view credit notes redirect
  him to callc/main
=end
  def can_view_credit_notes?
    if current_user.is_admin? or current_user.is_reseller? or (current_user.is_accountant? and current_user.accountant_allow_read('invoices_manage'))
      true
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

=begin
  Only admin, reseller and accountant with certain permissions can edit credit note
  financial data
=end
  def can_edit_finances?
    current_user and (current_user.is_admin? or current_user.is_reseller? or (current_user.is_accountant? and current_user.accountant_allow_edit('see_financial_data') and current_user.accountant_allow_read('invoices_manage')))
  end

=begin
  Only admin, reseller and accountant with certain permissions can view financial data
=end
  def can_view_finances?
    current_user and ((current_user.is_admin? or current_user.is_reseller? or (current_user.is_accountant? and current_user.accountant_allow_read('see_financial_data') and current_user.accountant_allow_read('invoices_manage'))))
  end

=begin
  User without appropriat permissions to edit financial data cannot access some
  credit notes pages, he should be redirected to callc/main.
=end
  def can_edit_financial_data?
    if can_edit_finances?
      true
    else
      dont_be_so_smart
      redirect_to :controller => "callc", :action => "main" and return false
    end
  end

=begin
  If user can edit financial data, we can pass variable to appropriat views, so that
  links to financial data would be rendered.
=end
  def link_to_financial_operations?
    @link_to_finances = can_edit_finances?
    return true
  end

=begin
  If user can view financial data, we can pass variable to appropriat views, so that
  financial data would be rendered.
=end
  def can_view_financial_data?
    @can_view_finances = can_view_finances?
    return true
  end

end
