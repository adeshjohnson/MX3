# -*- encoding : utf-8 -*-
class Dialplan < ActiveRecord::Base
  has_one :ivr_sound_file
  has_many :dids, :class_name => 'Did', :foreign_key => 'dialplan_id'
  belongs_to :user

  before_save :dp_before_save

  def dp_before_save
    self.user_id = User.current.id
  end

  def ringgroup
    Ringgroup.find(:first, :conditions => {:id => data1})
  end

  #
  #  def dids
  #    Did.find(:all, :conditions => "dialplan_id = #{self.id}")
  #  end

  def destroy_all
    if self.dptype == 'ivr'
      Extline.delete_all("exten = 'dialplan#{self.id}'")
    end
    Extline.delete_all(["exten = ?", "dp#{self.id}"])
    self.destroy
  end

  def pbxfunction

    pf = nil
    pf = Pbxfunction.find(self.data1) if self.data1 and self.data1.to_i > 0
    pf

  end

  def regenerate_ivr_dialplan()
    if self.dptype == 'ivr'
      months = %w(jan feb mar apr may jun jul aug sep oct nov dec)
      #      ivr_collection = []
      #
      #      extlines = Extline.find(:all, :conditions => "exten = 'dialplan#{self.id}'")
      #      for line in extlines do
      #        if line["app"] == "GotoIfTime" or line["app"] == "GoTo"
      #          data = line["appdata"].split("?").last.split(',').first
      #          first_ivr_block =  data.split("ivr_block")[1].to_i
      #          ivr = Ivr.find(:first, :conditions => "start_block_id = #{first_ivr_block}")
      #          for block in ivr.ivr_blocks do
      #            Extline.delete_all("context = 'ivr_block#{block.id}'")
      #          end
      #        end
      #      end
      Extline.delete_all("exten = 'dialplan#{self.id}'")

      # first debug line ---------------------
      dialplan = self
      context = "mor"
      exten = "dialplan#{dialplan.id}"
      app = "NoOp"
      appdata = "Dial Plan #{dialplan.id} reached"
      Extline.mcreate(context, "1", app, appdata, exten, "0")
      # second line ----- first IVR
      if dialplan["data2"].to_i != 0
        ivr1 = Ivr.find(:first, :conditions => "id = #{dialplan["data2"].to_i}")
        #        ivr_collection << ivr1
        app = "GotoIfTime"
        if dialplan["data1"].to_i != 0
          t = IvrTimeperiod.find(:first, :conditions => "id = #{dialplan["data1"].to_i}")
          appdata = t.start_hour.to_s+":"+t.start_minute.to_s+"-"+t.end_hour.to_s+":"+t.end_minute.to_s+"|"
          t.start_weekday == "0" ? appdata += "mon-" : appdata += t.start_weekday+"-"
          t.end_weekday == "0" ? appdata += "sun|" : appdata += t.end_weekday+"|"
          t.start_day.to_i == 0 ? appdata += "1-" : appdata += t.start_day.to_s+"-"
          t.end_day.to_i == 0 ? appdata += "31|" : appdata += t.end_day.to_s+"|"
          t.start_month.to_i == 0 ? appdata += months[0]+"-" :appdata += months[t.start_month.to_i-1]+"-"
          t.end_month.to_i == 0 ? appdata += months[11] :appdata += months[t.end_month.to_i-1]
          appdata +="?ivr_block#{ivr1.start_block_id}|s|1"
        else
          appdata = "*|*|*|*?ivr_block#{ivr1.start_block_id}|s|1"
        end
      else
        app = "NoOp"
        appdata = "First_Block_Not_Set"
      end
      Extline.mcreate(context, "2", app, appdata, exten, "0")
      # third line --------- second IVR
      if dialplan["data4"].to_i != 0
        ivr2 = Ivr.find(:first, :conditions => "id = #{dialplan["data4"].to_i}")
        #        ivr_collection << ivr2
        app = "GotoIfTime"
        if dialplan["data3"].to_i != 0
          t = IvrTimeperiod.find(:first, :conditions => "id = #{dialplan["data3"].to_i}")
          appdata = t.start_hour.to_s+":"+t.start_minute.to_s+"-"+t.end_hour.to_s+":"+t.end_minute.to_s+"|"
          t.start_weekday == "0" ? appdata += "mon-" : appdata += t.start_weekday+"-"
          t.end_weekday == "0" ? appdata += "sun|" : appdata += t.end_weekday+"|"
          t.start_day.to_i == 0 ? appdata += "1-" : appdata += t.start_day.to_s+"-"
          t.end_day.to_i == 0 ? appdata += "31|" : appdata += t.end_day.to_s+"|"
          t.start_month.to_i == 0 ? appdata += months[0]+"-" :appdata += months[t.start_month.to_i-1]+"-"
          t.end_month.to_i == 0 ? appdata += months[11] :appdata += months[t.end_month.to_i-1]
          appdata +="?ivr_block#{ivr2.start_block_id}|s|1"
        else
          appdata = "*|*|*|*?ivr_block#{ivr2.start_block_id}|s|1"
        end
      else
        app = "NoOp"
        appdata = "Second_Block_Not_Set"
      end
      Extline.mcreate(context, "3", app, appdata, exten, "0")
      # forth line ------------ Third IVR
      if dialplan["data6"].to_i != 0
        ivr3 = Ivr.find(:first, :conditions => "id = #{dialplan["data6"].to_i}")
        #        ivr_collection << ivr3
        app = "GotoIfTime"
        if dialplan["data5"].to_i != 0
          t = IvrTimeperiod.find(:first, :conditions => "id = #{dialplan["data5"].to_i}")
          appdata = t.start_hour.to_s+":"+t.start_minute.to_s+"-"+t.end_hour.to_s+":"+t.end_minute.to_s+"|"
          t.start_weekday == "0" ? appdata += "mon-" : appdata += t.start_weekday+"-"
          t.end_weekday == "0" ? appdata += "sun|" : appdata += t.end_weekday+"|"
          t.start_day.to_i == 0 ? appdata += "1-" : appdata += t.start_day.to_s+"-"
          t.end_day.to_i == 0 ? appdata += "31|" : appdata += t.end_day.to_s+"|"
          t.start_month.to_i == 0 ? appdata += months[0]+"-" :appdata += months[t.start_month.to_i-1]+"-"
          t.end_month.to_i == 0 ? appdata += months[11] :appdata += months[t.end_month.to_i-1]
          appdata +="?ivr_block#{ivr3.start_block_id}|s|1"
        else
          appdata = "*|*|*|*?ivr_block#{ivr3.start_block_id}|s|1"
        end
      else
        app = "NoOp"
        appdata = "Third_Block_Not_Set"
      end
      Extline.mcreate(context, "4", app, appdata, exten, "0")
      # fifth line ------- Forth - default IVR
      if dialplan["data7"].to_i != 0
        ivr4 = Ivr.find(:first, :conditions => "id = #{dialplan["data7"].to_i}")
        #        ivr_collection << ivr4
        app = "Goto"
        appdata = "ivr_block#{ivr4.start_block_id}|s|1"
      else
        app = "NoOp"
        appdata = "Default_Block_Not_Set"
      end
      Extline.mcreate(context, "5", app, appdata, exten, "0")
      for server in Server.find(:all)
        server.ami_cmd("extensions reload")
      end
    end
  end

  def type_id=(value)
    self.data1 = value
  end

  def ext=(value)
    self.data2 = value
  end

  def currency=(value)
    self.data3 = value
  end

  def language=(value)
    self.data4 = value
  end

  def sound_file_name
    sf = IvrSoundFile.where(:id => self.sound_file_id).includes(:ivr_voice).first
    return (sf) ? "#{sf.ivr_voice.voice}/#{sf.path}" : ""
  end

=begin
  'Tell time' status depends on whether to to tell time and whether to tell seconds.

  *Params*
  +tell_time+ - number specifying whether to tell time
  +tell_seconds+ - number specifying wheter to tell seconds

  *Returns*
  Integer number depending on params returns 0, 1 or 2.
=end
  def tell_time_status(tell_time=0, tell_seconds=0)
    if tell_time.to_i == 0
      return 0
    elsif tell_seconds.to_i == 1
      return 2
    else
      return 1
    end
  end

=begin
  *Returns*
  false or true depending on whether to tell time or not
=end
  def tell_time
    self.data3 == "1"
  end

=begin
  *Returns*
  false or true depending on whether to tell seconds or not
=end
  def tell_sec
    self.data3 == "2"
  end

  def Dialplan.change_tell_balance_value(value)
    dls = Dialplan.find(:all, :conditions => 'dptype = "quickforwarddids"')
    if dls and dls.size.to_i > 0
      for d in dls
        d.data1 = value
        d.save
      end
    end
  end

  def Dialplan.change_tell_time_value(value)
    dls = Dialplan.find(:all, :conditions => 'dptype = "quickforwarddids"')
    if dls and dls.size.to_i > 0
      for d in dls
        d.data2 = value
        d.save
      end
    end
  end
end
