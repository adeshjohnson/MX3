# -*- encoding : utf-8 -*-
class TestController < ApplicationController
  before_filter :authorize_admin, :except => [:fake_form, :vat_checking_get_status]
  require 'google4r/checkout'
  include Google4R::Checkout

  def create_user
    #    opts = {}
    #    params[:tax] ? opts[:tax] = params[:tax] : opts[:tax] = false
    #    params[:address] ? opts[:address] = params[:address] : opts[:address] = false
    user = User.find(:first, :order => "id desc").dup
    user.username = user.username.to_s + "no_adr"
    user.tax_id = 999999
    user.address_id = nil
    user.save(:validate => false)
    render :text => "OK"
  end

  def time
    @time = Time.now()
  end

  def vat_checking_get_status
    condition = Timeout::timeout(5) { !!Net::HTTP.new('ec.europa.eu',80).request_get('/taxation_customs/vies/vatRequest.html').code } rescue false
    render :text => (condition ? 1 : 0)
  end

  def check_db_update
    value = Confline.get_value('DB_Update_From_Script', 0)
    render :text => (value.to_i == 1 ? value : '')
  end

  def raise_exception
    params[:this_is_fake_exception] = nil
    params[:do_not_log_test_exception] = 1
    case params[:id]
      when "Errno::ENETUNREACH"
        raise Errno::ENETUNREACH
      when "Transactions"
        raise ActiveRecord::Transactions::TransactionError, 'Transaction aborted'
      when "RuntimeError"
        raise RuntimeError, 'No route to host'
      when "RuntimeErrorExit"
        raise RuntimeError, 'exit'
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
      when "ReCaptcha"
        raise NameError, 'uninitialized constant Ambethia::ReCaptcha::Controller::RecaptchaError'
      when "SyntaxError"
        raise SyntaxError
      when "OpenSSL::SSL::SSLError"
        Confline.set_value("Last_Crash_Exception_Class", "")
        raise OpenSSL::SSL::SSLError
      when "Cairo"
        raise LoadError, 'Could not find the ruby cairo bindings in the standard locations or via rubygems. Check to ensure they\'re installed correctly'
      when 'Google_account_not_active'
        params[:this_is_fake_exception] = "YES"
        raise GoogleCheckoutError, {:message => 'Seller Account 666666666666666 is not active.', :response_code => '', :serial_number => '6666666-6666-6666-6666-666666666666'}
      when "Google_500"
        params[:this_is_fake_exception] = ""
        raise RuntimeError, 'Unexpected response code (Net::HTTPInternalServerError): 500 - Internal Server Error'
      when "Gems"
        raise LoadError, 'in the standard locations or via rubygems. Check to en'
      when "MYSQL"
        params[:this_is_fake_exception] = "YES"
        Confline.set_value("Last_Crash_Exception_Class", "")
        sql = "alter table users drop first_name ;"
        test = ActiveRecord::Base.connection.execute(sql)
        us = User.find(0)
        us.first_name
      when "test_exceptions"
        Confline.set_value("Last_Crash_Exception_Class", "")
        params[:this_is_fake_exception] = ""
        raise SyntaxError
      when "pdf_limit"
        PdfGen::Count.check_page_number(4, 1)
      else
        flash[:notice] = _("ActionView::MissingTemplate")
        redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def nice_exception_raiser
    params[:do_not_log_test_exception] = 1
    params[:this_is_fake_exception] = nil
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
        user.balance += action.data2.to_d
        MorLog.my_debug("  Action reverted User: #{user.id}, action.data2: #{action.data2}")
        user.save
        action.destroy
        i += 1
      }
    }
    render :text => "DONE! Removed: #{i}"
  end

  def load_delta_sql
    path = (params[:path].to_s.empty? ? params[:id] : params[:path])
    MorLog.my_debug(path)
    # MorLog.my_debug(params[:path].join("/"))
    MorLog.my_debug(File.exist?("#{Rails.root}/config/routes.rb"))
    filename = "#{Rails.root}/selenium/#{path.to_s.gsub(/[^A-Za-z0-9_\/]/, "")}.sql"
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
    sys_admin = User.where({:id=>0}).first
    renew_session(sys_admin)  if sys_admin
    render :text => rez
  end


  # loads bundle file which has patch to sql files which are loaded one-by-one
  # used for tests to prepare data before testing
  # called by Selenium script through MOR GUI
  def load_bundle_sql
    path = (params[:path].to_s.empty? ? params[:id] : params[:path])
    MorLog.my_debug(path)
    # MorLog.my_debug(params[:path].join("/"))
    MorLog.my_debug(File.exist?("#{Rails.root}/config/routes.rb"))
    filename = "#{Rails.root}/selenium/bundles/#{path.to_s.gsub(/[^A-Za-z0-9_\/]/, "")}.bundle"
    MorLog.my_debug(filename)
    if File.exist?(filename)
      command = "/home/mor/selenium/scripts/load_bundle.sh #{filename}"
      MorLog.my_debug(command)
      rez = `#{command}`
      MorLog.my_debug("BUNDLE WAS LOADED: #{filename}")
    else
      MorLog.my_debug("Bundle file was not found: #{filename}")
      rez = "Not Found"
    end
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
      script = "ruby #{script_path} #{params[:params].to_s.strip.gsub(/(^"|"$)/, "")}"
      MorLog.my_debug(script)
      out = %x[#{script}]
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
