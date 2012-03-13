# -*- encoding : utf-8 -*-
class Callerid < ActiveRecord::Base
  belongs_to :device

  validates_uniqueness_of :cli, :message => _('Such_CLI_exists')
  validates_presence_of :cli, :message => _('Please_enter_details')
  validates_numericality_of :cli, :message => _("CLI_must_be_number")
  
  def Callerid.use_for_callback(cli, status)
    if status.to_i == 1
      sql = "UPDATE callerids SET callerids.email_callback = '0'
           WHERE device_id = '#{cli.device_id}' AND callerids.id != '#{cli.id}'"
      sql2= "UPDATE callerids SET callerids.email_callback = '1'
           WHERE callerids.id = '#{cli.id}'"
      ActiveRecord::Base.connection.update(sql)
      ActiveRecord::Base.connection.update(sql2)
    else
      sql2= "UPDATE callerids SET callerids.email_callback = '0'
           WHERE callerids.id = '#{cli.id}'"
      ActiveRecord::Base.connection.update(sql2)
    end
  end
  
  
  def Callerid.set_callback_from_emails(old_callerid, new_callerid)
    
    cli3 = Callerid.find(:first, :conditions => "cli = '#{old_callerid}' AND email_callback = '1' ")
    if  cli3
      cli = Callerid.find(:first, :conditions => "cli = '#{new_callerid}'")
      if cli
        MorLog.my_debug "changed: #{old_callerid} to #{new_callerid}"
        Callerid.use_for_callback(cli,1)
      else
        MorLog.my_debug "Create new Callerid, Callerid.cli=#{new_callerid}"
        cli2 = Callerid.new
        cli2.cli = new_callerid
        cli2.device_id = cli3.device_id
        cli2.description = ""
        cli2.comment = ""
        cli2.banned = 0
        cli2.added_at = Time.now
        cli2.save
        MorLog.my_debug "changed with creating: #{old_callerid} to #{new_callerid}"
        Callerid.use_for_callback(cli2,1)
      end
                
      Action.add_action2(0, "email_callback_change", "completed", "#{old_callerid} changed to #{new_callerid}")
      
    else
      MorLog.my_debug "Email Callback ERROR: #{old_callerid} not found or not allowed for email callback, dst: #{new_callerid}"
      Action.add_action2(0, "email_callback_change", "error", "#{old_callerid} not found or not allowed for email callback, dst: #{new_callerid}")

    end
  end

  def Callerid.create_from_csv(name, options)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV create_clids_from_csv #{name}", 1)

    usa_sql = "INSERT INTO callerids (cli, device_id, description, created_at)
    SELECT DISTINCT(replace(col_#{options[:imp_clid]}, '\\r', '')), '-1', 'this cli created from csv', '#{Time.now.to_s(:db)}'  FROM #{name}
    LEFT JOIN callerids on (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', ''))
    WHERE not_found_in_db = 1 and nice_error != 1 and callerids.id is null"
    #MorLog.my_debug usa_sql
    begin
      ActiveRecord::Base.connection.execute(usa_sql)
      ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(replace(col_#{options[:imp_clid]}, '\\r', ''))) FROM #{name} WHERE not_found_in_db = 1 and nice_error != 1 ").to_i
    rescue
      0
    end
  end

end
