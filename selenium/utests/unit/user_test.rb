require File.dirname(__FILE__) + '/../../../test/test_helper'

class UserTest < Test::Unit::TestCase

  def test_do_not_save_invalid_user
    user = User.new
    assert !user.valid?
    assert !user.save
  end

end
