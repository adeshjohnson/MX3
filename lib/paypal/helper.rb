module Paypal 
  # This is a collection of helpers which aid in the creation of paypal buttons 
  # 
  # Example:
  #
  #    <%= form_tag Paypal::Notification.ipn_url %>
  #    
  #      <%= paypal_setup "Item 500", Money.us_dollar(50000), "bob@bigbusiness.com" %>  
  #      Please press here to pay $500US using paypal. <%= submit_tag %>
  #    
  #    <% end_form_tag %> 
  #
  # For this to work you have to include these methods as helpers in your rails application.
  # One way is to add "include Paypal::Helpers" in your application_helper.rb
  # See Paypal::Notification for information on how to catch payment events. 
  module Helpers
    
    # Convenience helper. Can replace <%= form_tag Paypal::Notification.ipn_url %>
    # takes optional url parameter, default is Paypal::Notification.ipn_url
    def paypal_form_tag(url = Paypal::Notification.ipn_url)
      form_tag(url)
    end

    # This helper creates the hidden form data which is needed for a paypal purchase. 
    # 
    # * <tt>item_number</tt> -- The first parameter is the item number. This is for your personal organization and can 
    #   be arbitrary. Paypal will sent the item number back with the IPN so its a great place to 
    #   store a user ID or a order ID or something like  this. 
    #
    # * <tt>amount</tt> -- should be a parameter of type Money ( see http://leetsoft.com/api/money ) but can also 
    #   be a string of type "50.00" for 50$. If you use the string syntax make sure you set the current 
    #   currency as part of the options hash. The default is USD
    #
    # * <tt>business</tt> -- This is your paypal account name ( a email ). This needs to be a valid paypal business account.
    #
    # The last parameter is a options hash. You can override several things:
    #
    # * <tt>:notify_url</tt> -- default is nil. Supply an url which paypal will send its IPN notification to once a 
    #   purchase is made, canceled or any other status changes occure. 
    # * <tt>:return_url</tt> -- default is nil. If provided paypal will redirect a user back to this url after a 
    #   successful purchase. Useful for a kind of thankyou page. 
    # * <tt>:cancel_url</tt> -- default is nil. If provided paypal will redirect a user back to this url when
    #   the user cancels the purchase.
    # * <tt>:item_name</tt> -- default is 'Store purchase'. This is the name of the purchase which will be displayed
    #   on the paypal page. 
    # * <tt>:no_shipping</tt> -- default is '1'. By default we tell paypal that no shipping is required. Usually
    #   the shipping address should be collected in our application, not by paypal. 
    # * <tt>:no_note</tt> -- default is '1'
    # * <tt>:currency</tt> -- default is 'USD'
    # * <tt>:tax</tt> -- the tax for the store purchase. Same format as the amount parameter but optional
    # * <tt>:invoice</tt> -- Unique invoice number. User will never see this. optional
    # * <tt>:custom</tt> -- Custom field. User will never see this. optional
    # * <tt>:no_utf8</tt> -- if set to false this prevents the charset = utf-8 hidden field. (I don't know why you 
    #   would want to disable this... )
    #
    # Examples:
    #   
    #   <%= paypal_setup @order.id, Money.us_dollar(50000), "bob@bigbusiness.com" %>  
    #   <%= paypal_setup @order.id, '50.00', "bob@bigbusiness.com", :currency => 'USD' %>  
    #   <%= paypal_setup @order.id, '50.00', "bob@bigbusiness.com", :currency => 'USD', :notify_url => url_for(:only_path => false, :action => 'paypal_ipn') %>  
    #   <%= paypal_setup @order.id, Money.ca_dollar(50000), "bob@bigbusiness.com", :item_name => 'Snowdevil shop purchase', :return_url => paypal_return_url, :cancel_url => paypal_cancel_url, :notify_url => paypal_ipn_url  %>  
    # 
    def paypal_setup(item_number, amount, business, options = {})

      params = {
        :item_name => 'Balance update',
        :no_shipping => '1',
        :no_note => '1',
        :currency => session[:default_currency],
#       :return_url => nil
      }.merge(options)

      # We accept both, strings and money objects as amount    
      amount = amount.cents.to_f / 100.0 if amount.respond_to?(:cents)
      amount = sprintf("%.2f", amount)
      
      # same for tax
      
      if params[:tax]
        tax = params[:tax]
        tax = tax.cents.to_f / 100.0 if tax.respond_to?(:cents)
        tax = sprintf("%.2f", tax)
      end

#    params[:currency] = "GBP";


#	amount="0.01" #testing
      
      # Build the form 
      returning button = [] do
        button << tag(:input, :type => 'hidden', :name => 'cmd', :value => "_xclick")
        button << tag(:input, :type => 'hidden', :name => 'quantity', :value => 1)
        button << tag(:input, :type => 'hidden', :name => 'business', :value => business)
        button << tag(:input, :type => 'hidden', :name => 'amount', :value => amount)
        button << tag(:input, :type => 'hidden', :name => 'item_number', :value => item_number)
        button << tag(:input, :type => 'hidden', :name => 'item_name', :value => params[:item_name])
        button << tag(:input, :type => 'hidden', :name => 'no_shipping', :value => params[:no_shipping])
        button << tag(:input, :type => 'hidden', :name => 'no_note', :value => params[:no_note])
        button << tag(:input, :type => 'hidden', :name => 'return', :value => params[:return_url]) if params[:return_url]
        button << tag(:input, :type => 'hidden', :name => 'notify_url', :value => params[:notify_url]) if params[:notify_url]
        button << tag(:input, :type => 'hidden', :name => 'cancel_return', :value => params[:cancel_url]) if params[:cancel_url]
        button << tag(:input, :type => 'hidden', :name => 'tax', :value => tax) if params[:tax]
        button << tag(:input, :type => 'hidden', :name => 'invoice', :value => params[:invoice]) if params[:invoice]
        button << tag(:input, :type => 'hidden', :name => 'custom', :value => params[:custom]) if params[:custom]
        button << tag(:input, :type => 'hidden', :name => 'currency', :value => params[:currency]) if params[:currency]

        # if amount was a object of type money or something compatible we will use its currency, 
        button << tag(:input, :type => 'hidden', :name => 'currency_code', :value => amount.respond_to?(:currency) ? amount.currency : params[:currency])
        button << tag(:input, :type => 'hidden', :name => 'charset', :value => 'utf-8') unless params[:no_utf8]
      end.join("\n")
    end
    
  end
end