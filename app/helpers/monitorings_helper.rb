# -*- encoding : utf-8 -*-
module MonitoringsHelper

  def activity_indicator(value)
    (value) ? b_check : b_cross
  end

  def block_user(monitoring)
    monitoring.block ? b_check : b_cross
  end

  def send_admin_email(monitoring)
    monitoring.email ? b_check : b_cross
  end

  def format_period(period)
    if period.blank? or period < 60
      "30 #{_("minutes")}"
    elsif period >= 60 and period < 1380
      "#{period / 60} #{_("Hour_hours")}"
    else
      "#{period / 60 / 24} #{_("Day_days")}"
    end
  end

  def strong_username_if_self(user1, user2)
    if user1 == user2
      content_tag(:strong, user1.username)
    else
      user1.username
    end
  end

=begin
  Output user friendly information about monitoring type
=end
  def format_monitoring_type(type)
    if type == 'bellow'
      _('Drops_bellow')
    elsif type == 'above'
      _('Increases_more')
    elsif type == 'simultaneous'
      _('Simultaneous_calls')
    else
      _('Specify_how_to_format_monitoring_type') 
    end
  end

  def monitoring_values(monitoring, opts = {})
    period_in_past = case monitoring.period_in_past_type
    when "minutes"
      _("Thirty_minutes")
    when "hours"
      "#{monitoring.period_in_past / 60} #{_('Hour_hours')}"
    when "days"
      "#{monitoring.period_in_past / 1440} #{_('Day_days')}"
    end

    { :sent => (monitoring.send_email?) ? _("Will_be_sent") : _("Will_not_be_sent"),
      :blocked => (monitoring.block_user?) ? _("Will_be_blocked") : _("Will_not_be_blocked"),
      :period => period_in_past,
      :amount => "#{monitoring.amount || 0} #{Currency.get_default.name}",
      :users => _("all_users").downcase,
      :monitoringamount => (monitoring.monitoring_type == 'above' ? _('higher') : _('less'))
    }.merge(opts).to_json
  end

  def monitoring_messages
    { :will_be_blocked => _('Will_be_blocked'), :will_not_be_blocked => _('Will_not_be_blocked'), 
      :will_be_sent => _('Will_be_sent'), :will_not_be_sent => _('Will_not_be_sent'),
      :thirty_minutes => _('Thirty_minutes'), :days => _('Day_days').downcase, :hours => _('Hour_hours').downcase,
      :all => _('all_users').downcase, :prepaid => _('Prepaid').downcase + " " + _('users').downcase,
      :postpaid => _('Postpaid_users').downcase, :single => _('user') + ': ',
      :bellow_monitoringamount => _('less').downcase, :above_monitoringamount => _('higher').downcase
    }.to_json
  end

  def monitoring_messages_users
    out =Hash.new()
    User.find_all_for_select(correct_owner_id).each{|u| out[u.id] = "<strong>"+nice_user(u)+"</strong>"}
    out.to_json
  end

end
