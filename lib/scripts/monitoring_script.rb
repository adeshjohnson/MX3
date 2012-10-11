# -*- encoding : utf-8 -*-
#!/usr/bin/ruby

require '/home/mor/lib/sql_export'
include SqlExport

#---------- check that script is not running ------------------------------------
script_running = `ps ax | grep monitoring_script.rb | grep -v grep | wc -l`
if script_running.to_i > 1
  puts "FAIL : Script is already running!!!"
else

  require 'rubygems'
  require 'active_record'
  require 'optparse'
  require 'digest/sha1'

  options = {}
  optparse = OptionParser.new do |opts|

    # Define the options, and what they do
    options[:address] = nil
    opts.on('-a', "--address ADDRESS', 'Api address, default 'http://localhost/billing/api/ma_activate'") do |a|
      options[:address] = a
    end

    options[:name] = nil
    opts.on('-n', '--name NAME', "Database name, default 'mor'") do |n|
      options[:name] = n
    end

    options[:user] = nil
    opts.on('-u', '--user USER', "Database user, default 'mor'") do |u|
      options[:user] = u
    end

    options[:pasw] = nil
    opts.on('-p', '--password PASSWORD', "Database password, default 'mor'") do |p|
      options[:pasw] = p
    end

    options[:host] = nil
    opts.on('-s', '--server HOST', "Database host, default 'localhost'") do |h|
      options[:host] = h
    end

    options[:key] = nil
    opts.on('-k', '--key KEY', "API secret key, default ''") do |h|
      options[:key] = h
    end

    opts.on('-h', '--help', 'Display this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  #---------- SET CORECT PARAMS TO SCRIPT ! ---------------

  Api_addres = options[:address].to_s.empty? ? 'http://localhost/billing/api/ma_activate' : options[:address].to_s
  Api_key = options[:key].to_s.empty? ? '' : options[:key].to_s
  Debug_file = '/var/log/mor/monitorings.log'
  Database_name = options[:name].to_s.empty? ? 'mor' : options[:name]
  Database_username = options[:user].to_s.empty? ? 'mor' : options[:user]
  Database_password = options[:pasw].to_s.empty? ? '' : options[:pasw]
  Database_host = options[:host].to_s.empty? ? 'localhost' : options[:host]

  begin
    #---------- connect to DB ----------------------
    ActiveRecord::Base.establish_connection(:adapter => "mysql2", :database => Database_name, :username => Database_username, :password => Database_password, :host => Database_host)
    ActiveRecord::Base.connection


    #------------- User model ----------------------
    class User < ActiveRecord::Base
    end

    #------------- Call model ----------------------
    class Call < ActiveRecord::Base
    end

    #------------- Monitoring model ----------------
    class Monitoring < ActiveRecord::Base
      require 'net/http'
      require 'uri'


      def get_users(user_type = nil)
        find_all_users_sql = self.owner_id == 0 ? '' : " AND users.owner_id = #{self.owner_id} "


          operator = (self.monitoring_type == 'above' ? '>' : '<')

          if user_type && user_type =~ /postpaid|prepaid/ # monitoring for postpaids and prepaids

            Monitoring.debug("Monitoring for POSTPAID OR PREPAID users")

            users = User.find(:all,
                              :select => 'users.id',
                              :conditions => ["users.blocked = 0 AND users.postpaid = ? AND users.ignore_global_monitorings = 0 #{find_all_users_sql}", ((self.user_type == "postpaid") ? 1 : 0)],
                              :group => "users.id HAVING SUM(#{SqlExport.user_price_sql}) #{operator} #{self.amount.to_f}",
                              :joins => "JOIN calls ON (calls.user_id = users.id AND calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))")
          elsif user_type && user_type =~ /all/ # monitoring for all users

            Monitoring.debug("Monitoring for ALL users")

            users = User.find(:all,
                              :select => 'users.id',
                              :conditions => ["users.blocked = 0 AND users.ignore_global_monitorings = 0 #{find_all_users_sql}", self.id],
                              :group => "users.id HAVING SUM(#{SqlExport.user_price_sql}) #{operator} #{self.amount.to_f}",
                              :joins => "JOIN calls ON (calls.user_id = users.id AND calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))")

            Monitoring.debug("users.blocked = 0 AND users.ignore_global_monitorings = 0 #{find_all_users_sql}")
            Monitoring.debug("JOIN calls ON (calls.user_id = users.id AND calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))")
            Monitoring.debug("users.id HAVING SUM(#{SqlExport.user_price_sql}) #{operator} #{self.amount.to_f}")
          else # monitoring for individual users

            Monitoring.debug("Monitoring for PERSONAL users, amount: #{self.amount.to_f}, period: #{self.period_in_past.to_i} min")

            users = User.find(:all,
                              :select => 'users.id',
                              :conditions => "monitorings_users.monitoring_id = #{self.id} AND users.blocked = 0 #{find_all_users_sql}",
                              :group => "users.id HAVING SUM(#{SqlExport.user_price_sql}) #{operator} #{self.amount.to_f}",
                              :joins => "JOIN calls ON (calls.user_id = users.id AND calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE)) JOIN monitorings_users ON (users.id = monitorings_users.user_id)")
          end


        users
      end

      def get_calls(user_type = nil)
        find_all_users_sql = self.owner_id == 0 ? '' : " AND users.owner_id = #{self.owner_id} "
        if self.monitoring_type == 'simultaneous'
          Monitoring.debug("Monitoring for simultaneous calls")
          if user_type && user_type =~ /postpaid|prepaid/ # monitoring for postpaids and prepaids
            Monitoring.debug("Monitoring for POSTPAID OR PREPAID users")
            calls_sql = "select calls.id, dst, user_id, src, calldate from calls JOIN users ON (users.id = calls.id) where  users.blocked = 0 AND users.ignore_global_monitorings = 0 AND dst in (select dst from calls where calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE) group by dst) AND calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE)  #{find_all_users_sql} AND users.postpaid = #{self.user_type == "postpaid" ? 1 : 0} order by dst; "
          elsif user_type && user_type =~ /all/ # monitoring for all users
            Monitoring.debug("Monitoring for ALL users")
            calls_sql = "select calls.id, dst, user_id, src, calldate from calls JOIN users ON (users.id = calls.id) where  users.blocked = 0 AND users.ignore_global_monitorings = 0 AND dst in (select dst from calls where calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE) group by dst) AND calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE)  #{find_all_users_sql}  order by dst; "
          else # monitoring for individual users
            Monitoring.debug("Monitoring for PERSONAL users")
            calls_sql = "select calls.id, dst, user_id, src, calldate from calls JOIN users ON (users.id = calls.id) where  users.blocked = 0 AND users.ignore_global_monitorings = 0 AND dst in (select dst from calls where calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE) group by dst) AND calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE)  #{find_all_users_sql} AND users.id = #{self.id} order by dst; "
          end
        end
        if  calls_sql and !calls_sql.blank?
          calls = Call.find_by_sql(calls_sql)
        else
          calls = []
        end

        calls_string = []
        users = []
        dst = ''
        if calls and calls.size.to_i > 0
          for c in calls
            if dst.to_s != c.dst.to_s
              calls_string << dst.to_s + '\n'
              dst = c.dst.to_s
            end
            calls_string << c.dst.to_s + '|' + c.calldate.to_s + '|' + c.src.to_s + '\n'
            users << c.user_id
          end
        end
        return calls_string.join(''), users.uniq.join(",")
      end

      def send_notice_to_api(users, calls_string = '')
        if  self.monitoring_type == 'simultaneous'
          h =  Digest::SHA1.hexdigest(self.id.to_s + users.to_s + self.block.to_s + self.email.to_s + self.mtype.to_s + calls_string.to_s + Api_key.to_s)
          res = Net::HTTP.post_form(URI.parse(Api_addres),
                                    {'monitoring_id' => self.id, 'block' => self.block, 'email' => self.email, 'mtype' => self.mtype, 'users' => users.to_s, 'calls_string'=>calls_string, :hash=>h})
        else
          h =  Digest::SHA1.hexdigest(self.id.to_s + users.map(&:id).join(",") + self.block.to_s + self.email.to_s + self.mtype.to_s + Api_key.to_s)
          res = Net::HTTP.post_form(URI.parse(Api_addres),
                                    {'monitoring_id' => self.id, 'block' => self.block, 'email' => self.email, 'mtype' => self.mtype, 'users' => users.map(&:id).join(","), :hash=>h})
        end

        Monitoring.debug("#{Time.now().to_s(:db)} --- MONITORING notice send to #{Api_addres}") if res
        Monitoring.debug("#{res.body}") if res
      end

      def Monitoring.debug(msg)
        File.open(Debug_file, "a") { |f|
          f << msg.to_s
          f << "\n"
        }
      end

    end

    #------------------ Main -------------------
    Monitoring.debug("\n*******************************************************************************************************")
    Monitoring.debug("#{Time.now().to_s(:db)} --- STARTING MONITORING ")

    monitorings = Monitoring.find(:all, :conditions => 'active = 1')

    if monitorings and monitorings.size > 0
      Monitoring.debug("Found #{monitorings.size} monitorings")
    else
      Monitoring.debug("Monitorings not found...")
    end

    for monitoring in monitorings
      if monitoring.monitoring_type == 'simultaneous'
        users, calls = monitoring.get_calls(monitoring.user_type)
        if calls and calls.size > 0
          Monitoring.debug("Found calls size : #{calls.size} in monitoring id :#{monitoring.id} ")
          monitoring.send_notice_to_api(users, calls)
        end
      else
        users = monitoring.get_users(monitoring.user_type)
        if users and users.size > 0
          Monitoring.debug("Found users size : #{users.size} in monitoring id :#{monitoring.id} ")
          monitoring.send_notice_to_api(users)
        end
      end
    end
    puts "OK"

  rescue Exception => e
    #------------------ ERROR -------------------
    File.open(Debug_file, "a") { |f|
      f << "******************************************************************************************************* \n"
      f << "#{Time.now().to_s(:db)} --- ERROR ! \n #{e.class} \n #{e.message} \n"
      f << e.backtrace.join("\n")
      f << "\n\n"
    }
    puts "FAIL"
  end

  #yeah, we need to close MySQL connection...
  ActiveRecord::Base.remove_connection

  #Monitoring.debug("#{Time.now().to_s(:db)} --- FINISHING MONITORING ")

end
