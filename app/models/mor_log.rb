class MorLog
  begin
    require "ruby-prof"
  rescue LoadError
  end

  def MorLog.my_debug(msg, add_time = nil, format_string = "%y-%m-%d %H:%M:%S")
    if add_time 
      if add_time.class.to_s == "Time"
        msg = add_time.strftime(format_string) +" - "+ msg
        time = add_time
      else 
        msg = Time.now.strftime(format_string) +" - "+ msg 
        time = Time.now
      end
      
    end
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
    if add_time
      return time
    else
      return true
    end
  end
  
  def MorLog.log_exception(exception, id, controller, action)
    if exception
      crash_log_file = Confline.get_value("Crash_log_file").to_s
      crash_log_file = "/tmp/mor_crash.log" if crash_log_file.to_s.length == 0
       trace = (exception.respond_to?(:backtrace) ? exception.backtrace : [])
      File.open(crash_log_file, "a") { |f|
        f << "--------------------------------------------------------------------------------\n"
        f << "ID:         #{id.to_s}\n"
        f << "Class:      #{exception.class.to_s}\n"
        f << "Message:    #{exception.to_s}\n"
        f << "Controller: #{controller.to_s}\n"
        f << "Action:     #{action.to_s}\n"
        f << "----------------------------------------\n"
        f << "#{trace.join("\n")}"
        f << "\n"
      }
    end
  end
=begin
 Do not use this. It now generates to much ouptut. Needs to be cleaned before use.

 *Params*:

 +bind+ - "binding" current ruby binding.
=end
  def MorLog.debug_variables(bind)
    vars = eval('local_variables + instance_variables', bind)
    vars.each do |var|
      my_debug "#{var} = #{eval(var, bind).inspect}"
    end
  end

  def MorLog.profile_start
    RubyProf.stop if RubyProf.running?
    RubyProf.start
  end

  def MorLog.profile_end
    if RubyProf.running?
      result = RubyProf.stop
      printer = RubyProf::GraphHtmlPrinter.new(result)
      printer.print(File.new("#{RAILS_ROOT}/log/profile.html", "w"))
    end
  end
=begin
 Dumps some key call information. Feel free to edit to your needs.
=end
  def MorLog.dump_call_info(msg, call)
    str = ["START: #{msg}-CALL_ID:#{call.id}-----------------------------"]
    str << "  user_id : #{call.user_id}"
    str << "  DST: #{call.dst}"
    str << "  SRC: #{call.src}"
    str << "  Disposition: #{call.disposition}"
    str << "  Billsec: #{call.billsec}"

    if call.disposition == "ANSWERED"
      str << "  Provider:"
      {"rate" => call.provider_rate, "billsec" => call.provider_billsec, "price" => call.provider_price}.each{|msg, val| str << "    #{msg}: #{val}"}

      str << "  User:"
      {"rate" => call.user_rate, "billsec" => call.user_billsec, "price" => call.user_price}.each{|msg, val| str << "    #{msg}: #{val}"}
      if call.reseller_id.to_i > 0
        str << "  Reseller:"
        {"rate" => call.reseller_rate, "billsec" => call.reseller_billsec, "price" => call.reseller_price}.each{|msg, val| str << "    #{msg}: #{val}"}
      end
    end
    str << "END: #{msg}-------------------------------------"
    MorLog.my_debug(str.join("\n"))
  end
end