# -*- encoding : utf-8 -*-
class IvrVoice< ActiveRecord::Base
  has_many :ivr_sound_files
  belongs_to :user

  validates_uniqueness_of :voice
  validates_presence_of :voice

  before_create :set_user, :mkdir_for_voices
  before_validation :ivrv_before_validation

  def destroy_with_file
    for sound in self.ivr_sound_files do
      sound.destroy_with_file
    end
    Audio.rm_sound_file(Confline.get_value("IVR_Voice_Dir")+voice)
    self.destroy
  end

  def final_path
    path = Confline.get_value("Temp_Dir")
    final_path = Confline.get_value("IVR_Voice_Dir") + voice + "/"
    MorLog.my_debug "final_path:" + final_path.to_s
    return path, final_path
  end

  class << self # Class methods
    alias :all_columns :columns
    def columns
      all_columns.reject {|c| c.name == 'readonly'}
    end
  end

  def self.readonly
    self[:readonly]
  end

  def self.readonly=(s)
    self[:readonly] = s
  end

  protected
  
  def ivrv_before_validation
    self.voice = self.voice.downcase.gsub(/[^a-z_]/, "")
  end

  def validate
    errors.add(:voice, "Contains Invalid symbols") if voice.scan(/[^a-z_]/).size != 0
  end

  def  set_user
    self.user_id = User.current.id
  end

  def mkdir_for_voices
    dir = "#{Confline.get_value("IVR_Voice_Dir")+voice}"
    system("mkdir #{dir}")
    # create new voice on asterisk servers
    path = "/var/lib/asterisk/sounds/mor/ivr_voices/"
    servers = Server.find(:all, :conditions => "server_ip != '127.0.0.1' AND active = 1")
    for server in servers
      MorLog.my_debug("creating voice dir #{voice} on server #{server.server_ip}, path: #{path}")
      mkdir_cmd = "/usr/bin/ssh root@#{server.server_ip} -p #{server.ssh_port} -f mkdir #{path}#{voice} "
      system(mkdir_cmd)
      MorLog.my_debug(mkdir_cmd)
    end

    unless File.directory?(dir)
      errors.add(:voice, _("Cann_not_create_directory"))
      return false
    end
  end


end
