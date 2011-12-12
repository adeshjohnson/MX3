class Voucher < ActiveRecord::Base
  belongs_to :user
  belongs_to :payment
  belongs_to :tax, :dependent => :destroy

  def before_destroy
    if is_used?
      errors.add(:active, _("Voucher_Was_Already_Used")) and return false
    end
  end

  def assign_default_tax
    self.tax = Confline.get_default_tax(0)
  end

  def get_tax
    self.assign_default_tax if self.tax.nil?
    self.tax
  end

  def count_credit_with_vat
    self.get_tax.count_amount_without_tax(self.credit_with_vat)
  end

  def Voucher.set_tax(tax)
    Voucher.find(:all, :include => [:tax], :conditions => ["user_id = -1"]).each {|voucher|
      voucher.tax = Tax.new unless voucher.tax
      voucher.tax.update_attributes(tax)
    }
  end

  def is_active?
    (self.use_date or self.active_till < Time.now)
  end

  def is_usable?
    self.is_active? == false and self.active.to_i == 1
  end

  def is_used?
    self.use_date
  end

  def disable_card
    if Confline.get_value('Voucher_Card_Disable', User.current.owner_id).to_i == 1
      card = Card.find(:first, :conditions=>{:number=>number})
      if card
        card.sold = 1
        card.first_use = Time.now
        if card.save
          Action.add_action_hash(User.current, {:action=>'Disable_Card_when_Voucher_is_used', :target_id=>card.id, :target_type=>'Card', :data=>number, :data2=>id})
        end
      end
    end
  end

  def Voucher.get_use_dates
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT DATE(use_date) as 'udate' FROM vouchers ORDER BY DATE(use_date) ASC")
  end

  def Voucher.get_active_tills
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT active_till 'atill' FROM vouchers ORDER BY active_till ASC")
  end

  def Voucher.get_currencies
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT currency as 'curr' FROM vouchers ORDER BY currency ASC")
  end

  def Voucher.get_tags
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT vouchers.tag FROM vouchers ORDER BY tag ASC")
  end
  
end
