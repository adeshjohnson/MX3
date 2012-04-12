# -*- encoding : utf-8 -*-
class ActiveProcessor::IntegrationsController < ActiveProcessor::BaseController
  before_filter :check_localization

  verify :method => :post, :only => [:pay],
         :redirect_to => {:controller => :callc, :action => :main},
         :add_flash => {:notice => _('Dont_be_so_smart'),
                        :params => {:dont_be_so_smart => true}
         }

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

  def pending
    notify = ActiveMerchant::Billing::Integrations.const_get(params[:gateway].downcase.camelize).notification(request.raw_post)

    if notify.respond_to?(:acknowledge) && notify.acknowledge
      payment = Payment.find_by_id_and_completed(notify.item_id, 0)

      if payment
        gateway = ::GatewayEngine.find(:first, {:engine => payment.paymenttype.split("_").first, :gateway => payment.paymenttype.split("_")[1..-1].join("_"), :for_user => current_user.id}).query

        params['tax'] ||= 0

        user = User.find_by_id(payment.user.id)
        payment.update_attributes({
                                      :pending_reason => "Pending for gateway approval"
                                  })

        Action.add_action_hash(payment.user.id,
                               {:action => "payment: #{gateway.settings['name']}",
                                :data => "Transaction marked as pending by gateway #{gateway.settings['name']} (#{gateway.engine})",
                                :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{notify.fee if notify.respond_to?(:fee)} #{notify.currency} | sent: #{notify.gross} #{notify.currency}",
                                :data2 => "payment id: #{payment.id}"
                               })

        flash[:status] = _("Payment_Pending")
      end
    end

    redirect_to :controller => "/payments", :action => "personal_payments"
  end


  def notify
    notify = ActiveMerchant::Billing::Integrations.const_get(params[:gateway].downcase.camelize).notification(request.raw_post)

    if notify.respond_to?(:acknowledge) && notify.acknowledge
      payment = Payment.find_by_id_and_completed(notify.item_id, 0)
      params['tax'] ||= 0 # some gateway do not supply tax value, so set it to 0 if not present in params.

      unless payment.nil?
        if notify.acknowledge
          user = User.find_by_id(payment.user.id) # this is needed due to faulty association between user and payment models
          gateway = ::GatewayEngine.find(:first, {:engine => payment.paymenttype.split("_").first, :gateway => payment.paymenttype.split("_")[1..-1].join("_"), :for_user => payment.user_id}).query
          confirmation = gateway.get(:config, "payment_confirmation")

          if notify.complete? and payment.gross.to_f == notify.gross.to_f
            if confirmation.blank? or confirmation == "none" or (confirmation == "suspicious" and notify.payer_email.to_s == user.email)
              payment.update_attributes({
                                            :transaction_id => notify.transaction_id,
                                            :completed => 1,
                                            :shipped_at => Time.now,
                                            :payment_hash => notify.transaction_id,
                                            :pending_reason => "Completed"
                                        })

              Action.add_action_hash(payment.user.id,
                                     {:action => "payment: #{gateway.settings['name']}",
                                      :data => "User successfully payed using #{gateway.settings['name']} (#{gateway.engine})",
                                      :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{notify.fee if notify.respond_to?(:fee)} #{notify.currency} | sent: #{notify.gross} #{notify.currency}",
                                      :data2 => "payment id: #{payment.id}",
                                      :data4 => "authorization: #{notify.transaction_id}"
                                     })

              user.balance += payment.amount.to_f * ActiveProcessor.configuration.currency_exchange.call(payment.currency, Currency.get_default.name)
              user.save
            else
              payment.update_attributes({
                                            :completed => false,
                                            :transaction_id => notify.transaction_id,
                                            :payer_email => notify.payer_email,
                                            :pending_reason => "Waiting for confirmation",
                                            :payment_hash => notify.transaction_id
                                        })

              Action.add_action_hash(payment.user_id,
                                     {:action => "payment: #{gateway.settings['name']}",
                                      :data => "User successfully payed, waiting for payment approval #{gateway.settings['name']} (#{gateway.engine})",
                                      :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{notify.fee if notify.respond_to?(:fee)} #{notify.currency} | sent: #{notify.gross} #{notify.currency}",
                                      :data2 => "payment id: #{payment.id}",
                                      :data4 => "authorization: #{payment.transaction_id}"
                                     })

              if gateway.get(:config, 'payment_notification').to_i == 1
                owner = User.find_by_id(user.owner_id)
                email = Email.find(:first, :conditions => {:name => 'payment_notification_integrations', :owner_id => owner.id})

                variables = Email.email_variables(owner, nil, {:payment => payment, :payment_notification => notify, :payment_type => "#{gateway.name} (#{gateway.engine})"})
                EmailsController::send_email(email, Confline.get_value("Email_from", owner.id), [owner], variables)
              end
            end
          else
            payment.update_attribute(:pending_reason, "Failed")

            Action.add_action_hash(user.id,
                                   {:action => "payment: #{gateway.settings['name']}",
                                    :data => "User failed to pay using #{gateway.settings['name']} (#{gateway.engine})",
                                    :data3 => "#{payment.amount} #{payment.currency}",
                                    :data2 => "payment id: #{payment.id}",
                                    :data4 => "Failed on IPN acknowledge or sum was altered in HTML"
                                   })
          end
        else
          payment.update_attribute(:pending_reason, "Failed")

          Action.add_action_hash(user.id,
                                 {:action => "payment: #{gateway.settings['name']}",
                                  :data => "User failed to pay using #{gateway.settings['name']} (#{gateway.engine})",
                                  :data3 => "#{payment.amount} #{payment.currency}",
                                  :data2 => "payment id: #{payment.id}",
                                  :data4 => "Failed on IPN payment completed?"
                                 })
        end
      end
    end

    render :nothing => true
  end

end
