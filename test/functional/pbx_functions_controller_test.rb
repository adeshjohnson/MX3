require File.dirname(__FILE__) + '/../test_helper'
require 'pbx_functions_controller'

# Re-raise errors caught by the controller.
class PbxFunctionsController; def rescue_action(e) raise e end; end

class PbxFunctionsControllerTest < Test::Unit::TestCase
  def setup
    @controller = PbxFunctionsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
