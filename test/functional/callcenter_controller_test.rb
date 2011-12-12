require File.dirname(__FILE__) + '/../test_helper'
require 'callcenter_controller'

# Re-raise errors caught by the controller.
class CallcenterController; def rescue_action(e) raise e end; end

class CallcenterControllerTest < Test::Unit::TestCase
  def setup
    @controller = CallcenterController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
