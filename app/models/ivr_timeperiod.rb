class IvrTimeperiod < ActiveRecord::Base
  belongs_to :user

  @@weekdays = {}
  @@weekdays["mon"] = _("Monday")
  @@weekdays["tue"] = _("Tuesday")
  @@weekdays["wed"] = _("Wednesday")
  @@weekdays["thu"] = _("Thursday")
  @@weekdays["fri"] = _("Friday")
  @@weekdays["sat"] = _("Saturday")
  @@weekdays["sun"] = _("Sunday")
  
  @@months = %w( January February March April May June July August September October November December)


  def before_create
    self.user_id = User.current.id
  end
  
  def start_weekday_name
    if self.start_weekday == "0" 
      return ""
    else
      return @@weekdays[self.start_weekday]
    end
  end
  
  def end_weekday_name
    if self.end_weekday == "0" 
      return ""
    else
      @@weekdays[self.end_weekday]
    end  
  end
  
  def start_month_name
    @@months[self.start_month.to_i-1]
  end
  
  def end_month_name
    @@months[self.end_month.to_i-1]
  end
  
  def start_time
    tmpH = "0"+self.start_hour.to_s
    tmpH = tmpH[tmpH.size-2, tmpH.size]
    tmpM = "0"+self.start_minute.to_s
    tmpM = tmpM[tmpM.size-2, tmpM.size]
    tmpH+":"+tmpM
  end
  
  def end_time
    tmpH = "0"+self.end_hour.to_s
    tmpH = tmpH[tmpH.size-2, tmpH.size]
    tmpM = "0"+self.end_minute.to_s
    tmpM = tmpM[tmpM.size-2, tmpM.size]
    tmpH+":"+tmpM
  end
end