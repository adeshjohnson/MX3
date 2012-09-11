# -*- encoding : utf-8 -*-
class MorApi
  def MorApi.check_params_with_key(params, request)
    #hack find user from params u and p
    #even bigger hack to bypass authentication by password
    if params[:p] == 'nasty_hack_to_bypass_password'
      user = User.find(:first, :conditions => ["username = ?", params[:u].to_s])
    else
      user = User.find(:first, :conditions => ["username = ? and password = ?", params[:u].to_s, Digest::SHA1.hexdigest(params[:p].to_s)])
    end
    ret = {}
    ret[:user_id] = params[:user_id].to_i if params[:user_id] and params[:user_id].to_s !~ /[^0-9]/ and params[:user_id].to_i >= 0
    ret[:request_hash] = params[:hash].to_s if params[:hash] and params[:hash].to_s.length == 40
    ret[:period_start] = params[:period_start].to_i if params[:period_start] and params[:period_start].to_s !~ /[^0-9]/
    ret[:period_end] = params[:period_end].to_i if params[:period_end] and params[:period_end].to_s !~ /[^0-9]/
    ret[:direction] = params[:direction].to_s if params[:direction] and (params[:direction].to_s == 'outgoing' or params[:direction].to_s == 'incoming')
    ret[:calltype] = params[:calltype].to_s if params[:calltype] and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(params[:calltype].to_s)
    ret[:device] = params[:device].to_s if params[:device] and (params[:device].to_s !~ /[^0-9]/ or params[:device].to_s == 'all')
    ret[:balance] = params[:balance] if params[:balance] and params[:balance].to_s !~ /[^0-9.\-\+]/
    ret[:monitoring_id] = params[:monitoring_id].to_s if params[:monitoring_id] and (params[:monitoring_id] !~ /[^0-9]/)
    ret[:users] = params[:users].to_s if params[:users] and (params[:users] =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
    ret[:block] = params[:block].to_s if params[:block] and (params[:block] =~ /true|false/)
    ret[:email] = params[:email].to_s if params[:email] and (params[:email] =~ /true|false/)
    ret[:mtype] = params[:mtype].to_s if params[:mtype] and (params[:mtype] !~ /[^0-9]/)
    ret[:tariff_id] = params[:tariff_id].to_i if params[:tariff_id] and (params[:tariff_id].to_s !~ /[^0-9]/)
    ret[:only_did] = params[:only_did].to_i if params[:only_did] and (params[:only_did].to_s !~ /[^0-9]/)

    ret[:key] = Confline.get_value("API_Secret_Key", user ? user.get_correct_owner_id : 0).to_s
    string =
        ret[:user_id].to_s +
            ret[:period_start].to_s +
            ret[:period_end].to_s +
            ret[:direction].to_s+
            ret[:calltype].to_s+
            ret[:device].to_s+
            ret[:balance].to_s+
            ret[:monitoring_id].to_s+
            ret[:users].to_s+
            ret[:block].to_s+
            ret[:email].to_s+
            ret[:mtype].to_s+
            ret[:key].to_s+
            ret[:callerid].to_s+
            ret[:pin].to_s

    ret[:system_hash] = Digest::SHA1.hexdigest(string)
    ret[:device] = nil if ret[:device] == 'all'
    ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
    ret[:balance] = params[:balance].to_d
    unless ret[:system_hash].to_s == ret[:request_hash]
      MorApi.create_error_action(params, request, 'API : Incorrect hash')
    end

    return ret[:system_hash].to_s == ret[:request_hash], ret
  end

  def MorApi.create_error_action(params, request, name)
    Action.create({:user_id => -1, :date => Time.now(), :action => 'error', :data => name, :data2 => (request ? request.url.to_s[0..255] : ''), :data3 => (request ? request.remote_addr : ''), :data4 => params.inspect.to_s[0..255]})
  end


  def MorApi.check_params_with_all_keys(params, request)
    #hack find user from params u and p
    user = User.find(:first, :conditions => ["username = ? and password = ?", params[:u].to_s, Digest::SHA1.hexdigest(params[:p].to_s)])
    MorLog.my_debug params.to_yaml
    ret = {}
    ret[:user_id] = params[:user_id].to_i if params[:user_id] and params[:user_id].to_s !~ /[^0-9]/ and params[:user_id].to_i >= 0
    ret[:request_hash] = params[:hash].to_s if params[:hash] and params[:hash].to_s.length == 40
    ret[:period_start] = params[:period_start].to_i if params[:period_start] and params[:period_start].to_s !~ /[^0-9]/
    ret[:period_end] = params[:period_end].to_i if params[:period_end] and params[:period_end].to_s !~ /[^0-9]/
    ret[:direction] = params[:direction].to_s if params[:direction] and (params[:direction].to_s == 'outgoing' or params[:direction].to_s == 'incoming')
    ret[:calltype] = params[:calltype].to_s if params[:calltype] and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(params[:calltype].to_s)
    ret[:device] = params[:device].to_s if params[:device] and (params[:device].to_s !~ /[^0-9]/ or params[:device].to_s == 'all')
    ret[:balance] = params[:balance] if params[:balance] and params[:balance].to_s !~ /[^0-9.\-\+]/
    ret[:monitoring_id] = params[:monitoring_id].to_s if params[:monitoring_id] and (params[:monitoring_id] !~ /[^0-9]/)
    ret[:users] = params[:users].to_s if params[:users] and (params[:users] =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
    ret[:block] = params[:block].to_s if params[:block] and (params[:block] =~ /true|false/)
    ret[:email] = params[:email].to_s if params[:email] #and (params[:email] =~ /true|false/)
    ret[:mtype] = params[:mtype].to_s if params[:mtype] and (params[:mtype] !~ /[^0-9]/)
    ret[:tariff_id] = params[:tariff_id].to_i if params[:tariff_id] and (params[:tariff_id].to_s !~ /[^0-9]/)
    ret[:only_did] = params[:only_did].to_i if params[:only_did] and (params[:only_did].to_s !~ /[^0-9]/)

    ['u0', 'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11', 'u12', 'u13', 'u14', 'u15', 'u16', 'u17', 'u18', 'u19', 'u20', 'u21', 'u22', 'u23', 'u24', 'u25', 'u26', 'u27', 'u28',
     'ay', 'am', 'ad', 'by', 'bm', 'bd', 'pswd', 'user_warning_email_hour' 'pgui', 'pcsv', 'ppdf', 'recording_forced_enabled', 'i4', 'tax4_enabled', 'tax2_enabled', 'accountant_type_invalid', 'block_at_conditional', 'tax3_enabled', 'accountant_type', 'tax1_value', 'show_zero_calls', 'warning_email_active', 'compound_tax', 'tax4_name', 'allow_loss_calls', 'tax3_name', 'tax2_name', 'credit', 'tax1_name', 'total_tax_name', 'tax2_value', 'tax4_value', 'ignore_global_monitorings', 'i1', 'tax3_value', 'cyberplat_active', 'i2', 'i3', 'recording_enabled', 'email_warning_sent_test', 'own_providers', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:s_user] = params[:s_user] if params[:s_user] and params[:s_user].to_s !~ /[^0-9]/
    ret[:s_call_type] = params[:s_call_type] if params[:s_call_type]
    ret[:s_device] = params[:s_device] if params[:s_device] and (params[:s_device].to_s !~ /[^0-9]/ or params[:s_device].to_s == 'all')
    ret[:s_provider] = params[:s_provider] if params[:s_provider] and (params[:s_provider].to_s !~ /[^0-9]/ or params[:s_provider].to_s == 'all')
    ret[:s_hgc] = params[:s_hgc] if params[:s_hgc] and (params[:s_hgc].to_s !~ /[^0-9]/ or params[:s_hgc].to_s == 'all')
    ret[:s_did] = params[:s_did] if params[:s_did] and (params[:s_did].to_s !~ /[^0-9]/ or params[:s_did].to_s == 'all')

    ['s_destination', 'order_by', 'order_desc', 'description', 'pin', 'type', 'devicegroup_id', 'phonebook_id', 'number', 'name', 'speeddial'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:s_user_id] = params[:s_user_id] if params[:s_user_id] and params[:s_user_id].to_s !~ /[^0-9]/
    ret[:s_from] = params[:s_from] if params[:s_from] and params[:s_from].to_s !~ /[^0-9]/
    ret[:s_till] = params[:s_till] if params[:s_till] and params[:s_till].to_s !~ /[^0-9]/
    ret[:lcr_id] = params[:lcr_id].to_s if params[:lcr_id] and (params[:lcr_id].to_s !~ /[^0-9]/)
    ret[:dst] = params[:dst].to_s if params[:dst]
    ret[:src] = params[:src].to_s if params[:src]
    ret[:message] = params[:message].to_s if params[:message]
    ret[:caller_id] = params[:caller_id].to_s if params[:caller_id]
    ret[:device_id] = params[:device_id].to_s if params[:device_id]


    ['s_transaction', 's_completed', 's_username', 's_first_name', 's_last_name', 's_paymenttype', 's_amount_max', 's_currency', 's_number', 's_pin',
     'p_currency', 'paymenttype', 'tax_in_amount', 'amount', 'transaction', 'payer_email', 'shipped_at', 'fee', 'id', 'quantity', 'callerid', 'cardgroup_id',
     'status', 'date_from', 'date_till', 's_reseller_did', 's_did_pattern', 'lcr_id', 'dst', 'src', 'message', 'caller_id', 'device_id'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    # adding send email params
    ["server_ip", "device_type", "device_username", "device_password", "login_url", "login_username", "username", "first_name",
     "last_name", "full_name", "nice_balance", "warning_email_balance", "nice_warning_email_balance",
     "currency", "user_email", "company_email", "company", "primary_device_pin", "login_password", "user_ip",
     "date", "auth_code", "transaction_id", "customer_name", "company_name", "url", "trans_id",
     "cc_purchase_details", "monitoring_amount", "monitoring_block", "monitoring_users", "monitoring_type", "payment_amount", "payment_payer_first_name",
     "payment_payer_last_name", "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
     "payment_currency", "payment_type", "payment_fee", "call_list", 'email_name', 'email_to_user_id', 'caller_id', 'device_id'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:key] = Confline.get_value("API_Secret_Key", user ? user.get_correct_owner_id : 0).to_s
    MorLog.my_debug ret.to_yaml
    MorLog.my_debug "****************************************************8"
                                                        #for future: notice - users should generate hash in same order.
    string = ""

    hash_param_order = ['user_id', 'period_start', 'period_end', 'direction', 'calltype', 'device', 'balance', 'monitoring_id', 'users', 'block', 'email', 'mtype', 'tariff_id', 'u0', 'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11', 'u12', 'u13', 'u14', 'u15', 'u16', 'u17', 'u18', 'u19', 'u20', 'u21', 'u22', 'u23', 'u24', 'u25', 'u26', 'u27', 'u28', 'ay', 'am', 'ad', 'by', 'bm', 'bd', 'pswd', 'user_warning_email_hour', 'pgui', 'pcsv', 'ppdf', 'recording_forced_enabled', 'i4', 'tax4_enabled', 'tax2_enabled', 'accountant_type_invalid', 'block_at_conditional', 'tax3_enabled', 'accountant_type', 'tax1_value', 'show_zero_calls', 'warning_email_active', 'compound_tax', 'tax4_name', 'allow_loss_calls', 'tax3_name', 'tax2_name', 'credit', 'tax1_name', 'total_tax_name', 'tax2_value', 'tax4_value', 'ignore_global_monitorings', 'i1', 'tax3_value', 'cyberplat_active', 'i2', 'i3', 'recording_enabled', 'email_warning_sent_test', 'own_providers', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 's_user', 's_call_type', 's_device', 's_provider', 's_hgc', 's_did', 's_destination', 'order_by', 'order_desc', 'only_did', 'description', 'pin', 'type', 'devicegroup_id', 'phonebook_id', 'number', 'name', 'speeddial', 's_user_id', 's_from',
                        's_till', 's_transaction', 's_completed', 's_username', 's_first_name', 's_last_name', 's_paymenttype', 's_amount_max', 's_currency', 's_number', 's_pin',
                        'p_currency', 'paymenttype', 'tax_in_amount', 'amount', 'transaction', 'payer_email', 'fee', 'id', 'quantity', 'callerid', 'cardgroup_id', 'status', 'date_from', 'date_till', 's_reseller_did', 's_did_pattern', 'lcr_id', 'dst', 'src', 'message', "server_ip", "device_type", "device_username", "device_password", "login_url", "login_username", "username", "first_name", "last_name", "full_name", "nice_balance", "warning_email_balance", "nice_warning_email_balance","currency", "user_email", "company_email", "company", "primary_device_pin", "login_password", "user_ip","date", "auth_code", "transaction_id", "customer_name", "company_name", "url", "trans_id","cc_purchase_details", "monitoring_amount", "monitoring_block", "monitoring_users", "monitoring_type", "payment_amount", "payment_payer_first_name","payment_payer_last_name", "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
                        "payment_currency", "payment_type", "payment_fee", "call_list", 'email_name', 'email_to_user_id', 'caller_id', 'device_id']

    hash_param_order.each { |key|
      MorLog.my_debug key if ret[key.to_sym]
      string << ret[key.to_sym].to_s
    }

    #add key
    string << ret[:key].to_s

    ret[:system_hash] = Digest::SHA1.hexdigest(string)
    ret[:device] = nil if ret[:device] == 'all'
    ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
    ret[:balance] = params[:balance].to_d


    unless ret[:system_hash].to_s == ret[:request_hash]
      MorApi.create_error_action(params, request, 'API : Incorrect hash')
    end

    return ret[:system_hash].to_s == ret[:request_hash], ret, hash_param_order
  end


=begin
  This is THE method to add error string to xml object.

  *Params*
  +string+ - error message
  +xml_object+ - xml object to return with error message.

  *Returns*
  +xml+ 
  or
  +xml object+ 
=end
  def MorApi.return_error(string, doc = nil)
    if doc
      doc.status { doc.error(string) }
      return doc
    else
      doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
      doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      doc.status { doc.error(string) }
      return out_string
    end
  end
end
