# -*- encoding : utf-8 -*-
# Original Module for Paypal
# Changed for LinkPointCentral by A.Mazunin 08.05.2008
# Some variables are useless.

module Linkpoint

  module Helpers

    def linkpoint_form_tag(url = Linkpoint::Notification.ipn_url)
      form_tag(url, :id=>"lpform")
    end

    def linkpoint_setup(item_number, amount, business, options = {})
      params = {
        :item_name => 'Balance update',
        :no_shipping => 'true',
        :no_note => '1',
        :currency => session[:default_currency],
        :userid => session[:user_id]
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


      # Build the form
      returning button = [] do
        button << tag(:input, :type => 'hidden', :name => 'chargetotal', :id=> 'chargetotal', :value => amount)
        button << tag(:input, :type => 'hidden', :name => 'storename', :id => 'storename', :value => business)
        button << tag(:input, :type => 'hidden', :name => 'tax', :id=> 'tax', :value => options[:tax]) if options[:tax]
        button << tag(:input, :type => 'hidden', :name => 'subtotal', :id=> 'subtotal', :value => options[:subtotal]) if options[:subtotal]
        button << tag(:input, :type => 'hidden', :name => 'baddr1', :id=> 'baddr1', :value => options[:baddr1]) if options[:baddr1]
        button << tag(:input, :type => 'hidden', :name => 'bzip', :id=> 'bzip', :value => options[:bzip]) if options[:bzip]
        button << tag(:input, :type => 'hidden', :name => 'userid', :id => 'userid', :value => options[:userid]) if options[:userid]
        button << tag(:input, :type => 'hidden', :name => 'oid', :id => 'oid', :value => options[:payment]) if options[:payment]

        button << tag(:input, :type => 'hidden', :name => 'responseURL', :id=> 'responseSuccessURL', :value => options[:success_url]) if !options[:success_url].blank?
        button << tag(:input, :type => 'hidden', :name => 'responseFailURL', :id=> 'responseFailURL', :value => options[:fail_url]) if !options[:fail_url].blank?
        button << tag(:input, :type => 'hidden', :name => 'responseURL', :id=> 'responseURL', :value => options[:response_url]) if !options[:response_url].blank?
        button << tag(:input, :type => 'hidden', :name => 'debug',:value => 1)

        button << tag(:input, :type => 'hidden', :name => 'mode', :id=> 'mode', :value => "payonly")
        button << tag(:input, :type => 'hidden', :name => 'txntype', :id=> 'txntype', :value => "sale")
        button << tag(:input, :type => 'hidden', :name => 'shippingbypass', :id=> 'shippingbypass', :value => params[:no_shipping])
        button << tag(:input, :type => 'hidden', :name => 'custom', :id => 'custom', :value => params[:custom]) if params[:custom]
        button << tag(:input, :type => 'hidden', :name => 'currency', :id => 'currency', :value => params[:currency]) if params[:currency]
        
        #additional custom user information

        button << tag(:input, :type => 'hidden', :name => 'user_id', :id => 'user_id', :value => params[:user_id]) if params[:user_id]
        button << tag(:input, :type => 'hidden', :name => 'first_name', :id => 'first_name', :value => params[:first_name]) if params[:first_name]
        button << tag(:input, :type => 'hidden', :name => 'last_name', :id => 'last_name', :value => params[:last_name]) if params[:last_name]
        button << tag(:input, :type => 'hidden', :name => 'username', :id => 'username', :value => params[:username]) if params[:username]

      end.join("\n")
    end

  end
end
