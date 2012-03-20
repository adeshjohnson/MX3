# -*- encoding : utf-8 -*-
# ActiveProcessor for MOR
# basically just hook implementations

class GatewayEngine
  include ActiveProcessor::GatewayEngine
  include UniversalHelpers

  filter :enabled_by, lambda { |rec, user| Confline.by_params(rec.engine, rec.gateway, "enabled", user) != "1" }

  field :gateways, :form, :currency, { :as => 'select', :position => 90, :html_options => { :value => Currency.get_active.collect{|c| c.name } } }
  field :gateways, :form, :separator1, { :as => 'separator', :position => 100 }
  field :gateways, :form, :without_tax, { :as => 'plain_text', :position => 110, :html_options => { :size => 20, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " in #{g.settings['name'].to_s == 'HSBC' ? g.get(:config, 'default_geteway_currency') : g.settings['default_currency']}" } }
  field :gateways, :form, :with_tax, { :as => 'plain_text', :position => 120, :html_options => { :size => 10, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " in #{g.settings['name'].to_s == 'HSBC' ? g.get(:config, 'default_geteway_currency') : g.settings['default_currency']}" } }
  field :gateways, :form, :separator2, { :as => 'separator', :position => 130 }
  field :gateways, :form, :default_currency, { :as => 'hidden_field', :position => 140, :html_options => { :value => "USD", :id => "default_currency" } }

  field :integrations, :form, :currency, { :as => 'select', :position => 90, :html_options => { :value => Currency.get_active.collect{|c| c.name } } }
  field :integrations, :form, :separator1, { :as => 'separator', :position => 100 }
  field :integrations, :form, :without_tax, { :as => 'plain_text', :position => 110, :html_options => { :size => 20, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " in #{g.settings['default_currency']}" } }
  field :integrations, :form, :with_tax, { :as => 'plain_text', :position => 120, :html_options => { :size => 10, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " in #{g.settings['default_currency']}" } }
  field :integrations, :form, :separator2, { :as => 'separator', :position => 130 }
  field :integrations, :form, :default_currency, { :as => 'hidden_field', :position => 140, :html_options => { :value => "USD", :id => "default_currency" } }

  field :google_checkout, :form, :currency, { :as => 'select', :position => 90, :html_options => { :value => Currency.get_active.collect{|c| c.name } } }
  field :google_checkout, :form, :separator1, { :as => 'separator', :position => 100 }
  field :google_checkout, :form, :without_tax, { :as => 'plain_text', :position => 110, :html_options => { :size => 20, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " in #{g.get(:config, 'default_geteway_currency')}" } }
  field :google_checkout, :form, :with_tax, { :as => 'plain_text', :position => 120, :html_options => { :size => 10, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " in #{g.get(:config, 'default_geteway_currency')}" } }
  field :google_checkout, :form, :separator2, { :as => 'separator', :position => 130 }

  field :ideal, :form, :ideal_bank, { :as => 'ideal_banks', :position => 80}
  field :ideal, :form, :currency, { :as => 'select', :position => 90, :html_options => { :value => Currency.get_active.collect{|c| c.name } } }
  field :ideal, :form, :separator1, { :as => 'separator', :position => 100 }
  field :ideal, :form, :without_tax, { :as => 'plain_text', :position => 110, :html_options => { :size => 20, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " #{g.settings['default_currency']}" } }
  field :ideal, :form, :with_tax, { :as => 'plain_text', :position => 120, :html_options => { :size => 10, :disabled => "disabled", :class => "input" }, :after => lambda{|g| " #{g.settings['default_currency']}" } }
  field :ideal, :form, :separator2, { :as => 'separator', :position => 130 }
  field :ideal, :form, :default_currency, { :as => 'hidden_field', :position => 140, :html_options => { :value => "EUR", :id => "default_currency" } }


  field :ideal, :config, :ideal_acquirer, {:as => 'ideal_acquirer', :position => 2, :html_options => { } }

  # Configure according to conflines
  def on_find
    # find owner
    owner = User.find_by_id(@user).owner_id

    @gateways.each { |engine, gateways|
      gateways.each { |name, gateway|
        gateway.each_field_for(:config) { |field, options|
          if @mode == :config # if we update configuration, we need OUR values
            if gateway.fields["config"][field]["as"].to_s == "certificate_upload"
              gateway.set(:config, { field => Confline.by_params2(engine, name, field, @user) })
            else
              gateway.set(:config, { field => Confline.by_params(engine, name, field, @user) })
            end

          else # if we interact with gateway we need our OWNER's values!
            if gateway.fields["config"][field]["as"].to_s == "certificate_upload"
              gateway.set(:config, { field => Confline.by_params2(engine, name, field, owner) })
            else
              gateway.set(:config, { field => Confline.by_params(engine, name, field, owner) })
            end
          end
        }
      }
    }
  end

  # Update conflines
  def on_after_config_update
    @gateways.each { |engine, gateways|
      gateways.each { |name, gateway|
        if (!gateway.settings['testing']) || (gateway.settings['testing'] && Confline.get_value("test_production_environment") == "true")
          # Put values back to database only if there are no errors
          if gateway.errors.empty?
            gateway.each_field_for(:config) { |field, options|
              if gateway.fields["config"][field]["as"].to_s == "certificate_upload"
                value = gateway.get(:config, field)
                if value and !value.blank?
                  Confline.set_value([engine,name,field].join("_"), "1", @user)
                  Confline.set_value2([engine,name,field].join("_"), value, @user)
                end
              elsif gateway.fields["config"][field]["as"].to_s == "gateway_logo"
                Confline.set_value([engine,name,field].join("_"), gateway.get(:config, field), @user) unless gateway.get(:config, field).blank?
              else
                Confline.set_value([engine,name,field].join("_"), gateway.get(:config, field), @user)
              end
            }
          end
        end
      }
    }
  end

  def on_after_gateways_payment_validation
    gateway, params = query, @params[@engine][@gateway]
    payment = Payment.new do |p|
      p.user_id = @user
      p.paymenttype = "#{gateway.engine}_#{gateway.name}"
      p.amount = params['amount']
      p.currency = params['currency']
      p.pending_reason = "Unnotified payment"
      p.owner_id = User.find_by_id(@user).owner_id
      p.completed = 0
      p.first_name = params['first_name']
      p.last_name = params['last_name']
      p.date_added = Time.now
    end
    payment.save
    @transaction = payment.id

    # let's log the payment attempt
    Action.add_action_hash(@user,
      { :action => "payment: #{gateway.settings['name']}",
        :data => "User tried to pay using #{gateway.settings['name']} (#{gateway.engine})",
        :data2 => "payment id: #{payment.id}",
        :data3 => "#{payment.amount} #{payment.currency}"
      })
  end

  def on_after_gateways_successful_payment
    gateway = query

    payment = Payment.find(:first, :conditions => { :id => @transaction })
    user = User.find_by_id(payment.user_id)

    confirmation = gateway.get(:config, "payment_confirmation")

    if confirmation.blank? or confirmation == "none"
      payment.update_attributes({
          :tax => gateway.payment.orig_tax,
          :gross => gateway.payment.orig_with_tax,
          :completed => 1,
          :shipped_at => Time.now,
          :pending_reason => "Completed",
          :payment_hash => gateway.payment.response.authorization,
          :transaction_id => gateway.payment.response.params["transaction_id"].to_i
        })

      Action.add_action_hash(@user,
        { :action => "payment: #{gateway.settings['name']}",
          :data => "User successfully payed using #{gateway.settings['name']} (#{gateway.engine})",
          :data3 => "#{gateway.payment.orig_amount} #{gateway.payment.currency} | with tax: #{gateway.payment.orig_with_tax} #{gateway.payment.currency} | sent: #{gateway.payment.amount/100.0} #{gateway.settings['default_currency']}",
          :data2 => "payment id: #{payment.id}",
          :data4 => "authorization: #{gateway.payment.response.authorization}"
        })

      user.balance += gateway.payment.orig_amount.to_f * ActiveProcessor.configuration.currency_exchange.call(gateway.payment.currency, user.currency.name)
      user.save
    else
      payment.update_attributes({
          :tax => gateway.payment.orig_tax,
          :gross => gateway.payment.orig_with_tax,
          :completed => 0,
          :pending_reason => "Waiting for confirmation",
          :payment_hash => gateway.payment.response.authorization
        })

      Action.add_action_hash(@user,
        { :action => "payment: #{gateway.settings['name']}",
          :data => "User successfully payed, waiting for payment approval #{gateway.settings['name']} (#{gateway.engine})",
          :data3 => "#{gateway.payment.orig_amount} #{gateway.payment.currency} | with tax: #{gateway.payment.orig_with_tax} #{gateway.payment.currency} | sent: #{gateway.payment.amount/100.0} #{gateway.settings['default_currency']}",
          :data2 => "payment id: #{payment.id}",
          :data4 => "authorization: #{gateway.payment.response.authorization}"
        })

      if Confline.get_value("Email_Sending_Enabled", 0).to_i == 1
        if gateway.get(:config, 'payment_notification').to_i == 1
          email = Email.find(:first, :conditions => { :name => 'payment_notification_regular', :owner_id => user.owner_id })
          owner = User.find_by_id(user.owner_id)

          variables = Email.email_variables(owner, nil, { :payment => payment, :payment_notification => OpenStruct.new({ :business => payment.email }), :payment_type => "#{gateway.name} (#{gateway.engine})" })
          Email.send_email(email, [owner], Confline.get_value("Email_from", owner.id), 'send_email', {:assigns => variables, :owner => variables[:owner]})
          MorLog.my_debug('confirmation email sent')
        end
      end
    end
  end

  def on_after_gateways_failed_payment
    gateway = query
    payment = Payment.find(:first, :conditions => { :id => @transaction })
    user = User.find_by_id(payment.user_id)
  
    if !gateway.payment.response.blank?
      payment.update_attributes({
          :completed => 0,
          :shipped_at => Time.now,
          :pending_reason => "Failed",
          :payment_hash => gateway.payment.response.message ,
          :transaction_id => gateway.payment.response.params["transaction_id"].to_i
        })

      Action.add_action_hash(@user,
        { :action => "payment: #{gateway.settings['name']}",
          :data => "User failed to pay using #{gateway.settings['name']} (#{gateway.engine})",
          :data3 => "#{gateway.payment.orig_amount} #{gateway.payment.currency} | with tax: #{gateway.payment.orig_with_tax} #{gateway.payment.currency} | sent: #{gateway.payment.amount/100.0} #{gateway.settings['default_currency']}",
          :data2 => "payment id: #{payment.id}",
          :data4 => "reason: #{gateway.payment.response.message}"
        })
    else
      payment.update_attributes({
          :completed => 0,
          :shipped_at => Time.now,
          :pending_reason => "Failed",
          :payment_hash => "" ,
          :transaction_id => 0
        })

      Action.add_action_hash(@user,
        { :action => "payment: #{gateway.settings['name']}",
          :data => "User failed to pay using #{gateway.settings['name']} (#{gateway.engine})",
          :data3 => "#{gateway.payment.orig_amount} #{gateway.payment.currency} | with tax: #{gateway.payment.orig_with_tax} #{gateway.payment.currency} | sent: #{gateway.payment.amount/100.0} #{gateway.settings['default_currency']}",
          :data2 => "payment id: #{payment.id}",
          :data4 => ""
        })
    end
  end

  def on_after_integrations_successful_payment
    gateway, params = query, @params[@engine][@gateway]

    payment = Payment.new do |p|
      p.user_id = @user
      p.paymenttype = "#{gateway.engine}_#{gateway.name}"
      p.tax = gateway.payment.orig_tax
      p.gross = gateway.payment.orig_with_tax
      p.amount = gateway.payment.orig_amount
      p.currency = params['currency']
      p.pending_reason = "Unnotified payment"
      p.owner_id = User.find_by_id(@user).owner_id
      p.completed = 0
      p.date_added = Time.now
    end
    payment.save

    gateway.payment.transaction = payment.id

    # let's log the payment attempt
    Action.add_action_hash(@user,
      { :action => "payment: #{gateway.settings['name']}",
        :data => "User tried to pay using #{gateway.settings['name']} (#{gateway.engine})",
        :data2 => "payment id: #{payment.id}",
        :data3 => "#{payment.amount} #{payment.currency}"
      })
  end

  def on_after_google_checkout_successful_payment
    gateway, params = query, @params[@engine][@gateway]
    gw_payment = gateway.payment
    payment = Payment.new do |p|
      p.user_id = @user
      p.paymenttype = gateway.name
      p.tax =         round_to_cents(gw_payment.tax.to_i/100.0)
      p.gross =       round_to_cents(gw_payment.amount.to_i/100.0)
      p.amount =      round_to_cents(gw_payment.money.to_i/100.0)
      p.currency =    gw_payment.currency
      p.pending_reason = "Unnotified payment"
      p.owner_id = User.find_by_id(@user).owner_id
      p.completed = 0
      p.date_added = Time.now
    end
    payment.save

    gateway.payment.transaction = payment.id

    # let's log the payment attempt
    Action.add_action_hash(@user,
      { :action => "payment: #{gateway.settings['name']}",
        :data => "User tried to pay using #{gateway.settings['name']} (#{gateway.engine})",
        :data2 => "payment id: #{payment.id}",
        :data3 => "#{payment.amount} #{payment.currency}"
      })

    checkout_command = gateway.instance.create_checkout_command
    # Adding an item to shopping cart
    checkout_command.shopping_cart.create_item do |item|
      item.id = gateway.payment.transaction.to_i
      item.name = gateway.get(:config, :payment_message).to_s
      item.unit_price = Money.new((round_to_cents(gateway.payment.amount.to_i/100.0)*100).to_i, gateway.payment.currency)
      item.quantity = 1
    end
    gateway.response = checkout_command.send_to_google_checkout
  end

end
