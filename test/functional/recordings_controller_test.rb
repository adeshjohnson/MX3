require File.dirname(__FILE__) + '/../test_helper'
require 'recordings_controller'

class RecordingsController;       
  def rescue_action(e) 
    raise e 
  end; 
end

class StatsControllerTest < Test::Unit::TestCase
  
  def setup 
    @controller = RecordingsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end
  
  def test_should_show_recording_after_install
    login_as_admin(@request)
    get "setup"
    assert_select "table.maintable",nil, "ERROR: Maintable is not present" 
    assert_select "div.nb",nil, "ERROR: No 'NB' - normal/bold text."
    assert_select "td.main_window",nil, "ERROR: Main Window is not present."    
    get("show", :show_rec=>'2')
    assert_select "td.main_window",nil, "ERROR: Main Window is not present."
    assert_select "img[alt='User']",nil, "ERROR: User icon not present."
    assert_select "img[alt='Device']",nil, "ERROR: Device icon not present."
    assert_select "div#topbck",nil, "ERROR: No top back item."
    assert_select "div.nb",nil, "ERROR: No 'NB' - normal/bold text."
  end
  
end