require File.dirname(__FILE__) + '/../test_helper'
require 'accounting_controller'

class AccountingController;       
  def rescue_action(e) 
    raise e 
  end; 
end

class FunctionsControllerTest < Test::Unit::TestCase
  def setup
    @controller = AccountingController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end
  
  def test_should_open_vouchers_menu_after_install
    login_as_admin(@request)
    get "vouchers" 
    assert_select "table.maintable",nil, "ERROR: Maintable is not pressent."
    assert_select "td.main_window",nil, "ERROR: Main window is not present."
  end
  
  def test_should_open_invoices_menu_after_install
    login_as_admin(@request)
    get "invoices" 
    assert_select "table.maintable",nil, "ERROR: Maintable is not pressent."
    assert_select "td.main_window",nil, "ERROR: Main window is not present."
  end
  
  def test_should_open_generate_invoices_after_install
    MorLog.my_debug("test_should_open_generate_invoices_after_install")
    login_as_admin(@request)
    get "generate_invoices"
    MorLog.my_debug("some")
    assert_select "td.main_window",nil, "ERROR: Main window is not present."
    assert_select "form[action=/accounting/generate_invoices_status]" ,nil, "ERROR: Form not present. # or maybe developer made some mistakes. Contact Martynas."
    date = {}
    date["year"] = Time.now.year.to_s
    date["month"] = Time.now.month.to_s
    post("generate_invoices_status",
      :date => date,
      :postpaid => "1"
    )
    MorLog.my_debug("some3")
    assert_select "div.nb",nil, "ERROR: No 'NB' - normal/bold text."
    assert_select "div#topbck",nil, "ERROR: No top back item."   
  end
  
  def test_should_generate_test_pdf_after_install
    login_as_admin(@request)
    get "generate_test_pdf"
  end 
end