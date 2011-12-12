#!/usr/bin/ruby
# encoding: utf-8

#Vitalija Vildžiūtė
#2011-04-28
#Version : 2
#Kolmisoft


require 'rubygems'
require 'active_record'
require 'optparse'
require 'digest/sha1'

options = {}
optparse = OptionParser.new do|opts|

  # Define the options, and what they do
  options[:name] = nil
  opts.on( '-n', '--name NAME', "Database name, default 'mor'" ) do|n|
    options[:name] = n
  end

  options[:user] = nil
  opts.on( '-u', '--user USER', "Database user, default 'mor'" ) do|u|
    options[:user] = u
  end

  options[:pasw] = nil
  opts.on( '-p', '--password PASSWORD', "Database password, default 'mor'" ) do|p|
    options[:pasw] = p
  end

  options[:host] = nil
  opts.on( '-s', '--server HOST', "Database host, default 'localhost'" ) do|h|
    options[:host] = h
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    puts
    exit
  end
end

optparse.parse!

#---------- SET CORECT PARAMS TO SCRIPT ! ---------------

Debug_file = '/tmp/user_balance_check.log'
Database_name = options[:name].to_s.empty?  ? 'mor'  : options[:name]
Database_username = options[:user].to_s.empty?  ? 'mor'  : options[:user]
Database_password = options[:pasw].to_s.empty?  ? 'mor'  : options[:pasw]
Database_host =  options[:host].to_s.empty? ? 'localhost'  : options[:host]

begin
  #---------- connect to DB ----------------------
  ActiveRecord::Base.establish_connection(:adapter => "mysql", :database => Database_name, :username => Database_username, :password => Database_password, :host => Database_host)
  ActiveRecord::Base.connection


  #------------- User model ----------------------
  class User < ActiveRecord::Base

    def sum_calls(time = 0)
      if time == 0
        cond = ""
      else
        cond = "AND calldate >= '#{Time.now.beginning_of_month.to_s(:db)}'"
      end
      out = 0
      if usertype == 'reseller'
        c = Call.find(:all,
          :select=>"SUM(if((reseller_price + did_price + did_inc_price + did_prov_price) between -10000 and 10000 , (reseller_price + did_price + did_inc_price + did_prov_price), 0 )) as u_p",#"SUM(if((IF(calls.user_id = #{id},user_price,reseller_price) + did_price + did_inc_price + did_prov_price) > 10000 , 0,(IF(calls.user_id = #{id},user_price,reseller_price) + did_price + did_inc_price + did_prov_price) )) as u_p",
          :joins=>"LEFT JOIN devices AS dst_device ON (dst_device.id = calls.dst_device_id)",
          :conditions=>["(calls.reseller_id = ? OR calls.user_id = ? OR dst_device.user_id = ?) #{cond}",id,id,id]
        )
    #    puts "(calls.reseller_id = ? OR calls.user_id = ? OR dst_device.user_id = ?) #{cond}"
      else
        c = Call.find(:all,
          :select=>"SUM(if((user_price + did_price + did_inc_price + did_prov_price) between -10000 and 10000 , (user_price + did_price + did_inc_price + did_prov_price), 0 )) as u_p",
          :joins=>"LEFT JOIN devices AS dst_device ON (dst_device.id = calls.dst_device_id)",
          :conditions=>["(calls.user_id = ? OR dst_device.user_id = ?) #{cond}",id,id]
        )
    #    puts "(calls.user_id = ? OR dst_device.user_id = ?) #{cond}"
      end
      if c

          out = c[0].u_p

      end
   #   puts out
      out.to_f
    end

    def payments_sum(def_curr,time = 0)

      if time == 0
        cond = ""
      else
        cond = "AND shipped_at >= '#{Time.now.beginning_of_month.to_s(:db)}'"
      end
    #  puts cond
      pai = Payment.find(:all,
        :select => "SUM(IF(payments.currency != '#{def_curr}', ((amount-tax) / currencies.exchange_rate), (amount-tax))) AS p_sum",
        :joins=>"LEFT join currencies ON (payments.currency = currencies.name)",
        :conditions=>["user_id = ? and completed = 1 #{cond} and paymenttype in ('card', 'invoice', 'manual', 'voucher')", id])
#      puts "SUM(IF(payments.currency != '#{def_curr}', ((amount-tax) / currencies.exchange_rate), (amount-tax))) AS p_sum"
  #    puts "user_id = ? and completed = 1 #{cond} and paymenttype in ('card', 'invoice', 'manual', 'voucher')"
      out = pai ?  pai[0].p_sum : 0
      pai2 = Payment.find(:all,
        :select => "SUM(IF(payments.currency != '#{def_curr}',gross / currencies.exchange_rate,gross)) AS p_sum",
        :joins=>"LEFT join currencies ON (payments.currency = currencies.name)",
        :conditions=>["user_id = ? and completed = 1 #{cond} and paymenttype not in ('card', 'invoice', 'manual', 'voucher')", id])
  #    puts "user_id = ? and completed = 1 #{cond} and paymenttype not in ('card', 'invoice', 'manual', 'voucher')"
      out2 = pai2 ?  pai2[0].p_sum : 0
      ats = out.to_f + out2.to_f
      ats
    end

    def sum_subscriptions
      s = Subscription.find(:first, :conditions=>['user_id=?', id], :order=>'activation_start asc')
      if s
        self.subscriptions_in_period(s.activation_start, Time.now.beginning_of_month.to_s(:db))
      else
        0
      end
    end


    def sms_sum
      0
    end




    def if_action
      Action.find(:first, :conditions=>['user_id=? and action="user_balance_at_month_end"',id], :order=>'id desc')
    end

    def if_sub
      Subscription.count(:all, :conditions=>['user_id=? and added >=?', id, Time.now.beginning_of_month.to_s(:db)]) > 0
    end

    def sum_sub
      Subscription.find(:all,
        :select=>"sum(services.price) as s_sum",
        :joins=>"Left JOIN services on (services.id = service_id)",
        :conditions=>['user_id=? and activation_start >=?', id, Time.now.beginning_of_month.to_s(:db)]).s_sum
    end

    # ------- From Gui : user.rb

    def subscriptions_in_period(period_start, period_end)
      period_start =  period_start.to_s(:db) if period_start.class == Time or period_start.class == Date
      period_end =  period_end.to_s(:db) if period_end.class == Time or period_end.class == Date
      subs = Subscription.find(:all, :include => [:service], :conditions => ["(? BETWEEN activation_start AND activation_end OR ? BETWEEN activation_start AND activation_end OR (activation_start > ? AND activation_end < ?)) AND subscriptions.user_id = ?", period_start, period_end, period_start, period_end, self.id])
      prices = 0.to_f

      subs.each{|s| prices += s.price_for_period(period_start, period_end) }
      return prices.to_f
    end

    def find_1_way(c,def_curr, a)
      Debug.debug("#{c} === -* user_balance_at_month_end = #{a.data2}")
      payments_sum = self.payments_sum(def_curr,1)
      Debug.debug("#{c} === -* Payments sum = #{payments_sum.to_f}")
      calls_sum = self.sum_calls(1)
      Debug.debug("#{c} === -* Calls sum = #{calls_sum}")
      if self.postpaid == 0 and self.if_sub
        sum_sub = self.sum_sub
        Debug.debug("#{c} === -* New subscription sum = #{sum_sub}")
      else
        sum_sub = 0
      end
      return  a.data2.to_f + payments_sum.to_f - calls_sum.to_f - sum_sub.to_f, a.data2.to_f
    end

    def find_2_way(c,def_curr)

      payments_sum = self.payments_sum(def_curr)
      Debug.debug("#{c} === -* Payments sum = #{payments_sum.to_f}")
      calls_sum = self.sum_calls
      Debug.debug("#{c} === -* Calls sum = #{calls_sum}")
     # subscriptions_sum = 0 #self.sum_subscriptions
     # Debug.debug("#{c} === -* Subscriptions sum = #{self.sum_subscriptions}")
      if self.postpaid == 0 and self.if_sub
        sum_sub = self.sum_sub
        Debug.debug("#{c} === -* New subscription sum = #{sum_sub}")
      else
        sum_sub = 0
      end
      payments_sum.to_f - calls_sum.to_f - sum_sub.to_f
    end

  end

  #------------- Subscription model ----------------------
  class Subscription < ActiveRecord::Base
    belongs_to :user
    belongs_to :service

    # ------- From Gui : subscription.rb

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
        days_used =  end_date - start_date
        if start_date.month == end_date.month and start_date.year == end_date.year
          total_price = service.price
        else
          total_price = 0
          if Subscription.months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (Subscription.months_between(start_date, end_date)-1) * service.price
          end
          #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
          last_day_of_month = start_date.to_time.end_of_month.to_date
          last_day_of_month2 = end_date.to_time.end_of_month.to_date
          total_price += service.price
          total_price += service.price/last_day_of_month2.day * (end_date.day)
        end
      when "one_time_fee"
        if activation_start >= period_start and activation_start <= period_end
          total_price = service.price
        end
      when "periodic_fee"
        start_date, end_date = subscription_period(period_start, period_end)
        days_used =  end_date - start_date
        if start_date.month == end_date.month and start_date.year == end_date.year
          total_days = start_date.to_time.end_of_month.day
          total_price = service.price / total_days * (days_used+1)
        else
          total_price = 0
          if Subscription.months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (Subscription.months_between(start_date, end_date)-1) * service.price
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

    def Subscription.months_between(date1, date2)
      years = date2.year - date1.year
      months = years * 12
      months += date2.month - date1.month
      months
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
  end

  #------------- Service model ----------------------
  class Service < ActiveRecord::Base
  end

  #------------- Action model ----------------------
  class Action < ActiveRecord::Base
  end

  #------------- Payments model ----------------------
  class Payment < ActiveRecord::Base
  end

  #------------- Currency model ----------------------
  class Currency < ActiveRecord::Base
  end

  #------------- Currency model ----------------------
  class SmsMessage < ActiveRecord::Base
  end


  #------------- Conflines model ----------------------
  class Call < ActiveRecord::Base
  end

  #------------- Debug model ----------------
  class Debug

    def Debug.debug(msg)
      File.open(Debug_file, "a") { |f|
        f << msg.to_s
        f << "\n"
      }
      #puts msg.to_s
    end

  end

  #------------------ Main -------------------
  Debug.debug("\n*******************************************************************************************************")
  Debug.debug("#{Time.now().to_s(:db)} --- STARTING USER BALANCE CHECK ")

  users = User.find(:all, :conditions=>'blocked=0')
  puts "Found users : #{users.size}"
  def_curr = Currency.find(1).name
  c = 0
  users.each{|user|
    Debug.debug("#{c} === -* Found user : #{user.id} , balance = #{user.balance}")
    a = user.if_action
    o = 0
    if a
      # found action with balance
      # count from action data
      ex_b, o = user.find_1_way(c,def_curr, a)
    else
      # count all period
      ex_b = user.find_2_way(c,def_curr)
    end

    if user.balance.to_f.floor != ex_b.to_f.floor and user.balance != o
  #    puts "#{user.usertype} , #{user.postpaid}"
      y = "#{c} === User_id : #{user.id}, balance : #{user.balance}, expected_balance = #{ex_b}, dif = #{ex_b.to_f - user.balance}"
      Debug.debug(y)
      puts y
      c+=1
    end

  }
  puts "FOUND #{c}"

rescue  Exception => e
  puts e.to_yaml
  #------------------ ERROR -------------------
  File.open(Debug_file, "a") { |f| f << "******************************************************************************************************* \n"
    f << "#{Time.now().to_s(:db)} --- ERROR ! \n #{e.class} \n #{e.message} \n" }
  puts "FAIL"
end

#yeah, we need to close MySQL connection...
ActiveRecord::Base.remove_connection

Debug.debug("#{Time.now().to_s(:db)} --- FINISHING USER BALANCE CHECK ")
