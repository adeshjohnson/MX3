# -*- encoding : utf-8 -*-
class CronAction < ActiveRecord::Base
  belongs_to :cron_setting

  before_destroy :cron_before_destroy


  def cron_before_destroy
    self.create_new
  end

  def create_new
    time = self.next_run_time
    if time < cron_setting.valid_till and cron_setting.periodic_type != 0 or cron_setting.repeat_forever == 1
      CronAction.create({:cron_setting_id=>cron_setting.id, :run_at => time})
    end

  end

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
      if z.wday > 5
        time = time.to_s.to_time + 2.day
      else
        time = time.to_s.to_time + 1.day
      end
    when 5
      z = time.to_s.to_time + 1.day
      if z.wday < 5
        time = time.to_s.to_time + 5.day
      else
        time = time.to_s.to_time + 1.day
      end
    when 6
      time = time.to_s.to_time + 1.day
    end
    time
  end

  def CronAction.do_jobs
    actions = CronAction.find(:all, :conditions=>['run_at < ? AND failed_at IS NULL', Time.now().to_s(:db)], :include=>[:cron_setting])
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
            Action.add_action_hash(a.cron_setting.user_id, {:action=>'CronAction_run_successful', :data=>'CronAction successful change tariff', :target_id=>a.cron_setting.target_id, :target_type=>'User', :data3=>a.cron_setting_id, :data2=>a.cron_setting.to_target_id})
            a.destroy
            MorLog.my_debug("Cron Actions completed", 1)
          rescue Exception => e
            a.failed_at = Time.now
            a.last_error = e.class.to_s + ' \n ' + e.message.to_s + ' \n ' + e.try(:backtrace).to_s
            a.attempts = a.attempts.to_i + 1
            a.save
            a.create_new
            Action.add_action_hash(a.cron_setting.user_id, {:action=>'error', :data=>'CronAction dont run', :data2=>a.cron_setting_id, :data3=>a.cron_setting.to_target_id, :data4=>e.message.to_s + " " + e.class.to_s, :target_id=>a.cron_setting.target_id, :target_type=>'User'})
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
            Action.add_action_hash(a.cron_setting.user_id, {:action=>'CronAction_run_successful', :data=>'CronAction successful change provider tariff', :target_id=>a.cron_setting.provider_target_id, :target_type=>'Provider', :data3=>a.cron_setting_id, :data2=>a.cron_setting.provider_to_target_id})
            a.destroy
            MorLog.my_debug("Cron Actions completed", 1)
          rescue Exception => e
            a.failed_at = Time.now
            a.last_error = e.class.to_s + ' \n ' + e.message.to_s + ' \n ' + e.try(:backtrace).to_s
            a.attempts = a.attempts.to_i + 1
            a.save
            a.create_new
            Action.add_action_hash(a.cron_setting.user_id, {:action=>'error', :data=>'CronAction dont run', :data2=>a.cron_setting_id, :data3=>a.cron_setting.provider_to_target_id, :data4=>e.message.to_s + " " + e.class.to_s, :target_id=>a.cron_setting.provider_target_id, :target_type=>'Provider'})
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
