# -*- encoding : utf-8 -*-
class ActiveProcessor::IdealController < ActiveProcessor::BaseController
  before_filter :check_localization

  def index
    @gateway = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => current_user.id}).enabled_by(current_user.owner.id).query

    unless  @gateway
      flash[:notice] = _("Inactive_Gateway")
      redirect_to :controller => "/callc", :action => "main"
    end

    unless @gateway
      flash[:notice] = _("Inactive_Gateway")
      redirect_to :controller => "/callc", :action => "main" and return false
    end

    respond_to do |format|
      format.html {}
    end
  rescue ActiveProcessor::GatewayEngineError # invalid engine or gateway name specified
    flash[:notice] = _("Inactive_Gateway")
    redirect_to :controller => "/callc", :action => "main"
  end

  def pay
    @engine = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => current_user.id}).enabled_by(current_user.owner.id)
    @gateway = @engine.query

    unless  @gateway
      flash[:notice] = _("Inactive_Gateway")
      redirect_to :controller => "/callc", :action => "main"
    end


    params['gateways']["issuer_id"] = params[:purchase][:issuer_id] if params[:purchase] and params[:purchase][:issuer_id]
    if params[:purchase] and params[:purchase][:issuer_id] and @engine.pay_with(@gateway, request.remote_ip, params['gateways'])
      flash[:notice] = nil
      redirect_to @gateway.redirect_url and return false
    else
      respond_to do |format|
        format.html {
          flash.now[:notice] = _("Payment_Error")
          render :action => "index"
        }
      end
    end
  end

  def notify
    payment = Payment.find(:first, :conditions => {:transaction_id => params[:trxid], :pending_reason => "waiting_response"})
    if payment and !payment.transaction_id.blank?
      gateway = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => current_user.id}).enabled_by(current_user.owner_id).query
      success, message = gateway.check_response(payment)
      if success
        flash[:status] = message
      else
        flash[:notice] = message
      end
    else
      flash[:notice] = _('Payment_was_not_found')
    end
    redirect_to :action => :index
  end

  def done
    render :text => "done"
  end
end
