# -*- encoding : utf-8 -*-
module CallshopHelper

#  def tab_for(text, link, html_options = {}, link_options = {})
#    if current_page?(link)
#        (link_options.has_key?(:class)) ? link_options.update({ :class => "active #{html_options.fetch(:class)}" }) : link_options.update({ :class => "active" })
#        content_tag :li, content_tag(:span, text, {:class => "active"}), html_options
#    else
#      content_tag :li, link_to(text, link, link_options), html_options
#    end
#  end

  def tab_for(text, link, html_options = {}, link_options = {})
    text = "<span class='icon'></span>" + text
    link_options[:class] = "active" if current_page?(link)
    content_tag(:li, link_to(text, link, link_options).html_safe, html_options).html_safe
  end

  def javascript_parameters(callshop)
    {
      :id => callshop.id,
      :free_booths => callshop.status[:free_booths],
      :active_calls => callshop.status[:active_calls],
      :refresh_interval => 3000,
      :cache => { :booth_forms => { } },
      :currency => session[:default_currency].to_s,
      :urls => {
        :status_url => url_for({ :controller => "callshop", :action => "show", :id => callshop.id, :format => "json" }),
        :status_url_v2 => url_for({ :controller => "callshop", :action => "show_json", :id => callshop.id, :format => "json" }),
        :reservation_form => url_for({:controller => "callshop", :action => "new", :id => callshop.id }),
        :reservation => url_for({:controller => "callshop", :action => "reserve_booth", :id => callshop.id, :format => "json" }),
        :termination_form => url_for({:controller => "callshop", :action => "free_booth", :id => callshop.id }),
        :termination => url_for({:controller => "callshop", :action => "release_booth", :id => callshop.id }),
        :topup_form => url_for({:controller => "callshop", :action => "topup_booth", :id => callshop.id }),
        :update => url_for({:controller => "callshop", :action => "update", :id => callshop.id, :format => "json" }),
        :top_up => url_for({:controller => "callshop", :action => "topup_update", :id => callshop.id, :format => "json" }),
        :invoice_edit => url_for({:controller => "callshop", :action => "invoice_edit", :id => callshop.id }),
        :invoice_list => url_for({:controller => "callshop", :action => "invoices", :id => callshop.id, :format => "json"}),
        :invoice_print => url_for({:controller => "callshop", :action => "invoice_print", :id => callshop.id}),
        :comment_update => url_for({:controller => "callshop", :action => "comment_update", :id => callshop.id })
      },
      :updater => nil,
      :booths => callshop.status[:booths],
    }
  end

  def javascript_i18n
    {
      :validations => {
        :numerical_and_non_zero => _('Amount_must_be_numerical_and_greater_than_zero')
      },
      :states => {
        :end => _('End'),
        :cancel => _('Cancel')
      },
      :confirm => {
        :question => _('Are_you_sure'),
        :question_terminated_calls => _('Are_you_sure_calls_will_be_interrupted'),
        :yes => _('Yes'),
        :cancel => _('Cancel')
      },
      :adjust_user_balance => _('Adjust_user_balance'),
      :user_types => {
        :postpaid => _('Postpaid'),
        :prepaid => _('Prepaid')
      },
      :misc => {
        :update_comment => _('Update_comment')
      }
    }
  end

  def seconds_to_time(seconds)
    [seconds/3600, seconds/60 % 60, seconds % 60].map{|t| t.to_s.rjust(2, '0')}.join(':')
  end
end
