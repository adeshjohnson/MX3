# -*- encoding : utf-8 -*-
module ActiveProcessor
  class FormHelper
    extend ActionView::Helpers::TagHelper
    extend ActionView::Helpers::FormTagHelper
    extend ActionView::Helpers::FormHelper
    extend ActionView::Helpers::FormOptionsHelper
    extend ActionView::Helpers::CaptureHelper
    #extend ActionView::Helpers::PrototypeHelper
    #extend ActionView::Helpers::JavaScriptHelper

    def self.label(engine, gateway, name, options = {})
      if gateway == 'authorize_net' and (name == 'first_name' or name == 'last_name')
        if name == 'first_name'
          content_tag :label, self._("a_first_name"), {'for' => field_id(engine.to_s, gateway.to_s, name)} unless name =~ /separator|default_currency/
        elsif name == 'last_name'
          content_tag :label, self._("a_last_name"), {'for' => field_id(engine.to_s, gateway.to_s, name)} unless name =~ /separator|default_currency/
        end
      else
        content_tag :label, self._(sanitize_to_id(name)), {'for' => field_id(engine.to_s, gateway.to_s, name)} unless name =~ /separator|default_currency/
      end
    end

    def self.input(gateway, origname, options)
      html, id, field_name = "", field_id(gateway.engine, gateway.name, origname), field_name(gateway.engine, gateway.name, origname)
      options ||= {}
      html_options = options.has_key?('html_options') ? options['html_options'] : {}
      html_options.merge!({'id' => id})
      if html_options.has_key?('class')
        html_options.merge!({'class' => "#{html_options['class']} #{gateway.engine}_#{options['as']}"})
      else
        html_options.merge!({'class' => "#{gateway.engine}_#{options['as']}"})
      end
      value = html_options.has_key?('value') ? html_options['value'] : options['value']
      if field_name.include?('billing_address') and !field_name.include?('billing_address_enabled')
        value = billing_value(origname, options[:current_user])
      end

      if ['gateways[gateways][authorize_net][first_name]', 'gateways[gateways][authorize_net][last_name]', 'gateways[gateways][paypal][first_name]', 'gateways[gateways][paypal][last_name]'].include?(field_name)
        value = billing_value(origname, options[:current_user])
      end

      if options.has_key?('before')
        html << options['before'].call(gateway) if options['before'].is_a?(Proc)
        html << options['before'] if options['before'].is_a?(String)
      end

      case options['as']
        when "input_field"
          html << text_field_tag(field_name, value, html_options)
        when "input_field_custom"
          html << Web_URL + "/"
          html << text_field_tag(field_name, value, html_options)
        when "password_field"
          html << password_field_tag(field_name, value, html_options)
        when "text"
          html << text_area_tag(field_name, value, html_options)
        when "check_box"
          html << check_box_tag(field_name, "1", (value == "1") ? true : false, html_options.except('value'))
          html << hidden_field_tag(field_name, "0", html_options.merge(:id => "#{id}_hidden").except('value'))
          if options.has_key?('disables')
            html << self.observe_field(id, {:function => "disable_field('#{id}' ,'#{field_id(gateway.engine, gateway.name, options['disables'])}');"})
            html << "<script type='text/javascript'>\n  Event.observe(window, 'load', function() {disable_field('#{id}' ,'#{field_id(gateway.engine, gateway.name, options['disables'])}');});\n</script>"
          end
        when "check_box_redirect"
          html << check_box_tag(field_name, "1", (value == "1") ? true : false, html_options.except('value'))
          html << hidden_field_tag(field_name, "0", html_options.merge(:id => "#{id}_hidden").except('value'))
          if options.has_key?('disables')
            html << observe_field(id, {:function => "disable_field('#{id}' ,'#{field_id(gateway.engine, gateway.name, options['disables'])}');"})
            html << "<script type='text/javascript'>\n  Event.observe(window, 'load', function() {disable_field('#{id}' ,'#{field_id(gateway.engine, gateway.name, options['disables'])}');});\n</script>"
          end
        when "currency_select"
          html << select_tag(field_name, options_for_select(Currency.get_active.collect { |c| [c.name, c.name] }, value), html_options)
        when "select"
          if origname == 'currency'
            html << select_tag(field_name, options_for_select(Currency.get_active.collect { |c| [c.name, c.name] }, Currency.find(1).name), html_options)
          else
            html << select_tag(field_name, options_for_select(value), html_options)
          end
        when "hidden_field"
          html << hidden_field_tag(field_name, value, html_options)
        # special fields
        when "plain_text"
          html << "<strong id=\"#{origname}_field\">#{value}</strong>"
        when "separator"
          html << "<br />"
        when "card_select"
          html << select_tag(field_name, options_for_select(gateway.supported_cardtypes.collect { |c| c.to_s.humanize }, value), html_options)
        when "year_select"
          html << select_tag(field_name, options_for_select((Time.now().year..(Time.now().year+10)).collect { |c| c.to_s.humanize }, value), html_options)
        when "month_select"
          html << select_tag(field_name, options_for_select((1..12).collect { |c| (c < 10 ? '0' :'') + c.to_s.humanize }, value), html_options)
        when "payment_confirmation"
          html << select_tag(field_name, options_for_select([[_('not_required'), 'none'], [_('required_for_suspicious_payments'), 'suspicious'], [_('required_for_all_payments'), 'all']], value), html_options)
        when "payment_confirmation_lite"
          html << select_tag(field_name, options_for_select([[_('not_required'), 'none'], [_('required_for_all_payments'), 'all']], value), html_options)
        when "tax_in_amount_select"
          html << select_tag(field_name, options_for_select([[_('Included'), 'included'], [_('Excluded'), 'excluded']], value), html_options)
        when "gateway_logo"
          html << file_field_tag(field_name, html_options)
        when "ideal_banks"
          if gateway.kind_of?(ActiveProcessor::PaymentEngines::Ideal)
            begin
              issuers = gateway.get_issuers
              if issuers.size == 0
                html << _("Cannot_get_issuers")
              else
                sorted_issuers = issuers.sort_by { |issuer| issuer[:name] }
                html << select('purchase', 'issuer_id', sorted_issuers.map { |issuer| [issuer[:name], issuer[:id]] })
              end
            rescue
              html << _("Cannot_get_issuers")
            end
          end
        when "ideal_acquirer"
          html << select_tag(field_name, options_for_select(ActiveProcessor::PaymentEngines::Ideal.acquirers.map { |name, value| [name, name] }, value), html_options)
        when "certificate_upload"
          html << file_field_tag(field_name)
          html << "&nbsp;"
          unless value.blank?
            html << tag(:img, {:src => Web_Dir + "/images/icons/check.png", :title => _("Certificate_Exists")})
          else
            html << tag(:img, {:src => Web_Dir + "/images/icons/cross.png", :title => _("Certificate_not_exists")})
          end
        else
          html << "unrecognized field"
      end

      if options.has_key?('after')
        html << options['after'].call(gateway) if options['after'].is_a?(Proc)
        html << options['after'] if options['after'].is_a?(String)
      end

      html.html_safe
    end

    def self._(name)
      ActiveProcessor.configuration.translate_func.call("gateway_#{name}")
    end

    def self.field_id(engine, gateway, name)
      [sanitize_to_id(engine), "_", sanitize_to_id(gateway), "_", sanitize_to_id(name)].join
    end

    def self.sanitize_to_id(name)
      name.to_s.gsub(']', '').gsub(/[^-a-zA-Z0-9:.]/, "_")
    end

    def self.field_name(engine, gateway, name)
      if name.match(/^(.*)\[(.*)\]$/)
        ["gateways[", engine, "][", gateway, "][", $1, "][", $2, "]"].join
      else
        ["gateways[", engine, "][", gateway, "][", name, "]"].join
      end
    end

    def self.display_billing(gateway, owner, field)
      out = true
      out = false if Confline.get_value('gateways_authorize_net_billing_address_enabled', owner).to_i == 0 and gateway == 'authorize_net' and field.include?('billing_address')
      out
    end

    def self.display_blocks?(name, gtw)
      out= ''
      case name
        when 'first_name'
          out = "<tr><td colspan='2' class='bottom_border'>#{_('Credit_card_details')}</td></tr>"
        when 'billing_address[first_name]', 'billing_address[name]'
          out = "<tr><td colspan='2' class='bottom_border'>#{_('Billing_address')}</td></tr>"
        when 'billing_address[company]'
          out = "<tr><td colspan='2' class='bottom_border'>#{_('Billing_address')}</td></tr>"
        when 'amount'
          out ="<tr><td colspan='2' class='bottom_border'>#{_('Purchase_Details')}</td></tr>"
      end
      return out.html_safe
    end

    def self.billing_value(field, user)
      out = ''
      case field
        when 'billing_address[first_name]', 'billing_address[name]', 'first_name'
          out = user.first_name
        when 'billing_address[last_name]', 'last_name'
          out = user.last_name
        when 'billing_address[company]'
          out = user.clientid
        when 'billing_address[address]', 'billing_address[address1]'
          out = user.address.address
        when 'billing_address[city]'
          out = user.address.city
        when 'billing_address[state]'
          out = user.address.state
        when 'billing_address[zip]'
          out = user.address.postcode
        when 'billing_address[country]'
          out = user.address.direction.name
        when 'billing_address[phone]'
          out = user.address.phone
        when 'billing_address[fax]'
          out = user.address.fax
        when 'billing_address[email]'
          out = user.address.email
      end
      out
    end

    def self.observe_field(field_id, options = {})
            if options[:frequency] && options[:frequency] > 0
                       self.build_observer('Form.Element.Observer', field_id, options)
            else
                               self.build_observer('Form.Element.EventObserver', field_id, options)
            end
    end

    def self.build_observer(klass, name, options = {})
      if options[:with] && (options[:with] !~ /[\{=(.]/)
        options[:with] = "'#{options[:with]}=' + encodeURIComponent(value)"
      else
        options[:with] ||= 'value' unless options[:function]
      end

      callback = options[:function] || remote_function(options)
      javascript = "<script type='text/javascript'> new #{klass}('#{name}', "
      javascript << "#{options[:frequency]}, " if options[:frequency]
      javascript << "function(element, value) {"
      javascript << "#{callback}}"
      javascript << ") </script>"
      javascript.html_safe
    end

  end
end
