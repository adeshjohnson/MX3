require File.dirname(__FILE__) + '/../test_helper'
require 'cron_actions_controller'

# Re-raise errors caught by the controller.
class CronActionsController; def rescue_action(e) raise e end; end

class CronActionsControllerTest < Test::Unit::TestCase
  def setup
    @controller = CronActionsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
