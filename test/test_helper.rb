ENV["RAILS_ENV"] ||= "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'rubygems'
require 'mocha'
require 'ostruct'

class Test::Unit::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
# perdidele rizika
#  def go_real_development
#    self.use_transactional_fixtures = false
#    ENV["RAILS_ENV"] = "development"
#    ActiveRecord::Base.establish_connection(ENV["RAILS_ENV"])
#  end
# perdidele rizika  
#  def go_real
#    self.use_transactional_fixtures = false
#    ENV["RAILS_ENV"] = "production"
#    ActiveRecord::Base.establish_connection(ENV["RAILS_ENV"])
#  end
#  perdidele rizika
#  def go_for_test
#    self.use_transactional_fixtures = true
#    ENV["RAILS_ENV"] = "test" 
#    ActiveRecord::Base.establish_connection(ENV["RAILS_ENV"])
#  end

  def default_login_data(request)
    request.session[:first_name] = "Fake_name"
    request.session[:last_name] = "Fake_Last_Name"
    request.session[:items_per_page] = 50
    request.session[:lang] = 'en'
    request.session[:year_from] = '2007'
    request.session[:month_from] = '01'
    request.session[:day_from] = '01'
    request.session[:year_till] = '2010'
    request.session[:month_till] = '12'
    request.session[:day_till] = '30'
    request.session[:login] = true
    request.session[:manager_in_groups] = []
    request.session[:default_currency] = "USD"
    request.session[:show_currency] = "USD"
    
    return request
  end
  
  def login_as_admin (request)
    request = default_login_data(request)
    request.session[:usertype] = "admin"
    request.session[:user_id] = 0
    return request
  end
  
    def login_as_guest (request)
    request = default_login_data(request)
    request.session[:usertype] = nil
    request.session[:user_id] = nil
    request.session[:username] = nil
  end 
  
  def login_as_user (request)
    request = default_login_data(request)
    request.session[:usertype] = "user"
    request.session[:user_id] = 1
    request.session[:username] = "user"
  end 
  
  def login_as_reseller (request)
    request = default_login_data(request)
    request.session[:usertype] = "reseller"
    request.session[:user_id] = 2
    request.session[:username] = "reseller"
  end 
  
  def deny(condition, message)
    assert !condition , message
  end
  
  def assert_all_assigned(*vars)
    vars.each do |var|
      assert assigns(var), "Variable: '@#{var.to_s}' not assigned"
    end
  end

  # the 'integrated' way to login
  def login(user = 'admin', password = 'admin')
    old_controller = @controller
    @controller = CallcController.new
    post :try_to_login, :login => { :username => user, :psw => password} 
    assert_redirected_to :controller => "callc", :action => "main"
    assert_not_nil session[:user_id]
    assert_not_nil session[:usertype]
    @controller = old_controller
  end
end
