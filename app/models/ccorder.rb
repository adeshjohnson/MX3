# -*- encoding : utf-8 -*-
class Ccorder < ActiveRecord::Base
    has_many :cclineitems, :dependent => :destroy
    has_many :cc_invoices, :dependent => :destroy
    validates_presence_of :ordertype 
    
  
   
  def cards
    
#    sql = "SELECT cards.* FROM cards
#            JOIN cclineitems ON (cclineitems.card_id = cards.id)
#            WHERE cclineitems.ccorder_id = '#{self.id}'"
#    Card.find_by_sql(sql)
    Card.find(:all, :joins => "JOIN cclineitems ON (cclineitems.card_id = cards.id)",  :conditions=> ["cclineitems.ccorder_id = ?", self.id])
  end
  
end
