require File.dirname(__FILE__) + '/../test_helper'
require 'services_controller'

class PaymentsController;       
  def rescue_action(e) 
    raise e 
  end; 
end

class ServicesControllerTest < Test::Unit::TestCase
  
  def setup 
    @controller = ServicesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end
  
  def test_should_open_list_menu_after_install
    login_as_admin(@request)
    a = get "list" 
    Confline.my_debug(a.body)
    assert_select "table.maintable",nil, "ERROR: Maintable is not pressent"
    assert_select "td.main_window",nil, "ERROR: Main window is not present"
  end
end