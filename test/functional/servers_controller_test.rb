require File.dirname(__FILE__) + '/../test_helper'
require 'servers_controller'

class ServersController;       
  def rescue_action(e) 
    raise e 
  end; 
end

class ServersControllerTest < Test::Unit::TestCase
  def setup 
    @controller = ServersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new  
    login_as_admin(@request)  
  end
  
  def test_should_open_servers_list
    get("list")
    assert_select "table.maintable",nil, "ERROR: Maintable is not present." 
    assert_select "td.main_window",nil, "ERROR: Main Window is not present." 
    assert_select "img[alt='Delete']",nil, "ERROR: Delete icon not present."
    assert_select "img[alt='Edit']",nil, "ERROR: Delete icon not present."
  end
  
  def  test_should_change_server_status
    @server = Server.find(1)
    @server.active = 1
    @server.save
    get("list")
    assert_select "input[title=Disable][type=image]",nil, "ERROR: Disable icon is not present."  
    post("server_change_status", :id =>1)
    get("list")
    assert_select "input[title=Enable][type=image]",nil, "ERROR: Enable icon is not present."
  end
  
  def test_should_delete_server
    get("list")
    assert @response.body.index("<td>1</td>")!= nil, "ERROR: ID = 1 was not on page"
    post("destroy", :id => 1)
    get("list")
    assert @response.body.index("<td>1</td>")== nil, "ERROR: ID = 1 was not on page"
  end
  
  def test_should_open_server_edit_form
    username = "mor_username"
    get('edit', :id => 1)
    assert_select "form[action=/servers/server_update/1]",nil, "ERROR: Form is not present."
    assert_select "input[type=submit]",nil, "ERROR: Submit button is not present."
    post("server_update", 
      :id => 1,
      :server_id => 1,
      :server_hostname =>"",
      :server_ip =>"81.16.232.110",
      :server_url =>"",
      :server_type =>"",  
      :server_maxcalllimit=>"1000",
      :server_ami_username=>username,
      :server_ami_secret=>"morsecret",
      :server_port=>"5060",
      :server_comment =>"",
      :server_ssh_username=>"root",
      :server_ssh_secret =>"",
      :server_ssh_port=>"22"
    )
    get("list")
    assert_select "img[alt='Delete']",nil, "ERROR: Delete icon not present."
    assert_select "img[alt='Edit']",nil, "ERROR: Delete icon not present."
    assert_select "tr.row1",nil, "ERROR: Row1 is not present."  do
      assert_select("td[align=left]",{:count => 2}, "ERROR: No left aligned elements were found.") do
        assert_select("td[align=left]",{:text=>"mor_username"}, "ERROR: Username was not updated.")
      end
    end
  end
  
  def test_should_add_new_server
    login_as_admin(@request)  
    post("server_add", 
      :server_id => 15,
      :server_hostname =>"",
      :server_ip =>"11.22.33.44",
      :server_url =>"",
      :server_type =>"",  
      :server_maxcalllimit=>"1000",
      :server_ami_username=>"test_  mor_username",
      :server_ami_secret=>"morsecret",
      :port=>"5060",
      :server_comment =>"",
      :server_ssh_username=>"root",
      :server_ssh_secret =>"",
      :server_ssh_port=>"22"
    )
    get("list")
    assert @response.body.indtop("<td>15</td>")!= nil, "ERROR: ID = 15 was not on page."
    assert @response.body.index("<td>11.22.33.44</td>")!= nil, "ERROR: Server_ip = 11.22.33.44 was not on page."
  end
  
  def test_should_allow_set_server_providers
    get("server_providers", :id=>1)
    assert_select("option[value=1]",{:text=>"Test Provider"},"ERROR: Test Provider with ID=1 is not present.")
    post("add_provider_to_server", :id => 1, :provider_add => 1)
    get("server_providers", :id=>1)
    MorLog.my_debug(@response.body)
    assert_select("option[value=1]",{:text=>"Test Provider", :count => 0},"ERROR: Test Provider with ID=1 is not present.")
    assert @response.body.index("<td>1</td>")!= nil, "ERROR: ID = 1 was not on page."
    assert @response.body.index("<td><a href=\"/providers/edit/1\">Test Provider</a></td>")!= nil, "ERROR: Provider was not on page as added/"
    
  end
  
end
