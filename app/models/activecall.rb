# -*- encoding : utf-8 -*-
class Activecall < ActiveRecord::Base

  belongs_to :provider
  belongs_to :user
  belongs_to :did
  belongs_to :server

  def src_device
    Device.find(:first, :conditions => ["id = ?", self.src_device_id])
  end

  def dst_device
    Device.find(:first, :conditions => ["id = ?", self.dst_device_id])
  end

  def destination
    Destination.find(:first, :conditions => ["prefix = ?", self.prefix])
  end

  def duration
    Time.now.getlocal - Time.parse(answer_time.to_s)
  end

  def get_user_rate(user = nil, destination = nil)
#    user = self.user unless user
#    destination = self.destination unless destination
#
#    user_rate = nil
#    user_rate = self.user_rate
#    unless user_rate and destination
#      rate = Rate.find(:first, :include => [:ratedetails], :conditions => ["rates.tariff_id = ? AND rates.destination_id = ?", user.tariff_id, destination.id]).ratedetails[0]
#      user_rate = rate.rate.to_d
#    end
    user_rate = self.user_rate ? self.user_rate.to_d : 0.to_d
    return User.current.get_rate(user_rate)
  end

  def Activecall.count_for_user(user)
    if user and user.id and user.usertype
      if user.usertype == "admin" or user.usertype == 'accountant'
        return Activecall.count
      else
        if user.usertype == "reseller"
          #reseller
          user_sql = " WHERE activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id} OR  activecalls.owner_id = #{user.id} OR dst_usr.owner_id =  #{user.id} "
        else
          #user
          user_sql = " WHERE activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id} "
        end
        sql = "
        SELECT COUNT(*)
        FROM activecalls
        LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
        LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
        #{user_sql}"
        return ActiveRecord::Base.connection.select_value(sql)
      end
    end
    return 0
  end
end
