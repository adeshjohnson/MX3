class Invoicedetail < ActiveRecord::Base
  belongs_to :invoice

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    b.to_f * User.current.currency.exchange_rate.to_f
  end

  # coconverted_price(exr)nverted attributes for user in given currency exrate
  def converted_price(exr)
    b = read_attribute(:price)
    b.to_f * exr.to_f
  end
end
