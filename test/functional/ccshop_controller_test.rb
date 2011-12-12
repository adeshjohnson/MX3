require File.dirname(__FILE__) + '/../test_helper'
require 'ccshop_controller'

class CcshopController; 
  def rescue_action(e) 
    raise e 
  end; 
end

class CcshopControllerTest < Test::Unit::TestCase
 
  def setup 
    @controller = CcshopController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end 
  
  def test_should_show_index_after_install
    @request.session[:lang] = 'en'
    get "index"
    assert_select "td.left_menu", nil, "ERROR: Left menu is not present."
  end
  
  def test_should_open_call_list
    @request.session[:lang] = 'en'
    @request.session[:card_id] = 1
    get 'call_list'
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    assert_select "td.n[align=right]",nil,"ERROR: Table has no data."  do
    assert_select"td.n[align=right]" ,{:text => "22.22"},"ERROR: Table data has no number 22.22."
    end
  end
end