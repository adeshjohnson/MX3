class API
  def API::check_params_with_key(params, request)
    ret = {}
    ret[:user_id] = params[:user_id].to_i           if params[:user_id] and params[:user_id].to_s !~ /[^0-9]/ and params[:user_id].to_i >= 0
    ret[:request_hash] = params[:hash].to_s         if params[:hash] and params[:hash].to_s.length == 40
    ret[:period_start] = params[:period_start].to_i if params[:period_start] and params[:period_start].to_s !~ /[^0-9]/
    ret[:period_end] = params[:period_end].to_i     if params[:period_end] and params[:period_end].to_s !~ /[^0-9]/ 
    ret[:direction] = params[:direction].to_s       if params[:direction] and (params[:direction].to_s == 'outgoing' or params[:direction].to_s == 'incoming')
    ret[:calltype] = params[:calltype].to_s         if params[:calltype] and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(params[:calltype].to_s)
    ret[:device] = params[:device].to_s             if params[:device] and (params[:device].to_s !~ /[^0-9]/ or params[:device].to_s == 'all' )
    ret[:balance] = params[:balance].to_f           if params[:balance] and params[:balance].to_s !~ /[^0-9.\-\+]/
    ret[:monitoring_id] = params[:monitoring_id].to_s if params[:monitoring_id] and (params[:monitoring_id] !~ /[^0-9]/)
    ret[:users] = params[:users].to_s if params[:users] and (params[:users] =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
    ret[:block] = params[:block].to_s if params[:block] and (params[:block] =~ /true|false/)
    ret[:email] = params[:email].to_s if params[:email] and (params[:email] =~ /true|false/)
    ret[:mtype] = params[:mtype].to_s if params[:mtype] and (params[:mtype] !~ /[^0-9]/)
             
    ret[:key] = Confline.get_value("API_Secret_Key").to_s 
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
      ret[:key].to_s
    
    ret[:system_hash] = Digest::SHA1.hexdigest(string)
    ret[:device] = nil if ret[:device] == 'all'
    ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
    
    unless ret[:system_hash].to_s == ret[:request_hash]
      API::create_error_action(params, request, 'API : Incorrect hash')
    end
      
    return ret[:system_hash].to_s == ret[:request_hash], ret
  end

  def API::create_error_action(params, request, name)
    Action.create({:user_id=>-1, :date=>Time.now(), :action=>'error', :data=>name, :data2=>request.request_uri.to_s[0..255], :data3 => request.remote_addr, :data4 => params.inspect.to_s[0..255]})
  end
end
