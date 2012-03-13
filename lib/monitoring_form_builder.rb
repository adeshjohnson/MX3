# -*- encoding : utf-8 -*-
class MonitoringFormBuilder < ActionView::Helpers::FormBuilder
  def period_select(method, options = {})
    result = ""
    radio_value, value = @object.send("#{method}_type"), @object.send(method).to_i

    for period in ["minutes", "hours", "days"]
      result << radio_button("#{method}_type", period, :class => "period_select")
      
      case period
        when "minutes":
          result << "30 #{_('minutes')}"
          result << @template.hidden_field(@object_name, method, :value => "30", :class => "period_minutes")
        when "hours":
          result << @template.select(@object_name, method, (1..23).collect{ |hour| [hour, hour*60] }, {}, :class => "period_hours", :id => "monitoring_period_in_past_hours") 
          result << " #{_('Hour_hours')}"
        when "days":
          result << @template.select(@object_name, method, (1..31).collect{ |day| [day, day*24*60] }, {}, :class => "period_days", :id => "monitoring_period_in_past_days") 
          result << " #{_('Day_days')}"
      end
      result << "<br/>"
    end

    result
  end
end
