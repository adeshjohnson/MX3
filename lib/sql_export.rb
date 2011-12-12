module SqlExport
  def SqlExport.nice_user_sql(users = "users", name = "nice_user")
  # "IF(#{users}.id IS NULL, '', IF((LENGTH(#{users}.first_name )> 0 OR (LENGTH(#{users}.last_name) > 0)),CONCAT(#{users}.first_name, ' ', #{users}.last_name), #{users}.username))#{" AS '#{name}'" if name}"
  "IF(#{users}.id IS NULL, '', IF((LENGTH(#{users}.first_name )> 0 AND (LENGTH(#{users}.last_name) > 0)),CONCAT(#{users}.first_name, ' ', #{users}.last_name), IF((LENGTH(#{users}.first_name )> 0), #{users}.first_name, IF((LENGTH(#{users}.last_name )> 0), #{users}.last_name, #{users}.username)))) #{" AS '#{name}'" if name}"
  end
  # marks type possitions in user.hide_destination_end numbers
  @@types = {"gui" => 1, "csv" => 2, "pdf" => 3}
  
  def checked_possition?(permission_number, possition)
    (permission_number.to_i & 2**(possition.to_i-1)) != 0
  end

  def hide_last_numbers(number)
    number = number.to_s
    if number.length < 3
      return "X" * number.length
    else
      number[-3..-1] = "XXX"
      return number
    end
  end

  def hide_last_numbers_sql(column, options={})
    opts = {
      :with => "XXX",
      :last => 3,
      :as => column
    }.merge(options)
    "concat(substring(#{column}, 1, length(#{column})-#{opts[:last]}), '#{opts[:with]}') as #{opts[:as]}"
  end

  def hide_dst_for_user_sql(user, type, dst, options)
    reference = options[:as].to_s.blank? ? dst : options[:as].to_s
    (checked_possition?(user.hide_destination_end, @@types[type]) and user.usertype == 'user') ? hide_last_numbers_sql(dst, options) : SqlExport.column_escape_null(dst, reference, "")
  end

  def hide_dst_for_user(user, type, dst)
    (checked_possition?(user.hide_destination_end, @@types[type]) and user.usertype == 'user') ? hide_last_numbers(dst) : dst
  end

  def SqlExport.column_escape_null(column, reference = nil, escape_to = "")
    escape_to = "'#{escape_to}'" if escape_to.kind_of?(String)
    "IF(#{column} IS NULL, #{escape_to}, #{column}) #{"AS #{reference}" unless reference.blank?}"
  end

  def SqlExport.nice_date(column, opt={})
    "DATE_FORMAT(DATE_ADD(#{column}, INTERVAL #{opt[:tz] ? opt[:tz] : 0 } HOUR ),  '#{opt[:format].blank? ? '%Y-%m-%d %H:%i:%S' : opt[:format]}') #{"AS #{opt[:reference]}" unless opt[:reference].blank?}"
  end

  def SqlExport.replace_sep(column, replase_from = "", replase_to = "", reference = nil)
    replase_to = "'#{replase_to}'" if replase_to.kind_of?(String)
    escape_to = "'#{escape_to}'" if escape_to.kind_of?(String)
    "REPLACE(#{column}, '#{replase_from}', '#{replase_to}') #{"AS #{reference}" unless reference.blank?} "
  end

  def SqlExport.replace_dec(column, replase_to = "", reference = nil)
    escape_to = "'#{escape_to}'" if escape_to.kind_of?(String)
    "REPLACE(#{column}, '.', '#{replase_to}') #{"AS #{reference}" unless reference.blank?} "
  end

  def SqlExport.replace_price(column, opt={})
    z = opt[:ex] ? opt[:ex].to_f : User.current.currency.exchange_rate.to_f
    "(#{column} * #{z}) #{"AS #{opt[:reference]}" unless opt[:reference].blank?}"
  end

  def SqlExport.clean_filename(string)
    string.to_s.gsub(/[^\w\.\-]/, "_")
  end
 
end
