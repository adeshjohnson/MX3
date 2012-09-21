# -*- encoding : utf-8 -*-
#!/usr/bin/ruby
# encoding: utf-8

#Vitalija Vildžiūtė
#2011-05-25
#Version : 4
#Kolmisoft


require 'rubygems'
require 'active_record'
require 'optparse'
require 'digest/sha1'

options = {}
optparse = OptionParser.new do |opts|

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

  options[:r_id] = nil
  opts.on('-r', '--reseller RESELLER', "Reseller ID. Required.") do |r|
    options[:r_id] = r
  end

  options[:table] = nil
  opts.on('-t', '--table TABLE', "Table name") do |t|
    options[:table] = t
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    puts
    exit
  end
end

optparse.parse!

#---------- SET CORECT PARAMS TO SCRIPT ! ---------------

Debug_file = '/tmp/reseller_migration.log'
Database_name = options[:name].to_s.empty? ? 'mor' : options[:name]
Database_username = options[:user].to_s.empty? ? 'mor' : options[:user]
Database_password = options[:pasw].to_s.empty? ? 'mor' : options[:pasw]
Database_host = options[:host].to_s.empty? ? 'localhost' : options[:host]
Table_name = options[:table].to_s.empty? ? '' : options[:table]
if options[:r_id].to_s.empty?
  raise "ENTER RESELLER ID"
else
  Reseller_ID = options[:r_id]
end
if Table_name.to_s.empty?
  Output_file = "/tmp/reseller_new_db_#{Reseller_ID}_#{Time.now.to_i}.sql"
else
  Output_file = "/tmp/reseller_new_db_#{Reseller_ID}_#{Table_name}_#{Time.now.to_i}.sql"
end

begin
  #---------- connect to DB ----------------------
  ActiveRecord::Base.establish_connection(:adapter => "mysql", :database => Database_name, :username => Database_username, :password => Database_password, :host => Database_host)
  ActiveRecord::Base.connection

  #------------- Actions model ----------------
  class Action < ActiveRecord::Base
  end
  #------------- Acustratedetails model ----------------
  class Acustratedetail < ActiveRecord::Base
  end
  #------------- Adaction model ----------------
  class Adaction < ActiveRecord::Base
  end
  #------------- Aratedetail model ----------------
  class Aratedetail < ActiveRecord::Base
  end
  #------------- Address model ----------------
  class Address < ActiveRecord::Base
  end
  #------------- Callerid model ----------------
  class Callerid < ActiveRecord::Base
  end
  #------------- Callflow model ----------------
  class Callflow < ActiveRecord::Base
  end
  #------------- Call model ----------------
  class Call < ActiveRecord::Base

    def Call.make_inserts(new_provider_id)
      names = Call.column_names
      n2 = names.dup
      names.each_with_index { |n, id|
        i= 0
        if n == 'provider_price'
          i=1
          names[id]= 'reseller_price AS provider_price'
        end
        if n == 'reseller_id'
          i=1
          names[id]= '0 AS reseller_id'
        end
        if n == 'provider_id'
          i=1
          names[id]= "IF(providers.common_use = 1, #{new_provider_id}, provider_id) AS provider_id"
        end
        if i.to_i == 0
          names[id]= 'calls.'+n.to_s
        end
      }
      names = Call.column_names.join(',')
      actions_size= Call.count(:all, :conditions => "(calls.reseller_id = #{Reseller_ID} OR calls.user_id = #{Reseller_ID} OR calls.dst_user_id = #{Reseller_ID})")

      Debug.debug("Checking : calls")
      msg = "#=================== DELETE AND INSERT INTO calls , found to insert : #{actions_size.to_i} ==========="
      Debug.debug(msg)
      MyWritter.msg(msg)
      MyWritter.msg "TRUNCATE calls;"
      times = (actions_size.to_i / 1000).to_i + 1
      times.times { |i|
        Call.insert_split(names, n2, i*1000)
      }

    end


    def Call.insert_split(names, names2, range_start)
      actions = Call.find(:all, :select => "#{names}", :joins => 'LEFT JOIN providers ON (providers.id = calls.provider_id)', :conditions => "(calls.reseller_id = #{Reseller_ID} OR calls.user_id = #{Reseller_ID} OR calls.dst_user_id = #{Reseller_ID})", :group => "calls.id", :limit => "#{range_start},1000")
      sql_values = []
      if actions and actions.size.to_i > 0
        sql_header = "INSERT INTO calls (`#{names2.sort.join('`, `')}`) VALUES "
        actions.each { |a|
          atrib =[]
          a.attributes.sort.each { |key, value| atrib << MyHelper.output(value) }
          sql_values << atrib.join(', ')
        }
      end
      Debug.debug(range_start)
      MyWritter.msg sql_header + "(" + sql_values.join("), (") +");"
    end

  end
  #------------- Campaign model ----------------
  class Campaign < ActiveRecord::Base
  end
  #------------- Cardgroup model ----------------
  class Cardgroup < ActiveRecord::Base
  end
  #------------- Card model ----------------
  class Card < ActiveRecord::Base
  end
  #------------- cc_gmps model ----------------
  class CcGhostminutepercent < ActiveRecord::Base
    def self.table_name()
      "cc_gmps"
    end
  end
  #------------- cc_invoices model ----------------
  class CcInvoice < ActiveRecord::Base
  end
  #------------- cclineitems model ----------------
  class Cclineitem < ActiveRecord::Base
  end
  #------------- ccorders model ----------------
  class Ccorder < ActiveRecord::Base
  end
  #------------- Confline model ----------------
  class Confline < ActiveRecord::Base
    def Confline.update_velues
      confs = Confline.find(:all, :conditions => {:owner_id => Reseller_ID})
      Debug.debug("Checking : conflines")
      if confs and confs.size.to_i > 0
        msg = "#============ UPDATE CONFLINES : #{confs.size.to_i} ======================="
        Debug.debug(msg)
        MyWritter.msg(msg)
        confs.each { |c|
          atrib =[]
          c.attributes.each { |key, value| atrib << "#{key} = #{MyHelper.output(value)}" if key.to_s != 'id' }
          MyWritter.msg "UPDATE conflines SET #{atrib.join(", ")} WHERE name = '#{c.name}';"
        }
        MyWritter.msg "UPDATE conflines SET owner_id = 0 WHERE id > 0;"
      end
    end
  end
  #------------- CsInvoice model ----------------
  class CsInvoice < ActiveRecord::Base
  end
  #------------- Currencie model ----------------
  class Currencie < ActiveRecord::Base
  end
  #------------- Customrate model ----------------
  class Customrate < ActiveRecord::Base
  end
  #------------- Day model ----------------
  class Day < ActiveRecord::Base
  end
  #------------- Destination model ----------------
  class Destination < ActiveRecord::Base
  end
  #------------- Direction model ----------------
  class Direction < ActiveRecord::Base
  end
  #------------- Destinationgroup model ----------------
  class Destinationgroup < ActiveRecord::Base
  end
  #------------- Devicegroups model ----------------
  class Devicegroup < ActiveRecord::Base
  end
  #------------- Device model ----------------
  class Device < ActiveRecord::Base
  end
  #------------- devicetypes model ----------------
  class Devicetype < ActiveRecord::Base
  end
  #------------- dialplans model ----------------
  class Dialplan < ActiveRecord::Base
  end
  #------------- didrates model ----------------
  class Didrate < ActiveRecord::Base
  end
  #------------- dids model ----------------
  class Did < ActiveRecord::Base
  end
  #------------- Extline model ----------------
  class Extline < ActiveRecord::Base
  end
  class Email < ActiveRecord::Base
    def Email.update_velues
      confs = Email.find(:all, :conditions => ['owner_id=?', Reseller_ID])
      Debug.debug("Checking : emails")
      if confs and confs.size.to_i > 0
        msg = "#============ UPDATE EMAILS : #{confs.size.to_i} ======================="
        Debug.debug(msg)
        MyWritter.msg(msg)
        confs.each { |c|
          atrib =[]
          c.attributes.each { |key, value| atrib << "#{key} = #{MyHelper.output(value)}" }
          MyWritter.msg "UPDATE emails SET #{atrib.join(", ")} WHERE name = '#{c.name}';"
        }
        MyWritter.msg "UPDATE emails SET owner_id = 0 WHERE id > 0;"
      end
    end
  end
  #------------- flatrate_data model ----------------
  class FlatrateData < ActiveRecord::Base
    set_table_name "flatrate_data"
  end
  #------------- flatrate_data model ----------------
  class FlatrateDestination < ActiveRecord::Base
  end
  #------------- Group model ----------------
  class Group < ActiveRecord::Base
  end
  #------------- Hangupcausecode model ----------------
  class Hangupcausecode < ActiveRecord::Base
  end
  #------------- invoicedetails model ----------------
  class Invoicedetail < ActiveRecord::Base
  end
  #------------- invoice model ----------------
  class Invoice < ActiveRecord::Base
  end
  #------------- ivr_actions model ----------------
  class IvrAction < ActiveRecord::Base
  end
  #------------- ivr_actions model ----------------
  class IvrBlock < ActiveRecord::Base
  end
  #------------- ivr_extensions model ----------------
  class IvrExtension < ActiveRecord::Base
  end
  #------------- ivr_extensions model ----------------
  class IvrSoundFile < ActiveRecord::Base
  end
  #------------- ivr_timeperiods model ----------------
  class IvrTimeperiod < ActiveRecord::Base
  end
  #------------- ivr_voices model ----------------
  class IvrVoice < ActiveRecord::Base
  end
  #------------- ivrs model ----------------
  class Ivr < ActiveRecord::Base
  end
  #------------- ivrs model ----------------
  class LcrPartial < ActiveRecord::Base
  end
  #------------- lcrproviders model ----------------
  class Lcrprovider < ActiveRecord::Base
  end
  #------------- lcrproviders model ----------------
  class Lcr < ActiveRecord::Base
  end
  #------------- locationrules model ----------------
  class Locationrule < ActiveRecord::Base
  end
  #------------- payments model ----------------
  class Payment < ActiveRecord::Base
  end
  #------------- pdffaxes model ----------------
  class Pdffaxe < ActiveRecord::Base
  end
  #------------- pdffaxemails model ----------------
  class Pdffaxemail < ActiveRecord::Base
  end
  #-------------  phonebooks model ----------------
  class Phonebook < ActiveRecord::Base
  end
  #-------------  providercodecs model ----------------
  class Providercodec < ActiveRecord::Base
  end
  #-------------  providerrules model ----------------
  class Providerrule < ActiveRecord::Base
  end
  #-------------  provider model ----------------
  class Provider < ActiveRecord::Base
    def Provider.create_new
      p_id = Provider.count(:all, :conditions => "id > 0").to_i + 1
      dev_id = Device.count(:all, :conditions => "id > 0").to_i + 1
      msg = "#============ CREATE PROVIDER ID : #{p_id} AND DEVICE ID : #{dev_id} ======================="
      Debug.debug(msg)
      MyWritter.msg(msg)
      MyWritter.msg "INSERT INTO providers (id, name, tech, user_id, device_id) VALUES (#{p_id}, 'new_provider_from_migration', 'SIP', 0, #{dev_id});"
      MyWritter.msg "INSERT INTO devices (id, name, device_type, user_id, extension) VALUES (#{dev_id}, 'new_provider_from_migration', 'SIP', -1, '#{Device.find(:first).extension}');"
      return p_id
    end
  end
  #-------------  quickforwarddids model ----------------
  class Quickforwarddid < ActiveRecord::Base
  end
  #-------------  ratedetails model ----------------
  class Ratedetail < ActiveRecord::Base
  end
  #-------------  rate model ----------------
  class Rate < ActiveRecord::Base
  end
  #------------- Right model ----------------
  class Right < ActiveRecord::Base
  end
  #------------- Role model ----------------
  class Role < ActiveRecord::Base
  end
  #------------- RoleRight model ----------------
  class RoleRight < ActiveRecord::Base
  end
  #------------- serverproviders model ----------------
  class Serverprovider < ActiveRecord::Base
  end
  #------------- serverproviders model ----------------
  class Service < ActiveRecord::Base
  end
  #------------- serverproviders model ----------------
  class Subscription < ActiveRecord::Base
  end
  #------------- serverproviders model ----------------
  class Tariff < ActiveRecord::Base
  end
  #------------- serverproviders model ----------------
  class Tax < ActiveRecord::Base
  end
  #------------- serverproviders model ----------------
  class Terminator < ActiveRecord::Base
  end
  #------------- user_translations model ----------------
  class UserTranslation < ActiveRecord::Base
  end
  #------------- user_translations model ----------------
  class Usergroup < ActiveRecord::Base
  end
  #------------- user_translations model ----------------
  class User < ActiveRecord::Base
    def User.set_admin_id
      msg = "#============ UPDATE USER ID : #{Reseller_ID} ======================="
      Debug.debug(msg)
      MyWritter.msg(msg)
      MyWritter.msg "UPDATE users SET id = 0 , usertype = 'admin' WHERE id = #{Reseller_ID};"
    end
  end
  #------------- voicemail_boxes model ----------------
  class VoicemailBox < ActiveRecord::Base
  end
  #------------- voicemail_boxes model ----------------
  class Voucher < ActiveRecord::Base
  end


  #------------- Export all model ----------------
  class ExportAll

    def ExportAll.make_inserts(u_id, ru_id)
      u_id = u_id.join(",")
      ru_id = ru_id.join(",")
      if Table_name.blank?
        tables = Not_change_tables
        #[Acustratedetail, Adaction, Aratedetail, Callerid, Currencie, CcGhostminutepercent,  Destination, Direction, Destinationgroup, Right, Role, RoleRight, Day, Devicetype, Didrate, Extline, FlatrateData, FlatrateDestination, Hangupcausecode, Invoicedetail, IvrAction, IvrBlock, IvrExtension, Lcrprovider, Locationrule, Pdffaxemail, Pdffaxe, Providercodec, Providerrule, Quickforwarddid, Ratedetail, Rate, Serverprovider, Subscription, Tax, Usergroup, VoicemailBox]
      else
        tables = [Table_name.singularize.titleize.constantize]
      end
      tables.each { |t|
        case t.to_s
          when 'Acustratedetail'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN customrates ON (customrates.id = customrate_id)", :conditions => " user_id IN (#{u_id})", :group => "#{t.table_name}.id")
          when 'Adaction'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN campaigns ON (campaigns.id = campaign_id)", :conditions => "user_id IN (#{ru_id})", :group => "#{t.table_name}.id")
          when *['Aratedetail', 'Ratedetail']
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN rates ON (rates.id = rate_id) JOIN tariffs ON (tariffs.id = rates.tariff_id)", :conditions => "owner_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when *['Callerid', 'Devicecodec', 'Callflow', 'Pdffaxemail', 'Pdffaxe']
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN devices ON (devices.id = device_id)", :conditions => "devices.user_id IN (#{ru_id})", :group => "#{t.table_name}.id")
          when 'Extline'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "LEFT JOIN devices ON (devices.id = device_id)", :conditions => "devices.user_id IN (#{ru_id}) OR device_id = 0", :group => "#{t.table_name}.id")
          when 'VoicemailBox'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN devices ON (devices.id = device_id)", :conditions => "devices.user_id IN (#{ru_id})", :group => "#{t.table_name}.uniqueid")
          when *['CcGhostminutepercent', 'Cclineitem']
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN cardgroups ON (cardgroups.id = cardgroup_id)", :conditions => "cardgroups.owner_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when 'Ccorder'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN cc_invoices ON (cc_invoices.ccorder_id = ccorders.id)", :conditions => "cardgroups.owner_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when *['Didrate', 'Quickforwarddid']
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN dids ON (dids.id = did_id)", :conditions => "dids.reseller_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when 'FlatrateData'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN subscriptions ON (subscriptions.id = subscription_id)", :conditions => "subscriptions.user_id IN (#{u_id})", :group => "#{t.table_name}.id")
          when *['FlatrateDestination', 'Subscription']
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN services ON (services.id = service_id)", :conditions => "owner_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when 'Invoicedetail'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN invoices ON (invoices.id = invoice_id)", :conditions => "user_id IN (#{ru_id})", :group => "#{t.table_name}.id")
          when *['IvrAction', 'IvrExtension']
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN ivr_blocks ON (ivr_blocks.id = ivr_block_id) JOIN ivrs ON (ivrs.id = ivr_id)", :conditions => "user_id = #{Reseller_ID} ", :group => "#{t.table_name}.id")
          when 'IvrBlock'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN ivrs ON (ivrs.id = ivr_id)", :conditions => "user_id = #{Reseller_ID} ", :group => "#{t.table_name}.id")
          when *['Lcrprovider', 'Providercodec', 'Providerrule', 'Serverprovider']
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN providers ON (providers.id = provider_id)", :conditions => "user_id = #{Reseller_ID} ", :group => "#{t.table_name}.id")
          when 'Locationrule'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN locations ON (locations.id = location_id)", :conditions => "user_id = #{Reseller_ID} ", :group => "#{t.table_name}.id")
          when 'Rate'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN tariffs ON (tariffs.id = tariff_id)", :conditions => "owner_id = #{Reseller_ID} ", :group => "#{t.table_name}.id")
          when 'Tax'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => " LEFT JOIN cs_invoices ON (cs_invoices.tax_id = taxes.id) LEFT JOIN invoices ON (invoices.tax_id = taxes.id) LEFT JOIN users ON (users.tax_id = taxes.id) LEFT JOIN vouchers ON (vouchers.tax_id = taxes.id) LEFT JOIN cardgroups ON (cardgroups.tax_id = taxes.id)", :conditions => "invoices.user_id IN (#{ru_id}) OR cs_invoices.user_id  IN (#{ru_id}) OR users.id  IN (#{ru_id}) OR vouchers.user_id IN (#{ru_id}) OR cardgroups.owner_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when 'Usergroup'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => "JOIN groups ON (groups.id = group_id)", :conditions => "owner_id = #{Reseller_ID} ", :group => "#{t.table_name}.id")
          when 'Right'
            actions = t.find(:all, :select => "#{t.table_name}.*", :group => "controller, action")
          else
            actions = t.find(:all)
        end

        Debug.debug("Checking : #{t}")
        if actions and actions.size.to_i > 0

          msg = "#=================== DELETE AND INSERT INTO #{t.table_name} , found to insert : #{actions.size.to_i} ==========="
          Debug.debug(msg)
          MyWritter.msg(msg)
          MyWritter.msg "TRUNCATE #{t.table_name};"  if t.table_name.to_s != 'ivr_sound_files'  and t.table_name.to_s != 'ivr_voices'
          sql_header = "INSERT IGNORE INTO #{t.table_name} (`#{t.column_names.sort.join('`, `')}`) VALUES "

          sql_values = []
          actions.each_with_index { |a, i|
            sql_lines = []
            a.attributes.sort.each { |key, value|
              sql_lines << MyHelper.output(value)
            }
            sql_values << sql_lines.join(', ')
            if (i % 10000).to_i == 0 and i > 0
              MyWritter.msg sql_header + "(" + sql_values.join("), (") +");"
              sql_values = []
            end
          }
          MyWritter.msg sql_header + "(" + sql_values.join("), (") +");"
        end
      }
    end

  end
  #------------- Export all changes model ----------------
  class ExportAllChange

    def ExportAllChange.make_inserts(u_id)
      u_id = u_id.join(",")
      if Table_name.blank?
        tables = Change_tables
        #[Action, Address, Cardgroup, Card, Campaign, Customrate, CcInvoice, Devicegroup, Device, Dialplan, Did, Group, Invoice, IvrSoundFile, IvrTimeperiod, IvrVoice, Ivr, LcrPartial, Lcr, Payment, Phonebook, Provider, Service, Tariff, Terminator, UserTranslation, User, Voucher]
      else
        tables = [Table_name.singularize.titleize.constantize]
      end

      tables.each { |t|
        case t.to_s
          when *['Action', 'Campaign', 'Customrate', 'Devicegroup', 'Dialplan', 'Invoice', 'IvrSoundFile', 'IvrTimeperiod', 'IvrVoice', 'Ivr', 'LcrPartial', 'Lcr', 'Payment', 'Phonebook', 'Provider', 'Terminator', 'UserTranslation', 'Voucher']
            actions = t.find(:all, :select => "#{t.table_name}.*", :conditions => "user_id IN (#{u_id})", :group => "#{t.table_name}.id")
          when 'Device'
            actions = t.find(:all, :select => "#{t.table_name}.*", :joins => 'LEFT JOIN providers ON (providers.device_id = devices.id)', :conditions => "devices.user_id IN (#{u_id}) OR providers.user_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when 'Address'
            actions = t.find(:all, :select => "#{t.table_name}.*", :conditions => "id IN (SELECT address_id FROM users WHERE id IN (#{u_id}))", :group => "#{t.table_name}.id")
          when *['Cardgroup', 'Card', 'Group', 'Service', 'Tariff']
            actions = t.find(:all, :select => "#{t.table_name}.*", :conditions => "owner_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
          when *['CsInvoice', 'CcInvoice']
            actions = t.find(:all, :select => "#{t.table_name}.*", :conditions => "owner_id IN (#{u_id})", :group => "#{t.table_name}.id")
          when 'User'
            actions = t.find(:all, :select => "#{t.table_name}.*", :conditions => "id IN (#{u_id})", :group => "#{t.table_name}.id")
          when 'Did'
            actions = t.find(:all, :select => "#{t.table_name}.*", :conditions => "reseller_id = #{Reseller_ID}", :group => "#{t.table_name}.id")
        end
        Debug.debug("Checking : #{t}")
        if actions and actions.size.to_i > 0
          msg = "#=================== DELETE AND INSERT INTO #{t.table_name} , found to insert : #{actions.size.to_i} ==========="
          Debug.debug(msg)
          MyWritter.msg(msg)
          MyWritter.msg "TRUNCATE #{t.table_name};"  if t.table_name.to_s != 'ivr_sound_files'  and t.table_name.to_s != 'ivr_voices'
          sql_header ="INSERT IGNORE INTO #{t.table_name} (`#{t.column_names.sort.join('`, `')}`) VALUES "
          sql_values = []
          actions.each_with_index { |a, i|
            sql_lines = []
            a.attributes.sort.each { |key, value|
              case t.to_s
                when *['Action', 'Campaign', 'Customrate', 'CsInvoice', 'Device', 'Devicegroup', 'Dialplan', 'Invoice', 'IvrSoundFile', 'IvrTimeperiod', 'IvrVoice', 'Ivr', 'LcrPartial', 'Lcr', 'Payment', 'Phonebook', 'Provider', 'Terminator', 'UserTranslation', 'Voucher']
                  sql_lines << ExportAllChange.change_key('user_id', key, value)
                when *['Cardgroup', 'Card', 'CcInvoice', 'Group', 'Service', 'Tariff', 'User']
                  sql_lines << ExportAllChange.change_key('owner_id', key, value)
                when 'Did'
                  sql_lines << ExportAllChange.change_key('reseller_id', key, value)
                else
                  sql_lines << MyHelper.output(value)
              end
            }
            sql_values << sql_lines.join(', ')
            if (i % 10000).to_i == 0 and i > 0
              MyWritter.msg sql_header + "(" + sql_values.join("), (") +");"
              sql_values = []
            end
          }
          MyWritter.msg sql_header + "(" + sql_values.join("), (") +");"
        end
      }
    end

    def ExportAllChange.change_key(string, key, value)
      if key == string and value.to_i == Reseller_ID.to_i
        sql_lines = 0
      else
        sql_lines = MyHelper.output(value)
      end
      return sql_lines
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

  #------------- MyWritter model ----------------
  class MyWritter
    def MyWritter.msg(msg)
      File.open(Output_file, "a") { |f|
        f << msg.to_s
        f << "\n"
      }
    end

  end
  #------------- MyHelper model ----------------
  class MyHelper

    def MyHelper.output(value)
      case value.class.to_s
        when 'Integer'
          out = value.to_i
        when 'String'
          str = value.to_s.split("'")
          out = "'#{str.join("\\'")}'"
        when 'Time'
          out = "'#{value.to_s(:db)}'"
        when 'Date'
          out = "'#{value.to_s(:db)}'"
        when 'Float'
          out = value.to_f
        #      when 'Fixnum'
        #        out = value.to_s
        else
          out = "'#{value.to_s.gsub("'", "\\'")}'"
      end
      #puts out
      return out
    end

  end

  #------------------ Main -------------------
  Debug.debug("\n*******************************************************************************************************")
  Debug.debug("#{Time.now().to_s(:db)} --- STARTING RESELLER MIGRATION : #{Reseller_ID} ")

  users = User.find(:all, :conditions => "owner_id = #{Reseller_ID}")
  u_ids = []
  users.each { |u| u_ids << u.id }
  ru_ids = u_ids + [Reseller_ID]

  Change_tables = [Action, Address, Cardgroup, Card, Campaign, Customrate, CcInvoice, Devicegroup, Device, Dialplan, Did, Group, Invoice, IvrSoundFile, IvrTimeperiod, IvrVoice, Ivr, LcrPartial, Lcr, Payment, Phonebook, Provider, Service, Tariff, Terminator, UserTranslation, User, Voucher]
  Not_change_tables = [Acustratedetail, Adaction, Aratedetail, Callerid, Currencie, CcGhostminutepercent, Destination, Direction, Destinationgroup, Right, Role, RoleRight, Day, Devicetype, Didrate, Extline, FlatrateData, FlatrateDestination, Hangupcausecode, Invoicedetail, IvrAction, IvrBlock, IvrExtension, Lcrprovider, Locationrule, Pdffaxemail, Pdffaxe, Providercodec, Providerrule, Quickforwarddid, Ratedetail, Rate, Serverprovider, Subscription, Tax, Usergroup, VoicemailBox]

  if Table_name.blank?
    ExportAllChange.make_inserts(ru_ids)
    ExportAll.make_inserts(u_ids, ru_ids)
    Email.update_velues
    Confline.update_velues
    pr_id = Provider.create_new
    Call.make_inserts(pr_id)
    User.set_admin_id
  else
    if Change_tables.include?(Table_name.singularize.titleize.constantize)
      ExportAllChange.make_inserts(ru_ids)
    else
      ExportAll.make_inserts(u_ids, ru_ids)
    end
  end

  MyWritter.msg "\n"
  MyWritter.msg '#=====================================END==========================================='

  puts "OK : #{Output_file}"

rescue Exception => e
  puts e.to_yaml
  #------------------ ERROR -------------------
  File.open(Debug_file, "a") { |f| f << "******************************************************************************************************* \n"
  f << "#{Time.now().to_s(:db)} --- ERROR ! \n #{e.class} \n #{e.message} \n" }
  if e.class.to_s =='NameError'
    puts "Enter correct table name!"
  end
  puts "FAIL"
end

#yeah, we need to close MySQL connection...
ActiveRecord::Base.remove_connection

Debug.debug("#{Time.now().to_s(:db)} --- FINISHING RESELLER MIGRATION : #{Reseller_ID}")
