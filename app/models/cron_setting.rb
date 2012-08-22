# -*- encoding : utf-8 -*-
class CronSetting < ActiveRecord::Base
  belongs_to :user
  has_many :cron_actions

  before_save :cron_s_before_save
  after_create :cron_after_create
  after_update :cron_after_update

  def cron_s_before_save
    if self.action == "change_tariff"
      self.target_class = 'User'
      self.to_target_class = 'Tariff'
      self.user_id = User.current.id
    elsif self.action == "change_provider_tariff"
      self.target_class = 'Provider'
      self.to_target_class = 'Provider_Tariff'
      self.user_id = User.current.id
    end

    if (valid_from > valid_till and next_run_time > valid_till or valid_till.to_time < Time.now) and repeat_forever.to_i == 0
      errors.add(:period, _("Please_enter_correct_period"))
      return false
    end
    if periodic_type.to_i == 0 and valid_from.to_time < Time.now
      errors.add(:period, _("Please_enter_correct_period"))
      return false
    end
  end

  def CronSetting.cron_settings_actions
    [[_('change_tariff'), 'change_tariff'], [_('change_provider_tariff'), 'change_provider_tariff']]
  end

  def CronSetting.cron_settings_periodic_types
    [[_('One_time'), 0], [_('Yearly'), 1], [_('Monthly'), 2], [_('Weekly'), 3], [_('Work_days'), 4], [_('Free_days'), 5], [_('Daily'), 6]]
  end

  def CronSetting.cron_settings_priority
    [[_('high'), 10], [_('medium'), 20], [_('low'), 30]]
  end

  def CronSetting.cron_settings_target_class
    [[_('User'), 'User'], [_('Provider'), 'Provider']]
  end


  def target
    case target_class
      when 'User'
        User.find(:first, :conditions => {:id => target_id})
      when 'Provider'
        Provider.find(:first, :conditions => {:id => provider_target_id})
    end
  end

  def cron_after_create
    CronAction.create({:cron_setting_id => id, :run_at => self.next_run_time})
  end

  def cron_after_update
    CronAction.delete_all(:cron_setting_id => id)
    CronAction.create({:cron_setting_id => id, :run_at => self.next_run_time})
  end

  def next_run_time(tim=nil)
    if tim
      if tim.class.to_s.include?('Time')
        time = tim
      else
        time = tim.to_time
      end

    else
      time = valid_from.to_time
    end

    case periodic_type
      when 0
        time = time.to_s.to_time
      when 1
        time = time.to_s.to_time + 1.year
      when 2
        time = time.to_s.to_time + 1.month
      when 3
        time = time.to_s.to_time + 1.week
      when 4
        z = time.to_s.to_time + 1.day
        if weekend? z
          time = next_monday(time.to_s.to_time)
        else
          time = time.to_s.to_time + 1.day
        end
      when 5
        z = time.to_s.to_time + 1.day
        unless weekend? z
          time = next_saturday(time.to_s.to_time)
        else
          time = time.to_s.to_time + 1.day
        end
      when 6
        time = time.to_s.to_time + 1.day
    end
    if time < Time.now
      time = next_run_time(time)
    end
    time
  end

=begin
    Check whether given date is weekend or not

    *Params*
        date - datetime or time instance

    *Returns*
        true if given date is weekday else returns false
=end
  def weekend?(date)
    [6,0].include? date.wday
  end

=begin
  We need to get date of next monday
=end
  def next_monday(date)
    date += ((1-date.wday) % 7).days
  end

=begin
  We need to get date of next saturday, that is closest day of upcoming weekend
=end
  def next_saturday(date)
    date += ((6-date.wday) % 7).days
  end
end
