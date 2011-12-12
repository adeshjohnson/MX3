class IvrExtension < ActiveRecord::Base
  belongs_to :ivr_block
  
  def goto_ivr_block
    IvrBlock.find(:first, :conditions => "id = #{self.goto_ivr_block_id}")
  end
  
end