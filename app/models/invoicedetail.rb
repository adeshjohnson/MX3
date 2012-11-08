# -*- encoding : utf-8 -*-
class Invoicedetail < ActiveRecord::Base
  belongs_to :invoice

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    b.to_d * User.current.currency.exchange_rate.to_d
  end

  # coconverted_price(exr)nverted attributes for user in given currency exrate
  def converted_price(exr)
    b = read_attribute(:price)
    b.to_d * exr.to_d
  end

  def nice_inv_name
    id_name=""
    if  name.to_s.strip[-1..-1].to_s.strip == "-"
      name_length = name.strip.length
      name_length = name_length.to_i - 2
      id_name = name.strip
      id_name = id_name[0..name_length].to_s
    else
      id_name = name.to_s.strip
    end
    id_name.to_s.strip
  end
end
