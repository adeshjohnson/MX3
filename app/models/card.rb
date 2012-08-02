# -*- encoding : utf-8 -*-
class Card < ActiveRecord::Base
  belongs_to :cardgroup

  has_many :calls, :order => "calldate DESC"
  has_many :activecalls
  has_many :cclineitems
  belongs_to :user
  validates_uniqueness_of :number, :allow_nil => true, :scope => :cardgroup_id
  validates_uniqueness_of :pin, :allow_nil => true, :message => _('PIN_is_already_taken')
  validates_uniqueness_of :callerid, :if => :validate_caller_id, :message => _('Callerid_must_be_unique')

  before_save :validate_pin_length, :validate_number_length, :validate_min_balance
  before_create :card_before_create

  def validate_caller_id
    callerid and !callerid.to_s.blank?
  end

  def validate_number_length
    if self.number and self.number.length != self.cardgroup.number_length.to_i
      errors.add(:number, _('Bad_number_length_should_be') + ": " + self.cardgroup.number_length.to_s)
      false
    else
      true
    end
  end

  def validate_pin_length
    if self.pin and self.pin.length != self.cardgroup.pin_length
      errors.add(:pin, _('Bad_pin_length_should_be') + ": " + self.cardgroup.pin_length.to_s)
      false
    else
      true
    end
  end

  def validate_min_balance
    if self.min_balance.to_f < 0.to_f
      errors.add(:min_balance, _('Bad_minimal_balance'))
      false
    else
      true
    end
  end

  def Card.delete_from_sql(options={})
    cards_deleted = 0
    query = "DELETE cards
               FROM cards
               JOIN (SELECT cards.id
                     FROM cards
                     LEFT JOIN payments ON (payments.user_id = cards.id and paymenttype='Card')
                     LEFT JOIN calls ON (calls.card_id = cards.id)
                     LEFT JOIN activecalls ON (activecalls.card_id = cards.id)
                     WHERE activecalls.id IS NULL AND
                           calls.id IS NULL AND
                           payments.id IS NULL AND
                           cards.cardgroup_id = #{options[:cardgroup_id]} AND
                           cards.number BETWEEN #{options[:start_num]} AND #{options[:end_num]}
                     GROUP BY cards.id
                     LIMIT 10000) tmp USING(id)"
    begin
      rows_affected = ActiveRecord::Base.connection.delete(query)

      cards_deleted += rows_affected
    end while rows_affected > 0
    query = "SELECT COUNT(*)
               FROM  (SELECT cards.id
                      FROM cards
                      LEFT JOIN payments ON (payments.user_id = cards.id and paymenttype='Card')
                      LEFT JOIN calls ON (calls.card_id = cards.id)
                      LEFT JOIN activecalls ON (activecalls.card_id = cards.id)
                      WHERE (activecalls.id IS NOT NULL OR
                             calls.id IS NOT NULL OR
                             payments.id IS NOT NULL) AND
                             cards.cardgroup_id = #{options[:cardgroup_id]} AND
                             cards.number BETWEEN #{options[:start_num]} AND #{options[:end_num]}
                      GROUP BY cards.id) tmp"
    cards_not_deleted = ActiveRecord::Base.connection.select_value(query).to_i
    return    cards_deleted, cards_not_deleted
  end

  def Card.delete_and_hide_from_sql(options={})
    cards_deleted, cards_not_deleted = Card.delete_from_sql(options)
    if cards_not_deleted.to_i > 0
      cards_hidden = Card.hide_from_sql(options.merge!({:force=>true}))
    end
    return  cards_deleted, cards_hidden
  end

  def Card.hide_from_sql(options={})
    cards_hidden = 0
    if options[:force]
      query = "UPDATE cards SET callerid = NULL, number = CONCAT('DELETED_#{Time.now.to_i}_', number), pin = CONCAT('DELETED_#{Time.now.to_i}_', pin), hidden = 1 WHERE cards.cardgroup_id = #{options[:cardgroup_id]} AND cards.number BETWEEN #{options[:start_num]} AND #{options[:end_num]} LIMIT 10000;"
      begin
        rows_affected = ActiveRecord::Base.connection.update(query)
        cards_hidden += rows_affected
      end while rows_affected > 0
    else
      query = "UPDATE cards SET callerid = NULL, number = CONCAT('DELETED_#{Time.now.to_i}_', number), pin = CONCAT('DELETED_#{Time.now.to_i}_', pin), hidden = 1
               FROM cards
               JOIN (SELECT cards.id
                     FROM cards
                     LEFT JOIN payments ON (payments.user_id = cards.id and paymenttype='Card')
                     LEFT JOIN calls ON (calls.card_id = cards.id)
                     LEFT JOIN activecalls ON (activecalls.card_id = cards.id)
                     WHERE (activecalls.id IS NOT NULL OR
                           calls.id IS NOT NULL OR
                           payments.id IS NOT NULL) AND
                           cards.cardgroup_id = #{options[:cardgroup_id]} AND
                           cards.number BETWEEN #{options[:start_num]} AND #{options[:end_num]}
                     GROUP BY cards.id
                     LIMIT 10000) tmp USING(id)"
      begin
        rows_affected = ActiveRecord::Base.connection.update(query)
        cards_hidden += rows_affected
      end while rows_affected > 0
    end

    return  cards_hidden
  end


  def self.search(user_id, conditions, options)
    cond, vars = [], []

    cond << ['owner_id = ?']; vars << user_id

    unless conditions['s_number'].empty?
      cond << "number LIKE ?"
      vars << "#{conditions['s_number']}"
    end

    unless conditions['s_pin'].empty?
      cond << "pin LIKE ?"
      vars << "#{conditions['s_pin']}"
    end

    unless conditions['s_caller_id'].empty?
      cond << "callerid LIKE ?"
      vars << "#{conditions['s_caller_id']}"
    end

    unless conditions['s_balance_min'].empty?
      cond << "balance >= ?"
      vars << conditions['s_balance_min'].to_f
    end

    unless conditions['s_balance_max'].empty?
      cond << "balance <= ?"
      vars << conditions['s_balance_max'].to_f
    end

    if conditions['s_sold'] == "yes"
      cond << "sold = 1"
    elsif conditions['s_sold'] == "no"
      cond << "sold = 0"
    else
      cond << "(sold = 1 OR sold = 0)"
    end

    return find(:all, :conditions => [cond.join(" AND "), *vars], :order => "number ASC",
                :limit => "#{options[:page] * options[:per_page]}, #{options[:per_page]}"),
        count(:all, :conditions => [cond.join(" AND "), *vars])
  end

  def card_before_create
    card_f = Card.find(:first, :select => "cards.*, cardgroups.name AS 'ccg_name'", :conditions => ["number = ?", self.number.to_s], :joins => "LEFT JOIN cardgroups ON (cards.cardgroup_id = cardgroups.id)")
    if card_f
      errors.add(:number, _("Card_with_this_number_already_exists") + " : " + self.number.to_s + " (#{card_f.ccg_name}) ") if (card_f.owner_id == self.owner_id or self.owner_id == 0) and card_f.cardgroup_id != self.cardgroup_id
      return false
    end

    if self.pin.to_s.blank?
      errors.add(:pin, _("Card_pin_is_blank") + " : " + self.number.to_s)
      return false
    end
  end

  def is_owned_by?(user)
    user_id = user.usertype == 'accountant' ? 0 : user.id
    owner_id == user_id
  end

  def is_not_owned_by?(user)
    user_id = user.usertype == 'accountant' ? 0 : user.id
    owner_id != user_id
  end

  def payments
    pa = nil
    pa = Payment.find(self.user_id) if self.user_id and self.user_id.to_i > 0
    pa
  end

  def destroy_with_check
    if not self.has_calls? and not self.has_activecalls? and not Payment.find(:first, :conditions => ["paymenttype = ? and user_id = ?", "Card", self.id])
      self.destroy
    else
      self.hide
    end
  end

  # converted attributes for user in current user currency
  def balance
    b = read_attribute(:balance)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b.to_f
    end
  end

  def balance= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:balance, b)
  end

  def Card.get_order_by(params, options)
    case options[:order_by].to_s.strip.to_s
      when "number" then
        order_by = "number"
      when "name" then
        order_by = "name"
      when "pin" then
        order_by = "pin"
      when "caller_id" then
        order_by = "callerid"
      when "balance" then
        order_by = "balance"
      when "first_use" then
        order_by = "first_use"
      when "daily_charge" then
        order_by = "daily_charge_paid_till"
      when "sold" then
        order_by = "sold"
      when "language" then
        order_by = "language"
      when "user" then
        order_by = "nice_user"
      else
        order_by = options[:order_by]
    end
    order_by += " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by += " DESC" if options[:order_desc].to_i == 1 and order_by != ""
    return order_by
  end

  def disable_voucher
    if cardgroup.disable_voucher == true
      voucher = Voucher.find(:first, :conditions => {:number => number})
      if voucher
        voucher.use_date = Time.now
        if voucher.save
          Action.add_action_hash(User.current, {:action => 'Disable_Voucher_when_Card_is_used', :target_id => voucher.id, :target_type => 'Voucher', :data => number, :data2 => id})
        end
      end
    end
  end

  def has_calls?
    self.calls and self.calls.size > 0
  end

  def has_activecalls?
    self.activecalls and self.activecalls.size > 0
  end

=begin
  Add some amount to card.
  Note that after changeing balance we immediately save the card, since we dont use
  transactions that's least what we should do. If adding amount to balance or creating
  payment fails - we do our best to revert everything... but still without useing 
  transactions there are lot's of ways to fail.

  *Params*
  +amount+ amount to be added to balance and payment created in system currency

  *Returns*
  +boolean+ true changeing balance and creating payment succeeded, otherwise false. 
     Note that no transactions are used, so if smth goes wrong data might be corrupted.
=end
  def add_to_balance(amount, add_payment=true)
    self.balance += amount
    if self.save
      if add_payment
        if Payment.add_for_card(self, amount * Currency.count_exchange_rate(Currency.get_default, self.cardgroup.tell_balance_in_currency))
          return true
        else
          self.balance -= amount
          self.save
          return false
        end
      else
       Action.add_action_hash(User.current, {:action=>'Added to cards balance', :target_id=>self.id, :target_type=>"card", :data=>Email.nice_number(amount)})
       return true
      end
    else
      return false
    end
  end

=begin
  Disable the card, to do that we need to set it as not sold.
=end
  def disable
    self.sold = false
  end

=begin
  Sell card, obviuosly to do that we need to set appropriat setting. But
  note that card is saved as soon as it is set as sold. Then Payment is 
  created and also saved. Thats because we do our best not to let anyone to
  create payment without setting card as sold or vice versa. Though as you can
  see we do not use transactions, but instead if setting as sold or creating
  payment fails - we do our best to revert everything... but still there are 
  lot's of ways to fail.
  If card would be allready sold exception should be raised.

  *Returns*
  +boolean+ true if card was set as sold and payment generated succesfully, 
     otherwise false
=end
  def sell(currency=nil, owner_id=nil)
    if self.sold?
      errors.add(:sold, 'Cannot sell already sold card')
      return false
    else
      self.sold = true 
      if self.save
        #This is jus a crapy hack to make this method work with api and gui
        if currency and owner_id
          balance = self.balance
        else
          balance = self.balance * Currency.count_exchange_rate(Currency.get_default, self.cardgroup.tell_balance_in_currency) 
        end
        if Payment.add_for_card(self, balance, currency, owner_id)
          self.disable_voucher
          return true
        else
          self.sold = false
          self.save
          return false
        end
      else
        return false
      end
    end
  end


  def sell_from_bach(email, currency, user_id)
    if self.sold?
      errors.add(:sold, 'Cannot sell already sold card')
      return false
    else
      self.sold = true
      if self.save
        p = Payment.add_for_card(self, self.balance, currency, user_id)
        p.email = email
        if p.save
          return true
        else
          return false
        end
      else
        return false
      end
    end
  end

=begin
  Check whether the card is sold or not. Before thinking about selling the card
  should check whether it is not sold at this moment, cause no one can sell already
  sold card.

  *Returns*
  +boolean+ true if card is sold, false otherwise
=end
  def sold?
    (self.sold == 1)
  end

=begin
  Check whether that card is disabled. Card may be sold OR disabled, so if card is
  disabled you can assume that it is not sold and vice versa.

  *Returns*
  +boolean+ true if card is disabled, otherwise false
=end
  def disabled?
    not self.sold?
  end

=begin

=end
  def set_unique_pin
    begin
      pin = random_number(self.cardgroup.pin_length)
    end while Card.find(:first, :conditions => {:pin => pin})
    self.pin = pin
  end

=begin

=end
  def set_unique_number
    begin
      number = random_number(self.cardgroup.number_length)
    end while Card.find(:first, :conditions => {:number => number, :cardgroup_id => self.cardgroup_id})
    self.number = number
  end

  def balance_with_vat
     self.cardgroup.get_tax.count_tax_amount(self.balance) + balance
  end

=begin
  Checks if card is hidden or not. Card can be hidden and no one should be able to unhide it.
=end
  def hidden?
    self.hidden == 1
  end

=begin
  Hide the card so that no one could see it and set pin and caller id to nil, so that new cards 
  with these parameters could be created. Card can be hidden and no one should be able to unhide it.
=end
  def hide
    Action.add_action_hash(User.current, {:action=>'Card hidden permanently', :target_id=>self.id, :target_type=>"card", :data=>self.callerid, :data2=>self.pin, :data3=>self.number})
    Card.delete_and_hide_from_sql({:cardgroup_id => self.cardgroup_id, :start_num => self.number, :end_num => self.number})
    #self.write_attribute(:pin, "DELETED_#{Time.now.to_i}_" + self.pin.to_s)
    #self.write_attribute(:callerid, nil)
    #self.write_attribute(:number, "DELETED_#{Time.now.to_i}_" + self.number.to_s)
    #self.write_attribute(:hidden, 1)
    #self.save(:validate => false)
  end

  private

=begin
  Don't think that card shoudl be responsible for generating random
  number but.. This is a method to generate card's random pin and number
  that can consist only of numbers.

  *Returns*
  +string+ of numbers only, with length as specified
=end
  def random_number(length)
    number = ''
     length.times{
      number << rand(10).to_s
    }
    return number
  end

end
