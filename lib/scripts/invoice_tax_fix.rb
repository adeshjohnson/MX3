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
      for invoice in invoices
        Debug.debug("#{Time.now().to_s(:db)} B invoice_id:#{invoice.id}; invoice_price:#{invoice.price}; invoice_price_with_vat:#{invoice.price_with_vat} ")
        invoice.price_with_vat = invoice.price_with_tax()
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
