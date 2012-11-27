# -*- encoding : utf-8 -*-
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
    "DATE_FORMAT(DATE_ADD(#{column}, INTERVAL #{opt[:offset] ? opt[:offset].to_i : 0 } SECOND ), '#{opt[:format].blank? ? '%Y-%m-%d %H:%i:%S' : opt[:format]}') #{"AS #{opt[:reference]}" unless opt[:reference].blank?}"
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

  #========================== BILLING sql ======================================
  # if reseller pro provider call reseller_price = provider_price

  def SqlExport.reseller_provider_price_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      "(IF(providers.user_id > 0,  provider_price, reseller_price))"
    else
      "calls.reseller_price"
    end
  end

  def SqlExport.reseller_provider_rate_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      "(IF(providers.user_id > 0, provider_rate, calls.reseller_rate))"
    else
      "calls.reseller_rate"
    end
  end

  def SqlExport.user_price_sql
    # "(calls.user_price + calls.did_inc_price)"
    "(calls.user_price)"
  end

  def SqlExport.user_did_price_sql
    "(calls.did_price)"
  end

  def SqlExport.user_rate_sql
    "calls.user_rate"
  end

  def SqlExport.reseller_price_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      # "(IF(providers.user_id > 0, 0, reseller_price) + calls.did_inc_price)"
      "(IF(providers.user_id > 0, 0, reseller_price))"
    else
      #"(calls.reseller_price + calls.did_inc_price)"
      "(calls.reseller_price)"
    end
  end

  def SqlExport.reseller_rate_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      "IF(providers.user_id > 0, 0,reseller_rate)"
    else
      "calls.reseller_rate"
    end
  end

  def SqlExport.reseller_profit_sql
    "(#{SqlExport.user_price_sql} - #{SqlExport.reseller_provider_price_sql})"
  end

  def SqlExport.admin_profit_sql
    "(#{SqlExport.admin_user_price_sql} - #{SqlExport.admin_provider_price_sql})"
  end

  def SqlExport.admin_user_price_sql
    if (defined?(RS_Active) and RS_Active.to_i == 1)
      "IF(calls.reseller_id > 0,#{SqlExport.admin_reseller_price_sql},#{SqlExport.user_price_sql})"
    else
      "#{SqlExport.user_price_sql}"
    end
  end

  def SqlExport.admin_user_rate_sql
    "#{SqlExport.user_rate_sql}"
  end

  def SqlExport.admin_provider_price_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      #        "IF(providers.user_id != calls.reseller_id, calls.provider_price, 0)"
      "IF(providers.user_id > 0, 0, calls.provider_price)"
    else
      "calls.provider_price"
    end
  end

  def SqlExport.admin_provider_rate_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      "IF(providers.user_id > 0, 0 ,calls.provider_rate)"
    else
      "calls.provider_rate"
    end
  end

  def SqlExport.admin_reseller_price_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      # "(IF(providers.user_id > 0, 0 , reseller_price) + calls.did_inc_price)"
      "(IF(providers.user_id > 0, 0 , reseller_price))"
    else
      # "(calls.reseller_price + calls.did_inc_price)"
      "(calls.reseller_price)"
    end
  end

  def SqlExport.admin_reseller_rate_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      "IF(providers.user_id > 0, 0 , reseller_rate)"
    else
      "calls.reseller_rate"
    end
  end

  def SqlExport.left_join_reseler_providers_to_calls_sql
    " LEFT JOIN providers ON (providers.id = calls.provider_id) "
  end

  # ===================== withoud dids ==================================

  def SqlExport.user_price_no_dids_sql
    "calls.user_price"
  end

  def SqlExport.reseller_price_no_dids_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      "IF(providers.user_id > 0, reseller_price, 0)"
    else
      "calls.reseller_price"
    end
  end

  def SqlExport.admin_user_price_no_dids_sql
    "#{SqlExport.user_price_no_dids_sql}"
  end

  def SqlExport.admin_profit_no_dids_sql
    "(#{SqlExport.admin_user_price_no_dids_sql} - #{SqlExport.admin_provider_price_sql})"
  end

  def SqlExport.admin_reseller_price_no_dids_sql
    if (defined?(RSPRO_Active) and RSPRO_Active.to_i == 1)
      "IF(providers.user_id >  0,  0 ,reseller_price)"
    else
      "calls.reseller_price"
    end
  end

end
