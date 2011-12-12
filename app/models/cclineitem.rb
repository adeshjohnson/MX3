class Cclineitem < ActiveRecord::Base

    belongs_to :cardgroup
    belongs_to :ccorder , :dependent => :destroy
    belongs_to :card 

  def self.for_cardgroup(cardgroup)
	  item = self.new(:quantity => 1, :cardgroup => cardgroup, :price => cardgroup.price)
    item
  end 

end
