# -*- encoding : utf-8 -*-
#!/usr/bin/ruby
# encoding: utf-8

#Vitalija Vildžiūtė
#2010-12-07
#2756 | Version : 1
#Kolmisoft
#Specification : http://trac.kolmisoft.com/trac/wiki/MonthlyActionsFixSpecification

#---------- check that script is not running ------------------------------------
script_running = `ps ax | grep monthly_actions_fix.rb | grep -v grep | wc -l`
if script_running.to_i > 1
  puts "FAIL : Script is already running!!!"
else

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

    #    options[:date] = nil
    #    opts.on( '-d', '--date DATE', "Date to fix monthly actions, default #{Time.mktime(Time.now.year, Time.now.month, 1, 0, 0, 0).to_time.strftime("%Y-%m-%d %H:%M:%S")}" ) do|h|
    #      options[:date] = h
    #    end

    options[:gui_address] = nil
    opts.on( '-g', '--gui ADDRESS', "Address to action monthly_actions, default 'http://localhost/billing/callc/monthly_actions'" ) do|h|
      options[:gui_address] = h
    end

    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      puts
      exit
    end
  end

  optparse.parse!

  #---------- SET CORECT PARAMS TO SCRIPT ! ---------------

  M_date = options[:date].to_s.empty? ? Time.mktime(Time.now.year, Time.now.month, 1, 0, 0, 0).to_time : options[:date].to_s
  Debug_file = '/tmp/monthly_actions_fix.log'
  Database_name = options[:name].to_s.empty?  ? 'mor'  : options[:name]
  Database_username = options[:user].to_s.empty?  ? 'mor'  : options[:user]
  Database_password = options[:pasw].to_s.empty?  ? 'mor'  : options[:pasw]
  Database_host =  options[:host].to_s.empty? ? 'localhost'  : options[:host]
  Gui_address = options[:gui_address].to_s.empty? ? 'http://localhost/billing/callc/monthly_actions' : options[:gui_address]

  begin
    #---------- connect to DB ----------------------
    ActiveRecord::Base.establish_connection(:adapter => "mysql", :database => Database_name, :username => Database_username, :password => Database_password, :host => Database_host)
    ActiveRecord::Base.connection


    #------------- User model ----------------------
    class User < ActiveRecord::Base

      def find_actions_sum
        actions = Action.find(:all,:select=>'SUM(data2) as a_sum', :conditions=>['action=? AND DATE(date) = ? AND user_id=?', 'subscription_paid', M_date.to_date, self.id], :group=>'user_id')
        if actions and actions.size.to_i > 0
          return actions[0].a_sum.to_f
        else
          return 0.to_f
        end
      end

      def find_payments_sum
        actions = Payment.find(:all,:select=>'SUM(gross) as a_sum', :conditions=>['paymenttype=? AND DATE(shipped_at) = ? AND DATE(date_added) = ? AND user_id=?', 'subscription', M_date.to_date, M_date.to_date, self.id], :group=>'user_id')
        if actions and actions.size.to_i > 0
          return actions[0].a_sum.to_f
        else
          return 0.to_f
        end
      end

      def all_delete_actions
        Debug.debug("delete_actions")
        Action.delete_all(['action=? AND DATE(date) = ? AND user_id=?', 'subscription_paid', M_date.to_date, self.id])
      end

      def all_delete_payments
        Debug.debug("delete_payments")
        Payment.delete_all(['paymenttype=? AND DATE(shipped_at) = ? AND DATE(date_added) = ? AND user_id=?', 'subscription', M_date.to_date, M_date.to_date, self.id])
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
      require 'net/http'
      require 'uri'

      # Send post
      def Action.do_monthly_action
        res = Net::HTTP.post_form(URI.parse(Gui_address), {})
        if res
          Debug.debug("Responsce from GUI")
          Debug.debug(res.body)
          if res.body.include?('RAILS_ROOT')
            Debug.debug("ERROR IN GUI !!!")
            raise "ERROR IN GUI!!!"
          end
          if res.body.include?('To fast.')
            Debug.debug("ERROR TO FAST !!!")
            raise "ERROR TO FAST!!!"
          end
        else
          Debug.debug("Connection Failed")
        end
      end

    end

    #------------- Payments model ----------------------
    class Payment < ActiveRecord::Base
    end

    #------------- Conflines model ----------------------
    class Confline < ActiveRecord::Base
      def Confline.check_colldown
        c_time = Confline.find(:first, :conditions=>'name = "monthly_actions_cooldown_time"')
        time_set = Time.parse(c_time.value, Time.now-1.year) if c_time
        unless time_set and time_set + 2.hours > Time.now
        else
          Debug.debug("ERROR CAN RUN monthly_actions TO FAST !!!")
          raise "ERROR CAN RUN monthly_actions TO FAST !!!"
        end
      end
    end

    #------------- Debug model ----------------
    class Debug

      def Debug.debug(msg)
        File.open(Debug_file, "a") { |f|
          f << msg.to_s
          f << "\n"
        }
      end

    end

    #------------------ Main -------------------
    Debug.debug("\n*******************************************************************************************************")
    Debug.debug("#{Time.now().to_s(:db)} --- STARTING MONTHLY FIX SCRIPT ")

    # check action cooldown
    Confline.check_colldown

    # find users whit subscriptions
    users = User.find(:all,
      :select=>"users.*",
      :joins => ("RIGHT JOIN subscriptions ON (users.id = subscriptions.user_id)"),
      :conditions => ["blocked != 1"],
      :group=>'users.id',
      :readonly => false)
    Debug.debug("Users found : #{users.size.to_i}")
    # Set time
    time = M_date.to_time

    if users and users.size.to_i > 0
      users.each{|u|
        Debug.debug("******* USER : #{u.id}; #{u.username} ************")
        # Set time
        time = time.next_month if u.postpaid == 0
        period_start_with_time = time.beginning_of_month
        period_end_with_time = time.end_of_month.change(:hour => 23, :min => 59, :sec => 59)
        Debug.debug("Got Time : #{period_start_with_time} - #{period_end_with_time}")
        # Count subscriptions prices
        subscriptions_p = u.subscriptions_in_period(period_start_with_time, period_end_with_time)
        Debug.debug("Got subscriptions price : #{subscriptions_p}")
        # Count payments prices
        payment_p = u.find_payments_sum
        Debug.debug("Got payments price : #{payment_p}")
        # Count actions prices
        action_p = u.find_actions_sum
        Debug.debug("Got actions price : #{action_p}")
        Debug.debug("Old User Balance : #{u.balance}")

        # Verify that the value will be added
        if payment_p == action_p
          sum = action_p
          Debug.debug("Add action price #{sum}")
        else
          if payment_p.to_f == 0.to_f
            sum = action_p.to_f
            Debug.debug("Add action price #{sum}")
          else
            sum = payment_p.to_f * -1 # because subscriptions amount save with -.
            Debug.debug("Add payment price #{sum}")
          end
        end
        Debug.debug("Add price #{sum}")
        u.balance += sum
        if u.save
          Debug.debug("User new balance #{u.balance}")
          u.all_delete_actions
          u.all_delete_payments
        else
          Debug.debug("ERROR TO SAVE USER !!! #{u.id}")
          raise "ERROR TO SAVE USER !!! #{u.id}"
        end
      }
      Debug.debug("RUNING MONTHLY ACTIONS")
      puts "**RUNNING MONTHLY ACTIONS**"
      Action.do_monthly_action
    end
    puts "OK"

  rescue  Exception => e
    puts e.to_yaml
    #------------------ ERROR -------------------
    File.open(Debug_file, "a") { |f| f << "******************************************************************************************************* \n"
      f << "#{Time.now().to_s(:db)} --- ERROR ! \n #{e.class} \n #{e.message} \n" }
    puts "FAIL"
  end

  #yeah, we need to close MySQL connection...
  ActiveRecord::Base.remove_connection

  Debug.debug("#{Time.now().to_s(:db)} --- FINISHING MONTHLY FIX ")

end
