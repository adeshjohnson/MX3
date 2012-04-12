# -*- encoding : utf-8 -*-
class Ivr < ActiveRecord::Base
  has_many :ivr_blocks, :dependent => :destroy
  belongs_to :user

  before_create :ivr_before_create

  def ivr_before_create
    self.user_id = User.current.id
  end

  def start_block
    IvrBlock.find(:first, :include => [:ivr_extensions, :ivr_actions], :conditions => ["ivr_blocks.id = ?", self.start_block_id])
  end
end
