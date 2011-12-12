require File.dirname(__FILE__) + '/../test_helper'
require 'backups_controller'

class BackupsController; 
  def rescue_action(e) 
    raise e 
  end; 
end

class BackupsControllerTest < Test::Unit::TestCase
  def setup 
    @controller = BackupsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin(@request)
  end   
  
  def test_should_open_backup_manager_list
    get("backup_manager")
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    assert_select "img[alt='Add']",nil, "ERROR: Add icon not present."
  end  
  
  def test_should_open_new_backup
    get("backup_new")
    assert_select "form[action=/backups/backup_create][method=post]",nil, "ERROR: No form or it has incorect link." 
  end
  
end
