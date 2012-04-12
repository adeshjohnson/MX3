# -*- encoding : utf-8 -*-
class SmsRate < ActiveRecord::Base
  belongs_to :sms_tariff
  has_many :sms_ratedetails, :order => "start_time ASC"

  def destination
    destination = Destination.find(:first, :conditions => "prefix='#{self.prefix}'")
  end
end
