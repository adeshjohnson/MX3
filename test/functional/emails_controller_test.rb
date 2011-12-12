require File.dirname(__FILE__) + '/../test_helper'
require 'emails_controller'

class EmailsController; 
  def rescue_action(e) 
    raise e 
  end; 
end

class EmailsControllerTest < Test::Unit::TestCase
  def setup 
    
    @controller = EmailsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin(@request)
  end   
   
  def test_should_open_email_list
    get("list")
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    assert_select "tr.row1", nil, "ERROR: No rows available."
    assert_select "img[alt='Add']",nil, "ERROR: Add icon not present."
  end
  
  def test_should_add_new_email_type
    get("new")
    assert_select "form[action=/emails/create][method=post]",nil, "ERROR: No form or it has incorect link."
    assert_select "input[type=submit]",nil, "ERROR: Submit button is not present." 
    email = {}
    email["name"]= "new_test_email"
    email["subject"]= "test_subject"
    email["body"]= "Hello all, <br> This is test E-mail. <br> Good luck :)"
    
    post("create", :email => email)
    assert_equal "Email was successfully created", flash[:notice], "ERROR: Flash notice message was not as expected."
    mail_in_db = Email.find(:first, :conditions => "name = 'new_test_email'")
    
    get("list")
    assert_select "img[alt='Delete']",nil, "ERROR: Delete icon not present."
    assert_select "img[alt='Edit']",nil, "ERROR: Edit icon not present."
    assert_select "img[title='Send']",nil, "ERROR: Send icon not present."
    assert_select "tr.row2", nil, "ERROR: No rows available." do
      assert_select "td[align=left]", {:test=>"new_test_email"}, "ERROR: No rows available."
      assert_select "td[align=left]", {:test=>"test_subject"}, "ERROR: No rows available."
    end
    
    get("edit", :id => mail_in_db.id)  
    assert_select "form[action=/emails/update/#{mail_in_db.id}][method=post]",nil, "ERROR: No form or it has incorect link."
    assert_select "input[type=submit]",nil, "ERROR: Submit button is not present."
    email["name"]= "Updated_test_email"
    email["subject"]= "Updated_test_subject"
    
    post("update", :id => mail_in_db.id, :email=>email)
    assert_equal "Email was successfully updated", flash[:notice], "ERROR: Flash notice message was not as expected." 
    
    get("list")
    assert_select "tr.row2", nil, "ERROR: No rows available." do
      assert_select "td[align=left]", {:test=>"Updated_test_email"}, "ERROR: No rows available."
      assert_select "td[align=left]", {:test=>"Updated_test_subject"}, "ERROR: No rows available."
    end
    
    post("destroy", :id => mail_in_db.id)
    assert_equal "Email deleted", flash[:notice], "ERROR: Flash notice message was not as expected."
  end
 
end
