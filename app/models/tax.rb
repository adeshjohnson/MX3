# -*- encoding : utf-8 -*-
class Tax < ActiveRecord::Base
  has_one :user
  has_one :cardgroup
  has_one :invoice

  before_save :tax_before_save

=begin rdoc
 Validates tax.
=end
  def initialise(params = nil)
    super(params)
    self.compound ||= 1
  end

  def tax_before_save()
    self.total_tax_name = "TAX" if self.total_tax_name.blank?
    self.tax1_name = self.total_tax_name if self.tax1_name.blank?
  end

=begin rdoc
 Returns couns of enabled taxes.
=end

  def get_tax_count
    self.tax1_enabled.to_i+self.tax2_enabled.to_i+self.tax3_enabled.to_i+self.tax4_enabled.to_i
  end

  def sum_tax
    sum =tax1_value.to_d
    sum += tax2_value.to_d if tax2_enabled.to_i == 1
    sum += tax3_value.to_d if tax3_enabled.to_i == 1
    sum += tax4_value.to_d if tax4_enabled.to_i == 1
    sum
  end

  def assign_default_tax(tax={}, opt ={})
    options = {
        :save => true,
    }.merge(opt)
    if !tax or tax == {}
      tax ={
          :tax1_enabled => 1,
          :tax2_enabled => Confline.get_value2("Tax_2", 0).to_i,
          :tax3_enabled => Confline.get_value2("Tax_3", 0).to_i,
          :tax4_enabled => Confline.get_value2("Tax_4", 0).to_i,
          :tax1_name => Confline.get_value("Tax_1", 0),
          :tax2_name => Confline.get_value("Tax_2", 0),
          :tax3_name => Confline.get_value("Tax_3", 0),
          :tax4_name => Confline.get_value("Tax_4", 0),
          :total_tax_name => Confline.get_value("Total_tax_name", 0),
          :tax1_value => Confline.get_value("Tax_1_Value", 0).to_d,
          :tax2_value => Confline.get_value("Tax_2_Value", 0).to_d,
          :tax3_value => Confline.get_value("Tax_3_Value", 0).to_d,
          :tax4_value => Confline.get_value("Tax_4_Value", 0).to_d,
          :compound_tax => Confline.get_value("Tax_compound", 0).to_i
      }
    end
    self.attributes = tax
    self.save if options[:save] == true
  end

=begin rdoc
 Generates aaray of arrays [tax_name, tax_value] of all active taxes.
=end
  def to_active_array
    array = []
    array << [self.tax1_name, self.tax1_value] if self.tax1_enabled.to_i == 1
    array << [self.tax2_name, self.tax2_value] if self.tax2_enabled.to_i == 1
    array << [self.tax3_name, self.tax3_value] if self.tax3_enabled.to_i == 1
    array << [self.tax4_name, self.tax4_value] if self.tax4_enabled.to_i == 1
    array
  end


=begin rdoc
 Dummy method to fake tax1_enabled option. Method always return 1.

 *Returns*
 1 - tax1 is always enabled.
=end

  def tax1_enabled
    return 1
  end


=begin rdoc
 Dummy method to cover fact that tax1 is always enabled
=end

  def tax1_enabled=(*args)
  end

=begin rdoc
 Calculates amount with taxes applied. 

 *Params*

 +amount+

 *Returns*

 +amount+ - float value representing the amount after taxes have been applied.
=end

  def apply_tax(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    logger.fatal "ddddddddddddddddddddddddddddddddd"
    logger.fatal opts[:precision]
    if self.compound_tax.to_i == 1
      if opts[:precision]
        amount += format("%.#{opts[:precision].to_i}f", (amount* tax1_value/100.0)).to_d if tax1_enabled.to_i == 1
        amount += format("%.#{opts[:precision].to_i}f", (amount* tax2_value/100.0)).to_d if tax2_enabled.to_i == 1
        amount += format("%.#{opts[:precision].to_i}f", (amount* tax3_value/100.0)).to_d if tax3_enabled.to_i == 1
        amount += format("%.#{opts[:precision].to_i}f", (amount* tax4_value/100.0)).to_d if tax4_enabled.to_i == 1
        logger.fatal "iiiiiiiiiiiiiiiiiii"
        logger.fatal amount
      else
        amount += (amount* tax1_value/100.0) if tax1_enabled.to_i == 1
        amount += (amount* tax2_value/100.0) if tax2_enabled.to_i == 1
        amount += (amount* tax3_value/100.0) if tax3_enabled.to_i == 1
        amount += (amount* tax4_value/100.0) if tax4_enabled.to_i == 1
      end
    else
      tax = 0
      if opts[:precision]
        tax += format("%.#{opts[:precision].to_i}f", (amount* tax1_value/100.0)).to_d if tax1_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (amount* tax2_value/100.0)).to_d if tax2_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (amount* tax3_value/100.0)).to_d if tax3_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (amount* tax4_value/100.0)).to_d if tax4_enabled.to_i == 1
        logger.fatal "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
        logger.fatal tax
      else
        tax += (amount* tax1_value/100.0) if tax1_enabled.to_i == 1
        tax += (amount* tax2_value/100.0) if tax2_enabled.to_i == 1
        tax += (amount* tax3_value/100.0) if tax3_enabled.to_i == 1
        tax += (amount* tax4_value/100.0) if tax4_enabled.to_i == 1
      end
      amount += tax
    end
    logger.fatal amount
    amount
  end

=begin rdoc
 Calculates amount of tax to be appliet do given amount.

 *Params*

 +amount+

 *Returns*

 +amount+ - float value representing the tax.
=end

  def count_tax_amount(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    tax = amount
    if self.compound_tax.to_i == 1
      if opts[:precision]
        tax += format("%.#{opts[:precision].to_i}f", (tax* tax1_value/100.0)).to_d if tax1_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (tax* tax2_value/100.0)).to_d if tax2_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (tax* tax3_value/100.0)).to_d if tax3_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (tax* tax4_value/100.0)).to_d if tax4_enabled.to_i == 1
      else
        tax += (tax* tax1_value/100.0) if tax1_enabled.to_i == 1
        tax += (tax* tax2_value/100.0) if tax2_enabled.to_i == 1
        tax += (tax* tax3_value/100.0) if tax3_enabled.to_i == 1
        tax += (tax* tax4_value/100.0) if tax4_enabled.to_i == 1
      end
      return tax - amount
    else
      if opts[:precision]
        tax = format("%.#{opts[:precision].to_i}f", (amount* tax1_value/100.0)).to_d
        tax += format("%.#{opts[:precision].to_i}f", (amount* tax2_value/100.0)).to_d if tax2_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (amount* tax3_value/100.0)).to_d if tax3_enabled.to_i == 1
        tax += format("%.#{opts[:precision].to_i}f", (amount* tax4_value/100.0)).to_d if tax4_enabled.to_i == 1
      else
        tax = amount* tax1_value/100.0
        tax += (amount* tax2_value/100.0) if tax2_enabled.to_i == 1
        tax += (amount* tax3_value/100.0) if tax3_enabled.to_i == 1
        tax += (amount* tax4_value/100.0) if tax4_enabled.to_i == 1
      end
      return tax
    end

  end

=begin rdoc
 Calculates amount after applying all taxes in tax object.

 *Params*

 +amount+ - amount with vat.

 *Returns*

 +amount+ - float value representing the amount with taxes substracted.
=end

  def count_amount_without_tax(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    if self.compound_tax.to_i == 1
      if opts[:precision]
        amount = format("%.#{opts[:precision].to_i}f", (amount/(tax4_value.to_d+100)*100)).to_d if tax4_enabled.to_i == 1
        amount = format("%.#{opts[:precision].to_i}f", (amount/(tax3_value.to_d+100)*100)).to_d if tax3_enabled.to_i == 1
        amount = format("%.#{opts[:precision].to_i}f", (amount/(tax2_value.to_d+100)*100)).to_d if tax2_enabled.to_i == 1
        amount = format("%.#{opts[:precision].to_i}f", (amount/(tax1_value.to_d+100)*100)).to_d if tax1_enabled.to_i == 1
      else
        amount = (amount/(tax4_value.to_d+100)*100) if tax4_enabled.to_i == 1
        amount = (amount/(tax3_value.to_d+100)*100) if tax3_enabled.to_i == 1
        amount = (amount/(tax2_value.to_d+100)*100) if tax2_enabled.to_i == 1
        amount = (amount/(tax1_value.to_d+100)*100) if tax1_enabled.to_i == 1
      end
    else
      amount = amount.to_d/((sum_tax.to_d/100.0)+1.0).to_d
      amount = format("%.#{opts[:precision].to_i}f", amount) if opts[:precision]
    end
    amount
  end

=begin rdoc
 Returns list with taxes applied to given amount.
=end

  def applied_tax_list(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    list = []
    if self.compound_tax.to_i == 1
      if opts[:precision]
        list << {:name => tax1_name.to_s, :value => tax1_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax1_value).to_d/100.0), :amount => amount += format("%.#{opts[:precision].to_i}f", (amount*tax1_value).to_d/100.0).to_d} if tax1_enabled.to_i == 1
        list << {:name => tax2_name.to_s, :value => tax2_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax2_value).to_d/100.0), :amount => amount += format("%.#{opts[:precision].to_i}f", (amount*tax2_value).to_d/100.0).to_d} if tax2_enabled.to_i == 1
        list << {:name => tax3_name.to_s, :value => tax3_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax3_value).to_d/100.0), :amount => amount += format("%.#{opts[:precision].to_i}f", (amount*tax3_value).to_d/100.0).to_d} if tax3_enabled.to_i == 1
        list << {:name => tax4_name.to_s, :value => tax4_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax4_value).to_d/100.0), :amount => amount += format("%.#{opts[:precision].to_i}f", (amount*tax4_value).to_d/100.0).to_d} if tax4_enabled.to_i == 1
      else
        list << {:name => tax1_name.to_s, :value => tax1_value.to_d, :tax => amount*tax1_value/100.0, :amount => amount += amount*tax1_value/100.0} if tax1_enabled.to_i == 1
        list << {:name => tax2_name.to_s, :value => tax2_value.to_d, :tax => amount*tax2_value/100.0, :amount => amount += amount*tax2_value/100.0} if tax2_enabled.to_i == 1
        list << {:name => tax3_name.to_s, :value => tax3_value.to_d, :tax => amount*tax3_value/100.0, :amount => amount += amount*tax3_value/100.0} if tax3_enabled.to_i == 1
        list << {:name => tax4_name.to_s, :value => tax4_value.to_d, :tax => amount*tax4_value/100.0, :amount => amount += amount*tax4_value/100.0} if tax4_enabled.to_i == 1
      end
    else
      if opts[:precision]
        list << {:name => tax1_name.to_s, :value => tax1_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax1_value).to_d/100.0), :amount => format("%.#{opts[:precision].to_i}f", (amount*tax1_value).to_d/100.0).to_d} if tax1_enabled.to_i == 1
        list << {:name => tax2_name.to_s, :value => tax2_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax2_value).to_d/100.0), :amount => format("%.#{opts[:precision].to_i}f", (amount*tax2_value).to_d/100.0).to_d} if tax2_enabled.to_i == 1
        list << {:name => tax3_name.to_s, :value => tax3_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax3_value).to_d/100.0), :amount => format("%.#{opts[:precision].to_i}f", (amount*tax3_value).to_d/100.0).to_d} if tax3_enabled.to_i == 1
        list << {:name => tax4_name.to_s, :value => tax4_value.to_d, :tax => format("%.#{opts[:precision].to_i}f", (amount*tax4_value).to_d/100.0), :amount => format("%.#{opts[:precision].to_i}f", (amount*tax4_value).to_d/100.0).to_d} if tax4_enabled.to_i == 1
      else
        list << {:name => tax1_name.to_s, :value => tax1_value.to_d, :tax => amount*tax1_value/100.0, :amount => amount*tax1_value/100.0} if tax1_enabled.to_i == 1
        list << {:name => tax2_name.to_s, :value => tax2_value.to_d, :tax => amount*tax2_value/100.0, :amount => amount*tax2_value/100.0} if tax2_enabled.to_i == 1
        list << {:name => tax3_name.to_s, :value => tax3_value.to_d, :tax => amount*tax3_value/100.0, :amount => amount*tax3_value/100.0} if tax3_enabled.to_i == 1
        list << {:name => tax4_name.to_s, :value => tax4_value.to_d, :tax => amount*tax4_value/100.0, :amount => amount*tax4_value/100.0} if tax4_enabled.to_i == 1
      end
    end
    list
  end
end

