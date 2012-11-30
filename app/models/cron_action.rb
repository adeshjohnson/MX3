# -*- encoding : utf-8 -*-
class CronAction < ActiveRecord::Base
  belongs_to :cron_setting

  before_destroy :cron_before_destroy


  def cron_before_destroy
    self.create_new
  end

  def create_new
    logger.fatal self.to_yaml
    time = self.next_run_time
    if time < cron_setting.valid_till and cron_setting.periodic_type != 0 or cron_setting.repeat_forever == 1
      CronAction.create({:cron_setting_id => cron_setting.id, :run_at => time})
    end

  end

=begin
  we should chop off someone's hands for coding like that..
  but there's explanation what periodic_type magic numbers mean:
    0 - runs only once(how ilogical it is to ask about NEXT RUN if action can be run only once??!)
    1 - runs once every year
    2 - runs once every month
    3 - runs once every week
    4 - runs every work day
    5 - runs every free day
    6 - runs once every day

   Note that this method will give you an answer no matter whether it should be run next time or not,
   because cron job can have it's time limit.
=end
  def next_run_time
    time = run_at.to_time
    case cron_setting.periodic_type
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


  def CronAction.do_jobs
    actions = CronAction.find(:all, :conditions => ['run_at < ? AND failed_at IS NULL', Time.now().to_s(:db)], :include => [:cron_setting])
    MorLog.my_debug("Cron Action Jobs, found : (#{actions.size.to_i})", 1) if actions
    for a in actions
      if a.cron_setting
        MorLog.my_debug("**** Action : #{a.id} ****")
        case a.cron_setting.action
          when 'change_tariff'
            MorLog.my_debug("---- Change tariff into : #{a.cron_setting.to_target_id}")
            if a.cron_setting.target_id == -1
              sql = "UPDATE users SET tariff_id = #{a.cron_setting.to_target_id} WHERE owner_id = #{a.cron_setting.user_id}"
            else
              sql = "UPDATE users SET tariff_id = #{a.cron_setting.to_target_id} WHERE id = #{a.cron_setting.target_id} AND owner_id = #{a.cron_setting.user_id}"
            end
            # MorLog.my_debug(sql)
            begin
              ActiveRecord::Base.connection.update(sql)
              Action.add_action_hash(a.cron_setting.user_id, {:action => 'CronAction_run_successful', :data => 'CronAction successful change tariff', :target_id => a.cron_setting.target_id, :target_type => 'User', :data3 => a.cron_setting_id, :data2 => a.cron_setting.to_target_id})
              a.destroy
              MorLog.my_debug("Cron Actions completed", 1)
            rescue Exception => e
              a.failed_at = Time.now
              a.last_error = e.class.to_s + ' \n ' + e.message.to_s + ' \n ' + e.try(:backtrace).to_s
              a.attempts = a.attempts.to_i + 1
              a.save
              a.create_new
              Action.add_action_hash(a.cron_setting.user_id, {:action => 'error', :data => 'CronAction dont run', :data2 => a.cron_setting_id, :data3 => a.cron_setting.to_target_id, :data4 => e.message.to_s + " " + e.class.to_s, :target_id => a.cron_setting.target_id, :target_type => 'User'})
            end
          when 'change_provider_tariff'
            MorLog.my_debug("---- Change provider tariff into : #{a.cron_setting.provider_to_target_id}")
            if a.cron_setting.provider_target_id == -1
              sql = "UPDATE providers SET tariff_id = #{a.cron_setting.provider_to_target_id} WHERE user_id = #{a.cron_setting.user_id}"
            else
              sql = "UPDATE providers SET tariff_id = #{a.cron_setting.provider_to_target_id} WHERE id = #{a.cron_setting.provider_target_id} AND user_id = #{a.cron_setting.user_id}"
            end
            begin
              ActiveRecord::Base.connection.update(sql)
              Action.add_action_hash(a.cron_setting.user_id, {:action => 'CronAction_run_successful', :data => 'CronAction successful change provider tariff', :target_id => a.cron_setting.provider_target_id, :target_type => 'Provider', :data3 => a.cron_setting_id, :data2 => a.cron_setting.provider_to_target_id})
              a.destroy
              MorLog.my_debug("Cron Actions completed", 1)
            rescue Exception => e
              a.failed_at = Time.now
              a.last_error = e.class.to_s + ' \n ' + e.message.to_s + ' \n ' + e.try(:backtrace).to_s
              a.attempts = a.attempts.to_i + 1
              a.save
              a.create_new
              Action.add_action_hash(a.cron_setting.user_id, {:action => 'error', :data => 'CronAction dont run', :data2 => a.cron_setting_id, :data3 => a.cron_setting.provider_to_target_id, :data4 => e.message.to_s + " " + e.class.to_s, :target_id => a.cron_setting.provider_target_id, :target_type => 'Provider'})
            end
          when 'change_LCR'
            MorLog.my_debug("---- Change user LCR into : #{a.cron_setting.lcr_id}")
            if a.cron_setting.target_id == -1
              sql = "UPDATE users SET lcr_id = #{a.cron_setting.lcr_id}"
            else
              sql = "UPDATE users SET lcr_id = #{a.cron_setting.lcr_id} WHERE id = #{a.cron_setting.target_id}"
            end

            begin
              ActiveRecord::Base.connection.update(sql)
              Action.add_action_hash(a.cron_setting.user_id, {:action => 'CronAction_run_successful', :data => 'CronAction successful change provider tariff', :target_id => a.cron_setting.provider_target_id, :target_type => 'Provider', :data3 => a.cron_setting_id, :data2 => a.cron_setting.provider_to_target_id})
              a.destroy
              MorLog.my_debug("Cron Actions completed", 1)
            rescue Exception => e
              a.failed_at = Time.now
              a.last_error = e.class.to_s + ' \n ' + e.message.to_s + ' \n ' + e.try(:backtrace).to_s
              a.attempts = a.attempts.to_i + 1
              a.save
              a.create_new
              Action.add_action_hash(a.cron_setting.user_id, {:action => 'error', :data => 'CronAction dont run', :data2 => a.cron_setting_id, :data3 => a.cron_setting.lcr_id, :data4 => e.message.to_s + " " + e.class.to_s})
            end
        end
      else
        a.failed_at = Time.now
        a.last_error = "CronAction setting dont found : #{a.cron_setting_id}"
        a.attempts = a.attempts.to_i + 1
        a.save
        Action.add_action2(-1, 'error', 'CronAction setting dont found', a.id)
      end
    end
  end

end
