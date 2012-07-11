# -*- encoding : utf-8 -*-
class Audio


  def Audio::convert(src, dst, rm = nil, path = "", filename = "")
    MorLog.my_debug(src)
    MorLog.my_debug(dst)
    #path = Confline.get_value("Temp_Dir")

    convert_cmd = "/usr/local/mor/convert_mp3wav2astwav.sh #{src} #{dst}"
    MorLog.my_debug convert_cmd
    system(convert_cmd)


    MorLog.my_debug("Rm : " + rm.to_s)
    if rm and rm.to_i == 1
      Audio.rm_sound_file(src)
    end

    # send files to remote Asterisk servers if we know file name
    if path.length > 0 and filename.length > 0
      servers = Server.find(:all, :conditions => "server_ip != '127.0.0.1' AND active = 1")
      for server in servers
        MorLog.my_debug("moving audio file #{filename} to server #{server.server_ip}, path: #{path}")
        # move
        cp_cmd = "/usr/bin/scp -P #{server.ssh_port} #{dst} root@#{server.server_ip}:/tmp/#{filename} "
        mv_cmd = "/usr/bin/ssh root@#{server.server_ip} -p #{server.ssh_port} -f mv /tmp/#{filename} #{path} "
        MorLog.my_debug(cp_cmd)
        MorLog.my_debug(mv_cmd)

        system(cp_cmd)
        system(mv_cmd)
      end
    end
  end

  def Audio.nice_file_name(string)
    File.basename(string, '.*').gsub('.', '_')
  end

  def Audio.rm_sound_file(src)
    rm_cmd = "rm -fr \'#{src}\'"
    MorLog.my_debug(rm_cmd)
    system(rm_cmd)


    # delete file from remote Asterisk servers
    servers = Server.find(:all, :conditions => "server_ip != '127.0.0.1' AND active = 1")
    for server in servers
      MorLog.my_debug("deleting audio file #{rm_cmd} from server #{server.server_ip}")
      rm_cmd = "/usr/bin/ssh root@#{server.server_ip} -p #{server.ssh_port} -f #{rm_cmd} "
      MorLog.my_debug(rm_cmd)

      system(rm_cmd)
    end
  end

  def Audio.usible_name(dst, aa)
    if File.exists?(dst)
      aa.to_s + Time.now.to_i.to_s
    else
      aa
    end
  end

  def Audio.create_file(file, object, server_path)
    path, final_path = object.final_path
    notice = ''
    if file and notice.blank?
      if file.size.to_i > 0 and notice.blank?
        if  file.size.to_i < 10485760 and notice.blank?
          filename = File.basename(file.original_filename.gsub(/[^\w\.\_]/, '_'), '_')
          ext = filename.split(".").last
          #MorLog.my_debug ext
          if (ext.downcase == 'mp3' or ext.downcase == 'wav') and notice.blank?
            aa = Audio.nice_file_name(filename)
            new_name = Audio.usible_name("#{final_path}/#{aa}.wav", aa)
            #MorLog.my_debug new_name
            src = path + aa + "." +ext.downcase
            File.open(src, "wb") do |f|
              f.write(file.read)
            end
            dst = "#{final_path}#{final_path.chars.to_a.last == '/' ? '' : '/'}#{new_name}.wav"
            Audio.convert(src, dst, 1, server_path, new_name)
            if !File.exists?(dst) and notice.blank?
              notice = _("File_not_uploaded_please_check_file_system_permissions")
            else
              Action.add_action_hash(User.current, {:action => 'Sound_file_addet', :data => new_name, :data2 => dst, :target_id => object.id, :target_type => object.class.to_s.downcase})
            end
          else
            notice = _("File_is_not_wav_or_mp3")
          end
        else
          notice = _("File_is_too_big")
        end
      else
        notice =_('Please_select_file')
      end
    else
      notice = _("File_not_uploaded")
    end
    return notice, new_name.to_s # + '.wav'
  end

end
