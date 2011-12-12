class Backup < ActiveRecord::Base
  extend UniversalHelpers
  
  def destroy_all
    backup_folder = Confline.get_value('Backup_Folder')
    `rm -rf #{backup_folder.to_s + "/db_dump_" + self.backuptime.to_s + ".sql.tar.gz"}`
    self.destroy 
  end


  def Backup.backups_hourly_cronjob(user_id)
    MorLog.my_debug "Checking hourly backups"
    backup_shedule = Confline.get_value("Backup_shedule")
    backup_month = Confline.get_value("Backup_month")
    backup_month_day = Confline.get_value("Backup_month_day")
    backup_week_day = Confline.get_value("Backup_week_day")
    backup_hour = Confline.get_value("Backup_hour")
    backup_number = Confline.get_value('Backup_number')
    backup_folder = Confline.get_value('Backup_Folder')
    backup_disk_space = Confline.get_value('Backup_disk_space')
    MorLog.my_debug("Make backups at: #{backup_hour} h", true, "%Y-%m-%d %H:%M:%S")
    backup_hour = 0 if backup_hour.to_i == 24

    @time = Time.now()
    if backup_shedule.to_i == 1
      if (backup_month.to_i == @time.month.to_i) or (backup_month.to_s == "Every_month")
        if (backup_month_day.to_i == @time.day.to_i) or (backup_month_day.to_s == "Every_day")
          if (backup_week_day.to_i ==  @time.wday.to_i) or (backup_week_day.to_s == "Every_day")
            if (backup_hour.to_i == @time.hour.to_i) or (backup_hour.to_s == "Every_hour")
              res = 0
              MorLog.my_debug "Making auto backup"

              # check if we have enough space
              space = disk_space_usage(backup_folder.to_s).to_i
              MorLog.my_debug "Free space on HDD for backups: #{(100 - space)} %"
              if (100 - space) < backup_disk_space.to_i
                MorLog.my_debug "Not enough space on HDD to make new backup"
                res = 2
              end

              if res == 0

                # check if we have correct number of auto backups
                MorLog.my_debug "Checking for old backups"
                backups = Backup.find(:all, :conditions =>"backuptype = 'auto'")
                if backups.size.to_i >= backup_number.to_i
                  backup = Backup.find(:first, :conditions =>"backuptype = 'auto'", :order => "backuptime ASC")
                  backup.destroy_all
                  MorLog.my_debug "Old auto backup deleted"
                end

                #make backup
                res = Backup.private_backup_create(user_id, "auto", "")
              end

              if res > 0
                MorLog.my_debug("Auto backup failed")
              else
                MorLog.my_debug("Auto backup created")
              end
            end
          end
        end
      end
    end
  end

  def Backup.private_backup_create(user_id, backuptype = "manual", comment = "")
    time = Time.now().to_s(:db)
    backuptime =  time.split(/[- :]/).to_s
    backup_folder = Confline.get_value("Backup_Folder")

    backup_folder = "/usr/local/mor/backups" if backup_folder.to_s == ""

   # script=[]
    MorLog.my_debug("/usr/local/mor/make_backup.sh #{backuptime} #{backup_folder} -c")
    script= `/usr/local/mor/make_backup.sh #{backuptime} #{backup_folder} -c`

    return_code = script.to_s.scan(/\d+/).to_s.to_i

    MorLog.my_debug(return_code)

    if return_code == 0
      backup = Backup.new
      backup.comment = comment
      backup.backuptype = backuptype
      backup.backuptime =  backuptime
      backup.save
      MorLog.my_debug("Auto backup made", true, "%Y-%m-%d %H:%M:%S")
    end
    Action.add_action2(user_id.to_i, 'backup_created', backup.id, return_code)
    return_code
  end
end
