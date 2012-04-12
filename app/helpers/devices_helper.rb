# -*- encoding : utf-8 -*-
module DevicesHelper

  def draw_callflows(cfs)
    output = ""
    for cf in cfs
      case cf.action
        when "empty"
          output += "-<br>"
        when "forward"
          dev = Device.find(:first, :conditions => ["id = ?", cf.data]) if cf.data2 == "local"
          if cf.data2 == "local"
            if dev
              output += _('Forward') + " " + b_forward + " " + dev.device_type + "/" + dev.name + "<br>"
            else
              output += _("Device_not_found")
            end
          end
          output += _('Forward') + " " + b_forward + " " + cf.data + "<br>" if cf.data2 == "external"
          output += b_cross + _('Forward_not_functional_please_enter_dst') + "<br>" if cf.data2 == ""
        when "voicemail"
          output += b_voicemail + _('VoiceMail') + "<br>"
        when "fax_detect"
          dev = Device.find(:first, :conditions => ["id = ?", cf.data]) if cf.data2 == "fax"
          if dev and cf.data2 == "fax"
            output += _('Fax_detect') + ": " + b_fax + " " + dev.device_type + "/" + dev.extension + "<br>"
          else
            output += _('Fax_device_not_found')
          end
          output += b_cross + _('Fax_detect_not_functional_please_select_fax_device') + "<br>" if cf.data2 == ""
      end
    end
    output
  end

  def print_cf_type(cft)
    o = ""
    case cft
      when "before_call"
        o += _('Before_Call')
      when "answered"
        o += _('Answered')
      when "no_answer"
        o += _('No_Answer')
      when "busy"
        o += _('Busy')
      when "failed"
        o += _('Failed')
    end
    o
  end

  def print_cf_action(cfa)
    o = ""
    case cfa
      when "empty"
        o += _('Empty')
      when "forward"
        o += _('Forward')
      when "voicemail"
        o += _('VoiceMail')
    end
    o
  end
end
