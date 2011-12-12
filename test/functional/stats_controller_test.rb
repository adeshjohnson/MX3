require File.dirname(__FILE__) + '/../test_helper'
require 'stats_controller'

class StatsController;       
  def rescue_action(e) 
    raise e 
  end; 
end

class StatsControllerTest < Test::Unit::TestCase
  
  def setup 
    @controller = StatsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new 
    @request = login_as_admin(@request)
    #Confline.set_value("Items_Per_Page", 4)
  end
  
  def test_should_open_graps_after_install
    get "all_users_detailed"
    assert_select "table.maintable",nil, "ERROR: Maintable is not present" 
    assert_select "tr.row1",nil, "ERROR: ROW1 is not present."  
    assert_select "tr.row2",nil, "ERROR: ROW2 is not present." 
    assert_select "div#flashcontent1",nil, "ERROR: Flash 1 is not present." 
    assert_select "div#flashcontent2",nil, "ERROR: Flash 2 is not present." 
    assert_select "div#flashcontent3",nil, "ERROR: Flash 3 is not present." 
    assert_select "div#flashcontent4",nil, "ERROR: Flash 4 is not present." 
    assert_select "div#flashcontent5",nil, "ERROR: Flash 5 is not present."
  end
  
  def test_should_open_calls_list_after_install
    get "call_list"
    assert_select "div#topbck",nil, "ERROR: No top back item."
    assert_select "td.main_window",nil, "ERROR: Main Window is not present." 
    assert_select "img[alt='Money_dollar']",nil, "ERROR: Money icon not present."
  end
  
  def test_should_open_last_calls_stats_after_install
    get "last_calls_stats"    
    assert_select "div#topbck",nil, "ERROR: No top back item."
    assert_select "td.main_window",nil, "ERROR: Main Window is not present." 
    #assert_select "table.maintable",nil, "ERROR: Maintable is not present." lenteles nera jei nera nei 1 skambucio
  end
  
  def test_should_open_action_log
    login_as_admin(@request)
    get("action_log", :user_id =>"-1", :processed=> "-1", :action_type=> "all")
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    MorLog.my_debug(@response.body)
  end
end