# -*- encoding : utf-8 -*-
module IvrHelper

  def make_tooltip(block, actions, extensions)
    sumary_tool_tip = []
    sumary_tool_tip << "#{block.name}<br />#{_('Timeout_Response')}: #{block.timeout_response}<br />#{_('Timeout_Digits')}: #{block.timeout_digits}<br /><br /> #{_('Actions')}:<br />"
    for action in actions do
      sumary_tool_tip << "#{action.name}: #{action.data1}"
      sumary_tool_tip << "=#{action.data2}" if action.data3 and action.data2.length > 0
      sumary_tool_tip << "<br />"
    end

    sumary_tool_tip << "<br />#{_('Extensions')}:<br />"
    for extension in extensions
      sumary_tool_tip << "#{extension.exten}: #{extension.goto_ivr_block.name}<br />"
    end
    sumary_tool_tip.join("")
  end

  def draw_block(block, x, y, context, text_div, small = nil)
    line_nr = 0
    line_height = 12
    top_spacing = 6
    max_text_lenght = 20
    box_height = 203
    box_width = 150
    small_cell_width = 30
    small_cell_height = box_height / 7
    text_top_align = 8
    text_left_align = 10
    actions = block.ivr_actions
    extensions = block.ivr_extensions

    content = []
    sumary_tool_tip = make_tooltip(block, actions, extensions)

    content << "document.getElementById('#{text_div}').innerHTML +=  \"<div id = 'block_name' style='position:absolute; white-space: nowrap; font-weight: bold; top: #{y+top_spacing+line_nr*line_height}px; left: #{x+40}px;' ><a href='#' onclick=\\\"new Ajax.Updater('edit_window', '#{Web_Dir}/ivr/refresh_edit_window?block_id=#{block.id}', {asynchronous:true, evalScripts:true}); return false;\\\"  onmouseover=\\\"Tip('#{sumary_tool_tip}')\\\" onmouseout = \\\"UnTip()\\\">#{block.name}<\\\/a><\\\/div>\";"

    if small == nil
      line_nr += 1
      content << "document.getElementById('#{text_div}').innerHTML += \"<div id = 'block_name' style='position:absolute; white-space: nowrap;  top: #{y+top_spacing+line_nr*line_height}px; left: #{x+40}px;' ><a onmouseover=\\\"Tip(\'#{_('Timeout_Response')}: #{block.timeout_response}\')\\\" onmouseout = \\\"UnTip()\\\">#{_('Timeout_Response')}: #{block.timeout_response}<\\\/a><\\\/div>\";"
      line_nr += 1
      content << "document.getElementById('#{text_div}').innerHTML += \"<div id = 'block_name' style='position:absolute; white-space: nowrap;  top: #{y+top_spacing+line_nr*line_height}px; left: #{x+40}px;' ><a onmouseover=\\\"Tip(\'#{_('Timeout_Digits')}: #{block.timeout_digits}\')\\\" onmouseout = \\\"UnTip()\\\">#{_('Timeout_Digits')}: #{block.timeout_digits}<\\\/a><\\\/div>\";"
      line_nr += 2
      i = 0
      7.times do
        content << "#{context}.strokeRect(#{x}, #{y+i*small_cell_height}, #{small_cell_width}, #{small_cell_height});"
        content << "#{context}.strokeRect(#{x+box_width+small_cell_width}, #{y+i*small_cell_height}, #{small_cell_width}, #{small_cell_height});"
        i += 1
      end

      for exten in block.ivr_extensions do
        if exten.exten.to_i != 0 or exten.exten == "0"
          pos = exten.exten.to_i
        else
          case exten.exten
            when "#"
              pos = 10
            when "*"
              pos = 11
            when "i"
              pos = 12
            when "t"
              pos = 13
          end
        end
        content << "document.getElementById('#{text_div}').innerHTML+=\"<div id = 'block_name' style='position:absolute; white-space: nowrap; font-weight: bold; top: #{y+(pos%7)*small_cell_height+text_top_align}px; left: #{x+((pos/7)*(box_width+small_cell_width)+text_left_align)}px;' >#{exten.exten}<\\\/div>\";"
      end
      content << "document.getElementById('#{text_div}').innerHTML+=\"<div id = 'block_name' style='position:absolute; white-space: nowrap; font-weight: bold; top: #{y+top_spacing+line_nr*line_height}px; left: #{x+40}px;' >#{_("Actions")}:<\\\/div>\";"

      for action in actions do
        line_nr += 1
        case action.name
          when "Delay"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_delay' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}: #{action.data1}<\\\/a><\\\/div>\";"
          when "Hangup"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_hangup' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}: #{action.data1}<\\\/a><\\\/div>\";"
          when "Debug"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_debug' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}<\\\/a><\\\/div>\";"
            line_nr += 1
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_debug2' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+50}px;'>#{check_string_length(action.data1, max_text_lenght)}<\\\/div>\";"
          when "Playback"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_playback' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1} - #{action.data2}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}:<\\\/a><\\\/div>\";"
            line_nr += 1
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_playback2' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+50}px;'>#{check_string_length(action.data1+" - "+action.data2, max_text_lenght)}<\\\/div>\";"
          when "Change Voice"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_voice' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}:<\\\/a><\\\/div>\";"
            line_nr += 1
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_voice2' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+50}px;'>#{check_string_length(action.data1, max_text_lenght)}<\\\/div>\";"
          when "Transfer To"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_goto' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}:<\\\/a><\\\/div>\";"
            line_nr += 1
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_goto2' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+50}px;'>#{check_string_length(action.data1.to_s+":"+action.data2.to_s, max_text_lenght)}<\\\/div>\";"
          when "Mor"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_name' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}<\\\/a><\\\/div>\";"
          when "Set Accountcode"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_name' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}:<\\\/a><\\\/div>\";"
            line_nr += 1
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_voice2' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+50}px;'>#{check_string_length(action.data1, max_text_lenght)}<\\\/div>\";"
          when "Set Variable"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_name' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name+': '+action.data1+'='+action.data2}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}:<\\\/a><\\\/div>\";"
            line_nr += 1
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_voice2' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+50}px;'>#{check_string_length(action.data1+'='+action.data2, max_text_lenght-2)}<\\\/div>\";"
          when "Change CallerID (Number)"
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='change_callerid' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}:<\\\/a><\\\/div>\";"
            line_nr += 1
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='change_callerid2' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+50}px;'>#{check_string_length(action.data1, max_text_lenght)}<\\\/div>\";"
          else
            content << "document.getElementById('#{text_div}').innerHTML+=\"<div id='block_name' style='position:absolute; white-space: nowrap; top:#{y+top_spacing+line_nr*line_height}px; left:#{x+40}px;'><a onmouseover=\\\"Tip(\'#{action.name}: #{action.data1}\')\\\" onmouseout = \\\"UnTip()\\\">#{action.name}<\\\/a><\\\/div>\";"
        end
      end
    end

    if line_nr > 15 or small != nil
      if line_nr == 0
        box_height = 29
      else
        box_height = line_nr *13
        if box_height > 280
          content = ["canvas.height = '#{box_height+50}';"] + content
        end
      end

    end
    content << "#{context}.strokeRect(#{x+small_cell_width}, #{y}, #{box_width}, #{box_height});"
    content.join("\n")
  end

  def draw_block_icon(block, x, y, context, text_div)
    actions = block.ivr_actions
    extensions = block.ivr_extensions
    sumary_tool_tip = make_tooltip(block, actions, extensions)
    content = []
    content << "var icon = new Image();"
    content << "icon.src = '#{Web_Dir}'+'/images/icons/view.png';"
    content << "document.getElementById('#{text_div}').innerHTML +=  \"<div id = 'block_name' style='position:absolute; font-weight: bold; top: #{y+16}px; left: #{x-block.name.size*2}px;' ><a href='#' onclick=\\\"new Ajax.Updater('edit_window', '#{Web_Dir}/ivr/refresh_edit_window?block_id=#{block.id}', {asynchronous:true, evalScripts:true}); return false;\\\"  onmouseover=\\\"Tip(\'#{sumary_tool_tip}\')\\\" onmouseout = \\\"UnTip()\\\">#{block.name}<\\\/a><\\\/div>\";"
    content << "icon.onload=#{context}.drawImage(icon, #{x} ,#{y});"
    content.join("")
  end

  def block_link(block)
    actions = block.ivr_actions
    extensions = block.ivr_extensions
    sumary_tool_tip = make_tooltip(block, actions, extensions).gsub("/", "\\/")
    content = link_to_remote(b_view+block.name,
                             {:url => {:controller => :ivr,
                                       :action => :refresh_edit_window,
                                       :block_id => block.id,
                             },
                              :update => "edit_window",
                              :loading => "Element.show('spinner');",
                              :complete => "Element.hide('spinner');"},
                             {:onmouseover => "Tip(\'#{sumary_tool_tip}\');", :onmouseout => "UnTip();"})
    content
  end

=begin rdoc
Generates default observer for MOR. With some default params. Like frequency

<tt>action</tt> - IvrAction.
+number+ - Number of data field to be updated. Default = 1
=end

  def generate_default_observer(action, number = nil, options ={})
    name = (number ? "action_#{action.id.to_s}_#{number.to_s}" : "action_#{action.id.to_s}")
    return observe_field(name, {
        :url => {:controller => "ivr", :action => "update_data1", :id => action.id, :number => number},
        :loading => "Element.show('spinner');",
        :complete => "Element.hide('spinner');#{last_changed(name.to_s)}",
        :with => "'data=' + value"}.merge(options)
    )
  end

  def generate_default_observer2(action, name, options ={})
    return observe_field(name.to_s, {
        :url => {:controller => "ivr", :action => "update_data2", :id => action.id},
        :loading => "Element.show('spinner');",
        :complete => "Element.hide('spinner');#{last_changed(name.to_s)}",
        :with => "'data=' + value"}.merge(options))
  end

=begin rdoc
Generates selector and observer for <b>Delay</b> action.

<tt>action</tt> - IvrAction.
=end

  def generate_delay(action)
    code = [text_field_tag("action_#{action.id.to_s}", action.data1.to_s, "class" => "input", :size => "10", :maxlength => "10")]
    code << generate_default_observer(action)
    code.join("\n")
  end

=begin rdoc
Generates selector and observer for <b>Change voice</b> action.

<tt>action</tt> - IvrAction.
=end

  def generate_change_voice(action)
    voices = current_user.ivr_voices.find(:all)
    if voices.size > 0
      code = [select_tag(action.id, options_for_select(voices.map { |voice| [voice.voice.to_s, voice.voice.to_s] }, action.data1.to_s), {:id => "action_#{action.id}"})]
      code << generate_default_observer(action)
    else
      code = ["<b>#{_("No_Voices_To_Select_From")}</b>"]
    end
    code.join("\n")
  end

=begin rdoc
Generates selector and observer for <b>Playback</b> action.

<tt>action</tt> - IvrAction.
=end
  def generate_playback(action)
    content_tag(:div, playback(action), {:id => "playback_params_#{action.id}"})
  end

  def playback(action)
    voice = current_user.ivr_voices.find(:all)
    if !action.data1.blank?
      sound_files = current_user.ivr_sound_files.find(:all,
                                                      :joins => "LEFT JOIN ivr_voices ON (ivr_voices.id = ivr_sound_files.ivr_voice_id)",
                                                      :conditions => ["ivr_voices.voice = ?", action.data1])
    else
      sound_files = []
    end
    code = select_tag(action.id, options_for_select(voice.map { |lan| [lan.voice.to_s, lan.voice.to_s] }, action.data1.to_s), {:id => "action_#{action.id}"})
    code += select_tag("sound_files_#{action.id}", options_for_select(sound_files.map { |file| [check_string_length(file.path, 30).to_s, file.path.to_s] }, action.data2.to_s), {:id => "action_sound_files_#{action.id}"})
    code += generate_default_observer(action, nil, {:update => "playback_params_#{action.id}"})
    code += generate_default_observer2(action, "action_sound_files_#{action.id.to_s}")
    code
  end


=begin rdoc
Generates selector and observer for <b>Hangup</b> action.

<tt>action</tt> - IvrAction.
=end

  def generate_hangup(action)
    code = select_tag(action.id, options_for_select([['Busy', 'Busy'], ['Congestion', 'Congestion']], action.data1.to_s), {:id => "action_#{action.id}"})
    code += generate_default_observer(action)
    code
  end

=begin rdoc
Generates selector and observer for <b>Transfer To</b> action.

<tt>action</tt> - IvrAction.

 # TODO this method needs some rework. Splitting and refactoring selectors.
=end

  def generate_transfer_to(action)
    content_tag(:div, transfer_to(action), {:id => "goto_params_#{action.id}"})
  end

  def transfer_to(action)
    transfers = ['IVR', 'DID', 'Device', 'Block']
    transfers << 'Extension' if mor_11_extend?
    code = select_tag action.id, options_for_select(transfers.map { |t| [t, t] }, action.data1.to_s), {:id => "action_#{action.id}"}
    options = []
    case action.data1
      when 'DID'
        dids = current_user.load_dids(:all, :conditions => "status = 'active'", :order => "did")
        options = dids.map { |did| ["#{did.did} (#{did.status})", did.did.to_s] }
      when 'IVR'
        ivrs = current_user.ivrs.find(:all)
        options = ivrs.map { |ivr| [ivr.name.to_s, ivr.start_block_id.to_s] }
      when 'Block'
        action_block = action.ivr_block
        blocks = IvrBlock.find(:all, :conditions => ["ivr_id = ?", action_block.ivr_id])
        options = blocks.map { |block| [block.name.to_s, block.id.to_s] }
      when 'Device'
        sql = "SELECT devices.id as id, users.first_name as first_name, users.last_name as last_name, devices.device_type as dev_type, devices.name as dev_name, devices.extension as dev_extension FROM devices LEFT JOIN users ON (devices.user_id = users.id) WHERE devices.user_id > -1 AND users.owner_id = #{current_user.id}"
        devices = ActiveRecord::Base.connection.select_all(sql)
        options = devices.map { |d| ["#{nice_user_from_data(d["username"], d["first_name"], d["last_name"])} - #{device_info_from_data(d["dev_type"], d["dev_name"], d["dev_extension"])}", d["dev_extension"].to_s] }
    end

    if action.data1 == 'Extension'
      code += text_field_tag("action_param_#{action.id.to_s}", action.data2.to_s, "class" => "input", :size => "30", :maxlength => "255")
    else
      code += select_tag(action.id, options_for_select(options, action.data2.to_s), {:id => "action_param_#{action.id}"})
    end
    code += generate_default_observer(action, nil, {:update => "goto_params_#{action.id}"})
    code += generate_default_observer2(action, "action_param_#{action.id.to_s}")
    code
  end

=begin rdoc
Generates selector and observer for <b>Debug</b> action.

<tt>action</tt> - IvrAction.
=end

  def generate_debug(action)
    code = text_field_tag("action_#{action.id.to_s}", action.data1.to_s, "class" => "input", :size => "30", :maxlength => "255")
    code += generate_default_observer(action)
    code
  end

=begin rdoc

=end


  def generate_set_accountcode(action)
    devices = current_user.load_users_devices(:all, :include => :user, :conditions => "devices.user_id > -1")
    code = select_tag(action.id, options_for_select(devices.map { |device| ["#{nice_user(device.user)} - #{nice_device_no_pic(device)}", device.id.to_s] }, action.data1.to_s), {:id => "action_#{action.id}"})
    code += generate_default_observer(action)
    code
  end


=begin rdoc
  Generates selector and observer for <b>Set Variable</b> action.

  <tt>action</tt> - IvrAction.

  Variables hash defines possible variables to chose from.
=end

  def generate_set_variable(action)
    variables = {"MOR_ASK_DST_TIMES" => "MOR_ASK_DST_TIMES"}
    code = "<select id ='action#{action.id}' name='#{action.id}'>"
    for variable in variables do
      code += "<option value='#{variable[0]}' #{ 'selected' if action.data1.to_s == variable[0]} >#{variable[0]}</option>\n"
    end
    code += "</select>"
    code += text_field_tag("action#{action.id.to_s}_2", action.data2.to_s, "class" => "input", :size => "30", :maxlength => "255")
    code += generate_default_observer(action)
    code += generate_default_observer(action, 2)
  end

=begin rdoc
Generates selector and observer for <b>Change CallerID (Number)</b> action.

<tt>action</tt> - IvrAction.
=end

  def generate_change_callerid(action)
    code = [text_field_tag("action_#{action.id.to_s}", action.data1.to_s, "class" => "input", :size => "15", :maxlength => "15")]
    code << generate_default_observer(action)
    code.join("\n")
  end

=begin rdoc
  Shows proper data input/select fields for action.

  +action+ - IvrAction
=end

  def proper_params(action)
    return "<b>Error in command. Contact developers.</b>" if !action or action.class.to_s != "IvrAction"
    case action.name.to_s
      when "Delay"
        return generate_delay(action)
      when "Change Voice"
        return generate_change_voice(action)
      when "Playback"
        return generate_playback(action)
      when "Hangup"
        return generate_hangup(action)
      when "Transfer To"
        return generate_transfer_to(action)
      when "Debug"
        return generate_debug(action)
      when "Set Accountcode"
        return generate_set_accountcode(action)
      when "Mor"
        return ""
      when "Set Variable"
        return generate_set_variable(action)
      when "Change CallerID (Number)"
        return generate_change_callerid(action)
      else
        return "<b>Unknown command. Contact developers.</b>"
    end
    ""
  end

=begin rdoc
Clears all text in first text area in IVR edit window.
=end

  def clear_text
    "document.getElementById('div_space').innerHTML = '';"
  end

=begin rdoc
Clears all text in second text area in IVR edit window.
=end

  def clear_text2
    "document.getElementById('div_space2').innerHTML = '';"
  end

=begin
 Checks lenght of the string and corrects string if it is to long.

 +string+ - String variable.
 +size+ - size sthing should be able to fit in.
=end

  def check_string_length(string, size)
    if (size <= 3) and (string.to_s.size > size)
      return "..."
    end
    #size += 1
    if string.to_s.size > size
      string = string[0..size-4] + "..."
    end
    string
  end

  # kazkokia netvarkla kad neima is aplication_helper.rb
  # TODO isiaiskinti kodel neveikia normaliai

  def print_tech(tech)
    if tech
      tech = Confline.get_value("Change_Zap_to") if tech.downcase == "zap" and Confline.get_value("Change_Zap").to_i == 1
    else
      tech = ""
    end
    tech
  end

=begin rdoc
 Shows select menu with possible action choises. If choise is invalidated by absence
 then this choise is disabled with message. Currently only "Playback" and "Change Voice"
 may be invalidated if there are no IvrVoice or IvrSoundFile objects.

 *Params*

 * +action+ - IvrAction that should be assigned with select field
 * +pos_actions+ - array of possible actions to chose from
 * +options+ - additional params. :sounds, :voices
=end
  def pos_action_select(action, pos_actions = [], options ={})
    id = "change_action_#{action.id}"
    code = ["<select id ='#{id}' name='#{action.id}' onclick='view_extension(this.value, #{action.id});'>"]
    pos_actions.each { |pos_action|
      case pos_action
        when "Playback"
          unless options[:voices]
            code << "  <option disabled value= '#{pos_action}'>#{pos_action} - #{_('No_Ivr_Voices')}</option>"

          else
            unless options[:sounds]
              code << "  <option disabled value= '#{pos_action}'>#{pos_action} - #{_('No_Ivr_Sounds')}</option>"
            else
              code << "  <option value= '#{pos_action}' #{'selected' if action.name.to_s == pos_action.to_s}>#{pos_action}</option>"
            end
          end
        when "Change Voice"
          unless options[:voices]
            code << "  <option disabled value= '#{pos_action}'>#{pos_action} - #{_('No_Ivr_Voices')}</option>"
          else
            code << "  <option value= '#{pos_action}' #{'selected' if action.name.to_s == pos_action.to_s}>#{pos_action}</option>"
          end
        else
          code << "  <option value= '#{pos_action}' #{'selected' if action.name.to_s == pos_action.to_s}>#{pos_action}</option>"
      end
    }
    code << "</select>"
    code << observe_field(id, :update => "action_params_#{action.id}", :with => "action_name", :url => {:action => "action_params", :id => action.id}, :loading => "Element.show('spinner');", :complete => "Element.hide('spinner');")
    code.join("\n")
  end

  def device_info_from_data(type, name, extension)
    "#{print_tech(type)} #{(type.to_s == "FAX" or name.to_s.length == 0) ? extension : name}"
  end

  def last_changed(element_id)
    "$('last_changed').value = '#{element_id}:' + $('#{element_id}').value"
  end
end
