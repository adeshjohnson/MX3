# -*- encoding : utf-8 -*-
class SmsTariff < ActiveRecord::Base
  has_many :sms_rates, :dependent => :destroy
  has_many :sms_providers
  has_many :users
  before_destroy :s_before_destroy

  def s_before_destroy
    if self.sms_providers and self.sms_providers.size > 0
      errors.add(:sms_providers, _("SMS_Tariff_assigned_to_provider"))
      return false
    end
    if self.users and self.users.size > 0
      errors.add(:sms_providers, _("SMS_Tariff_assigned_to_user"))
      return false
    end
    return true
  end

  def rates_by_st(st, sql_start, per_page, options={})
    ex_r = options[:exchange_rate] ? options[:exchange_rate] : 1
    SmsRate.find_by_sql ["SELECT sms_rates.*, (sms_rates.price * #{ex_r}) AS 'curr_price' FROM destinations, sms_rates, directions WHERE sms_rates.sms_tariff_id = ? AND destinations.prefix = sms_rates.prefix AND directions.code = destinations.direction_code AND directions.name like ? GROUP BY sms_rates.id ORDER BY directions.name ASC, destinations.prefix ASC LIMIT " + sql_start.to_s + "," + per_page.to_s, self.id, st.to_s+'%']
  end

  def free_destinations_by_st(st)
    adests = Destination.find_by_sql ["SELECT destinations.* FROM destinations, directions WHERE directions.code = destinations.direction_code AND directions.name like ? ORDER BY directions.name ASC, destinations.prefix ASC", st.to_s+'%']
    dests = self.destinations
    fdests = []
    fdests = adests - dests

  end

  def destinations
    Destination.find_by_sql ["SELECT destinations.* FROM destinations, sms_tariffs, sms_rates WHERE sms_rates.sms_tariff_id = ? AND destinations.prefix = sms_rates.prefix GROUP BY destinations.id ORDER BY destinations.prefix ASC", self.id]
  end


  def add_new_rate(prefix, rate_value)
    rate = SmsRate.new
    rate.sms_tariff_id = self.id
    rate.prefix = prefix
    rate.price = rate_value

    rate.save
  end


  def delete_all_rates

    sql = "DELETE FROM sms_rates WHERE sms_rates.sms_tariff_id = '#{self.id.to_s}'"
    res = ActiveRecord::Base.connection.execute(sql)


  end

  def sms_rate_by_dst(dst)
    SmsRate.find_by_sql ["SELECT sms_rates.* FROM destinations, sms_rates, directions WHERE sms_rates.sms_tariff_id = '#{self.id}' AND destinations.prefix = sms_rates.prefix AND directions.prefix = '#{dst}' GROUP BY sms_rates.id ORDER BY directions.name ASC, destinations.prefix ASC LIMIT "]
  end
end
