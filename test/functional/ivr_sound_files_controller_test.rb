require File.dirname(__FILE__) + '/../test_helper'
require 'ivr_sound_files_controller'

# Re-raise errors caught by the controller.
class IvrSoundFilesController; def rescue_action(e) raise e end; end

class IvrSoundFilesControllerTest < Test::Unit::TestCase
  def setup
    @controller = IvrSoundFilesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
