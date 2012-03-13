# -*- encoding : utf-8 -*-
class Cart < ActiveRecord::Base

    attr_reader :items
    attr_reader :total_price

  def initialize
    empty!
  end

  def empty!
    @items = []
    @total_price = 0.00
  end

  def add_product(cardgroup)   
    left = Card.count(:conditions => ["sold = 0 AND cardgroup_id = ?", cardgroup.id])
    
    for item_in_cart in @items do
      if item_in_cart.cardgroup_id == cardgroup.id
        left = left - 1
      end
    end
    if left > 0
      item = Cclineitem.for_cardgroup(cardgroup)
      @items << item 
      @total_price += cardgroup.price + cardgroup.get_tax.count_tax_amount(cardgroup.price)
      return true
    end 
    return false
  end

  def remove_item(cg_id)
    cardgroup = Cardgroup.find(:first, :include => [:tax], :conditions => ["cardgroups.id = ? ", cg_id])
    for item in @items
      if item.cardgroup_id.to_i == cg_id.to_i
        @items.delete(item)
        break
      end
    end
    @total_price -= cardgroup.price + cardgroup.get_tax.count_tax_amount(cardgroup.price)
  end
end
