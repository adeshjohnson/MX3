module StatsHelper

  def sort_link_helper(text, param)

    key = param

    order = "desc"    
    order = "asc" if params[:sort] == param and params[:order] == "desc"
    
    options = {
      :url => {:action => 'list', :params => params.merge({:order => order, :sort => key, :page => nil})},
      :update => 'table',
      :before => "Element.show('spinner')",
      :success => "Element.hide('spinner')"
    }
    html_options = {
      :title => _('Sort_by_this_field'),
      :href => url_for(:action => 'list', :params => params.merge({:order => order, :sort => key, :page => nil})),
      :class => "nb"
    } 
    link_to_remote(text, options, html_options, :loading => "Element.show('spinner');", :complete=> "Element.hide('spinner');")
  end




  def sort_td_class_helper(item)
    item = item.to_s

    pic = "sortup.gif" if params[:order] == "asc" and item == params[:sort]
    pic = "sortdown.gif" if params[:order] == "desc" and item == params[:sort]
    
    image_tag pic, :style => 'border-style:none', :title => "sortup" if pic
  end

  def show_call_dst(call, text_class) 
    dest = Destination.find(:first, :conditions => ["prefix = ?", call.prefix])
    dest_txt = []
    if dest
      @direction_cache ||= {}
      direction = @direction_cache[dest.direction_code.to_s] ||= dest.direction
      dest_txt << "#{direction.name.to_s + " " if direction }#{dest.subcode} #{dest.name}"
    end
    dest_txt << _("User_dialed")+ ": " + call.dst
    dest_txt << _("Prefix_used")+ ": " + call.prefix.to_s if call.prefix.to_s.length > 0

    rez = ["<td id='dst_#{call.id}' 
                class='#{text_class}'  
                align='left'
                onmouseover=\"Tip(\'#{ dest_txt.join('<br>') }\')\" 
                onmouseout = \"UnTip()\">"]
    if session[:usertype] == "user"
      rez << hide_dst_for_user(current_user, "gui", call.localized_dst)
    else
      rez << call.localized_dst
    end
    rez << "</td>"
    rez.join("")
  end

  def call_duration(call, text_class, call_type)
    rez = ["<td id='duration_#{call.id}' class='#{text_class}' align='center'>"]
    unless ["missed", "missed_inc",  "missed_inc_all"].include?(call_type)
      rez << nice_time(call.nice_billsec)
    else
      rez << nice_time(call.duration)
    end
    rez << "</td>"
    rez.join()
  end

  def check_or_cross(stat, name)
    stat.to_i == 1 ? b_check({:id => "#{name}", :class => "#{name}_marker"}) : b_cross({:id => "#{name}", :class => "#{name}_marker"})
  end

  def active_calls_tooltip(call)
    lega = ""
    legb = ""
    pdd = ""
    
    if monitorings_addon_active?
      lega =  _("LegA_Codec") + ": " + call["lega_codec"].to_s
      if call["answer_time"]
        legb =  _("LegB_Codec") + ": " + call["legb_codec"].to_s
        pdd = _("PDD") + ": " + call["pdd"].to_f.to_s + " s"
      end
    end
    
    [
      _("Server") + ": " + call["server_id"].to_s,
      _("UniqueID") + ": " + call["uniqueid"].to_s,
      _("User_rate") + ": " + call["user_rate"].to_s + " " + current_user.currency.name, lega, legb, pdd,
    ].reject(&:blank?).join("<br />")

  end
end
