# -*- encoding : utf-8 -*-
module ActiveProcessor
  class BaseController < ApplicationController
    layout "callc" #layout ActiveProcessor.configuration.layout
    before_filter :check_post_method_pg, :only => [:pay]
    before_filter :check_localization
    before_filter :check_if_gateway_enabled, :only => [:index]
    before_filter :check_if_enabled, :only => [:index, :pay]
                   #before_filter :verify_params, :only => [ :pay ]

                   #  verify :method => :post, :only => [ :pay ],
                   #    :redirect_to => { :controller => "/callc", :action => :main },
                   #    :add_flash => { :notice => _('Dont_be_so_smart'),
                   #    :params => { :dont_be_so_smart => true }
                   #  }

                   # GET /{gateway}
    def index
      @gateway = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => current_user.id}).enabled_by(current_user.owner.id).query

      unless @gateway
        flash[:notice] = _("Inactive_Gateway")
        redirect_to :controller => "/callc", :action => "main" and return false
      end


      @page_title = @gateway.display_name
      @page_icon = "money.png"

      respond_to do |format|
        format.html {}
      end

    rescue ActiveProcessor::GatewayEngineError # invalid engine or gateway name specified
      flash[:notice] = _("Inactive_Gateway")
      redirect_to :controller => "/callc", :action => "main"
    end

    # GET /pay
    def pay

      @engine = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => current_user.id}).enabled_by(current_user.owner.id)
#      @page_title = @engine.display_name
#      @page_icon = "money.png"

      respond_to do |format|
        if @engine.pay_with(@engine.query, request.remote_ip, params['gateways'])

          format.html {
            flash[:status] = _('Payment_Successful')
            if params[:gateway] == 'paypal'
              custom_redirect = Confline.get_value('gateways_paypal_PayPal_Custom_redirect', current_user.owner.id).to_i
              custom_redirect_successful_payment = Confline.get_value('gateways_paypal_Paypal_return_url', current_user.owner.id)
              if custom_redirect and custom_redirect.to_i == 1
                redirect_to Web_URL + "/" + custom_redirect_successful_payment.to_s
              else
                redirect_to :controller => "/callc", :action => "main"
              end
            else
              redirect_to :controller => "/callc", :action => "main"
            end

          }
        else
          @gateway = @engine.query
          format.html {
            flash.now[:notice] = _('Payment_Error') + " <small>#{(@gateway.payment.response.try(:message) rescue "") unless @gateway.payment.nil?}</small>"
            render :action => "index"
          }
        end
      end
    end

    # POST /notify
    def notify

    end

    private

    def check_if_gateway_enabled
      if !current_user or Confline.get_value([params['engine'], params['gateway'], "enabled"].join("_"), current_user.owner_id).to_i == "0"
        flash[:notice] = _("Inactive_Gateway")
        redirect_to :controller => "/callc", :action => "main"
      end
    end

    def check_user
      redirect_to :controller => "/callc", :action => "main" if !session[:usertype_id] or session[:usertype] == "guest" or session[:usertype].to_s == ""
    end

    def check_if_enabled
      redirect_to :controller => "/callc", :action => "main" if !defined?(PG_Active) || PG_Active != 1
    end

    def verify_params
      unless params['gateways']
        dont_be_so_smart
        redirect_to :controller => "/callc", :action => "main"
      end
    end

    def check_post_method_pg
      unless request.post?
        flash[:notice] = _('Dont_be_so_smart')
        redirect_to :controller => "callc", :action => "main" and return false
      end
    end

  end
end
