class PaymentGatewaysController < ApplicationController
  layout "callc"
  before_filter :check_localization
  before_filter :check_if_enabled

  

  # gateway configuration listing 
  def configuration
    @page_title = _('Payment_Gateways')
    @gateways = GatewayEngine.find(:enabled, { :for_user => current_user.id, :mode => :config })

    respond_to do |format|
      format.html { }
    end
  end

  # Configuration update method
  def update
    @gateways = GatewayEngine.find(:enabled, { :for_user => current_user.id, :mode => :config })

    respond_to do |format|
      if @gateways.update_with(:config, params[:gateways])
        format.html {
          flash[:status] = _('Settings_saved')
          redirect_to :action => 'configuration'
        }
      else
        format.html {
          flash.now[:notice] = _('gateway_error')
          render :action => "configuration"
        }
      end
    end  
  end

  private

  def check_if_enabled
    redirect_to :controller => "callc", :action => "main" if !payment_gateway_active? || !current_user || !["reseller", "admin"].include?(current_user.usertype) || (current_user.usertype == 'reseller' and session[:res_payment_gateways].to_i != 2 )
  end

end
