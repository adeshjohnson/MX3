# -*- encoding : utf-8 -*-
class TestController < ApplicationController
  before_filter :authorize_admin, :except => [:fake_form]

  def create_user
    #    opts = {}
    #    params[:tax] ? opts[:tax] = params[:tax] : opts[:tax] = false
    #    params[:address] ? opts[:address] = params[:address] : opts[:address] = false
    user = User.find(:first, :order => "id desc").dup
    user.username = user.username.to_s + "no_adr"
    user.tax_id = 999999
    user.address_id = nil
    user.save(false)
    render :text => "OK"
  end

  def time
    @time = Time.now()
  end

  def raise_exception
    params[:this_is_fake_exception] = nil
    case params[:id]
      when "Errno::ENETUNREACH"
        raise Errno::ENETUNREACH
      when "Transactions"
        raise ActiveRecord::Transactions::TransactionError, 'Transaction aborted'
      when "RuntimeError"
        raise RuntimeError, 'No route to host'
      when "Errno::EHOSTUNREACH"
        raise Errno::EHOSTUNREACH
      when "Errno::ETIMEDOUT"
        raise Errno::ETIMEDOUT
      when "SystemExit"
        raise SystemExit
      when "SocketError"
        raise SocketError
      when "NoMemoryError"
        params[:this_is_fake_exception] = "YES"
        raise NoMemoryError
      when "DNS_TEST"
        raise 'getaddrinfo: Temporary failure in name resolution'
      when "SyntaxError"
        raise SyntaxError
      when "OpenSSL::SSL::SSLError"
        Confline.set_value("Last_Crash_Exception_Class", "")
        raise OpenSSL::SSL::SSLError
      when "Cairo"
        raise LoadError, 'Could not find the ruby cairo bindings in the standard locations or via rubygems. Check to ensure they\'re installed correctly'
      when "Gems"
        raise LoadError, 'in the standard locations or via rubygems. Check to en'
      when "MYSQL"
        Confline.set_value("Last_Crash_Exception_Class", "")
        sql = "alter table users drop first_name ;"
        test = ActiveRecord::Base.connection.execute(sql)
        us = User.find(0)
        us.first_name
      when "test_exceptions"
        Confline.set_value("Last_Crash_Exception_Class", "")
        #params[:this_is_fake_exception] = ""
        raise SyntaxError
      when "pdf_limit"
        PdfGen::Count.check_page_number(4, 1)
    end
  end

  def nice_exception_raiser
    params[:this_is_fake_exception] = "YES"
    if params[:exc_class]
      raise eval(params[:exc_class].to_s), params[:exc_message].to_s
    end
  end

  def last_exception
    render :text => Confline.get_value("Last_Crash_Exception_Class", 0).to_s
  end

  def remove_duplicates
    i = 0
    sql = "SELECT user_id, data, target_id, count(*) as 'size' FROM actions WHERE action = 'subscription_paid' GROUP BY user_id, data, target_id HAVING size > 1"
    duplicates = ActiveRecord::Base.connection.execute(sql)
    duplicates.each { |dub|
      (dub[3].to_i - 1).times {
        action = Action.find(:first, :include => [:user], :conditions => ["action = 'subscription_paid' AND user_id = ? AND data = ? AND target_id = ?", dub[0].to_i, dub[1], dub[2].to_i])
        user = action.user
        user.balance += action.data2.to_f
        MorLog.my_debug("  Action reverted User: #{user.id}, action.data2: #{action.data2}")
        user.save
        action.destroy
        i += 1
      }
    }
    render :text => "DONE! Removed: #{i}"
  end

  def load_delta_sql
    MorLog.my_debug(params[:path])
    # MorLog.my_debug(params[:path].join("/"))
    MorLog.my_debug(File.exist?("#{Rails.root}/config/routes.rb"))
    filename = "#{Rails.root}/selenium/tests/#{params[:path].to_s.gsub(/[^A-Za-z_\/]/, "")}.sql"
    MorLog.my_debug(filename)
    if File.exist?(filename)
      command = "mysql -u mor -pmor mor < #{filename}"
      MorLog.my_debug(command)
      rez = `#{command}`
      MorLog.my_debug("DELTA SQL FILE WAS LOADED: #{filename}")
    else
      MorLog.my_debug("Delta SQL file was not found: #{filename}")
      rez = "Not Found"
    end
    renew_session(User.find(0))
    render :text => rez
  end

  def restart
    `mor -l`
  end

  def fake_form
    @all_fields = params.reject { |key, value| ['controller', 'action', 'path_to_action'].include?(key) }
    @data = params[:path_to_action]
  end

  def run_ma_script
    script_path = File.expand_path("#{Rails.root}/lib/scripts/monitoring_script.rb")
    if File.exist?(script_path)
      MorLog.my_debug("SCRIPT WAS FOUND")
      script = "/usr/bin/ruby #{script_path} #{params[:params].to_s.strip.gsub(/(^"|"$)/, "")}"
      MorLog.my_debug(script)
      out = `#{script}`
      MorLog.my_debug(out)
      render :text => "DONE (#{out})"
    else
      MorLog.my_debug("SCRIPT WAS NOT FOUND")
      render :text => "script not found"
    end
  end

  def test_api
    allow, values = MorApi.check_params_with_all_keys(params, request)
    render :text => values[:system_hash]
  end

  def make_select

    @tables = ActiveRecord::Base.connection.tables

    @table = @tables.include?(params[:table]) ? params[:table] : nil

    if params[:id] and @table
      if @table.to_s != 'sessions'
        @select = @table.singularize.titleize.gsub(' ', '').constantize.find(:first, :conditions => {:id => params[:id]})
      else
        @select = ActiveRecord::Base.connection.select_all("SELECT * FROM #{params[:table]} WHERE id = #{params[:id].to_i}")
      end
    end
  end

end
