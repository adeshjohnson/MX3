# -*- encoding : utf-8 -*-
module ActiveProcessor
  module PaymentEngines
    class Osmp < PaymentEngine

      require 'yaml'

      attr_accessor :name
      attr_accessor :instance
      attr_accessor :response

      def initialize(engine, name, options = {}, fields = {})
        @message = {
            :ok => {:code => 0, :msg => "osmp_message_0", :fatal => false}, # OK
            :temporary_error => {:code => 1, :msg => "osmp_message_1", :fatal => false}, # Temporary error. Please repeat your request later
            :wrong_subscribers_id_format => {:code => 4, :msg => "osmp_message_4", :fatal => true}, # Wrong subscribers identifier format
            :id_not_found => {:code => 5, :msg => "osmp_message_5", :fatal => true}, # "The subscribers ID is not found (Wrong number)".
            :payment_forbidden => {:code => 7, :msg => "osmp_message_7", :fatal => true}, # Payment accepting forbidden by provider
            :payment_forbidden_technical => {:code => 8, :msg => "osmp_message_8", :fatal => true}, # Payment accepting forbidden because of technical problems
            :acount_disabled => {:code => 79, :msg => "osmp_message_79", :fatal => true}, # Subscribers account is not active
            :not_finished => {:code => 90, :msg => "osmp_message_90", :fatal => false}, # Payments processing is not finished
            :amount_to_small => {:code => 241, :msg => "osmp_message_241", :fatal => true}, # The amount is too small
            :amount_to_big => {:code => 242, :msg => "osmp_message_242", :fatal => true}, # The amount is too large
            :cannot_check_accunt => {:code => 244, :msg => "osmp_message_244", :fatal => true}, # Impossible to check accounts status
            :other_error => {:code => 300, :msg => "osmp_message_300", :fatal => true} # Other providers’ error
        }

        @name = name.to_s
        super(engine, name, options, fields)
      end

      def check(transaction)
        ActiveProcessor.debug("Checking OSMP")
        ActiveProcessor.debug("Transaction: #{transaction.inspect}")

        if transaction[:user]
          @payment = Payment.create_for_user(transaction[:user], {
              :pending_reason => "waiting_response",
              :paymenttype => [@engine, @name].join("_"),
              :currency => transaction[:currency],
              :gross => transaction[:money_with_tax],
              :tax => transaction[:tax],
              :amount => transaction[:money],
              :transaction_id => transaction[:id],
              :date_added => Time.now
          })
        else
          @payment = nil
        end
        osmp_transaction(transaction[:id]) { |xml|
          unless @payment # user was not found so payment was not created
            ActiveProcessor.debug(" >ERROR. Payment not created. User not found.")
            xml.result(@message[:id_not_found][:code])
            xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:id_not_found][:code]}"))
          else
            if Payment.find(:first, :conditions => ["transaction_id = ? AND paymenttype = ?", transaction[:id].to_s, [@engine, @name].join("_")]) # already exists payment with this transaction_id
              ActiveProcessor.debug("  >ERROR. Payment already created.")
              xml.result(@message[:other_error][:code])
              xml.comment(ActiveProcessor.configuration.translate_func.call(@message[:other_error][:msg]))
            else
              if get(:config, 'min_amount').to_i > 0 and @payment.gross < get(:config, 'min_amount').to_i # payment is to small
                ActiveProcessor.debug("  >ERROR. Payment amount to small.")
                xml.result(@message[:amount_to_small][:code])
                xml.comment(ActiveProcessor.configuration.translate_func.call(@message[:amount_to_small][:msg]) + get(:config, 'min_amount').to_s)
              else
                if get(:config, 'max_amount').to_i > 0 and @payment.gross > get(:config, 'max_amount').to_i #payment is too big
                  ActiveProcessor.debug("  >ERROR. Payment amount to big.")
                  xml.result(@message[:amount_to_big][:code])
                  xml.comment(ActiveProcessor.configuration.translate_func.call(@message[:amount_to_big][:msg]) + get(:config, 'max_amount').to_s)
                else
                  # nereikia/nebebutina saugoti paymento!
                  #                  unless @payment.save # cannot save payment
                  #                    ActiveProcessor.debug("  >ERROR. Payment was not saved.")
                  #                    xml.result(@message[:temporary_error][:code])
                  #                    xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:temporary_error][:code]}"))
                  #                  else # OK
                  ActiveProcessor.debug("  >Payment OK.")
                  xml.result(@message[:ok][:code])
                  xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:ok][:code]}"))
                                                                                                            #                  end
                                                                                                            #--------------------------------------
                end
              end
            end
          end
        }
      end

      # call payment save when pay.
      def pay(user, ip, params)
        transaction = params[:transaction]
        ActiveProcessor.debug("Paying OSMP")
        ActiveProcessor.debug("Transaction: #{transaction.to_yaml}")
        #create payment
        if transaction[:user]
          @payment = Payment.create_for_user(transaction[:user], {
              :pending_reason => "waiting_response",
              :paymenttype => [@engine, @name].join("_"),
              :currency => transaction[:currency],
              :gross => transaction[:money_with_tax],
              :tax => transaction[:tax],
              :amount => transaction[:money],
              :transaction_id => transaction[:id],
              :date_added => transaction[:date]
          })
        else
          @payment = nil
        end
        osmp_transaction(transaction[:id]) { |xml|
          unless @payment # user was not found so payment was not created
            ActiveProcessor.debug(" >ERROR. Payment not created. User not found.")
            xml.result(@message[:id_not_found][:code])
            xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:id_not_found][:code]}"))
          else
            if Payment.find(:first, :conditions => ["date_added = ? AND paymenttype = ? AND transaction_id = ?", transaction[:date], [@engine, @name].join("_"), transaction[:id]]) # already exists payment with this date_added
              ActiveProcessor.debug("  >ERROR. Payment already created.")
              xml.result(@message[:other_error][:code])
              xml.comment(ActiveProcessor.configuration.translate_func.call(@message[:other_error][:msg]))
            else
              if get(:config, 'min_amount').to_i > 0 and @payment.gross < get(:config, 'min_amount').to_i # payment is to small
                ActiveProcessor.debug("  >ERROR. Payment amount to small.")
                xml.result(@message[:amount_to_small][:code])
                xml.comment(ActiveProcessor.configuration.translate_func.call(@message[:amount_to_small][:msg]) + get(:config, 'min_amount').to_s)
              else
                if get(:config, 'max_amount').to_i > 0 and @payment.gross > get(:config, 'max_amount').to_i #payment is too big
                  ActiveProcessor.debug("  >ERROR. Payment amount to big.")
                  xml.result(@message[:amount_to_big][:code])
                  xml.comment(ActiveProcessor.configuration.translate_func.call(@message[:amount_to_big][:msg]) + get(:config, 'max_amount').to_s)
                else
                  user = User.find(:first, :conditions => ['id = ?', @payment.user_id])
                  if @payment.save
                    confirmation = get(:config, "payment_confirmation")
                    if confirmation.blank? or confirmation == "none"
                      ActiveProcessor.debug("  > waiting_response")
                      @payment.update_attributes({:completed => 1, :shipped_at => params[:date], :pending_reason => "Completed"})
                      Action.add_action_hash(@payment.user_id,
                                             {:action => "payment: #{self.settings['name']}",
                                              :data => "User successfully payed using OSMP",
                                              :data3 => "#{@payment.amount} #{@payment.currency} | tax: #{@payment.gross - @payment.amount} #{@payment.currency} | fee: #{@payment.fee} #{@payment.currency} | sent: #{@payment.gross} #{@payment.currency}",
                                              :data2 => "payment id: #{@payment.id}",
                                              :data4 => "authorization: #{@payment.transaction_id}"
                                             })
                      user.balance += @payment.amount_to_system_currency
                      return user.save
                    else
                      @payment.update_attributes({
                                                     :completed => false,
                                                     :pending_reason => "Waiting for confirmation"
                                                 })
                      ActiveProcessor.log("    >> Payment: #{@payment.id}, Pending_reason: #{@payment.pending_reason.downcase}")
                      ActiveProcessor.log("    >> USER (#{user.id}) waiting for confirmation.")
                      Action.add_action_hash(@payment.user_id,
                                             {:action => "payment: #{settings['name']}",
                                              :data => "User successfully payed, waiting for payment approval #{settings['name']} (OSMP)",
                                              :data3 => "#{@payment.amount} #{@payment.currency} | tax: #{@payment.gross - @payment.amount} #{@payment.currency} | fee: #{@payment.fee} #{@payment.currency} | sent: #{@payment.gross} #{@payment.currency}",
                                              :data2 => "payment id: #{@payment.id}",
                                              :data4 => "Transaction: #{@payment.transaction_id}"
                                             })

                      if get(:config, 'payment_notification').to_i == 1
                        owner = User.find_by_id(user.owner_id)
                        email = Email.find(:first, :conditions => {:name => 'payment_notification_regular', :owner_id => owner.id})

                        variables = Email.email_variables(owner, nil, {:payment => @payment, :payment_notification => OpenStruct.new({}), :payment_type => "OSMP (OSMP)"})
                        EmailsController::send_email(email, Confline.get_value("Email_from", owner.id), [owner], variables)
                      end
                      return true
                    end
                    # OK
                    ActiveProcessor.debug("  >Payment saved.")
                    xml.result(@message[:ok][:code])
                    xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:ok][:code]}"))

                  else
                    # cannot save payment
                    ActiveProcessor.debug("  >ERROR. Payment was not saved.")
                    xml.result(@message[:temporary_error][:code])
                    xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:temporary_error][:code]}"))
                  end
                end
              end
            end
          end
        }
      end

      def valid_settings?
        if !get(:config, 'max_amount').to_f.zero? and !get(:config, 'min_amount').to_f.zero? and get(:config, 'max_amount').to_f < get(:config, 'min_amount').to_f
          @errors.store("min_amount", "gateway_error_min_amount_more_than_max")
        end
      end

      def valid?(params)
        true
      end

      #      def pay(user, ip, params)
      #        ActiveProcessor.debug("Paying OSMP")
      #        transaction = params[:transaction]
      #        payment = Payment.find(:first, :conditions => ["transaction_id = ? AND paymenttype = ?", transaction[:id].to_s, [@engine, @name].join("_")])
      #        if payment
      #          return finish_transaction(payment, params)
      #        else
      #          return false
      #        end
      #      end

      def payment_status(payment)
        return false unless payment
        osmp_transaction(payment.transaction_id) { |xml|
          xml.sum(round_to_cents(payment.gross))
          case payment.pending_reason
            when "Completed" then
              xml.result(@message[:ok][:code])
              xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:ok][:code]}"))
            #                when "Waiting for confirmation"
            #                  xml.result(@message[:not_finished][:code])
            #                  xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:not_finished][:code]}"))
            else
              xml.result(@message[:temporary_error][:code])
              xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:temporary_error][:code]}"))
          end
        }
      end

      def display_name
        "OSMP"
      end

      def error_response(txn_id)
        osmp_transaction(txn_id) { |xml|
          xml.result(@message[:other_error][:code])
          xml.comment(ActiveProcessor.configuration.translate_func.call("osmp_message_#{@message[:other_error][:code]}"))
        }
      end

      def osmp_transaction(tnx_id, &block)
        xml = Builder::XmlMarkup.new
        xml.instruct!(:xml, :version => "1.0")
        xml.response {
          xml.osmp_txn_id(tnx_id)
          yield xml
        }
      end

      private

      #def finish_transaction(payment, params)
      #user = payment.user
      #ActiveProcessor.debug("finish_transaction(#{user.id}, #{payment.id}")
      #        case payment.pending_reason
      #        when "waiting_response"
      #          confirmation = get(:config, "payment_confirmation")
      #          if confirmation.blank? or confirmation == "none"
      #            ActiveProcessor.debug("  > waiting_response")
      #            payment.update_attributes({:completed => 1, :shipped_at => params[:date], :pending_reason => "Completed"})
      #            Action.add_action_hash(payment.user_id,
      #              { :action => "payment: #{self.settings['name']}",
      #                :data => "User successfully payed using OSMP",
      #                :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{payment.fee} #{payment.currency} | sent: #{payment.gross} #{payment.currency}",
      #                :data2 => "payment id: #{payment.id}",
      #                :data4 => "authorization: #{payment.transaction_id}"
      #              })
      #            user.balance += payment.amount_to_system_currency
      #            return user.save
      #          else
      #            payment.update_attributes({
      #                :completed => false,
      #                :pending_reason => "Waiting for confirmation"
      #              })
      #            ActiveProcessor.log("    >> Payment: #{payment.id}, Pending_reason: #{payment.pending_reason.downcase}")
      #            ActiveProcessor.log("    >> USER (#{user.id}) waiting for confirmation.")
      #            Action.add_action_hash(payment.user_id,
      #              { :action => "payment: #{settings['name']}",
      #                :data => "User successfully payed, waiting for payment approval #{settings['name']} (Google Checkout)",
      #                :data3 => "#{payment.amount} #{payment.currency} | tax: #{payment.gross - payment.amount} #{payment.currency} | fee: #{payment.fee} #{payment.currency} | sent: #{payment.gross} #{payment.currency}",
      #                :data2 => "payment id: #{payment.id}",
      #                :data4 => "Transaction: #{payment.transaction_id}"
      #              })
      #
      #            if get(:config, 'payment_notification').to_i == 1
      #              owner = User.find_by_id(user.owner_id)
      #              email = Email.find(:first, :conditions => { :name => 'payment_notification_regular', :owner_id => owner.id })
      #
      #              variables = Email.email_variables(owner, nil, { :payment => payment, :payment_notification => OpenStruct.new({}), :payment_type => "OSMP (OSMP)" })
      #              EmailsController::send_email(email, Confline.get_value("Email_from", owner.id), [owner], variables)
      #            end
      #            return true
      #          end

      #        when "Waiting for confirmation"
      #          ActiveProcessor.debug("  > Waiting for confirmation")
      #          return true
      #        when "Completed"
      #          ActiveProcessor.debug("  > Completed")
      #          return true
      #end
      # end

      def round_to_cents(amount)
        return sprintf("%.2f", amount)
      end
    end
  end
end
