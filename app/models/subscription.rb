# -*- encoding : utf-8 -*-
class Subscription < ActiveRecord::Base

  belongs_to :user
  belongs_to :service
  has_many :flatrate_datas, :dependent => :destroy

  before_save :s_before_save

  def s_before_save
    if service.servicetype == "one_time_fee"
      self.activation_end = self.activation_start
    end
  end

=begin
  having troubles, cause rails tries to convert datetime timezone and save to database.
  Damn web fwamework successfuly converts and saves to db, but does not convert back when
  selecting from db. anyways we dont need any of this conversion feature, but cant find a 
  way to completele turn it off
=end  
  def activation_start=(value)
    logger.fatal value.inspect
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:activation_start, value)
  end

=begin
  note a comment above activation_start method
=end
  def activation_end=(value)
    logger.fatal value.inspect
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:activation_end, value)
  end

  def time_left
    time = Time.now
    out = 0
    if time > activation_start and time < activation_end

      year_month = time.strftime("%Y-%m")
      data = FlatrateData.find(:first, :conditions => "`year_month` = '#{year_month}' AND subscription_id = #{self.id}")
      out = data.seconds.to_i if data

      #      datas = flatrate_datas(:conditions => ["year_month = ?", time.strftime("%Y-%m")])
      #      datas.each{ |data| out += data.minutes.to_i }

      out = service.quantity.to_i * 60 - out
    end
    out
  end

  def time_left= (value)
    time = Time.now
    if service.servicetype == "one_time_fee" and time > activation_start and time < activation_end
      datas = flatrate_datas(:conditions => ["year_month = ?", time.strftime("%Y-%m")])
      datas.each { |data|
        data.minutes = service.quantity.to_i - value
        data.save
      }
    end
  end

=begin
  lets try to figure out what this method is ment to do..
  When one passes period of time(start & end date), this method
  calculates intersection of period passed and its activation 
  period. 
  Seems like it is ment to calculate period when subscription 
  was active, but only in period that one passed to this method

  For instance if we have two periods
  activation period: 1-------------------3
  period passed:            2--------------------------------4
  method will return period starting from 2 to 3.

  Note that there is a bug when periods do no intersect 
  activation period: 1------2
  period passed:                3----------------------------4
  method will return period starting from 3 to 2(OMG!!)
=end
  def subscription_period(period_start, period_end)
    use_start = (activation_start < period_start ? period_start : activation_start)
    use_end = (activation_end > period_end ? period_end : activation_end)
    return use_start.to_date, use_end.to_date
  end

  def price_for_period(period_start, period_end)
    period_start = period_start.to_s.to_time if period_start.class == String
    period_end = period_end.to_s.to_time if period_end.class == String
    if activation_end < period_start or period_end < activation_start
      return 0
    end
    total_price = 0
    case service.servicetype
      when "flat_rate"
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        if start_date.month == end_date.month and start_date.year == end_date.year
          total_price = service.price
        else
          total_price = 0
          if months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (months_between(start_date, end_date)-1) * service.price
          end
          #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
          last_day_of_month = start_date.to_time.end_of_month.to_date
          last_day_of_month2 = end_date.to_time.end_of_month.to_date
          total_price += service.price
          total_price += service.price/last_day_of_month2.day * (end_date.day)
        end
      when "one_time_fee"
        logger.fatal "one_time_fee"
        logger.fatal "#{activation_start} >= #{period_start} and #{activation_start} <= #{period_end}"
        if activation_start >= period_start and activation_start <= period_end
          total_price = service.price
        end
      when "periodic_fee"
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        logger.fatal "periodic_fee"
        logger.fatal "#{start_date.month} == #{end_date.month} and #{start_date.year} == #{end_date.year}"
        #if periodic fee if daily month should be the same every time and
        #if condition should evaluate to true every time
        if start_date.month == end_date.month and start_date.year == end_date.year
          if self.service.periodtype == 'month'
            total_days = start_date.to_time.end_of_month.day.to_i
            total_price = service.price / total_days * (days_used.to_i+1)
          elsif self.service.periodtype == 'day'
            total_price = service.price * (days_used.to_i+1)
          end
        else
          total_price = 0
          if months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (months_between(start_date, end_date)-1) * service.price
          end
          #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
          last_day_of_month = start_date.to_time.end_of_month.to_date
          last_day_of_month2 = end_date.to_time.end_of_month.to_date
          total_price += service.price/last_day_of_month.day * (last_day_of_month - start_date+1).to_i
          total_price += service.price/last_day_of_month2.day * (end_date.day)
        end
    end
    total_price
  end

=begin
  Counts amount of money to be returned for the rest of current month
=end
  def return_for_month_end
    amount = 0
    case service.servicetype
      when "flat_rate"
        period_start = Time.now
        period_end = Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        total_days = start_date.to_time.end_of_month.day
        amount = service.price / total_days * (days_used+1)
      when "one_time_fee"
        amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_d
      when "periodic_fee"
        if service.periodtype == 'day'
          amount = Action.sum('data2', :conditions => ["action = 'subscription_paid' AND user_id = ? AND data >= ? AND target_id = ?", self.user_id, "#{Time.now.year}-#{Time.now.month}-#{'1'}", self.id])
        else
          amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_d
       end
    end
    logger.debug "Amount: #{amount}"
    return amount.to_d
  end

  def return_money_whole
    user.user_type == "prepaid" ? end_time = Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59) : end_time = Time.now.beginning_of_month
    amount = 0
    case service.servicetype
      when "one_time_fee"
        amount = service.price if end_time > activation_end
      when "flat_rate" 
        amount = price_for_period(activation_start, end_time).to_d
      when "periodic_fee"
        case self.service.periodtype 
          when 'day'
            amount = self.subscriptions_paid_this_month
          when 'month'
            amount = price_for_period(activation_start, end_time).to_d
        end
    end
    if amount > 0
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount
      return user.save
    else
      return false
    end
  end
 
=begin
  Counts amount that was paid during current month.
  Note that amount is in system currency and beggining of month is in system timezone
 
  *Returns*
  +amount+ amount(float) that was paid diring current month for this subscription, might be 0.
=end
  def subscriptions_paid_this_month
    actions = Action.find(:first, :select=>'SUM(data2) AS amount', :conditions=>"action = 'subscription_paid' AND target_id = #{self.id} AND date > '#{Time.now.beginning_of_month.to_s(:db)}'")
    return actions.amount.to_d
  end

  def return_money_month
    amount = 0
    user = self.user
    amount = self.return_for_month_end if user and user.user_type.to_s == "prepaid"
    if amount > 0
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount.to_d
      return user.save
    else
      return false
    end
  end

  def disable
    self.activation_end = Time.now.to_s(:db)
    self.time_left = 0 if service.servicetype == "flat_rate"
  end

  private

  def months_between(date1, date2)
    years = date2.year - date1.year
    months = years * 12
    months += date2.month - date1.month
    months
  end
end
