# Original Module for Paypal
# Rewritten for Webmoney by Uknown
# Changed by A.Mazunin 08.05.2008
# Some variables are useless.

module WebMoney
  module Helpers

    def webmoney_setup(payment_id, amount, purse, options = {})
      params = {
        :item_name => 'Balance update',
        :no_shipping => '1',
        :no_note => '1',
        :currency => session[:default_currency]
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
        button << tag(:input, :type => 'hidden', :name => 'LMI_PAYEE_PURSE', :value => purse)
        button << tag(:input, :type => 'hidden', :name => 'LMI_PAYMENT_AMOUNT', :value => amount)
        button << tag(:input, :type => 'hidden', :name => 'LMI_PAYMENT_NO', :value => payment_id)
        button << tag(:input, :type => 'hidden', :name => 'LMI_PAYMENT_DESC', :value => params[:description]) if params[:description]
        # Required only for testing
        button << tag(:input, :type => 'hidden', :name => 'LMI_SIM_MODE', :value => params[:test_sim_mode]) if params[:test_mode]
        button << tag(:input, :type => 'hidden', :name => 'LMI_RESULT_URL', :value => params[:result_url]) if params[:result_url]
        button << tag(:input, :type => 'hidden', :name => 'LMI_RESULT_METHOD', :value => '1') if params[:result_url]
        button << tag(:input, :type => 'hidden', :name => 'LMI_SUCCESS_URL', :value => params[:success_url]) if params[:success_url]
        button << tag(:input, :type => 'hidden', :name => 'LMI_SUCCESS_METHOD', :value => "1") if params[:success_url]
        button << tag(:input, :type => 'hidden', :name => 'LMI_FAIL_URL', :value => params[:fail_url]) if params[:fail_url]
        button << tag(:input, :type => 'hidden', :name => 'LMI_FAIL_METHOD', :value => '1') if params[:fail_url]
        button << tag(:input, :type => 'hidden', :name => 'gross', :value => params[:gross]) if params[:gross]
        button << tag(:input, :type => 'hidden', :name => 'user', :value => params[:user]) if params[:user]
      end.join("\n")
    end

  end
end