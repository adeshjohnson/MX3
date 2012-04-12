# -*- encoding : utf-8 -*-
class PhonebooksController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :authorize
  before_filter :check_localization
  before_filter :find_phonebook, :only => [:update, :edit, :destroy, :show]
  before_filter :find_user, :only => [:add_new]
  before_filter :find_phonebooks, :only => [:index, :list]


  def index
    list
    render :action => 'list'
  end

  def list
    @page_title = _('PhoneBook')
    @page_icon = "book.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PhoneBook"

    @phonebook = Phonebook.new
  end

  # before_filter:
  #   find_user
  def add_new
    @phonebook = Phonebook.new(params[:phonebook]) do |p|
      p.added = Time.now
      p.user = @user
    end

    if @phonebook.valid? and @phonebook.save
      flash[:status] = _('Added')
      redirect_to :action => 'list'
    else
      flash_errors_for(_("Please_fill_all_fields"), @phonebook)
      find_phonebooks
      render :action => "list"
    end
  end

  # before_filter:
  #   find_phonebook
  def show
  end

  def new
    @phonebook = Phonebook.new
  end

  # before_filter:
  #   find_phonebook
  def create
    @phonebook = Phonebook.new(params[:phonebook])
    if @phonebook.save
      redirect_to :action => 'list'
    else
      flash_errors_for(_("Record_was_not_saved"), @phonebook)
      render :action => 'new'
    end
  end

  # before_filter:
  #   find_phonebook
  def edit
    @page_title = _('Edit_PhoneBook')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PhoneBook"
  end

  # before_filter:
  #   find_phonebook
  def update
    if @phonebook.update_attributes(params[:phonebook])
      flash[:status] = _('Updated')
      redirect_to :action => 'list'
    else
      flash_errors_for(_("Record_was_not_saved"), @phonebook)
      redirect_to :action => 'edit', :id => @phonebook.id
    end
  end

  # before_filter:
  #   find_phonebook
  def destroy
    user_id = @phonebook.user_id

    @phonebook.destroy
    flash[:status] = _('Deleted')
    redirect_to :action => 'list', :id => user_id
  end

  private

  def find_phonebook
    @phonebook = Phonebook.find_by_id(params[:id])

    unless @phonebook
      flash[:notice]=_('Phonebook_was_not_found')
      redirect_to :action => :index and return false
    end
    if @phonebook.user_id != session[:user_id] and session[:usertype] != "admin"
      dont_be_so_smart
      redirect_to :action => :list and return false
    end
  end

  def find_user
    @user = User.find_by_id(session[:user_id])
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :index and return false
    end
  end

  def find_phonebooks
    user_id = session[:user_id]
    user_id = params[:id] if params[:id] and session[:usertype] == "admin"
    @user = User.find_by_id(user_id)

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => :index and return false
    end

    @phonebooks = Phonebook.user_phonebooks(@user)

  end
end
