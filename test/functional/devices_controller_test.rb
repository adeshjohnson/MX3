require File.dirname(__FILE__) + '/../test_helper'
require 'devices_controller'

class DevicesController; 
  def rescue_action(e) 
    raise e 
  end; 
end

class DevicesControllerTest < Test::Unit::TestCase
  def setup 
    @controller = DevicesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin(@request)
  end   
   
  def test_create_device    
    login_as_admin(@request) 
    @admin = User.find(0)
    assert_not_nil @admin, 'Admin was not found'
    get "new", :return_to_action=>"list", :return_to_controller => "users", :user_id => @admin.id
    assert_select "form[action=#{Web_Dir}/devices/create?user_id=#{@admin.id}]" ,nil, "Valid new device form not present."
    assert_select "input#device_description",nil , "Description field not present"
    dev = {}
    dev["description"] = "New_Device"
    dev["pin"] = "1234"
    dev["type"] = 'SIP'
    dev["name"] = 'Test_Device'
  end
  
  def test_create_new_device_delete_device    
    ##http://localhost:3000/devices/new?return_to_action=list&return_to_controller=users&user_id=1441
    login_as_admin(@request)   
    a = get "new", :return_to_action=>"list", :return_to_controller => "users", :user_id => 0
    Confline.my_debug(a.body)
    #flunk("Not yet implemented : test_create_new_device_delete_device")
  end
  
  def test_generate_invoice
    #http://localhost:3000/devices/new?return_to_action=list&return_to_controller=users&user_id=1441
    #flunk("Not yet implemented : test_generate_invoice")
  end
  
  def test_should_open_default_device_settings
    login_as_admin(@request)
    get("default_device")    
    assert_select "form[action=/devices/default_device_update][method=post]",nil, "ERROR: No form or it has incorect link."
    assert_select "input[type=submit]",nil, "ERROR: Submit button is not present."
  end
  
  def test_should_save_default_device_settings
    login_as_admin(@request)
# NOTE check_box sends no data if not checked
    codec ={} 
    codec["alaw"]="1" 
#    codec["ulaw"]="1" 
#    codec["g726"]="1" 
#    codec["g723"]="1" 
    codec["g729"]="1" 
#    codec["gsm"]="1" 
#    codec["ilbc"]="1" 
#    codec["lpc10"]="1" 
#    codec["speex"]="1" 
#    codec["adpcm"]="1" 
#    codec["slin"]="1" 
#    codec["h261"]="1" 
#    codec["h263"]="1" 
#    codec["h263p"]="1" 
#    codec["h264"]="1" 

    dev = {}
    dev["device_type"] = "SIP"
    dev["dtmfmode"] = "rfc2833"
    dev["works_not_logged"] = "1"
    dev["location_id"]= "1"
    dev["record"] = "0"
    dev["nat"] = "yes"
    dev["voicemail_active"] = "0"
    dev["trustrpid"] = "no"
    dev["sendrpid"] = "no"
    dev["t38pt_udptl"] = "no"
    dev["promiscredir"] = "no"
    dev["progressinband"] = "no"
    dev["videosupport"] = "no"
    dev["allow_duplicate_calls"] = "no"
    dev["tell_balance"] = "no"
    dev["tell_time"] = "no"
    dev["tell_rtime_when_left"] = "60"
    dev["repeat_rtime_every"] = "60"

    post("default_device_update",
      :device => dev,
      :codec => codec,
      :device_timeout=> "60",
      :runk => "0",
      :call_limit => "0" ,
      :cid_name =>"" ,
      :cid_number =>"", 
      :host => "dynamic", 
      :dynamic_check =>"1",
      :canreinvite => "no",
      :qualify => "yes",
      :qualify_time => "2000",
      :callgroup => "",
      :pickupgroup => "",
      :vm_email => "",
      :vm_psw => "",
      :ip1=>"0.0.0.0" ,
      :mask1=>"0.0.0.0", 
      :ip2=>"",
      :mask2=>"",
      :ip3=>"",
      :mask3=>"",
      :fromuser => "",
      :fromdomain => ""
#      :insecure_port => "1",
#      :insecure_invite => "1"
#      :process_sipchaninfo => "1"
    )
    assert_equal "Settings_Saved", flash[:notice], "ERROR: Flash message was not correct."
  end
  
  def test_save_voice_mail
    #flunk("Not yet implemented : test_save_voice_mail")
  end
  
  def test_call_graphs
    #flunk("Not yet implemented : test_call_graphs")
  end
  
  def test_show_user_records
    #flunk("Not yet implemented : test_show_user_records")
  end
  
  def test_calls_menu
    #flunk("Not yet implemented : test_calls_menu")
  end
  
  def test_callflow
    login_as_admin(@request)
    
    get "callflow", :id => 2
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    assert_select "tr.row1", nil, "ERROR: No rows available."
    assert_select "img[alt='Edit']",nil, "ERROR: Edit icon not present."
    assert_select "img[alt='User']",nil, "ERROR: User icon not present."
    assert_select "img[alt='Device']",nil, "ERROR: Device icon not present."
    assert_select "img[alt='Asterisk']",nil, "ERROR: Asterisk icon not present."
    assert_select "a[href='/users/edit/2']",nil, "ERROR: Link was not found."
    assert_select "a[href='/devices/device_edit/2']",nil, "ERROR: Link was not found."
    assert_select "a[href='/devices/device_extlines/2']",nil, "ERROR: Link was not found."
    assert_select "tr.row1",nil, "ERROR: tr.row1 does not exists." do |e|
      assert_select "td[align=center]",{:text => "Before Call", :count => 1}, "ERROR: Name is not corret."
      assert_select "td[align=center]",{:text => "Answered", :count => 1}, "ERROR: Name is not corret."
      assert_select "td[align=center]",{:text => "Busy", :count => 1}, "ERROR: Name is not corret."
    end
    assert_select "tr.row2",nil, "ERROR: tr.row2 does not exists." do |e|
      assert_select "td[align=center]",{:text => "Call", :count => 1}, "ERROR: Name is not corret."
      assert_select "td[align=center]",{:text => "No Answer", :count => 1}, "ERROR: Name is not corret."
      assert_select "td[align=center]",{:text => "Failed", :count => 1}, "ERROR: Name is not corret."
    end

   get "callflow_edit", :id => 2, :cft => 'before_call'
     
     assert_select "img[alt='Edit']",nil, "ERROR: Edit icon not present."
     assert_select "img[alt='User']",nil, "ERROR: User icon not present."
     assert_select "img[alt='Device']",nil, "ERROR: Device icon not present."
     assert_select "img[alt='Asterisk']",nil, "ERROR: Asterisk icon not present."
     assert_select "a[href='/users/edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_extlines/2']",nil, "ERROR: Link was not found."
     assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
     assert_select "tr.row1",nil, "ERROR: tr.row1 does not exists." do |e|
        assert_select "form[method=post]",nil, "ERROR: No form or it has incorect link." 
        assert_select "input[type=image]",nil, "ERROR: Submit button is not present."
     end
     
   cf=Callflow.find(:first)
   serv = Server.find(:first)
   serv.active = 0
   serv.save
   
    did=Did.new
    did.device_id = 2
    did.did = '000004343434'
    did.save
   
  get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_action', :cf_action=>'forward', :cf =>cf.id 
     
     assert_select "img[alt='Edit']",nil, "ERROR: Edit icon not present."
     assert_select "img[alt='User']",nil, "ERROR: User icon not present."
     assert_select "img[alt='Device']",nil, "ERROR: Device icon not present."
     assert_select "img[alt='Asterisk']",nil, "ERROR: Asterisk icon not present."
     assert_select "a[href='/users/edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_extlines/2']",nil, "ERROR: Link was not found."
     assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
     assert_select "tr.row1",nil, "ERROR: tr.row1 does not exists." do |e|
        assert_select "form[method=post]",nil, "ERROR: No form or it has incorect link." 
        assert_select "input[type=image]",nil, "ERROR: Submit button is not present."
        assert_select "input[name=cf_data]",nil, "ERROR: Radio buton is not present."
        assert_select "select[name=device_id]",nil, "ERROR: Select is not present."
        assert_select "input[name=ext_number]",nil, "ERROR: Input field is not present."
        assert_select "input[name=cf_data3]",nil, "ERROR: Radio buton is not present."
        assert_select "input[name=cf_data4]",nil, "ERROR: Input field is not present."
        assert_select "input[type=submit]",nil, "ERROR: Submit button is not present."
        assert_select "select[name=did_id]",nil, "ERROR: Select is not present."
    end  
    
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_local_device', :cf_action=>'forward', :cf =>cf.id , :cf_data=>5, :device_id=>3 
     assert_equal "Call Flow updated", flash[:notice] 
   
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_local_device', :cf_action=>'forward', :cf =>cf.id , :cf_data=>5, :device_id=>""
     assert_equal "Please select device", flash[:notice]
    
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_local_device',  :cf_action=>'forward', :cf =>cf.id , :cf_data3=>3, :did_id=>3 
     assert_equal "Call Flow updated", flash[:notice] 

   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_local_device',  :cf_action=>'forward', :cf =>cf.id , :cf_data3=>2
     assert_select "tr.row1",nil, "ERROR: tr.row1 does not exists." do |e|
       assert_select "td[class=border_disabled]",{:text => "Unchanged", :count => 1}, "ERROR: Name is not corret."
     end
     assert_equal "Call Flow updated", flash[:notice]    
    
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_local_device',  :cf =>cf.id , :cf_data3=>1
     assert_select "tr.row1",nil, "ERROR: tr.row1 does not exists." do |e|
       assert_select "td[class=border_disabled]",{:text => "From_device:", :count => 1}, "ERROR: Name is not corret."
     end
     assert_equal "Call Flow updated", flash[:notice]  
    
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_local_device',  :cf =>cf.id , :cf_data3=>4, :cf_data4=>4 
     assert_equal "Call Flow updated", flash[:notice]  
    
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_action', :cf_action=>'voicemail', :cf =>cf.id 
    
     assert_select "img[alt='Edit']",nil, "ERROR: Edit icon not present."
     assert_select "img[alt='User']",nil, "ERROR: User icon not present."
     assert_select "img[alt='Device']",nil, "ERROR: Device icon not present."
     assert_select "img[alt='Asterisk']",nil, "ERROR: Asterisk icon not present."
     assert_select "a[href='/users/edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_extlines/2']",nil, "ERROR: Link was not found."
     assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
     assert_select "tr.row1",nil, "ERROR: tr.row1 does not exists." do |e|
        assert_select "form[method=post]",nil, "ERROR: No form or it has incorect link." 
        assert_select "input[type=image]",nil, "ERROR: Submit button is not present."
       
    end  
    
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_action', :cf_action=>'fax_detect', :cf =>cf.id 
    
     assert_select "img[alt='Edit']",nil, "ERROR: Edit icon not present."
     assert_select "img[alt='User']",nil, "ERROR: User icon not present."
     assert_select "img[alt='Device']",nil, "ERROR: Device icon not present."
     assert_select "img[alt='Asterisk']",nil, "ERROR: Asterisk icon not present."
     assert_select "a[href='/users/edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_edit/2']",nil, "ERROR: Link was not found."
     assert_select "a[href='/devices/device_extlines/2']",nil, "ERROR: Link was not found."
     assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
     assert_select "tr.row1",nil, "ERROR: tr.row1 does not exists." do |e|
        assert_select "form[method=post]",nil, "ERROR: No form or it has incorect link." 
        assert_select "input[type=image]",nil, "ERROR: Submit button is not present."
        assert_select "select[name=device_id]",nil, "ERROR: Select is not present."
    end   
    
   get "callflow_edit", :id => 2, :cft => 'before_call', :whattodo => 'change_fax_device', :cf_action=>'fax_detect', :cf =>cf.id , :device_id=>3
     assert_equal "Call Flow updated", flash[:notice]

    
  end
  
end
