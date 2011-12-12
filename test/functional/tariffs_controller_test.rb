require File.dirname(__FILE__) + '/../test_helper'
require 'tariffs_controller'

class TariffsController;       
  def rescue_action(e) 
    raise e 
  end; 
end

class TariffsControllerTest < Test::Unit::TestCase
  def setup 
    @controller = TariffsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end
  
  def test_should_open_new_tariff_page_after_install
    login_as_admin(@request)
    get("new")
    assert_select "input.input",nil, "ERROR: Tariff name textfield is not present."
    assert_select "input[type=submit]",nil, "ERROR: Submit button is not present."
  end
  
  def test_shoul_open_tariff_menu_after_install
    login_as_admin(@request)
    get("list")
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    assert_select "img[alt='Delete']",nil, "ERROR: Delete icon not present."
    assert_select "img[alt='Add']",nil, "ERROR: Add icon not present."
  end
  
  def test_should_create_tariffs_after_install
    login_as_admin(@request)
    num1 = Tariff.count
    #tariff = {"purpose" => "user", "name" => 'user_tariff_1', "currency"=> 'EUR'}
    tariff = {}
    tariff["name"] = 'user_tariff_1'
    tariff["currency"] = 'EUR'
    
    tariff["purpose"] ="user"
    post("create", :tariff => tariff)
    
    post("create", :tariff => tariff)
    assert_equal @response.flash[:notice], "Tariff was not created", "ERROR: Tariff with the same name was created."
    
    tariff["purpose"] ="user_wholesale"
    post("create", :tariff => tariff)
    
    tariff["purpose"] ="provider"
    post("create", :tariff => tariff)
    
    num2 = Tariff.count
    assert_equal 3, num2-num1, "ERROR: Tariff count has not changed as expected."
  end
end
