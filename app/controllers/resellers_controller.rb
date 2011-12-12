class ResellersController < ApplicationController
  layout "callc"
  before_filter :check_localization
  before_filter :authorize

 
  verify :method => :post, :only => [:settings_change],
    :redirect_to => { :action =>  :settings}

  @@settings = [
    [:boolean, "Show_HGC_for_Resellers"],
    [:boolean, "Resellers_Allow_Use_Zap_Device"],
    [:boolean, "Resellers_Allow_Use_Virtual_Device"],
    [:boolean, "Resellers_can_add_their_own_DIDs"],
    [:boolean, "Resellers_Allow_Assign_DID_To_Trunk"],
  ]

  def settings
    @page_title = _('Settings')
    @page_icon = 'cog.png'
    @settings = @@settings
    @providers = current_user.providers(:all, :conditions=>['hidden=?',0], :order => "name ASC")
  end
  
  def settings_change
    @@settings.each{ |type, name|
      case type
      when :boolean then
        Confline.set_value(name, params[name.downcase.to_sym].to_i, 0)
      end
    }
    Confline.set_value("DID_default_provider_to_resellers", params[:did_provider])
    Confline.set_value('Allow_resellers_change_device_PIN', params[:allow_resellers_change_device_pin].to_i)
    
    flash[:status] = _('Settings_saved')
    redirect_to :action => 'settings' and return false
  end
end
