require File.dirname(__FILE__) + '/../test_helper'
require 'c2c_controller'

# Re-raise errors caught by the controller.
class C2cController; 
  # Raises exceptions that were raised by controller. So no errors are lost.
  def rescue_action(e) 
    raise e 
  end; 
end

class C2cControllerTest < Test::Unit::TestCase
  def setup
    @controller = C2cController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  #empty test
  def test_truth
    assert true
  end
end
