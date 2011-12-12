require File.dirname(__FILE__) + '/../test_helper'
require 'ivr_time_periods_controller'

# Re-raise errors caught by the controller.
class IvrTimePeriodsController; def rescue_action(e) raise e end; end

class IvrTimePeriodsControllerTest < Test::Unit::TestCase
  def setup
    @controller = IvrTimePeriodsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
