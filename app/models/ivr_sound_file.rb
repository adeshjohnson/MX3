# -*- encoding : utf-8 -*-
class IvrSoundFile< ActiveRecord::Base
  belongs_to :ivr_voice
  belongs_to :user

  before_create :ivr_s_before_create

  def ivr_s_before_create
    self.user_id = User.current.id
  end

  def voice
    IvrVoice.find(:first, :conditions => "id = #{self.ivr_voice_id}")
  end

  def file_list(voice_id = nil)
    if voice_id
      res = find(:all)
    else
      res = find(:all, :conditions => {:ivr_voice_id => voice_id})
    end
    if res == nil or res.size == 0
      return {}
    end
    res
  end

  def destroy_with_file
    Audio.rm_sound_file(Confline.get_value("IVR_Voice_Dir")+"/"+self.voice.voice+"/"+self.path)
    self.destroy
  end

  def nice_size
    ext = "B"
    size = self.size.to_f
    if size > 1024
      size = size / 1024
      ext = "Kb"
    end

    if size > 1024
      size = size / 1024
      ext = "Mb"
    end

    if size > 1024
      size = size / 1024
      ext = "Gb"
    end

    sprintf("%.2f", size).to_s + " "+ ext.to_s
  end

  class << self # Class methods
    alias :all_columns :columns

    def columns
      all_columns.reject { |c| c.name == 'readonly' }
    end
  end

  def self.readonly
    self[:readonly]
  end

  def self.readonly=(s)
    self[:readonly] = s
  end

  protected
  def validate_on_create
    file = IvrSoundFile.find(:first, :conditions => "ivr_voice_id = \'#{ivr_voice_id}\' and path =\'#{path}\'")
    errors.add(:path, "File already exists") if file
  end


end
