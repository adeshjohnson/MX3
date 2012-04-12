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

  def time_left
    time = Time.now
    out = 0
    if time > activation_start and time < activation_end

      year_month = time.strftime("%Y-%m")
      data = FlatrateData.find(:first, :conditions => "`year_month` = '#{year_month}' AND subscription_id = #{self.id}")
      out = data.minutes.to_i if data

      #      datas = flatrate_datas(:conditions => ["year_month = ?", time.strftime("%Y-%m")])
      #      datas.each{ |data| out += data.minutes.to_i }

      out = service.quantity.to_i - out
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

  def subscription_period(period_start, period_end)
    #from which day used?
    if activation_start < period_start
      use_start = period_start
    else
      use_start = activation_start
    end
    #till which day used?
    if activation_end > period_end
      use_end = period_end
    else
      use_end = activation_end
    end
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
        if start_date.month == end_date.month and start_date.year == end_date.year
          total_days = start_date.to_time.end_of_month.day
          total_price = service.price / total_days * (days_used+1)
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
        amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_f
      when "periodic_fee"
        amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_f
    end
    logger.debug "Amount: #{amount}"
    return amount.to_f
  end

  def return_money_whole
    user.user_type == "prepaid" ? end_time = Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59) : end_time = Time.now.beginning_of_month
    amount = 0
    case service.servicetype
      when "one_time_fee"
        amount = service.price if end_time > activation_end
      when "flat_rate", "periodic_fee"
        amount = price_for_period(activation_start, end_time).to_f
    end
    if amount > 0
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount
      return user.save
    else
      return false
    end
  end

  def return_money_month
    amount = 0
    user = self.user
    amount = self.return_for_month_end if user and user.user_type.to_s == "prepaid"
    if amount > 0
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount.to_f
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
