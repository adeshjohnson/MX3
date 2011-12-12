class Invoice < ActiveRecord::Base
  belongs_to :user
  belongs_to :payment
  has_many :invoicedetails
  belongs_to :tax, :dependent => :destroy

  def price_with_tax(options = {})
    if options[:ex]
      if tax
        tax.apply_tax(converted_price(options[:ex]), options)
      else
        if options[:precision]
          format("%.#{options[:precision].to_i}f",converted_price_with_vat(options[:ex])).to_f
        else
          converted_price_with_vat(options[:ex])
        end
      end
      
    else
      if tax
        tax.apply_tax(price, options)
      else
        if options[:precision]
          format("%.#{options[:precision].to_i}f",price_with_vat).to_f
        else
          price_with_vat
        end
      end
    end
  end

  def tax_amount(options ={})
    if options[:ex]
      tax.count_tax_amount(converted_price(options[:ex]), options)
    else
      tax.count_tax_amount(price, options)
    end
  end

  def calls_price
    price = 0.0
    for invd in self.invoicedetails
      price += invd.price if invd.invdet_type == 0
    end
    price
  end

  def Invoice.filename(user, type, long_name, file_type)
    temp = (type == "prepaid" ? "Prepaid_" : "")
    use_short = Confline.get_value("#{temp}Invoice_Short_File_Name", user.owner_id).to_i
    use_short == 1 ? "#{user.first_name}_#{user.last_name}.#{file_type}" : "#{long_name}.#{file_type}"
  end

  def paid?; paid == 1; end

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    b.to_f * User.current.currency.exchange_rate.to_f
  end

  def price_with_vat
    b = read_attribute(:price_with_vat)
    b.to_f * User.current.currency.exchange_rate.to_f
  end
  
  # converted attributes for user in given currency exrate
  def converted_price(exr)
    b = read_attribute(:price)
    b.to_f * exr.to_f
  end


  # converted attributes for user in given currency exrate
  def converted_price_with_vat(exr)
    b = read_attribute(:price_with_vat)
    b.to_f * exr.to_f
  end

end
