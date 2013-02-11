# -*- encoding : utf-8 -*-
class BackupsController < ApplicationController

  layout "callc"
  before_filter :check_localization
  before_filter :authorize

  def index
    redirect_to :action => 'backup_manager'
  end

  def list
    redirect_to :action => 'backup_manager'
  end

  def backup_manager
    @page_title = _('Backup_manager')
    @page_icon = 'database_save.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Backup_system"
    @backups = Backup.order("backuptime ASC").all
  end

  def backup_new
    @page_title = _('Backup_new')
    @page_icon = 'add.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Backup_system"
    @back = Backup.new
  end

  def backup_destroy

    backup = Backup.where(:id => params[:id]).first
    unless backup
      flash[:notice] = _("Backup_was_not_found")
      redirect_to :action => :backup_manager and return false
    end
    backup.destroy_all

    flash[:status] = _('Backup_deleted')
    redirect_to :action => 'backup_manager'
  end

  def backup_download
    path = Confline.get_value("Backup_Folder")
    backup = Backup.where(:id => params[:id]).first
    unless backup
      flash[:notice] = _('Backup_was_not_found')
      redirect_to :action => :backup_manager and return false
    end
    filename = "db_dump_" + backup.backuptime.to_s + ".sql.tar.gz"
    full_filename = path +"/"+ filename

    begin
      file = File.open(full_filename, "rb")
      send_data file.read, :filename => filename
    rescue
      flash[:notice] = _('Backup_file_is_missing')
      redirect_to :action => :backup_manager and return false
    end
  end

  def backup_create
    res = Backup.private_backup_create(session[:user_id], "manual", params[:comment])
    if res == 1
      my_debug("Manual backup failed")
      flash[:notice] = _('Error') + " : " + backup_error
    else
      my_debug("Manual backup created")
      flash[:status] = _('Backup_created')
    end
    redirect_to :action => 'backup_manager'
  end

  def backup_restore

    backup = Backup.where(:id => params[:id]).first
    unless backup
      flash[:notice] = _('Backup_was_not_found')
      redirect_to :action => :backup_manager and return false
    end

    res = private_backup_restore(backup)
    MorLog.my_debug(res)
    if res.to_i == 1
      my_debug("Backup restore failed")
      flash[:notice] = _('Error') + " : " + backup_error
    else
      my_debug("Backup restored")
      flash[:status] = _('Backup_restored')
    end
    redirect_to :action => 'backup_manager'
  end

  def backups_hourly_cronjob
    Backup.backups_hourly_cronjob(session[:user_id])
    render :nothing => true
  end

  private

  def private_backup_restore(backup)
    backup = Backup.find(backup) unless backup.class == Backup
    backup_folder = Confline.get_value("Backup_Folder")

    #script=[]
    #logger.fatal "/usr/local/mor/make_restore.sh #{backup.backuptime} #{backup_folder} -c"
    command = "/usr/local/mor/make_restore.sh #{backup.backuptime} #{backup_folder} -c"
    logger.fatal command
    script = %x[#{command}]
    logger.fatal script
    #my_debug("response : " + script[0].split(" ").last.last.to_s )    

    return_code = script.to_s.scan(/\d+/).last.to_i #script.to_s.scan(/\d+/).to_s.to_i

    Action.add_action2(session[:user_id].to_i, 'backup_restored', backup.id, return_code)
    return_code
  end

  def backup_error
    if File.exists?("/tmp/mor_debug_backup.txt")
      file = File.open("/tmp/mor_debug_backup.txt", "rb")
      error = file.read.split("\n")
      total_numbers = error.size
      error[(total_numbers - 1).to_i].to_s
    else
      ""
    end
  end
end
