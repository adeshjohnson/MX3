require File.dirname(__FILE__) + '/../test_helper'
require 'dialplans_controller'

# Re-raise errors caught by the controller.
class DialplansController; def rescue_action(e) raise e end; end

class DialplansControllerTest < Test::Unit::TestCase
  def setup
    @controller = DialplansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
