require File.dirname(__FILE__) + '/../test_helper'
require 'ivr_voices_controller'

# Re-raise errors caught by the controller.
class IvrVoicesController; def rescue_action(e) raise e end; end

class IvrVoicesControllerTest < Test::Unit::TestCase
  def setup
    @controller = IvrVoicesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
