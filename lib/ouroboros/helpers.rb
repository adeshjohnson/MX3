# -*- encoding : utf-8 -*-
module Ouroboros
  module Helpers
    require "digest"

    @@ouronboros_link = "https://secure.pencepay.com/payment/auth.php"

=begin rdoc
 Initializes form for orouboros payment.
 <% ouroboros_form_tag do %> 
 <% end %> 
=end

    def ouroboros_form_tag(options = {}, *parameters_for_url, &block)
      form_tag(@@ouronboros_link, options, *parameters_for_url, &block)
    end

=begin rdoc
 
=end

    def ouroboros_setup(options = {})
      opt = {
      }.merge(options)
      if !(opt[:mch_code] and opt[:amount])
        return("")
      end
      opt[:signature] = Ouroboros::Hash.format_signature(opt.merge(:amount => sprintf("%0.0f", opt[:amount].to_f*100)))

      returning form = [] do
        form << tag(:input, :type => 'hidden', :name => 'mch_code', :value => opt[:mch_code])
        form << tag(:input, :type => 'hidden', :name => 'amount', :value => sprintf("%0.0f", opt[:amount].to_f*100))
        form << tag(:input, :type => 'hidden', :name => 'signature', :value => opt[:signature])
        form << tag(:input, :type => 'hidden', :name => 'order_id', :value => opt[:order_id]) if opt[:order_id]
        form << tag(:input, :type => 'hidden', :name => 'return_url', :value => (opt[:return_url])) if opt[:return_url]
        form << tag(:input, :type => 'hidden', :name => 'accept_url', :value => (opt[:accept_url])) if opt[:accept_url]
        form << tag(:input, :type => 'hidden', :name => 'cancel_url', :value => (opt[:cancel_url])) if opt[:cancel_url]
        form << tag(:input, :type => 'hidden', :name => 'lang', :value => opt[:lang]) if opt[:lang]
        form << tag(:input, :type => 'hidden', :name => 'currency', :value => opt[:currency]) if opt[:currency]
        form << tag(:input, :type => 'hidden', :name => 'customer_name', :value => opt[:customer_name]) if opt[:customer_name]
        form << tag(:input, :type => 'hidden', :name => 'customer_surname', :value => opt[:customer_surname]) if opt[:customer_surname]
        form << tag(:input, :type => 'hidden', :name => 'customer_address ', :value => opt[:customer_address]) if opt[:customer_address]
        form << tag(:input, :type => 'hidden', :name => 'customer_city', :value => opt[:customer_city]) if opt[:customer_city]
        form << tag(:input, :type => 'hidden', :name => 'customer_zip', :value => opt[:customer_zip]) if opt[:customer_zip]
        form << tag(:input, :type => 'hidden', :name => 'customer_country', :value => opt[:customer_country]) if opt[:customer_country]
        form << tag(:input, :type => 'hidden', :name => 'customer_telephone', :value => opt[:customer_telephone]) if opt[:customer_telephone]
        form << tag(:input, :type => 'hidden', :name => 'card_type', :value => opt[:card_type]) if opt[:card_type]
        form << tag(:input, :type => 'hidden', :name => 'description', :value => opt[:description]) if opt[:description]
        form << tag(:input, :type => 'hidden', :name => 'payment_policy', :value => opt[:payment_policy]) if opt[:payment_policy]

        #form << tag(:input, :type => 'hidden', :name => '', :value => opt[:]) if opt[:]
      end.join("\n")
    end
  end
end
