# -*- encoding : utf-8 -*-
class Recording < ActiveRecord::Base

  belongs_to :call
  belongs_to :user
  belongs_to :dst_user, :class_name => 'User', :foreign_key => 'dst_user_id'

#  def call
#    Call.find(:first, :conditions => ["id = ?",self.call_id])
#  end

  def destroy_all

    if self.local.to_i == 1
      # delete from local server

      MorLog.my_debug("Deleting audio file #{self.uniqueid}.mp3 from local server")
      rm_cmd = "rm -f /home/mor/public/recordings/#{self.uniqueid}.mp3"
      MorLog.my_debug(rm_cmd)
      system(rm_cmd)

    else
      # delete from remote server
      server = Confline.get_value("Recordings_addon_IP").to_s
      server_port = Confline.get_value("Recordings_addon_Port").to_s
      server_user = Confline.get_value("Recordings_addon_Login").to_s

      file_path = "/usr/local/mor/recordings/#{self.uniqueid.to_s}.mp3"

      MorLog.my_debug("Deleting audio file #{self.uniqueid}.mp3 from remote server #{server.to_s}")
      rm_cmd = "/usr/bin/ssh #{server_user.to_s}@#{server.to_s} -p #{server_port.to_s} -f rm -fr #{file_path} "
      MorLog.my_debug(rm_cmd)
      system(rm_cmd)

    end

    self.destroy
  end

=begin
    full_path = Confline.get_value("IVR_Voice_Dir")+"/"+@voice.voice+"/"+self.path
    rm_cmd = "rm -f #{full_path}"
    system(rm_cmd)
    
    # delete file from remote Asterisk servers 
    servers = Server.find(:all, :conditions => "server_ip != '127.0.0.1' AND active = 1")
    for server in servers
      MorLog.my_debug("deleting audio file #{full_path} from server #{server.server_ip}")
      rm_cmd = "/usr/bin/ssh root@#{server.server_ip} -p #{server.ssh_port} -f rm -fr #{full_path} "
      MorLog.my_debug(rm_cmd)
        
      system(rm_cmd)
=end


  # mp3 file without path
  def mp3
    self.uniqueid.to_s + ".mp3"
  end

end
