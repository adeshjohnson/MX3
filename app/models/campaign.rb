# -*- encoding : utf-8 -*-
class Campaign < ActiveRecord::Base

  belongs_to :user
  belongs_to :device
  has_many :adnumbers
  has_many :adactions, :order => "priority ASC"

  before_save :validate_device, :check_time

  def validate_device
    if !['admin', 'accountant'].include?(User.current.usertype)
      if device
        dev_user = device.user
      else
        errors.add(:device, _("Device_not_found"))
        return false
      end
      if User.current.usertype == 'reseller' and device and !Device.find(:first, :joins=>"LEFT JOIN users ON (devices.user_id = users.id)", :conditions=>"devices.id = #{device.id} and (users.owner_id = #{User.current.id} or users.id = #{User.current.id})")
        errors.add(:device, _("Device_not_found"))
        return false
      end

      if User.current.usertype == 'user' and device and dev_user and dev_user.id != User.current.id
        errors.add(:device, _("Device_not_found"))
        return false
      end
    end
  end

  def check_time
    if retry_time.to_i < 60
      errors.add(:retry_time, _("Please_enter_retry_time_higher_or_equal_to_60"))
      return false
    end
    if wait_time.to_i < 30
      errors.add(:wait_time, _("Please_enter_wait_time_higher_or_equal_to_30"))
      return false
    end
  end

  def new_numbers_count
    Adnumber.count_by_sql "SELECT COUNT(adnumbers.id) FROM adnumbers WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'new'"    
  end

  def executed_numbers_count
    Adnumber.count_by_sql "SELECT COUNT(adnumbers.id) FROM adnumbers WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'executed'"    
  end

  def completed_numbers_count
    Adnumber.count_by_sql "SELECT COUNT(adnumbers.id) FROM adnumbers WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"    
  end

  def completed_numbers_user_billsec
    #sql = "SELECT SUM(calls.user_billsec) FROM adnumbers JOIN calls ON (adnumbers.channel = calls.channel) WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"    
    #res = ActiveRecord::Base.connection.select_value(sql)   
    0
  end

  def user_price
    #sql = "SELECT SUM(calls.user_price) FROM adnumbers JOIN calls ON (adnumbers.channel = calls.channel) WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"    
    #res = ActiveRecord::Base.connection.select_value(sql)   
    0
  end

  def profit
    #sql = "SELECT SUM(calls.user_price - calls.provider_price) FROM adnumbers JOIN calls ON (adnumbers.channel = calls.channel) WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"    
    #res = ActiveRecord::Base.connection.select_value(sql)   
    0
  end

  def count_completed_user_billsec(device, channels, from, till)
    sql =" SELECT SUM(calls.user_billsec) FROM calls WHERE (src_device_id = #{device} AND channel REGEXP '#{channels}' AND disposition = 'ANSWERED' AND calldate BETWEEN '#{from} 00:00:00' AND '#{till} 23:59:59') "
    ActiveRecord::Base.connection.select_value(sql)
  end

  def count_completed_user_billsec_longer_than_ten(device, channels, from, till)
    sql =" SELECT SUM(calls.user_billsec) FROM calls WHERE (src_device_id = #{device} AND channel REGEXP '#{channels}' AND disposition = 'ANSWERED' AND calldate BETWEEN '#{from} 00:00:00' AND '#{till} 23:59:59') AND user_billsec > 10"
    ActiveRecord::Base.connection.select_value(sql)
  end

  def final_path
    path = Confline.get_value("Temp_Dir")
    final_path = Confline.get_value('AD_Sounds_Folder')
   
    if final_path.to_s == ""
      final_path = "/home/mor/public/ad_sounds"
    end

     MorLog.my_debug "final_path:" + final_path.to_s

    return path, final_path
  end

end
