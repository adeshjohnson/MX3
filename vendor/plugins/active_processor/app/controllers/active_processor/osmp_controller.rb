# -*- encoding : utf-8 -*-
class ActiveProcessor::OsmpController < ActiveProcessor::BaseController
  before_filter :check_localization

  def index
    redirect_to :controller => "/callc", :action => "main" and return false
  end

  def pay
    redirect_to :controller => "/callc", :action => "main" and return false
  end

  def notify
    ActiveProcessor.debug("OSMP#notify")
    transaction = {:command => params[:command].to_s, :amount => params[:sum].to_f, :id => params[:txn_id].to_i}
    transaction[:user] = User.find(:first, :conditions => ["username = ?", params[:account]])

    if !params[:account] or params[:account].to_s.length == 0 or !transaction[:user] or !transaction[:user] or !transaction[:user].respond_to?(:username)
      ActiveProcessor.debug("  > Account: #{params[:account]}")
      user_not_found_response(transaction[:id]) and return false
    end

    unless params[:command] and ["pay", "check"].include?(params[:command])
      ActiveProcessor.debug("  > Command: #{params[:command]}")
      fail_request(transaction[:id], "Bad command.") and return false
    end
    
    if !params[:sum] or params[:sum].to_f <= 0
      ActiveProcessor.debug("  > Sum: #{params[:sum]}")
      fail_request(transaction[:id], "Bad sum.") and return false
    end

    if !params[:txn_id] or params[:txn_id].to_i <= 0
      ActiveProcessor.debug("  > Tnx_id: #{params[:txn_id]}")
      fail_request(transaction[:id], "Bad transaction ID.") and return false
    end

    if !params[:account] or params[:account].to_s.length == 0 or !transaction[:user]
      ActiveProcessor.debug("  > Account: #{params[:account]}")
      fail_request(transaction[:id], "Bad Account.") and return false
    end

    if params[:command] == "pay" and !params[:txn_date]
      ActiveProcessor.debug("  > Date: #{params[:txn_date]}")
      fail_request(transaction[:id], "Bad transaction date.") and return false
    end
    
    begin
      ActiveProcessor.debug("OSMP accessed.")
      @engine = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => transaction[:user].id }).enabled_by(transaction[:user].owner_id)
      @gateway = @engine.query
      if @gateway and @engine
        transaction[:date] = params[:txn_date]
        transaction[:money_with_tax] = transaction[:amount].to_f
        transaction[:money] = ActiveProcessor.configuration.substract_tax.call(transaction[:user], transaction[:amount].to_f).to_f
        transaction[:tax] = transaction[:money_with_tax] - transaction[:money]
        transaction[:currency] = @gateway.get(:config, "default_geteway_currency")
        ActiveProcessor.debug("  > COMMAND :#{transaction[:command]}")
        case transaction[:command].to_s
        when "check" then
          ActiveProcessor.debug("  > CHECKING")         
          render :xml=> @gateway.check(transaction) and return false
        when "pay" then
          ActiveProcessor.debug("  > PAY")
          payment =  Payment.find(:first, :conditions => ["date_added = ? AND paymenttype = ? AND transaction_id = ?", transaction[:date], [params[:engine], params[:gateway]].join("_"), transaction[:id]])
          if payment
            render :xml => @gateway.error_response(params[:txn_id]) and return false
          else
            @engine.pay_with(@gateway, request.remote_ip, params.merge(:transaction => transaction))
            payment =  Payment.find(:first, :conditions => ["date_added = ? AND paymenttype = ? AND transaction_id = ?", transaction[:date], [params[:engine], params[:gateway]].join("_"), transaction[:id]])
            if payment
              render :xml => @gateway.payment_status(payment) and return false
            else
              render :xml => @gateway.error_response(params[:txn_id]) and return false
            end
          end
          redirect_to :action => :index and return false
        end
        else
          flash[:notice] = _("Inactive_Gateway")
          redirect_to :controller => "/callc", :action => "main" and return false
        end
    rescue Exception => e
      MorLog.log_exception(e, transaction[:id], "OSMP_CONTROLLER", "NOTIFY")
      ActiveProcessor.debug("  > EXPCEPTION IN OSMP")
      fail_request(transaction[:id], "Internal error.") and return false
      
    end
  end

  private

  def fail_request(tnx_id, comment)
    xml = Builder::XmlMarkup.new
    xml.instruct!(:xml, :version=>"1.0")
    render :xml => xml.response{
      xml.osmp_txn_id(tnx_id)
      xml.result(300)
      xml.comment(comment)
    }
  end

  # a little duplication with ospm lib
  def user_not_found_response(tnx_id)
    xml = Builder::XmlMarkup.new
    xml.instruct!(:xml, :version=>"1.0")
    render :xml => xml.response{
      xml.osmp_txn_id(tnx_id)
      xml.result(5)
      xml.comment("The subscribers ID is not found (Wrong number)")
    }
  end
end
