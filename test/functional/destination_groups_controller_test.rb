require File.dirname(__FILE__) + '/../test_helper'
require 'destination_groups_controller'

# Re-raise errors caught by the controller.
class DestinationGroupsController; def rescue_action(e) raise e end; end

class DestinationGroupsControllerTest < Test::Unit::TestCase
  def setup
    @controller = DestinationGroupsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
