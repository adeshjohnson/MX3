class Terminator < ActiveRecord::Base
  attr_protected :user_id
  has_many :providers
  belongs_to :user
end

