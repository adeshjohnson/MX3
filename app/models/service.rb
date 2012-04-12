# -*- encoding : utf-8 -*-
class Service < ActiveRecord::Base
  has_many :subscriptions
  has_many :flatrate_destinations, :dependent => :destroy

  validates_presence_of :name, :message => _("Service_must_have_a_name")
  validates_presence_of :servicetype, :message => _("Service_must_have_a_service_type")
  validates_numericality_of :quantity, :message => _("Quantity_should_be_digit")
  validates_numericality_of :price, :message => _("Price_should_be_digit")

  def validate
    if servicetype == 'flat_rate'
      errors.add(:price, _("Should_have_price")) if !price
      errors.add(:quantity, _("Should_have_quantity")) if !quantity
      errors.add(:price, _("Price_should_be_possitive")) if price and price.to_i < 0
      errors.add(:quantity, _("Quantity_should_be_possitive")) if quantity and quantity < 0
      return false if errors.size > 0
    end
    return true
  end

  before_destroy :s_before_destroy

  def s_before_destroy
    if subscriptions.size > 0
      errors.add(:subscriptions, _('Cant_delete_subscriptions_exist'))
      return false
    end
    return true
  end

  def type
    return servicetype
  end

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b
    end
  end

  def price= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:price, b)
  end

  # converted attributes for user in current user currency
  def selfcost_price
    b = read_attribute(:selfcost_price)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b
    end
  end

  def selfcost_price= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:selfcost_price, b)
  end

end

