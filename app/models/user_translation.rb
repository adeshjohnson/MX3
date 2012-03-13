# -*- encoding : utf-8 -*-
class UserTranslation < ActiveRecord::Base
  belongs_to :user
  belongs_to :translation

  def UserTranslation.get_active
    UserTranslation.find(:all, :conditions=>"active=1 and user_id = #{User.current.id}")
  end
end
