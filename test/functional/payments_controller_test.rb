require File.dirname(__FILE__) + '/../test_helper'
require 'payments_controller'

class PaymentsController;       
  def rescue_action(e) 
    raise e 
  end; 
end

class PaymentsControllerTest < Test::Unit::TestCase
  
  def setup 
    @controller = PaymentsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end
  
  def test_should_open_list_menu_after_install
    login_as_admin(@request)
    get "list" 
    assert_select "table.maintable",nil, "ERROR: Maintable is not pressent"
    assert_select "td.main_window",nil, "ERROR: Main window is not present"
    assert_select "select#date_from_minute",nil, "ERROR: Date minute selector is not present"
  end
end