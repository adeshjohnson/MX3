# -*- encoding : utf-8 -*-
#!/usr/bin/ruby
# encoding: utf-8

#Vitalija Vildžiūtė
#2012-11-02
#Version : 1
#Kolmisoft


require 'rubygems'
require 'active_record'
require 'optparse'
require 'digest/sha1'

options = {}
optparse = OptionParser.new do |opts|
                                        # Define the options, and what they do

  # Define the options, and what they do
  options[:name] = nil
  opts.on('-n', '--name NAME', "Database name, default 'mor'") do |n|
    options[:name] = n
  end

  options[:user] = nil
  opts.on('-u', '--user USER', "Database user, default 'mor'") do |u|
    options[:user] = u
  end

  options[:pasw] = nil
  opts.on('-p', '--password PASSWORD', "Database password, default 'mor'") do |p|
    options[:pasw] = p
  end

  options[:host] = nil
  opts.on('-s', '--server HOST', "Database host, default 'localhost'") do |h|
    options[:host] = h
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    puts
    exit
  end
end

optparse.parse!

#---------- SET CORECT PARAMS TO SCRIPT ! ---------------

Debug_file = '/tmp/invoices_tax_fix.log'
Database_name = options[:name].to_s.empty? ? 'mor' : options[:name]
Database_username = options[:user].to_s.empty? ? 'mor' : options[:user]
Database_password = options[:pasw].to_s.empty? ? 'mor' : options[:pasw]
Database_host = options[:host].to_s.empty? ? 'localhost' : options[:host]

begin
  #---------- connect to DB ----------------------
  ActiveRecord::Base.establish_connection(:adapter => "mysql2", :database => Database_name, :username => Database_username, :password => Database_password, :host => Database_host)
  ActiveRecord::Base.connection

  #------------- Confline model ----------------
  class Confline < ActiveRecord::Base

    # Returns confline value of given name and user_ID
    def Confline::get_value(name, id = 0)
      cl = Confline.find(:first, :conditions => ["name = ? and owner_id  = ?", name, id])
      return cl.value if cl
      return ""
    end

    # Sets confline value.
    def Confline::set_value(name, value = 0, id = 0)
      cl = Confline.where(["name = ? and owner_id = ?", name, id]).first
      if cl
        cl.value = value
        cl.save
      else
        new_confline(name, value, id)
      end
    end


    # creates new confline with given params
    def Confline::new_confline(name, value, id = 0)
      confline = Confline.new()
      confline.name = name.to_s
      confline.value = value.to_s
      confline.owner_id = id
      confline.save
    end

  end

  #------------- invoice model ----------------
  class Invoice < ActiveRecord::Base

    belongs_to :tax, :dependent => :destroy

    def price_with_tax(options = {})

      if tax
        tax.apply_tax(price, options)
      else
        price_with_vat
      end
    end

    def generate_taxes_for_invoice(nc)
      if tax
      taxes = self.tax.applied_tax_list(self.price, {:precision => nc})
      self.tax_1_value = self.nice_invoice_number(taxes[0][:tax] , {:nc => nc, :apply_rounding=>true})
      self.tax_2_value =  self.nice_invoice_number(taxes[1][:tax] , {:nc => nc, :apply_rounding=>true})    if   taxes[1]
      self.tax_3_value =  self.nice_invoice_number(taxes[2][:tax] , {:nc => nc, :apply_rounding=>true})    if   taxes[2]
      self.tax_4_value =   self.nice_invoice_number(taxes[3][:tax] , {:nc => nc, :apply_rounding=>true})   if   taxes[3]
      end
      self.price_with_vat = self.nice_invoice_number(self.price_with_tax({:precision => nc}) , {:nc => nc, :apply_rounding=>true})
      self
    end

    def nice_invoice_number(number, options = {})
      nc = options[:apply_rounding] ?  (options[:nc] ? options[:nc] : self.invoice_precision) :  self.invoice_precision
      n = sprintf("%0.#{nc}f", number.to_d) if number
      if options[:change_decimal] and options[:no_repl].to_i == 0
        n = n.gsub('.', options[:global_decimal])
      end
      n
    end

  end

  #------------- tax model ----------------
  class Tax < ActiveRecord::Base
    has_one :invoice
=begin rdoc
    Dummy method to fake tax1_enabled option. Method always return 1.

    1*Returns*
    1 - tax1 is always enabled.
=end

    def tax1_enabled
      return 1
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
      if self.compound_tax.to_i == 1
        if opts[:precision]
          amount += format("%.#{opts[:precision].to_i}f", (amount* tax1_value/100.0)).to_d if tax1_enabled.to_i == 1
          amount += format("%.#{opts[:precision].to_i}f", (amount* tax2_value/100.0)).to_d if tax2_enabled.to_i == 1
          amount += format("%.#{opts[:precision].to_i}f", (amount* tax3_value/100.0)).to_d if tax3_enabled.to_i == 1
          amount += format("%.#{opts[:precision].to_i}f", (amount* tax4_value/100.0)).to_d if tax4_enabled.to_i == 1
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
        else
          tax += (amount* tax1_value/100.0) if tax1_enabled.to_i == 1
          tax += (amount* tax2_value/100.0) if tax2_enabled.to_i == 1
          tax += (amount* tax3_value/100.0) if tax3_enabled.to_i == 1
          tax += (amount* tax4_value/100.0) if tax4_enabled.to_i == 1
        end
        amount += tax
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

  #------------- Debug model ----------------
  class Debug
    def Debug.debug(msg)
      File.open(Debug_file, "a") { |f|
        f << msg.to_s
        f << "\n"
      }
    end
  end

  #------------------ Main -------------------
  Debug.debug("\n*******************************************************************************************************")
  Debug.debug("#{Time.now().to_s(:db)} --- STARTING INVOICES TAX FIX ")

  if Confline.get_value('Script_recalculate_invoices_tax').to_i == 0
    invoices = Invoice.all
    if invoices and invoices.size.to_i > 0
      gl_nc = Confline.get_value("Nice_Number_Digits")
      prep_nc = Confline.get_value("Prepaid_Round_finals_to_2_decimals").to_i == 1 ? 2 : (gl_nc.to_i > 0 ? gl_nc : 2)
      post_nc = Confline.get_value("Round_finals_to_2_decimals").to_i == 1 ? 2 : (gl_nc.to_i > 0 ? gl_nc : 2)
      for invoice in invoices
        Debug.debug("#{Time.now().to_s(:db)} B invoice_id:#{invoice.id}; invoice_price:#{invoice.price}; invoice_price_with_vat:#{invoice.price_with_vat} ")
        invoice.invoice_precision = invoice.invoice_type.to_s == 'prepaid' ? prep_nc : post_nc
        invoice = invoice.generate_taxes_for_invoice(invoice.invoice_precision)
        if invoice.save
          Debug.debug("#{Time.now().to_s(:db)} A invoice_id:#{invoice.id}; invoice_price:#{invoice.price}; invoice_price_with_vat:#{invoice.price_with_vat} ")
        else
          Debug.debug("#{Time.now().to_s(:db)} A invoice_id:#{invoice.id}; NOT SAVED!!!! ")
        end
      end
      Confline.set_value('Script_recalculate_invoices_tax', 1)
    end

  end


  puts "OK"

rescue Exception => e
  puts e.to_yaml
  #------------------ ERROR -------------------
  File.open(Debug_file, "a") { |f| f << "******************************************************************************************************* \n"
  f << "#{Time.now().to_s(:db)} --- ERROR ! \n #{e.class} \n #{e.message} \n" }
  puts "FAIL"
end

#yeah, we need to close MySQL connection...
ActiveRecord::Base.remove_connection

Debug.debug("#{Time.now().to_s(:db)} --- FINISHING INVOICES TAX FIX ")
