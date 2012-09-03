# -*- encoding : utf-8 -*-
class CsInvoice < ActiveRecord::Base
  include UniversalHelpers
  belongs_to :user
  belongs_to :tax

  before_save :cs_before_save
  before_create :cs_before_create

  def calls(end_date = Time.now.strftime("%Y-%m-%d %H:%M:%S"))
    @calls ||= user.calls("ANSWERED", self.created_at.strftime("%Y-%m-%d %H:%M:%S"), end_date, "outgoing")
  end

  def call_price
    @call_price ||= round_to_cents(calls.sum { |call| round_to_cents(curr_price(call.user_price)) })
  end

  def call_duration
    @call_duration ||= calls.sum(&:user_billsec)
  end

  def postpaid?
    invoice_type == "postpaid"
  end

  def prepaid?
    invoice_type == "prepaid"
  end

  def cs_before_save
    self.balance = round_to_cents(self.balance)
  end

  def cs_before_create
    tax = user.get_tax.dup
    tax.save
    self.tax_id = tax.id
  end

  def balance
    b = read_attribute(:balance)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def balance= value
    if User.current and User.current.currency
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:balance, b)
  end

  def price_with_tax(options = {})
    if self.tax
      self.tax.apply_tax(call_price, options)
    else
      call_price
    end
  end

end
