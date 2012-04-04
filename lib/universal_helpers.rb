# -*- encoding : utf-8 -*-
module UniversalHelpers

  def nice_user_from_data(username, first_name, last_name, options = {})
    nu = h(username.to_s)
    nu = h(first_name.to_s + " " + last_name.to_s) if first_name.to_s.length + last_name.to_s.length > 0
    if options[:link] and options[:user_id]
      nu = link_to nu, :controller => "users", :action => "edit", :id => options[:user_id].to_i
    end
    nu
  end

  #  def nice_date(date)
  #    date.strftime("%Y-%m-%d") if date
  #  end
  #
  #  def nice_date_time(time)
  #    time.strftime("%Y-%m-%d %H:%M:%S") if time
  #  end

  def disk_space_usage(folder)
    space = `df -P '#{folder}' | grep -o "[0-9]*%" | cut -c 1-2`
    space
  end

  def add_contition_and_param(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions <<  search_string
      condition_params << search_value
    end
  end

  def add_contition_and_param_like(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions <<  search_string
      condition_params << search_value.to_s + '%'
    end
  end

  def add_integer_contition_and_param(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions <<  search_string
      condition_params << q(search_value.to_s.gsub(',', '.'))
    end
  end

  def add_integer_contition_and_param_not_negative(value, search_value, search_string, conditions, condition_params)
    if !value.blank? and value.to_i != -1
      conditions <<  search_string
      condition_params << q(search_value.to_s.gsub(',', '.'))
    end
  end

  def  add_contition_and_param_not_all(value, search_value, search_string, conditions, condition_params)
    if value.to_s != _('All')
      conditions <<  search_string
      condition_params << search_value
    end
  end

  def clear_options(options)
    options.each {|key, value|
      logger.debug "Need to clear search."
      if key.to_s.scan(/^s_.*/).size > 0
        options[key] = nil
        logger.debug "     clearing #{key}"
      end
    }
    return options
  end

=begin
 Loads file to local file system using mysql.
 *Params*
 +filename+ - required param. File name +without+ extension and path.
 +extension+ - file extension. Default - csv
 +path+ - path to file. Default - /tmp/
 *Return*
 +filename+ if load is successful.
 +nil+ - if no file is loaded.
=end

  def load_file_through_database(filename, extension = "csv", path = "/tmp/")
    full_file_path = "#{q(path)}#{q(filename)}.#{q(extension)}"
    logger.debug("  >> load_file_through_database(#{filename})")
    file = ActiveRecord::Base.connection.execute("select LOAD_FILE('#{full_file_path}')")#.fetch_row()[0]
    if file.first[0]
      File.open(full_file_path, 'w') {|f| f.write(file) }
      logger.debug("  >> load_file_through_database = file")
      return filename
    else
      logger.debug("  << load_file_through_database = nil")
      return nil
    end
  end

=begin rdoc
 Santitizes params for sql input.
=end

  def q(str)
    str.class == String ? ActiveRecord::Base.connection.quote_string(str) : str
  end

  # format time from seconds
  def nice_time(time)
    time = time.to_i
    return "" if time == 0
    h = time / 3600
    m = (time - (3600 * h)) / 60
    s = time - (3600 * h) - (60 * m)
    good_date(h) + ":" + good_date(m) + ":" + good_date(s)
  end

  # format time from seconds
  def invoice_nice_time(time, type)
    if type.to_i == 0
      nice_time(time)
    else
      nice_time_in_minits(time)
    end
  end

  def nice_time_in_minits(time)
    time = time.to_i
    return "" if time == 0
    m = time / 60
    s = time - (60 * m)
    good_date(m) + ":" + good_date(s)
  end

  def nice_time_from_date(date)
    date ? good_date(date.hour) + ":" + good_date(date.min) + ":" + good_date(date.sec) : ""
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = "0" + dd if dd.length<2
    dd
  end

  def  nice_day(string)
    string.to_i < 10 ? "0" + string : string
  end

  def curr_price(price)
    price * User.current.currency.exchange_rate.to_f
  end

  def round_to_cents(amount)
    ((amount.to_f * 100).ceil.to_f / 100)
  end

  def format_money(amount, currency = nil)
    [sprintf("%.2f", round_to_cents(amount.to_f)), currency].compact.join(" ")
  end

  def page_select_header(page, total_pages , page_select_params = {}, options = {}, return_type = "table")
    page = page.to_i
    ret = []
    if total_pages.to_i > 1
      opts= {:id_prefix => "page_", :wrapper => true}.merge(options)

      page_select_params = {} if page_select_params.class != Hash
      keys = [:page]
      page_select_params = page_select_params.reject {|k,v| keys.include?(k || k.to_sym)}
      pstart = page - 10
      pstart = 1 if pstart < 1
      pend = page + 10
      pend = total_pages if pend > total_pages

      back10 = page - 20
      if back10.to_i <= 0
        back10 = 1 if pstart > 1
        back10 = nil if pstart == 1
      end
      forw10 = page + 20
      if forw10 > total_pages
        forw10 = total_pages if pend < total_pages
        forw10 = nil if pend == total_pages
      end

      back100 = page - 100
      if back100.to_i < 0
        back100 = 1 if back10.to_i > 1 if back10
        if (back10.to_i <= 1) or (not back10 )
          back100 = nil
        end
      end

      forw100 = page + 100
      if forw100.to_i > total_pages
        forw100 = total_pages if forw10 < total_pages if forw10
        forw100 = nil if forw10 == total_pages or not forw10
      end
      case return_type
      when "table"
        ret = ["<div align='center'>\n<table class='page_title2' width='100%'>\n<tr>"] if opts[:wrapper] == true
        ret << "    <td align = 'center' id='#{opts[:id_prefix]}#{page.to_i}'>"
        ret <<  " "+link_to("<<", {:action => params[:action],:page => back100}.merge(page_select_params), {:title => "-100"}) if back100
        ret <<  " "+link_to("<", {:action => params[:action], :page => back10}.merge(page_select_params), {:title => "-20"}) if back10
        for p in pstart..pend
          ret << "<b>" if p == page
          ret <<  " "+link_to(p, {:action => params[:action], :page => p}.merge(page_select_params))
          ret <<  "</b> " if p == page
        end
        ret << " "+link_to(">", {:action => params[:action], :page => forw10}.merge(page_select_params), {:title => "+20"}) if forw10
        ret << " "+link_to(">>", {:action => params[:action],:page => forw100}.merge(page_select_params), {:title => "+100"}) if forw100
        ret << "   </td>\n</tr>\n</table>\n</div>\n<br>" if opts[:wrapper] == true
      when "div"
        ret = ["<div>"] if opts[:wrapper] == true
        ret <<  link_to("<<", {:action => params[:action],:page => back100}.merge(page_select_params), {:title => "-100", :class=>"pagination_link"}) if back100
        ret <<  link_to("<", {:action => params[:action], :page => back10}.merge(page_select_params), {:title => "-20", :class=>"pagination_link"}) if back10
        for p in pstart..pend
          if p == page
            ret << "<span class='current'>#{p}</span>"
          else
            ret <<  link_to(p, {:action => params[:action], :page => p}.merge(page_select_params), {:class=>"pagination_link"})
          end
        end
        ret << link_to(">", {:action => params[:action], :page => forw10}.merge(page_select_params), {:title => "+20", :class=>"pagination_link"}) if forw10
        ret << link_to(">>", {:action => params[:action],:page => forw100}.merge(page_select_params), {:title => "+100", :class=>"pagination_link"}) if forw100
        ret << "</div>" if opts[:wrapper] == true
      when "array"
        ret <<  ["&lt;&lt;",  back100] if back100
        ret <<  ["&lt;", back10] if back10
        for p in pstart..pend
          ret << (p == page ? [p, nil] : [p, p])
        end
        ret << ["&gt;", forw10] if forw10
        ret << ["&gt;&gt;", forw100] if forw100
      end
    end
    case return_type
    when "table" then return ret.join("\n").html_safe
    when "div" then return ret.join("\n").html_safe
    when "array" then return ret.html_safe
    end
    return nil
  end
end
