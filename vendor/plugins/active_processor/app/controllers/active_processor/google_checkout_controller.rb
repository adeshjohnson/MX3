# -*- encoding : utf-8 -*-
class ActiveProcessor::GoogleCheckoutController < ActiveProcessor::BaseController
  before_filter :check_localization
  skip_before_filter :check_if_enabled, :only => [:notify]

  def pay
    @engine = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => current_user.id}).enabled_by(current_user.owner.id)
    @gateway = @engine.query

    if @engine.pay_with(@gateway, request.remote_ip, params['gateways'])
      respond_to do |format|
        format.html {}
      end
    else
      respond_to do |format|
        format.html {
          flash.now[:notice] = _("Payment_Error")
          render :action => "index"
        }
      end
    end
  end

  # POST /notify
  def notify
    render :text => "Move along" and return unless request.post?

    # <hack>
    temp_configuration = {:merchant_id => '', :merchant_key => '', :use_sandbox => false}
    temp_frontend = Google4R::Checkout::Frontend.new(temp_configuration)
    temp_handler = temp_frontend.create_notification_handler
    # </hack>
    temp_frontend.tax_table_factory = TaxTableFactory.new

    begin
      notification = temp_handler.handle(request.raw_post)
      ActiveProcessor.log("  >> Got notification: #{notification}")
      case notification
        when Google4R::Checkout::NewOrderNotification then
          payment = Payment.find_by_id_and_completed(notification.shopping_cart.items.first.id, false)
          owner = User.find_by_id(payment.user_id).owner_id
          payment.update_attributes({
                                        :transaction_id => notification.google_order_number,
                                        :pending_reason => notification.financial_order_state
                                    })
          ActiveProcessor.log("    >> Payment: #{payment.id}, Pending_reason: #{payment.pending_reason.downcase}")
        when Google4R::Checkout::OrderStateChangeNotification then
          payment = Payment.find_by_transaction_id_and_completed(notification.google_order_number, false)
          if payment
            owner = User.find_by_id(payment.user_id).owner_id
            payment.update_attributes({
                                          :pending_reason => notification.new_financial_order_state
                                      })
            ActiveProcessor.log("    >> Payment: #{payment.id}, Pending_reason: #{payment.pending_reason.downcase}")
            ActiveProcessor.log("    >> order_state: #{notification.new_financial_order_state} ")

            if payment.pending_reason.downcase.eql?("chargeable")
              @engine = ::GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => payment.user_id}).enabled_by(owner)
              frontend = @engine.query.init

              ActiveProcessor.log("    >> CHARGE! ID:#{payment.transaction_id}, Money: #{payment.gross.to_f * 100} #{payment.currency}")
              command = frontend.create_charge_order_command
              command.google_order_number = payment.transaction_id
              command.amount = Money.new(payment.gross.to_f * 100, payment.currency)
              command.send_to_google_checkout
            end
          end
        when Google4R::Checkout::RiskInformationNotification then
        when Google4R::Checkout::ChargeAmountNotification then
          payment = Payment.find_by_transaction_id_and_completed(notification.google_order_number, false)


          unless payment.nil?
            gateway = ::GatewayEngine.find(:first, {:engine => "google_checkout", :gateway => "google_checkout", :for_user => payment.user_id}).query
            confirmation = gateway.get(:config, "payment_confirmation")

            user = User.find_by_id(payment.user_id)
            if confirmation.blank? or confirmation == "none"
              payment.update_attributes({
                                            :completed => true,
                                            :shipped_at => notification.timestamp,
                                            :pending_reason => "Completed"
                                        })

              Action.add_action_hash(payment.user_id,
                                     {:action => "payment: #{gateway.settings['name']}",
                                      :data => "User successfully payed using #{gateway.settings['name']} (Google Checkout)",
                                      :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{payment.fee} #{payment.currency} | sent: #{payment.gross} #{payment.currency}",
                                      :data2 => "payment id: #{payment.id}",
                                      :data4 => "authorization: #{payment.transaction_id}"
                                     })
              user.balance += payment.amount.to_f * ActiveProcessor.configuration.currency_exchange.call(payment.currency, Currency.get_default.name)
              user.save
              ActiveProcessor.log("    >> Payment: #{payment.id}, Pending_reason: #{payment.pending_reason.downcase}")
              ActiveProcessor.log("    >> USER (#{user.id}) balance was updated")
            else
              payment.update_attributes({
                                            :completed => false,
                                            :pending_reason => "Waiting for confirmation",
                                        })
              ActiveProcessor.log("    >> Payment: #{payment.id}, Pending_reason: #{payment.pending_reason.downcase}")
              ActiveProcessor.log("    >> USER (#{user.id}) waiting for confirmation.")
              Action.add_action_hash(payment.user_id,
                                     {:action => "payment: #{gateway.settings['name']}",
                                      :data => "User successfully payed, waiting for payment approval #{gateway.settings['name']} (Google Checkout)",
                                      :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{payment.fee} #{payment.currency} | sent: #{payment.gross} #{payment.currency}",
                                      :data2 => "payment id: #{payment.id}",
                                      :data4 => "authorization: #{payment.transaction_id}"
                                     })

              if gateway.get(:config, 'payment_notification').to_i == 1
                owner = User.find_by_id(user.owner_id)
                email = Email.find(:first, :conditions => {:name => 'payment_notification_regular', :owner_id => owner.id})

                variables = Email.email_variables(owner, nil, {:payment => payment, :payment_notification => OpenStruct.new({}), :payment_type => "#{gateway.name} (#{gateway.engine})"})
                EmailsController::send_email(email, Confline.get_value("Email_from", owner.id), [owner], variables)
              end
            end
          else
            ActiveProcessor.log("    >> Payment not found.")
          end
        else
          ActiveProcessor.log("unkown notification type from google: #{notification}")
      end
      render :text => Google4R::Checkout::NotificationAcknowledgement.new(notification).to_xml
    rescue Google4R::Checkout::UnknownNotificationType => e
      ActiveProcessor.log("unkown notification type from google: #{e.message}")
      render :text => "Error (unknown notification): #{e.message}", :status => 200
    end
  end

end
