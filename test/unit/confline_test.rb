require File.dirname(__FILE__) + '/../test_helper'

class ConflineTest < Test::Unit::TestCase
  def test_should_create_confline 
    confline = create
    assert confline.valid?, "Confline is not valid: \n #{confline.to_yaml}"    
  end
  
  def test_should_not_create_invalid_confline 
    confline = create(:name => "")
    deny confline.valid?, "Invalid confline should not pass: \n #{confline.to_yaml}"    
  end
  
  def test_should_set_and_get_correct_data
    Confline.set_value("Test_Confline","12")
    assert Confline.get_value("Test_Confline", 0).to_i == 12, "Confline should update propertly" 
    deny Confline.get_value("Test_Confline", 0).to_i == 13, "Confline should not get invalid values"
  end
 
  def confline_test
  end
  
private

  def create(options ={})
    Confline.create({
        :name => "Test_Confline",
        :value => "1"
      }.merge(options))
  end
end