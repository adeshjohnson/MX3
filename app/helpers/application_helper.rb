# -*- encoding : utf-8 -*-
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include SqlExport
  include UniversalHelpers
  #    def ApplicationHelper::reset_values
  #      @nice_number_digits = nil
  #    end

  def tooltip(title, text)
    raw "onmouseover=\"Tip(\' #{text} \', WIDTH, -600, TITLE, '#{title}', TITLEBGCOLOR, '#494646', FADEIN, 200, FADEOUT, 200 )\" onmouseout = \"UnTip()\"".html_safe
  end

  def weekday_name(day)
    weekdays = %w( Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
    weekdays[day.to_i-1]
  end

  def draw_flag(country_code)
    unless country_code.blank?
      image_tag("flags/" + country_code.to_s.downcase + ".jpg", :style => 'border-style:none', :title => country_code.to_s.upcase)
    end
  end

  def draw_flag_by_code(flag)
    unless flag.blank?
      image_tag("flags/" + flag + ".jpg", :style => 'border-style:none', :title => flag.upcase)
    end
  end

  def nice_time2(time)
    format = session[:time_format].to_s.blank? ? "%H:%M:%S" : session[:time_format].to_s
    t = time.respond_to?(:strftime) ? time : ('2000-01-01 ' + time.to_s).to_time
    t.strftime(format.to_s) if time
  end

  def nice_date_time(time, options={})
    if time
      if options
        format = options[:date_time_format].to_s.blank? ? "%Y-%m-%d %H:%M:%S" : options[:date_time_format].to_s
      else
        format = session[:date_time_format].to_s.blank? ? "%Y-%m-%d %H:%M:%S" : session[:date_time_format].to_s
      end
      t = time.respond_to?(:strftime) ? time : time.to_time
      d = t.strftime(format.to_s)
    end
    d
  end

  def nice_date(date, options={})
    if date
      if options
        format = options[:date_format].to_s.blank? ? "%Y-%m-%d" : options[:date_format].to_s
      else
        format = session[:date_format].to_s.blank? ? "%Y-%m-%d" : session[:date_format].to_s
      end
      t = date.respond_to?(:strftime) ? date : date.to_time
      d = t.strftime(format.to_s)
    end
    d
  end

  def nice_number(number, options = {})
    n = "0.00"
    if options[:nice_number_digits]
      n = sprintf("%0.#{options[:nice_number_digits]}f", number.to_d) if number
      if options[:change_decimal]
        n = n.gsub('.', options[:global_decimal])
      end
    else
      nice_number_digits = (session and session[:nice_number_digits]) or Confline.get_value("Nice_Number_Digits")
      nice_number_digits = 2 if nice_number_digits == ''
      n = sprintf("%0.#{nice_number_digits}f", number.to_f) if number
      if session and session[:change_decimal]
        n = n.gsub('.', session[:global_decimal])
      end
    end
    n
  end

  def long_nice_number(number)
    n = ""
    n = sprintf("%0.6f", number) if number
    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end

  def nice_bytes(bytes, sufix_stop = "")
    bytes = bytes.to_d
    sufix_pos = 0
    sufix = ["b", "Kb", "Mb", "Gb", "Tb"]
    if  sufix_stop == "" or !sufix.include?(sufix_stop)
      while bytes >= 1024 do
        bytes = bytes/1024
        sufix_pos += 1
      end
    else
      while sufix[sufix_pos] != sufix_stop
        bytes = bytes/1024
        sufix_pos += 1
      end
    end
    session[:nice_number_digits] ||= Confline.get_value("Nice_Number_Digits").to_i
    session[:nice_number_digits] ||= 2
    bytes = 0 unless bytes
    n = sprintf("%0.#{session[:nice_number_digits]}f", bytes.to_d)+" "+sufix[sufix_pos]
    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end

  def nice_number_currency(number, exchange_rate = 1)
    number = number * exchange_rate.to_d if number
    n = ""
    n = sprintf("%0.#{session[:nice_number_digits]}f", number) if number
    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end


  # shows nice
  def nice_src(call, options={})
    value = Confline.get_value("Show_Full_Src")
    srt = call.clid.split(' ')
    name = srt[0..-2].join(' ').to_s.delete('"')
    number = call.src.to_s
    if options[:pdf].to_i == 0
      session[:show_full_src] ||= value
    end
    if value.to_i == 1 and name.length > 0
      return "#{number} (#{name})"
    else
      return "#{number}"
    end
  end

  # converting caller id like "name" <11> to name
  def nice_cid(cid)
    MorLog.my_debug("Use of nice_cid(cid) is deprecated user nice_src(call) instead.")
    cid = cid.to_s.split(/"\s*/).to_s
    if cid.length > 0
      cid = cid[0, cid.index('<')]
    end
    cid
  end

  # converting caller id like "name" <11> to 11
  def cid_number(cid)
    if cid and cid.index('<') and cid.index('>')
      cid = cid[cid.index('<')+1, cid.index('>') - cid.index('<') - 1]
    else
      cid = ""
    end
    cid
  end

  def date_time(string)
    year = string[0..3]
    mont = string[4..5]
    day = string[6..7]
    hour = string[8..9]
    minute = string[10..11]
    secunde = string[12..13]
    out= year + "-" + mont + "-" + day + " " + hour + ":" + minute + ":" + secunde
  end

  def session_from_date
    sfd = session[:year_from].to_s + "-" + good_date(session[:month_from].to_s) + "-" + good_date(session[:day_from].to_s)
  end

  def session_till_date
    sfd = session[:year_till].to_s + "-" + good_date(session[:month_till].to_s) + "-" + good_date(session[:day_till].to_s)
  end

  def session_from_datetime
    sfd = session[:year_from].to_s + "-" + good_date(session[:month_from].to_s) + "-" + good_date(session[:day_from].to_s) + " " + good_date(session[:hour_from].to_s) + ":" + good_date(session[:minute_from].to_s) + ":00"
  end

  def session_till_datetime
    sfd = session[:year_till].to_s + "-" + good_date(session[:month_till].to_s) + "-" + good_date(session[:day_till].to_s) + " " + good_date(session[:hour_till].to_s) + ":" + good_date(session[:minute_till].to_s) + ":59"
  end

  def nice_month_name(i)
    {"1" => _('January'), "2" => _('February'), "3" => _('March'), "4" => _('April'), "5" => _('May'), "6" => _('June'), "7" => _('July'), "8" => _('August'), "9" => _('September'), "10" => _('October'), "11" => _('November'), "12" => _('December')}[i.to_s].to_s
  end

  # ================ BUTTONS - ICONS =============
  def b_commnet_edit(title)
    image_tag('icons/comment_edit.png', :title => title) + " "
  end

  def b_sort_desc
    image_tag('icons/bullet_arrow_down.png') + " "
  end

  def b_sort_asc
    image_tag('icons/bullet_arrow_up.png') + " "
  end

  def b_phone
    image_tag('icons/phone.png') + " "
  end

  def b_server
    image_tag('icons/server.png') + " "
  end

  def b_spy
    image_tag('icons/sound.png') + " "
  end

  def b_add
    image_tag('icons/add.png', :title => _('Add')) + " "
  end

  def b_up
    image_tag('icons/arrow_up.png', :title => _('Up')) + " "
  end

  def b_down
    image_tag('icons/arrow_down.png', :title => _('Down')) + " "
  end

  def b_delete
    image_tag('icons/delete.png', :title => _('Delete')) + " "
  end

  def b_unassign(options={})
    opts = {:title => _('Unasssign user')}.merge(options)
    #TODO:get sutable icon, maybe user_delete
    image_tag('icons/user_delete.png', :title => opts[:title]) + " "
  end

  def b_hangup
    image_tag('icons/delete.png', :title => _('Hangup')) + " "
  end

  def b_edit
    image_tag('icons/edit.png', :title => _('Edit')) + " "
  end

  def b_back
    image_tag('icons/back.png', :title => _('Back')) + " "
  end

  def b_world_go
    image_tag('icons/world_go.png', :title => "") + " "
  end

  def b_forward
    image_tag('icons/forward.png', :title => "") + " "
  end

  def b_view
    image_tag('icons/view.png', :title => _('View')) + " "
  end

  def b_payments
    image_tag('icons/view.png', :title => _('Payments')) + " "
  end

  def b_details(txt = " ")
    image_tag('icons/details.png', :title => _('Details')) + txt
  end

  def b_user
    image_tag('icons/user.png', :title => _('User')) + " "
  end

  def b_reseller
    image_tag('icons/user_gray.png', :title => _('Reseller')) + " "
  end

  def b_user_gray(options = {})
    opts = {:title => _('User')}.merge(options)
    image_tag('icons/user_gray.png', :title => opts[:title]) + " "
  end

  def b_key
    image_tag('icons/key.png', :title => _('Password')) + " "
  end

  def b_members
    image_tag('icons/group.png', :title => _('Members')) + " "
  end

  def b_change_type
    image_tag('icons/user_edit.png', :title => _('Change_type')) + " "
  end

  def b_chart_bar
    image_tag('icons/chart_bar.png', :title => _('Chart')) + " "
  end

  def b_info(options = {})
    opts = {:title => _('Info')}.merge(options)
    image_tag('icons/information.png', :title => opts[:title]) + " "
  end

  def b_play
    image_tag('icons/play.png', :title => _('Play')) + " "
  end

  def b_time
    image_tag('icons/time.png', :title => _('Time')) + " "
  end

  def b_stop
    image_tag('icons/stop.png', :title => _('Stop')) + " "
  end

  def b_download
    image_tag('icons/download.png', :title => _('Download')) + " "
  end

  def b_music
    image_tag('icons/music.png', :title => _('Recording')) + " "
  end

  def b_record
    image_tag('icons/music.png', :title => _('Recording')) + " "
  end

  def b_device
    image_tag('icons/device.png', :title => _('Device')) + " "
  end

  def b_check(options ={})
    options[:id] = "icon_chech_"+options[:id].to_s if options[:id]
    image_tag('icons/check.png', {:title => "check"}.merge(options)) + " "
  end

  def b_copy(options ={})
    options[:id] = "icon_chech_"+options[:id].to_s if options[:id]
    image_tag('icons/page_copy.png', {:title => _('copy')}.merge(options)) + " "
  end

  def b_csv
    image_tag('icons/excel.png', :title => _('CSV')) + " "
  end

  def b_pdf
    image_tag('icons/pdf.png', :title => _('PDF')) + " "
  end

  def b_cross(options = {})
    options[:id] = "icon_cross_"+options[:id].to_s if options[:id]
    image_tag('icons/cross.png', {:title => "cross"}.merge(options)) + " "
  end

  def b_note
    image_tag('icons/note.png', :title => _("Note")) + " "
  end

  def b_note_add
    image_tag('icons/note_add.png', :title => _("Add_Note")) + " "
  end

  def b_note_delete
    image_tag('icons/note_delete.png', :title => _("Delete_Note")) + " "
  end

  def b_note_edit
    image_tag('icons/note_edit.png', :title => _("Edit_Note")) + " "
  end

  def b_reminder
    image_tag('icons/clock.png', :title => _("Reminder")) + " "
  end

  def b_reminder_add
    image_tag('icons/clock_add.png', :title => _("Add_Reminder")) + " "
  end

  def b_reminder_delete
    image_tag('icons/clock_delete.png', :title => _("Delete_Reminder")) + " "
  end

  def b_reminder_edit
    image_tag('icons/clock_edit.png', :title => _("Edit_Reminder")) + " "
  end

  def b_cart
    image_tag('icons/cart.png', :title => _('Cart')) + " "
  end

  def b_bullet_white
    image_tag('icons/bullet_white.png', :title => "") + " "
  end

  def b_bullet_green
    image_tag('icons/bullet_green.png', :title => "") + " "
  end

  def b_bullet_red
    image_tag('icons/bullet_red.png', :title => "") + " "
  end

  def b_bullet_yellow
    image_tag('icons/bullet_yellow.png', :title => "") + " "
  end

  def b_bullet_grey
    image_tag('icons/control_blank.png', :title => "") + " "
  end

  def b_help_grey
    image_tag('icons/help_grey.png', :title => "") + " "
  end

  def b_blue_bullet
    image_tag('icons/bullet_blue.png', :title => "") + " "
  end

  def b_bullet_black
    image_tag('icons/bullet_black.png', :title => "") + " "
  end

  def b_black_bullet
    image_tag('icons/bullet_black.png', :title => "") + " "
  end


  def b_cart_go
    image_tag('icons/cart_go.png', :title => "") + " "
  end

  def b_cart_empty
    image_tag('icons/cart_delete.png', :title => "") + " "
  end

  def b_cart_checkout
    image_tag('icons/cart_edit.png', :title => "") + " "
  end

  def b_help
    image_tag('icons/help.png', :title => "") + " "
  end

  def b_money
    image_tag('icons/money.png', :title => _('Add_manual_payment')) + " "
  end

  def b_groups
    image_tag('icons/groups.png', :title => _('Groups')) + " "
  end

  def b_subscriptions
    image_tag('icons/layers.png', :title => _('Subscriptions')) + " "
  end

  def b_rates
    image_tag('icons/coins.png', :title => _('Rates')) + " "
  end

  def b_crates
    image_tag('icons/coins.png', :title => _('Custom_rates')) + " "
  end

  def b_actions(options = {})
    image_tag('icons/actions.png', {:title => _('Actions')}.merge(options)) + " "
  end

  def b_details_show
    image_tag('icons/bullet_arrow_down.png', :title => _('Show_details')) + " "
  end

  def b_details_hide
    image_tag('icons/bullet_arrow_up.png', :title => _('Hide_details')) + " "
  end

  def b_undo
    image_tag('icons/undo.png', :title => _('Undo')) + " "
  end

  def b_generate
    image_tag('icons/application_go.png', :title => _('Generate')) + " "
  end

  def b_providers
    image_tag('icons/provider.png', :title => _('Providers')) + " "
  end

  def b_provider_ani
    image_tag('icons/provider_ani.png', :title => _('Provider_with_ANI')) + " "
  end

  def b_date
    image_tag('icons/date.png', :title => "") + " "
  end

  def b_call
    image_tag('icons/call.png', :title => "") + " "
  end

  def b_cardgroup
    image_tag('icons/page_white_stack.png', :title => "") + " "
  end

  def b_call_info
    image_tag('icons/information.png', :title => _('Call_info')) + " "
  end

  def b_trunk
    image_tag('icons/trunk.png', :title => _('Trunk')) + " "
  end

  def b_trunk_ani
    image_tag('icons/trunk_ani.png', :title => _('Trunk_with_ANI')) + " "
  end

  def b_rates_delete
    image_tag('icons/coins_delete.png', :title => _('Rates_delete')) + " "
  end

  def b_make_tariff
    image_tag('icons/application_add.png', :title => _('Make_tariff')) + " "
  end

  def b_provider
    image_tag('icons/provider.png', :title => _('Provider')) + " "
  end

  def b_skype
    image_tag('icons/skype.png', :title => _('Skype')) + " "
  end

  def b_currency
    image_tag('icons/money_dollar.png', :title => _('Currency')) + " "
  end

  def b_cli
    image_tag('icons/cli.png', :title => _('CLI')) + " "
  end

  def b_did
    image_tag('icons/did.png', :title => _('DID')) + " "
  end

  def b_tracing
    image_tag('icons/lightning.png', :title => _('Tracing')) + " "
  end

  def b_testing
    image_tag('icons/lightning.png', :title => _('Testing')) + " "
  end


  def b_lcr
    image_tag('icons/arrow_switch.png', :title => _('LCR')) + " "
  end

  def b_ivr
    image_tag('icons/arrow_divide.png', :title => _('IVR')) + " "
  end

  def b_exclamation(options = {})
    image_tag('icons/exclamation.png', options) + " "
  end

  def b_cancel
    image_tag('icons/cancel.png') + " "
  end

  def b_extlines
    image_tag('icons/asterisk.png', :title => _('Extlines')) + " "
  end

  def b_online
    image_tag('icons/status_online.png', :title => _('Logged_in_to_GUI')) + " "
  end

  def b_offline
    image_tag('icons/status_offline.png', :title => _('Not_Logged_in_to_GUI')) + " "
  end

  def b_search(options = {})
    opts = {:title => _('Search')}.merge(options)
    image_tag('icons/magnifier.png', opts) + " "
  end

  def b_callflow
    image_tag('icons/cog_go.png', :title => _('Call_Flow')) + " "
  end

  def b_voicemail
    image_tag('icons/voicemail.png', :title => _('Voicemail')) + " "
  end

  def b_warning
    image_tag('icons/error.png', :title => _('Warning')) + " "
  end

  def b_rules
    image_tag('icons/page_white_gear.png', :title => _('Provider_rules')) + " "
  end

  def b_empty
    image_tag('icons/page_white.png')
  end

  def b_login_as(options = {})
    opts = {:title => _('Login_as')}.merge(options)
    image_tag('icons/application_key.png', opts) + " "
  end

  def b_call_tracing
    image_tag('icons/lightning.png', :title => _('Call_Tracing')) + " "
  end

  def b_test
    image_tag('icons/lightning.png', :title => _('Test')) + " "
  end

  def b_primary_device
    image_tag('icons/star.png', :title => _('Primary_device')) + " "
  end

  def b_email_send
    image_tag('icons/email_go.png', :title => _('Send')) + " "
  end

  def b_fax
    image_tag('icons/printer.png', :title => _('Fax')) + " "
  end

  def b_email
    image_tag('icons/email.png', :title => _('Email')) + " "
  end

  def b_refresh
    image_tag('icons/arrow_refresh.png', :title => _('Refresh')) + " "
  end

  def b_hide
    image_tag('icons/contrast.png', :title => _('Hide')) + " "
  end

  def b_unhide
    image_tag('icons/contrast.png', :title => _('Unhide')) + " "
  end

  def b_logins
    image_tag('icons/chart_pie.png', :title => _('Logins')) + " "
  end

  def b_call_stats
    image_tag('icons/chart_bar.png', :title => _('Call_Stats')) + " "
  end

  def b_integrity_check
    image_tag('icons/lightning.png', :title => _('Integrity_check')) + " "
  end

  def b_fix
    image_tag('icons/wrench.png', :title => _('Fix')) + " "
  end

  def b_virtual_device
    image_tag('icons/virtual_device.png', :title => _('Virtual_Device')) + " "
  end

  def b_cog
    image_tag('icons/cog.png') + " "
  end

  def b_book
    image_tag('icons/book.png', :title => _('Phonebook')) + " "
  end


  def b_restore
    image_tag('icons/database_refresh.png', :title => _('Restore')) + " "
  end

  def b_download
    image_tag('icons/database_go.png', :title => _('Download')) + " "
  end

  def b_user_log
    image_tag('icons/report_user.png', :title => _('User_log')) + " "
  end

  def b_active(value)
    (value) ? b_check : b_cross
  end


  def currency_selector(diff = nil)
    currs = Currency.get_active
    out = "<table width='100%' class='simple'><tr><td align='right'>"
    for curr in currs
      out += "<b>" if curr.name == session[:show_currency]
      #        if !diff
      #          out += "<a href='#{params[:action]}/#{curr.name}'>#{curr.name}</a>"
      #        else
      #          out += "<a href='?currency=#{curr.name}'>#{curr.name}</a>"
      #        end
      out += link_to("#{curr.name}", :currency => curr.name)
      out += "</b>" if curr.name == session[:show_currency]
    end
    out += "</td></tr></table>"
    out
  end

  def print_tech(tech)
    if tech
      tech = Confline.get_value("Change_dahdi_to") if tech.downcase == "dahdi" and Confline.get_value("Change_dahdi").to_i == 1
    else
      tech = ""
    end
    tech
  end

  def dial_string(prov, dst, cut, add)

    cut = "" if not cut
    add = "" if not add

    ds = dst
    ds = "1234567890" if dst.length == 0
    if prov.device
      ds = print_tech(prov.tech) + "\\" + prov.device.name + "\\" + add + ds[cut.length..-1]
    else
      ds = print_tech(prov.tech).to_s + "\\" + prov.channel.to_s + "\\" + prov.add_a.to_s + ds[cut.length..-1].to_s
    end
    ds
  end

  # draws correct picture of device
  def nice_device_pic(device, options = {})
    provider = device.provider
    d = ""
    d = b_device if device.device_type == "SIP" or device.device_type == "IAX2" or device.device_type == "H323" or device.device_type == "dahdi"
    d = b_trunk if device.istrunk == 1 and device.ani and device.ani == 0
    d = b_trunk_ani if device.istrunk == 1 and device.ani and device.ani == 1
    d = b_fax if device.device_type == "FAX"
    d = b_virtual_device if device.device_type == "Virtual"
    d = b_skype if device.device_type == "Skype"
    d = b_provider if provider
    d.html_safe
  end

  def nice_device_type(device, options = {})
    opts = {
        :image => true,
        :tach => true
    }.merge(options)
    d = []
    d << nice_device_pic(device) if opts[:image] == true
    d << print_tech(device.device_type) if opts[:tech] == true
    d.join("\n").html_safe
  end


  def nice_device(device, options = {})
    opts = {
        :image => true,
        :tech => true
    }.merge(options)
    d = ""
    if device
      d = nice_device_type(device, opts) + "/"
      d += device.name if !device.username.blank? and device.device_type != "FAX"
      d += device.extension if device.device_type == "FAX" or device.name.length == 0 or device.username.blank?
    end

    d.html_safe
  end

  def nice_device_no_pic(device)
    d = ""
    if (device)
      d = print_tech device.device_type + "/"
      d += device.name if device.device_type != "FAX"
      d += device.extension if device.device_type == "FAX" or device.name.length == 0
    end
    d
  end

  def nice_device_from_data(dev_type, dev_name, dev_extension, dev_istrunk, dev_ani, options = {})
    d=""
    d = b_device if dev_type == "SIP" or dev_type == "IAX2" or dev_type == "H323" or dev_type == "dahdi"
    d = b_trunk if dev_istrunk == 1 and dev_ani == 0
    d = b_trunk_ani if dev_istrunk == 1 and dev_ani == 1
    d = b_fax if dev_type == "FAX"
    d = b_virtual_device if dev_type == "Virtual"

    d += print_tech dev_type + "/"
    d += dev_name if dev_type != "FAX"
    d += dev_extension if dev_type == "FAX" or dev_name.length == 0
    if options[:link] == true and options[:device_id].to_i > 0
      d = link_to d, :controller => "devices", :action => "device_edit", :id => options[:device_id].to_i
    end
    d
  end

  def user_link_nice_device(device)
    link_to nice_device(device), :controller => "devices", :action => "user_device_edit", :id => device.id
  end

  def link_nice_device(device)
    if device.user_id != -1
      raw link_to nice_device(device).html_safe, :controller => "devices", :action => "device_edit", :id => device.id
    else

      provider = device.provider
      if provider
        link_to nice_device(device), :controller => "providers", :action => "edit", :id => provider.id
      end

    end
  end

  def link_nice_device_user(device)
    if device
      user = device.user
      if device.user_id == session[:user_id] or user.owner_id == session[:user_id]
        return link_nice_user(user)
      else
        owner = user.owner
        return link_user_gray(owner, {:title => _("This_user_belongs_to_Reseller") + ": " +nice_user(owner)}) + nice_user(user)
      end
    end
  end

  def nice_user(user)
    # dont panic. h() << sanitizes names from &, <, > characters
    if user
      if user.first_name.to_s.length + user.last_name.to_s.length > 0
        return user.first_name.to_s + " " + user.last_name.to_s
      else
        return user.username
      end
    end
    return ""
  end

  def link_nice_user_if_own(user)
    user = User.find(:first, :conditions => ["users.id = ?", user]) if user.class != User
    if user
      user.owner_id == correct_owner_id ? link_nice_user(user) : nice_user(user)
    else
      ""
    end
  end

  def nice_group(group)
    nu = group.name
    nu
  end

  def nice_inv_name(iv_id_name)
    id_name=""
    if  iv_id_name.to_s.strip.to_s[-1..-1].to_s.strip.to_s == "-"
      name_length = iv_id_name.to_s.strip.to_s.length
      name_length = name_length.to_i - 2
      id_name = iv_id_name.to_s.strip.to_s
      id_name = id_name[0..name_length].to_s
    else
      id_name = iv_id_name.to_s
    end
    id_name
  end

  def link_nice_user(user, options = {})
    raw link_to nice_user(user).html_safe, {:controller => "users", :action => "edit", :id => user.id}.merge(options)
  end

  def link_user_gray(user, options = {})
    link_to b_user_gray({:title => options[:title]}), {:controller => "users", :action => "edit", :id => user.id}.merge(options.except(:title))
  end

  def link_nice_group(group)
    link_to nice_group(group), :controller => "cardgroups", :action => "edit", :id => group.id
  end

=begin rdoc
 Sanitized provider name and link to provider edit if  required.
=end

  def nice_provider_from_data(provider, options = {})
    np = h(provider.to_s)
    if options[:link] and options[:provider_id].to_i > 0
      np = link_to np, :controller => :providers, :action => :edit, :id => options[:provider_id].to_i
    end
    np
  end


=begin rdoc

=end

  def nice_did_from_data(did, options = {})
    nd = h(did.to_s)
    if options[:link] and options[:did_id].to_i > 0
      nd = link_to nd, :controller => :dids, :action => :edit, :id => options[:did_id].to_i
    end
    nd
  end

=begin rdoc

=end

  def nice_server_from_data(server, options = {})
    ns = h(server.to_s)
    if options[:link] and options[:server_id].to_i > 0
      ns = link_to ns, :controller => :servers, :action => :edit, :id => options[:server_id].to_i
    end
    ns
  end

  def nice_server(server)
    if server
      _('Server') + '_' + server.server_id.to_s + ': ' + server.server_ip.to_s + '|' + server.hostname.to_s
    end
  end

  def confline(name, id = 0)
    MorLog.my_debug("confline from application_helper.rb is deprecated. Use Confline.get_value")
    MorLog.my_debug("Called_from :: #{caller[0]}")
    Confline.get_value(name, id)
  end

  def confline2(name, id = 0)
    MorLog.my_debug("confline2 from application_helper.rb is deprecated. Use Confline.get_value2")
    MorLog.my_debug("Called_from :: #{caller[0]}")
    Confline.get_value2(name, id)
  end

  def flag_list
    fl = ""
    if session[:tr_arr] and session[:tr_arr].size > 1
      for tr in session[:tr_arr]
        title = tr.name
        title += "/#{tr.native_name}" if tr.native_name.length > 0
        fl += "<a href='?lang=" + tr.short_name + "'> " + image_tag("flags/#{tr.flag}.jpg", :style => 'border-style:none', :title => title) + "</a>"
      end
    end
    fl
  end


  def device_code(code)
    name="Default_device_codec_"+code.to_s
    Confline.get_value(name, session[:user_id])
  end

  def reminder_finder()
    @reminders = CcReminder.find(:all, :conditions => "start_time < '#{nice_date_time(Time.now)}' and user_id ='#{session[:user_id]}'")
    #my_debug @reminders.to_yaml
    code =""
    if @reminders.size.to_i > 0
      code = link_to _('YOU_HAVE A_REMINDER') + " !!!!!!!!!! ", :controller => "callcenter", :action => "reminders", :rem => @reminders
    end
    code
  end

  # ================ DEBUGGING =============

  def dump(object)
    "<pre>" << object.to_yaml << "</pre>"
  end

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  # Helper tha formats call debug info to be shown on a tooltip.
  def format_debug_info(hash)
    debug_text = "PeerIP: " + hash["peerip"].to_s + "<br>"
    debug_text += "RecvIP: " + hash["recvip"].to_s + "<br>"
    debug_text += "SipFrom: " + hash["sipfrom"].to_s + "<br>"
    debug_text += "URI: " + hash["uri"].to_s + "<br>"
    debug_text += "UserAgent: " + hash["useragent"].to_s + "<br>"
    debug_text += "PeerName: " + hash["peername"].to_s + "<br>"
    debug_text += "T38Passthrough: " + hash["t38passthrough"].to_s + "<br>"
    debug_text
  end

  def clean_value(value)
    #cv = value
    #remove columns from start and end
    #cv = cv[1..cv.length] if cv[0,1] == "\""
    #cv = cv[0..cv.length-2] if cv[cv.length-1,1] == "\""
    cv = value.to_s.gsub("\"", "")
    cv
  end

  def clean_value_all(value)
    cv = value.to_s
    while cv[0, 1] == "\"" or cv[0] == "'" do
      cv = cv[1..cv.length]
    end
    while cv[cv.length-1, 1] == "\"" or cv[cv.length-1, 1] == "'" do
      cv = cv[0..cv.length-2]
    end
    cv
  end

  # Returns HangupCauseCode message by code
  def get_hangup_cause_message(code)
    if session["hangup#{code.to_i}".intern]
      #        MorLog.my_debug("Code was found in session")
      return session["hangup#{code.to_i}".intern]
    else
      line = Hangupcausecode.find(:first, :conditions => "code = #{code.to_i}")
      if line
        #          MorLog.my_debug("Code was found in DB")
        #          MorLog.my_debug("Sesion : "+session["hangup#{code.to_i}".intern])
        session["hangup#{code.to_i}".intern] = line.description
      else
        #          MorLog.my_debug("Code was NOT found in DB")
        session["hangup#{code.to_i}".intern] = "<b>"+_("Unknown_Error")+"</b><br />"
      end
      #        MorLog.my_debug("Returning value: "+ session["hangup#{code.to_i}".intern].to_s)
      return session["hangup#{code.to_i}".intern]
    end
  end

  def client_form(client)
    @direction = Direction.find(:all)
    @address = Addres.find(:first, :conditions => "id='#{client.address_id}'")
    code = ""
    code += '
    <table class = "maintable">
  <tr>
    <th colspan="2"><b>' + _("Client_Info") + '</b></th>
  </tr>
  <tr>
    <th> ' + _("First_Name") + '</th>
    <td> '
    code+= text_field_tag('first_name', client.first_name, "class" => "input", :size => "35", :maxlength => "50")
    code+= '</td>
  </tr>
  <tr>
    <th>' + _("Last_Name") + '</th>
    <td>'
    code+= text_field_tag('last_name', client.last_name, "class" => "input", :size => "35", :maxlength => "50")
    code+= '</td>
  </tr>
  <tr>
    <th>' + _("Client_ID") + '</th>
    <td>' + text_field_tag('clientid', client.clientid, "class" => "input", :size => "35", :maxlength => "50") + '</td>
  </tr>
  <tr>
    <th>' + _("Agreement_Number") + '</th>
    <td>' + text_field_tag('agreement_number', client.agreement_number, "class" => "input", :size => "35", :maxlength => "50") +'</td>
  </tr>
  <tr>
    <th>' + _("Agreement_Date") +'</th>
    <td>' + text_field_tag('agreement_date', client.agreement_date, "class" => "input", :size => "35", :maxlength => "50") + '</td>
  </tr>
  <tr>
    <th>' + _("VAT_Number") + '</th>
    <td>' + text_field_tag('vat_number', client.vat_number, "class" => "input", :size => "35", :maxlength => "50") + '</td>
  </tr>
  <tr>
    <th colspan="2"><b>' + _("Address") +'</b></th>
  </tr>
  <tr>
    <th><b>'+ _("Direction") + '</b></th>
    <td>
      <select name ="direction">'
    @directions.each { |dir|
      code+= "<option value='#{dir.id}'#{'selected' if dir.id.to_s == @address.direction_id.to_s}>#{dir.name}</option>"
    }
    code+="  </select>
    </td>
  </tr>
  <tr>
    <th>#{_("State")}</th>
    <td>#{ text_field_tag('state', @address.state, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{ _("County")}</th>
    <td>#{ text_field_tag('county', @address.county, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{ _("City")}</th>
    <td>#{ text_field_tag('city', @address.city, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{ _("Postcode")}</th>
    <td>#{ text_field_tag('postcode', @address.postcode, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{ _("Address")}</th>
    <td>#{ text_field_tag('address', @address.address, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{ _("Phone")}</th>
    <td>#{ text_field_tag('phone', @address.phone, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{ _("Mob_Phone")}</th>
    <td>#{ text_field_tag('mob_phone', @address.mob_phone, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{ _("Fax")}</th>
    <td>#{ text_field_tag('fax', @address.fax, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
  <tr>
    <th>#{_("Email")}</th>
    <td>#{ text_field_tag('email', @address.email, "class" => "input", :size => "35", :maxlength => "50") }</td>
  </tr>
</table>"

    my_debug code
    code
  end

  def nice_web(string)
    if string.include?("http//") or string.include?("http://") or string.include?("https//") or string.include?("https://")
      web = string
    else
      web = 'http://' + string.to_s
    end
    return web.to_s
  end


  def callcenter_next_client(task_id, client_id, from_action)
    link_to image_tag('icons/user_go.png', :title => _('Next_Client')) + " "+ _('Next_Client'), :controller => "callcenter", :action => 'next_client', :from_action => from_action, :id => task_id, :from_task => task_id, :from_client => client_id
  end

=begin rdoc
 Creates link with arrow image representing table sort header.

 *Params*

 * <tt>true_col_name</tt> - true field name of sql order by. E.g. users.first_name.
 * <tt>col_header_name</tt> - String to name the field in link. "User".
 * <tt>options</tt> - options hash

 * <tt>options[:order_desc]</tt> - 1 : order descending     2 : order ascending
 * <tt>options[:order_by]</tt> - string simmilar to true_col_name.
 *Returns*

 link_to with params for ordering.
=end

  def sortable_list_header(true_col_name, col_header_name, options)
    link_to(
        ((b_sort_desc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 1).to_s+
            (b_sort_asc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 0).to_s+
            col_header_name).html_safe, :action => params[:action], :order_by => true_col_name.to_s, :order_desc => (options[:order_by].to_s == true_col_name ? 1 - options[:order_desc] : 1))
  end

  def remote_sortable_list_header(true_col_name, col_header_name, options)
    raw link_to_remote(
        (b_sort_desc.html_safe if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 1).to_s.html_safe +
            (b_sort_asc.html_safe if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 0).to_s.html_safe +
            col_header_name.html_safe,
        {:update => options[:update],
         :url => {:controller => options[:controller].to_s, :action => options[:action].to_s, :order_by => true_col_name.to_s, :order_desc => (options[:order_by].to_s == true_col_name ? 1 - options[:order_desc] : 1)},
         :loading => "Element.show('spinner');",
         :complete => "Element.hide('spinner');"}, {:class => "sortable_column_header"}).html_safe
  end

  def nice_list_order(user_col_name, col_header_name, options, params_sort={})
    order_dir = (options[:order_desc].to_i == 1 ? 0 : 1)
    raw link_to(
            ((b_sort_desc if options[:order_desc].to_i== 1 and user_col_name.downcase == options[:order_by].to_s).to_s.html_safe+
                (b_sort_asc if options[:order_desc].to_i== 0 and user_col_name.downcase == options[:order_by].to_s).to_s.html_safe+
                _(col_header_name.to_s.html_safe)).html_safe, {:action => params[:action], :order_by => user_col_name, :order_desc => order_dir}.merge(params_sort), {:id => "#{user_col_name}_#{order_dir}"})
  end

  def link_nice_tariff_if_own(tariff)
    if tariff
      tariff.owner_id == correct_owner_id ? link_nice_tariff_simple(tariff) : nice_tariff(tariff)
    else
      ""
    end
  end

  def nice_tariff(tariff)
    tariff.name
  end

  def link_nice_tariff_simple(tariff)
    if tariff.purpose == 'user'
      link_to tariff.name, :controller => "tariffs", :action => "user_rates_list", :id => tariff.id, :st => "A"
    elsif tariff.purpose == 'user_wholesale'
      link_to tariff.name, :controller => "tariffs", :action => "rates_list", :id => tariff.id, :st => "A"
    end
  end

  def nice_provider(provider)
    [provider.name, provider.id].join("/")
  end

  def link_nice_provider(provider)
    link_to(nice_provider(provider), :controller => :providers, :action => :edit, :id => provider.id)
  end

  def link_nice_provider_if_own(provider)
    if provider
      provider.user_id == correct_owner_id ? link_nice_provider(provider) : nice_provider(provider)
    else
      ""
    end
  end


  def link_nice_tariff(tariff)
    out = "<b>#{_('Tariff')}: </b>"
    out += link_to tariff.name, :controller => "tariffs", :action => "rates_list", :id => tariff.id, :st => "A"
    out += "<br><br>"
  end

  def link_nice_tariff_retail(tariff)
    out = "<b>#{_('Tariff')}: </b>"
    out += link_to tariff.name, :controller => "tariffs", :action => "user_rates_list", :id => tariff.id, :st => "A"
    out += "<br><br>"
  end

  def nice_lcr(lcr)
    lcr.name
  end

  def link_nice_lcr(lcr)
    link_to(nice_lcr(lcr), :controller => :lcrs, :action => :edit, :id => lcr.id)
  end

  def link_nice_lcr_if_own(lcr)
    if lcr
      lcr.user_id == correct_owner_id ? link_nice_lcr(lcr) : nice_lcr(lcr)
    else
      ""
    end
  end

  def lcrpartial_prefixl(direction)
    if direction
      destinations = Destination.find(:all, :conditions => ["direction_code = ?", direction.code.to_s], :order => "prefix ASC")
      code = []
      for destination in destinations
        code << "<option value='#{destination.prefix.to_s}'>#{destination.prefix.to_s} - #{destination.subcode} #{destination.name}</option>"
      end
      code.join("\n").html_safe
    else
      ''
    end
  end

  def sanitize_to_id(name)
    name.to_s.gsub(']', '').gsub(/[^-a-zA-Z0-9:.]/, "_")
  end

  def ordered_list_header(true_col_name, user_col_name, col_header_name, options)
    raw link_to(
        (b_sort_desc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 1).to_s.html_safe+
            (b_sort_asc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 0).to_s.html_safe+
            _(col_header_name.to_s.html_safe), :action => params[:action], :order_by => user_col_name.to_s, :order_desc => (options[:order_by].to_s == true_col_name ? 1 - options[:order_desc] : 1)).html_safe
  end

  # suformuoja tabų pavadinimus javascriptui
  def gateway_tabs(gateway_names)
    gateway_names.collect { |gw| gw.inspect }.join(",").html_safe
  end

  def gateways_enabled
    defined?(PG_Active) and PG_Active == 1
  end

  def gateways_enabled_for(user)
    defined?(PG_Active) and PG_Active == 1 and user and ["reseller", "admin"].include?(user.usertype)
  end

  def gateway_logo(gateway, html_options = {})
    value = gateway.get(:config, "logo_image")
    url = (value.to_s.blank? ? "logo/#{gateway.name}_logo.gif" : "logo/#{value}")
    image_tag(url, html_options)
  end

  def gateway_link(name, engine, gateway)
    external = gateway.settings['external'].to_s
    if external == "true" # external payments have no menu, so show only logo IMG.
      return gateway_logo(gateway, {:style => 'border-style:none', :title => name.to_s.gsub("_", " ").capitalize})
    else
      return link_to(gateway_logo(gateway, {:style => 'border-style:none', :title => name.to_s.gsub("_", " ").capitalize}), {:controller => "payment_gateways/#{engine}/#{name}"}, {:id => "#{engine}_#{name}"})
    end
  end

  def iwantto_list(links)
    out = []
    if links and links.size > 0 and session[:hide_iwantto].to_i == 0
      out << "<br><br>"
      out << b_help + _('I_want_to')+ ":" + "<br>".html_safe
      out << "<ul class='iwantto_help'>"

      links.each { |arr| out << "<li><a href='#{arr[1].to_s}' target='_blank'>#{_(arr[0])}</a></li>" }
      out << "</ul>"
    end
    out.join("\n")
  end

  def select_sound_file(object, method, value = nil, html_options = {})
    html_options.delete(:include_blank) ? select_options = [[_("None"), ""]] : select_options = []
    if reseller? and !current_user.reseller_allow_providers_tariff?
      select_options += IvrSoundFile.find(:all, :include => [:ivr_voice]).collect { |sf| ["#{sf.ivr_voice.voice}/#{sf.path}", sf.id] }.sort
    else
      select_options += IvrSoundFile.find(:all, :include => [:ivr_voice], :conditions => {:user_id => correct_owner_id}).collect { |sf| ["#{sf.ivr_voice.voice}/#{sf.path}", sf.id] }.sort
    end
    select(object.class.to_s.downcase, method, select_options, {:selected => (value) ? value : object.send(method)}, html_options)
  end

  def hide_device_passwords_for_users
    session[:usertype] != "admin" and session[:hide_device_passwords_for_users].to_i == 1
  end

=begin
  Generic settings group line. Can hold any helpers or HTML.

 *Params*

 +block+

=end
  def settings_group_line(name, tip='', &block)
    cont = ["<tr #{tip}>"]
    cont << "<td width='30%'><b>#{name}:</b></td>"
    cont << "<td>"
    cont << block.call
    cont << "</td>"
    cont << "</tr>"
    cont.join("\n").html_safe
  end

=begin

  Empty line to be used *NOT* inside a group.

=end

  def settings_empty_row
    "<tr><td width='30'></td><td>&nbsp;</td><td></td></tr>"
  end

  def settings_group_line(name, tip='', &block)
    "<tr #{tip}>\n<td width='30'></td>\n<td><b>#{name}:</b></td>\n<td>#{block.call}</td>\n</tr>"
  end

=begin
name -      text that will be dislpayed near checkbox
prop_name - form variable name
conf_name - name of confline that will be represented by checkbox.
=end

  def setting_boolean(name, prop_name, conf_name, owner_id = 0, html_options = {})
    settings_group_line(name, html_options[:tip]) {
      check_box_tag(prop_name.to_s, '1', Confline.get_value(conf_name.to_s, owner_id).to_i == 1, html_options)
    }
  end

  def settings_field(type, name, owner_id = 0, html_options = {})
    case type
      when :boolean then
        setting_boolean(_(name), name.downcase, name, owner_id, html_options)
      else
        settings_group_line("UNKNOWN TYPE", html_options[:tip]) {}
    end
  end

=begin
 name -      text that will be dislpayed near text field
 prop_name - form variable name
 conf_name - name of confline that will be represented by text field.
=end

  def settings_string(name, prop_name, conf_name, owner_id = 0, html_options = {})
    settings_group_line(name, html_options[:tip]) {
      text_field_tag(prop_name.to_s, Confline.get_value(conf_name.to_s, owner_id).to_s, {"class" => "input", :size => "35", :maxlength => "50"}.merge(html_options))
    }
  end

  def icon(name, options = {})
    opts = {:class => "icon " + name.to_s.downcase}.merge(options)
    content_tag(:span, "", opts)
  end

  def active_call_bullet(call)
    #MorLog.my_debug(call)
    if call.class == Call
      call.answer_time.blank? ? icon("bullet_yellow") : icon("bullet_green")
    else
      call["answer_time"].blank? ? icon("bullet_yellow") : icon("bullet_green")
    end
  end

  def can_view_forgot_password?
    Confline.get_value("Email_Sending_Enabled", 0).to_i == 1 and !Confline.get_value("Email_Smtp_Server", 0).to_s.blank? and Confline.get_value("Show_forgot_password", session[:owner_id].to_i).to_i == 1
  end

  def link_show_devices_if_own(user, options = {})
    options[:text] ||= nice_user(user)
    if user.owner_id == correct_owner_id
      link_to(options[:text], :controller => :devices, :action => :show_devices, :id => user.id)
    else
      options[:text]
    end
  end

=begin 
  Optional parameter `currency` should be supplied if you want to convert users credit 
  to some particular currency. Note that currency is actualy currency name, not currency object 
=end  
  def nice_credit(user, currency=nil) 
    if user.credit and user.postpaid?
      if user.credit_unlimited?  
        credit = _('Unlimited') 
      else 
        exchange_rate = currency ? Currency.count_exchange_rate(user.currency.name, currency) : 1 
        credit = nice_number(exchange_rate * user.credit)
      end
    else
      credit = 0
    end
    credit
  end

=begin
  if not user returns nil
  if user returns tooltip that contains information about user tariff, lcr, credit,,
  country and city.
  referencial integrity may be broken hence if user.address
=end
  def nice_user_tooltip(user)
    if user
      user_details = raw "<b>#{_('Tariff')}:</b> #{user.try(:tariff_name)} <br> <b>#{_('LCR')}:</b> #{user.try(:lcr_name)}<br> <b>#{_('Credit')}:</b> #{nice_credit(user)}".html_safe
      address_details = raw "<br> <b>#{_('Country')}:</b> #{user.try(:county)}<br> <b>#{_('City')}:</b> #{user.try(:city)}".html_safe
      tooltip('User details', (user_details + address_details).html_safe)
    end
  end

  def nice_tariff_rates_tolltip(tariff, dest_id, dest_id_d)
    if dest_id and dest_id.size.to_i > 0
      unless tariff.purpose == 'user'
        rates = Rate.find(:all, :conditions => ["tariff_id = ? AND destination_id IN (#{dest_id.join(',')})", tariff.id], :include => [:ratedetails, :destination])
        string = ''
        rates.each { |r|
          r.ratedetails.each { |rr|
            string << "#{r.destination.prefix} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time} => #{rr.rate} (#{tariff.currency}) <br />" }
        }
      else
        if dest_id_d and dest_id_d.size.to_i > 0
          rates = Rate.find(:all, :conditions => ["tariff_id = ? AND destinationgroup_id IN (#{dest_id_d.join(',')})", tariff.id], :include => [:aratedetails, :destinationgroup])
          string = ''
          rates.each { |r|
            r.aratedetails.each { |rr|
              string << "#{r.destinationgroup.name} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time}, #{rr.artype} => #{rr.price} (#{tariff.currency}) <br />" }
          }
        end
      end
      tooltip(tariff.name, string)
    end
  end

  def nice_rates_tolltip(rate)
    string = ""
    unless rate.tariff.purpose == 'user'
      rate.ratedetails.each { |rr|
        if rate.destination
          string << "#{rate.destination.prefix} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time} => #{rr.rate} (#{rate.tariff.currency}) <br />"
        end
      }
    else
      rate.aratedetails.each { |rr|
        if rate.destinationgroup
          string << "#{rate.destinationgroup.name} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time}, #{rr.artype} => #{rr.price} (#{rate.tariff.currency}) <br />"
        end
      }
    end
    tooltip(rate.tariff.name, string)
  end

  def nice_end_ivr_tooltip
    tooltip(_('End_IVR'), _('End_ivr_explanation'))

  end

  def nice_did_with_dialplan(did)
    out = did.did.to_s + " - " + did.status
    out += " - " + did.dialplan.name if did.dialplan
    out
  end

  def device_reg_status(device)

    out = ""
    icon = ""

    device.reg_status = device.reg_status.to_s


    if device.reg_status.length == 0
      return out
    end


    if device.reg_status[0..1] == "OK"
      icon = 'icons/bullet_green.png'
    end

    if device.reg_status == "Unmonitored"
      icon = 'icons/bullet_white.png'
    end

    if device.reg_status == "UNKNOWN"
      icon = 'icons/bullet_black.png'
    end

    if device.reg_status[0..5] == "LAGGED"
      icon = 'icons/bullet_yellow.png'
    end

    if device.reg_status == "UNREACHABLE"
      icon = 'icons/bullet_red.png'
    end

    out = image_tag(icon, :title => device.reg_status)

    out
  end


  def spy_channel_icon(channel, id)
    link_to image_tag('icons/sound.png', :title => _('Spy_Channel')), {:controller => "functions", :action => "spy_channel", :id => id, :channel => channel}, :onclick => "window.open(this.href,'new_window','height=40,width=300');return false;".html_safe
  end

  def nice_card(card)
    _('Card') + "/#" + card.number.to_s
  end

  def link_nice_card(card, options={})
    #returns a link to card, that should have been passed as parameter.
    #link text will be nice_card
    link_to_card(card, nice_card(card), options)
  end

  def link_to_card(card, value=nil, options={})
    #returns a link to card, that should have been passed as parameter.
    #link text will be whatever you passed as value or if nothing was
    #passed it'll be nice_card
    logger.fatal card.inspect
    logger.fatal value.inspect
    if value
      link = link_to value, {:controller => "cards", :action => "show", :id => card.id}.merge(options)
      logger.fatal link
    else
      link = link_nice_card(card, options)
      logger.fatal link
    end
    return link
  end

  def call_list_pdf_link(opt={})
    link_to b_pdf + _('Export_to_PDF'), :action => :last_calls_stats, :pdf => 1
  end

  def nice_did_rate_explain(type)
    case type
      when 'incoming'
        _('DID_incoming_rate_explained')
      when 'provider'
        _('DID_Provider_rate_explained')
      when 'owner'
        _('DID_owner_rate_explained')
    end
  end

end
