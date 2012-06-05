# -*- encoding : utf-8 -*-
module DidsHelper
  def did_user_info(did, user)
    user_info = ''
    if user and did
      unless did.reseller_id > 0 and user.id == 0
        if user.owner_id == correct_owner_id
          user_info = link_to(nice_user(user), {:controller => "users", :action => "edit", :id => did.user_id}, {:id => "user_link"+ did.id.to_s})
        else
          user_info = nice_user(user)
        end
      end
    end
    return user_info
  end

  def did_reseller_info(did)
    if did and did.reseller_id.to_i > 0 and did.reseller and ["admin", "accountant"].include?(current_user.usertype)
      b_user_gray(:title => nice_user(did.reseller)) + "\n" + nice_user(did.reseller)
    end
  end

  def format_dialplan(did)
    did.dialplan_id != 0 ? dialplan = did.dialplan : dialplan = nil
    if dialplan
      dp = did.dialplan
      case dp.dptype
        when 'pbxfunction'
          link_to dp.name + " (" + dp.dptype + ")", {:controller => :functions, :action => :pbx_function_edit, :id => dp.id}
        when 'quickforwarddids'
          dp.name + " (" + dp.dptype + ")"
        when 'ringgroup'
          link_to dp.name + " (" + dp.dptype + ")", {:controller => :ringgroups, :action => :edit, :id => dp.data1}
        else
          link_to dp.name + " (" + dp.dptype + ")", {:controller => :dialplans, :action => :edit, :id => dp.id}
      end
    end
  end

  def show_call_limit(did)
    did.call_limit.to_i == 0 ? _('Unlimited') : did.call_limit
  end

  def format_device(did, device, link = 1)
    cont = []
    if device
      if link == 1
        cont << link_nice_device(device)
      else
        cont << nice_device(device)
      end
      unless session[:usertype] == "accountant" or link == 0
        cont << link_to(b_callflow, :controller => "devices", :action => "callflow", :id => did.device_id)
      end
    end
    cont.join("\n")
  end

  def did_status(did)
    if current_user.usertype == "reseller"
      "free" if did.user_id.to_i == 0
      "reserved" if did.user_id.to_i != 0 and did.device_id.to_i = 0
      "active" if did.user_id.to_i!= 0 and did.device_id.to_i != 0
    else
      @did.status
    end
  end
end
