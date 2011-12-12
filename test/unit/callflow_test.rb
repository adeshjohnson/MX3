require File.dirname(__FILE__) + '/../test_helper'

class CallflowTest < Test::Unit::TestCase
  
  #fixtures :callflows
  
  
  
  def test_should_not_create_invalid_callflow
    callflow = create(:device_id=>nil)
    deny !callflow.valid?, "Invalid callflow should not pass: \n #{callflow.to_yaml}"    
  end
  
  def test_should_create_callflow 
    callflow = create
    assert callflow.valid?, "Callflow is not valid: \n #{callflow.to_yaml}"    
  end
  
  def test_should_set_and_get_correct_data
    callflow = create
    callflow.device_id = 120 
    assert callflow.save
    
    assert callflow.device_id.to_i == 120, "Callflow should update propertly" 
    deny callflow.device_id.to_i != 120, "Callflow should not get invalid values"

  end
 
  
private

  def create(options ={})
    Callflow.new({
        :device_id =>100,
        :cf_type => "before_call",
        :priority => "1",
        :action =>"empty"
      }.merge(options))
    
  end
end