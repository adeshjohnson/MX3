# -*- encoding : utf-8 -*-
class ErpController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:settings_update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_erp

  def settings
    @page_title = _('Erp_settings')
    @page_icon = 'cog.png'
    if not Confline.valid_erp_settings?(current_user.id)
      flash[:notice] = _('ERP_settings_are_invalid')
    end
  end

  def settings_update
    coid = correct_owner_id
    Confline.set_value("ERP_login", params[:erp_login], coid)
    Confline.set_value("ERP_password", params[:erp_password], coid)
    Confline.set_value("ERP_domain", params[:erp_domain], coid)
    set_erp_settins(current_user)
    flash[:status] = _('Settings_saved')
    redirect_to :action => :settings and return false
  end

  def check_erp
    unless erp_active?
      dont_be_so_smart
      redirect_to :controller => "callc", :action => 'main' and return false
    end
  end

end
