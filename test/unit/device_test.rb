require File.dirname(__FILE__) + '/../test_helper'

class ConflineTest < Test::Unit::TestCase
  
  def test_should_not_save_device_with_same_username
    dev = Device.find(:first)
    dev2 = dev.clone
    dev2.extension = dev2.extension + dev2.extension
    deny dev2.save, "ERROR: Should not save device with same user name"
    dev2.username = "unique_new_username"
    
#    MorLog.my_debug(dev2.errors.to_yaml)
    assert_valid dev2
    MorLog.my_debug("Check")
    MorLog.my_debug(dev2.check_username_uniqueness)
    assert dev2.save, "ERROR: Should create device with different username"
  end
  
#  EXAMPLES:
#  def test_should_create_confline 
#    confline = create
#    assert confline.valid?, "Confline is not valid: \n #{confline.to_yaml}"    
#  end
#  
#  def test_should_not_create_invalid_confline 
#    confline = create(:name => "")
#    deny confline.valid?, "Invalid confline should not pass: \n #{confline.to_yaml}"    
#  end
#  
#  def test_should_set_and_get_correct_data
#    Confline.set_value("Test_Confline","12")
#    assert Confline.get_value("Test_Confline", 0).to_i == 12, "Confline should update propertly" 
#    deny Confline.get_value("Test_Confline", 0).to_i == 13, "Confline should not get invalid values"
#  end
 
end