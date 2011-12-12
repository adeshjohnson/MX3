require File.dirname(__FILE__) + '/../test_helper'
require 'functions_controller'

class FunctionsController; 
  def rescue_action(e) 
    raise e 
  end; 
end

class FunctionsControllerTest < Test::Unit::TestCase
  
  def setup 
    @controller = FunctionsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin(@request)
  end 
  
  def test_settings_should_be_visible_only_for_admin_after_install
    #testing without login data aka guest.
    login_as_guest(@request)
    get "settings"
    assert_redirected_to :controller => "callc", :action=>"login"
    login_as_admin(@request)
    get "settings"
    assert_select "div.dhtmlgoodies_aTab", nil, "Menu elements are not present."
    assert_select "div#dhtmlgoodies_tabView1", nil, "Menu is not present." 
    assert_select "form[action=/functions/settings_change]" ,nil, "Form not present."
    login_as_user(@request)
    get "settings"
    assert_redirected_to :controller => "callc", :action=>"login"
    assert_equal "You are not authorized to view this page", flash[:notice]    
  end
  
  def test_settings_save_should_work_after_install
    get "settings"
    assert_select "div.dhtmlgoodies_aTab", nil, "Menu elements are not present."
    assert_select "div#dhtmlgoodies_tabView1", nil, "Menu is not present." 
    assert_select "form[action=/functions/settings_change]" ,nil, "Form not present."
    login_as_admin(@request)
    post("settings_change",
      #Globals
      :company => 'KolmiSoft',
      :company_email => 'kolmitest@gmail.com',
      :version => 'MOR 0.6 PRO',
      :copyright_title => ' by <a href=\'http://www.kolmisoft.com\' target=\"_blank\">KolmiSoft </a> 2006-2008',
      :admin_browser_title => 'MOR PRO 0.6',
       #Registration

      :registration_enabled => '1',
      :tariff_for_registered_users => '2',
      :lcr_for_registered_users => '1',
      :default_vat_percent => '18',
      :default_country_id => '123',
      :asterisk_server_ip => '111.222.333.444',
      :default_cid_name => '',
      :default_cid_number => '',
      :send_email_to_user_after_registration => '1',
      :send_email_to_admin_after_registration => '1',
      :allow_user_to_enter_vat => '0',
      
      #Invoices
    
      :invoice_number_start => 'INV',
      :invoice_number_lengt => '9',
      :invoice_number_type => '2',
      :invoice_period_start_day => '01',
      :invoice_show_calls_in_detailed => '1',
      :invoice_address_format => '2',
      :invoice_address1 => 'Street Address',
      :invoice_address2 => 'City, Country',
      :invoice_address3 => 'Phone, fax',
      :invoice_address4 => 'Web, email',
      :invoice_bank_details_line1 => 'Please make payments to:',
      :invoice_bank_details_line2 => 'Company name',
      :invoice_bank_details_line3 => 'Bank name',
      :invoice_bank_details_line4  => 'Bank account number',
      :invoice_bank_details_line5  => 'Add. info',
      :invoice_end_title      => 'Thank you for your business!',
      :i1 => '0',
      :i2 => '0',
      :i3 => '0',
      :i4 => '0',
      :i5 => '0',
      :i6 => '0',
    
      #WEB Callback

      :cb_active    => '1',
      :cb_maxretries  => '0', 
      :cb_retrytime  => '10',
      :cb_waittime    => '20',
      :web_callback_cid => '',    
      
      #Emails
      
      :email_sending_enabled    => '',      
      :email_smtp_server     => 'smtp.gmail.com', 
      :email_domain     => 'localhost.localdomain',
      :email_login     => 'kolmitest',
      :email_password     => 'kolmitest99',
      :email_batch_size    => '50',  
      :email_from => '',
      :time => '',
     
      :colorfield1     => '',     
      :usual_text_font_size => '',
      :style1 => '',
      :style2 => '',
      :style3 => '',
      
      :colorfield2 => '',
      :style4 => '',
      :style5 => '',
      :style6 => '',
      
      :usual_text_highlighted_text_size => '',
      :colorfield3 => '',
      :h_f_font_size => '',
      :style7 => '',
      :style8 => '',
      :style9 => '',
      :colorfield4 => '',
      :colorfield5 => '',
      :colorfield6 => '',
      :colorfield7 => '',
      #Various

      :c2c_active  => '1',
      :user_wholesale_enabled => '1',
      :days_for_did_close => '90',
      :agreement_number_length => '10',
      :nice_number_digits => '2',
      :items_per_page => '50',
      :device_pin_length  => '6',
      :fax_device_enabled   => '1',
      :email_fax_from_sender  => 'fax@some.domain.com', 
      :change_zap  => '0',
      :change_zap_to => 'PSTN',

      :device_range_min => '104',     
      :device_range_max => '9999',
      :ad_sound_folder => '/home/mor/public/ad_sounds',
      :csv_separator => ',',
      :csv_decimal => '.',

      :XML_API_Extension => '',
      :active_calls_max => '100',
      :active_calls_interval => '5',
      :gm_fullscreen => '0',
      :gm_reload_time => '15',
      :gm_width => '640',
      :gm_height => '480'
    )
    assert_redirected_to :controller => "functions", :action=>"settings"
    login_as_admin(@request)
    get "settings"    
    assert_select "div.dhtmlgoodies_aTab", nil, "Menu elements are not present."
    assert_select "div#dhtmlgoodies_tabView1", nil, "Menu is not present." 
    assert_select "form[action=/functions/settings_change]" ,nil, "Form not present."
  end
  
    
  def test_should_open_payments_settings
    get("settings_payments")
    assert_select "form[action=/functions/settings_payments_change][method=post]",nil, "ERROR: No form or it has incorect link."
    assert_select "input[type=submit]",nil, "ERROR: Submit button is not present."
  end
  
  def test_should_save_payments_settings
    post("settings_payments_change",
      :vouchers_enabled => "1",
      :voucher_number_length => "15",
      :voucher_disable_time => "60",
      :voucher_attempts_to_enter => "3",
      :paypal_enabled => "1",
      :paypal_email => "sales@bla.com",
      :paypal_default_currency => "EUR",
      :paypal_default_amount => "10",
      :paypal_min_amount => "5",
      :paypal_test => "1",
      :webmoney_enabled => "1",
      :webmoney_purse => "Z616776332783",
      :webmoney_default_currency => "EUR",
      :webmoney_default_amount => "10",
      :webmoney_min_amount => "5",
      :webmoney_test => "1",
      :webmoney_sim_mode => "1",
      :webmoney_secret_key => "secret",
      :linkpoint_enabled => "1",
      :linkpoint_storeid => "",
      :linkpoint_default_currency => "EUR",
      :linkpoint_default_amount => "",
      :linkpoint_min_amount => "",
      :cyberplat_enabled => "1",
      :cyberplat_test => "1",
      :cyberplat_default_currency => "EUR",
      :cyberplat_default_amount => "10",
      :cyberplat_min_amount => "5",
      :cyberplat_transaction_fee => "3",
      :cyberplat_shopip => "11.22.33.44",
      :cyberplat_disabled_info => "Cyberplat disabled",
      :cyberplat_crap => "Some cyberplat info"
    )
    assert_equal "Settings saved", flash[:notice]  
  end
  
  def test_set_and_change_back_logo_after_install
    get("settings_logo")
    assert_select "form[action=/functions/settings_logo_save]", nil, "Form not present."
    post("settings_logo_save",
      :logo =>""
    )
    assert_redirected_to :controller => "functions", :action=>"settings_logo"
    assert_equal "Zero size file", flash[:notice]   
    post("settings_logo_save",
      :logo =>ActionController::TestUploadedFile.new(Test::Unit::TestCase.fixture_path + '../../public/images/rails.png', 'image/png')
    )
    
    assert_equal "Logo uploaded", flash[:notice]
    assert File.exist?(Test::Unit::TestCase.fixture_path + '../../public/images/rails.png'), "Logo file 'rails.png' do not exists"
    assert_equal Confline.get_value("Logo_Picture"), "logo/rails.png", "Confline for logo is not correct."
    
    post("settings_logo_save",
      :logo =>ActionController::TestUploadedFile.new(Test::Unit::TestCase.fixture_path + '../../public/images/logo/mor_logo.png', 'image/png')
    )
    assert_equal "Logo uploaded", flash[:notice], 'Logo was not uploaded correctly.'
    assert File.exist?(Test::Unit::TestCase.fixture_path + '../../public/images/logo/mor_logo.png'), "Logo file 'mor_logo.png' do not exists"
    assert_equal Confline.get_value("Logo_Picture"), "logo/mor_logo.png", "Confline for logo is not correct."   
  end
  
  def test_should_open_translations_after_install
    get("translations")
    assert_select "td.left_menu", nil, "ERROR: Left menu is not present."
    assert_select "ul#sortable_list", nil, "ERROR: Sortable list is not pressent."
  end
  
  def test_should_open_currencies_window
    get("currencies")
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    assert_select "form[action=/functions/currency_add][method=post]",nil, "ERROR: No form or it has incorect link."
  end
  
  def test_should_create_new_currency   
    post("currency_add")
    assert_equal "Please enter details", flash[:notice]  
    post("currency_add", :name=> "TUG", :full_name => "Voiplandijos tugrikas", :exchange_rate => "0.5")    
    tug = Currency.find(:first, :conditions => "name = 'TUG'")
    assert_equal "Currency created", flash[:notice]
    get("currencies")
    assert_select "img[alt='Delete']",nil, "ERROR: Delete icon not present."
    assert_select "input[type=image][title=Disable]",nil, "ERROR: Disable icon is not present."
    assert_select "form[action=/functions/currencies_change_status/#{tug.id}][method=post]",nil, "ERROR: No form or it has incorect link."
    post("currencies_change_status", :id => tug.id)
    assert_equal "Currency disabled", flash[:notice]    
    post("currencies_change_status", :id => tug.id)
    assert_equal "Currency enabled", flash[:notice]
    post("currencies_change_update_status", :id => tug.id)
    assert_equal "Currency update disabled", flash[:notice] 
    
    get("currency_edit", :id => tug.id)
    assert_select "table.maintable",nil, "ERROR: Maintable is not present."
    assert_select "img[alt='Edit']",nil, "ERROR: Edit icon not present."
    post("currency_update", :id =>tug.id, :full_name=> "Voiplandijos tugrikas updated", :exchange_rate=>"1.5")
    assert_equal "Currency details updated", flash[:notice]
    get("currencies")
    assert_select "tr.row2",nil, "ERROR: tr.row2 does not exists." do |e|
      assert_select "td[align=left]",{:text => "Voiplandijos tugrikas updated", :count => 1}, "ERROR: Name is not corret."
    end
    assert_select "td[align=right]",{:text => "1.5"}, "ERROR: Number is not corret."
    
    post("currencies_change_update_status", :id => tug.id)
    assert_equal "Currency update enabled", flash[:notice] 
    post("currency_destroy", :id=>tug.id)
    assert_equal "Currency deleted", flash[:notice]
  end
end