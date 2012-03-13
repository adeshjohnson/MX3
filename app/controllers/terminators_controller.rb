# -*- encoding : utf-8 -*-
class TerminatorsController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only=>[:create , :destroy ,:update, :provider_remove, :provider_add ]
  before_filter :check_localization
  before_filter :authorize
  before_filter :providers_enabled_for_reseller?
  before_filter :find_terminator, :only => [:provider_add, :providers, :destroy, :update, :edit]
  
  def index
    list
    render :action => 'list'
  end
  
=begin rdoc
 Lists terminators
=end

  def list
    @page_title = _('Terminators')
    @page_icon = "provider.png"
    @terminators = current_user.load_terminators
  end


=begin rdoc
 Creates a terminator

 *Params*:

 +name+ - terminators name

 *Flash*:

  +Terminator_was_created+ - if terminator was successfully created
  +Terminator_was_not_created+ - if terminator was not successfully created

 *Redirect*

 +terminators+
=end

  def create
    term = Terminator.new(:name => params[:name].to_s, :user => current_user)
    if term.save
      flash[:status] = _('Terminator_was_created')
    else
      flash[:notice] = _('Terminator_was_not_created')
    end
    redirect_to :action => 'list' and return false
  end


=begin rdoc
 Destroys terminator

 *Params*:

 +id+ - terminators id

 *Flash*:

  Terminator_was_destroyed - if terminator was successfully destroyed
  Terminator_was_not_destroyed - if terminator was not successfully destroyed

 *Redirect*

 +terminators+
=end

  def destroy
    if @terminator.destroy
      flash[:status] = _('Terminator_was_destroyed')
      Provider.update_all("terminator_id = 0", "terminator_id = #{@terminator.id}")
    else
      flash_errors_for(_('Terminator_was_not_destroyed'), @terminator)
    end
    redirect_to :action => 'list' and return false
  end

=begin rdoc

=end

  def edit
    @page_title = _('Terminator_edit') + ": " + @terminator.name
    @page_icon = "edit.png"
  end
=begin rdoc
 Updates terminator.

 *Params*:

 +id+ - terminators id
 +name+ - new name for terminator

 *Flash*:

  Terminator_updated - if terminator was successfully updated
  Terminator_was_not_updated - if terminator was not successfully updated

 *Redirect*

 +terminators+
=end

  def update
    @terminator.name = params[:terminator][:name]
    if @terminator.save
      flash[:status] = _('Terminator_was_updated')
    else
      flash[:notice] = _('Terminator_was_not_updated')
    end
    redirect_to :action => 'list' and return false
  end


=begin rdoc
 Shows and allows terminator providers management

 *Params*:

 +id+ - terminators id
=end

  def providers
    @page_title = _('Terminator_providers')
    @page_icon = "provider.png"
    if current_user.usertype == 'reseller'
      @assigned = Provider.find(:all, :conditions => ["providers.terminator_id = ? AND (providers.user_id = ? OR (providers.common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id})))", @terminator.id, current_user.id], :order => "name ASC")
      @not_assigned =  Provider.find(:all, :conditions => ["providers.terminator_id = 0 AND (providers.user_id = ? OR (providers.common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id})))", current_user.id], :order => "name ASC")
    else
      @assigned = Provider.find(:all, :conditions => ["providers.terminator_id = ? AND (providers.user_id = ? OR providers.common_use = 1)", @terminator.id, current_user.id], :order => "name ASC")
      @not_assigned =  Provider.find(:all, :conditions => ["providers.terminator_id = 0 AND (providers.user_id = ? OR providers.common_use = 1)", current_user.id], :order => "name ASC")
    end
  end


=begin rdoc
 Assigns Provider to Terminator.

 *Params*:

 +id+ - terminators id
 +provider_id+ - provider id

 *Flash*:

  Provider_was_assigned - if terminator was successfully updated
  Terminator_was_not_assigned - if terminator was not successfully updated

 *Redirect*

 +terminator_providers+
=end

  def provider_add
    prov = Provider.find(:first, :conditions => ["providers.id = ? AND (providers.user_id = ? or providers.common_use = 1)", params[:provider_id], session[:user_id]])
    unless prov
      flash[:notice] = _('Provider_was_not_found')
      redirect_to :action => :terminators and return false
    end
    prov.terminator_id = @terminator.id
    if prov.save
      flash[:status] = _('Provider_was_assigned')
    else
      flash[:notice] = _('Provider_was_not_assigned')
    end
    redirect_to :action => 'providers', :id => params[:id] and return false
  end


=begin rdoc
 Removes Provider to Terminator.

 *Params*:

 +id+ - terminators id
 +provider_id+ - provider id

 *Flash*:

  Provider_was_removed_from_terminator  - if terminator was successfully updated
  Terminator_was_not_removed_from_terminator - if terminator was not successfully updated

 *Redirect*

 +terminator_providers+
=end

  def provider_remove
    prov = Provider.find(:first, :conditions => ["providers.id = ? AND (providers.user_id = ? or providers.common_use = 1)", params[:provider_id], session[:user_id]])
    unless prov
      flash[:notice] = _('Provider_was_not_found')
      redirect_to :action => :list and return false
    end
    prov.terminator_id = 0
    if prov.save
      flash[:status] = _('Provider_was_removed_from_terminator')
    else
      flash[:notice] = _('Provider_was_not_removed_from_terminator')
    end
    redirect_to :action => 'providers', :id => params[:id] and return false
  end

  private

  def find_terminator
    @terminator = current_user.load_terminator(params[:id])
    unless @terminator
      flash[:notice] = _('Terminator_was_not_found')
      redirect_to :action => :list and return false
    end
  end
  
end
