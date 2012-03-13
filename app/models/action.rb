# -*- encoding : utf-8 -*-
# Represents logger for system administrator.
class Action < ActiveRecord::Base

  belongs_to :user

  # Adds action in Action table. Action time is current time. Return false if user was not found.
  # * +user_id+ - id of the user that experienced the problem.
  # * +action+ - action to describe what was happening.
  # * +message+ - problem description.

  def Action.add_action(user_id, action = "", message = "")
    if user_id and User.find(:first, :conditions => ["id = ?", user_id])
      act = Action.new
      act.date = Time.now
      act.user_id = user_id
      act.action = action.to_s
      act.data = message.to_s
      act.save
      return act
    else
      return false
    end
  end

  # Adds action in Action table. Action time is current time. Return false if user was not found.
  #
  # * +user_id+ - id of the user that experienced the problem.
  # * +user_id+ - action to describe what was happening.
  # * +message+ - problem description.

  def Action.add_action2(user_id, action = "", data = "", data2 = "")
    if user_id and User.find(:first, :conditions => "id = #{user_id}")
      act = Action.new
      act.date = Time.now
      act.user_id = user_id
      act.action = action.to_s
      act.data = data.to_s
      act.data2 = data2.to_s
      act.save
      return act
    else
      return false
    end
  end


=begin rdoc
 Adds action in Action table. Action time is current time. Return false if user was not found.
 * +user_id+ - id of the user that experienced the problem.
 * +details+ - Hash of Action params. Any action param can be overloaded.
=end

  def Action.add_action_hash(user, details={})
    if user.class != User
      user = User.find(:first, :conditions => ["id = ?", user])
    end
    detai = {
      :date => details[:date].blank? ? Time.now : details[:date] ,
      :data => "",
      :data2 => "",
      :user_id => user.id,
      :target_id => nil,
      :target_type => "",
      :action => ""
    }.merge(details)
    if user and !user.id.blank?
      act = Action.new
      act.update_attributes(detai)
      return act
    else
      return false
    end
  end

  # Adds error message to actions table. Action time is current time. Return false if user was not found.
  #
  # * +user_id+ - id of the user that experienced the problem.
  # * +message+ - problem description.

  def Action.add_error (user_id, message = "", opts = {})
    if user_id and User.find(:first, :conditions => "id = #{user_id}")
      act = Action.new
      act.date = Time.now
      act.user_id = user_id
      act.action = "error"
      act.data = message.to_s
      act.processed = 0
      act.data2 = opts[:data2].to_s if opts[:data2]
      act.data3 = opts[:data3].to_s if opts[:data3]
      act.data4 = opts[:data4].to_s if opts[:data4]
      act.save
      return act
    else
      return false
    end
  end

  def Action.create_email_sending_action(obj, action, email, options = {})
    act = Action.new
    act.date = Time.now
    act.processed = 0
    if action == 'sms_email_sent'
      act.user_id= options[:email_from_user].id
      act.action=action
      act.target_type="Sms"
      act.target_id=options[:sms_id]
      act.data=options[:email_to_address]
    else
      owner = obj.class.to_s == 'User' ? obj.owner_id : 0
      act.user_id = owner
      if options[:er_type].to_i == 0
        act.data = obj.id
        act.data2 = email.id
        act.action = obj.class.to_s == 'User' ? 'email_sent' : 'paypal_email_sent'
        status = act.action
      else
        act.action = 'error'
        act.data = 'Cant_send_email'
        message = _('Emeil_is_empty')
        message += " " + obj.first_name + " " + obj.last_name if obj.class.to_s == 'User'
        act.data2 = message
        act.data3 = email.id
        act.data4 = options[:err_message] if options[:err_message]
        status = message
      end
      act.target_id = obj.id
      act.target_type = obj.class.to_s.downcase
    end
    act.save
    return status
  end

  def Action.create_cards_action(order, message = "card_sold")
    cards = order.cards
    for card in cards
      act = Action.new
      act.date = Time.now
      act.action = message
      act.data = card.id
      act.data2 = order.payer_email
      act.save
    end
  end

  def Action.dont_be_so_smart(user_id, request, params)
    user_id ||= '-1'
    Action.new(:user_id => user_id, :date => Time.now.to_s(:db), :action => "hacking_attempt", :data => request["REQUEST_URI"].to_s[0..255], :data2 => request["REMOTE_ADDR"].to_s, :data3 => params.inspect.to_s[0..255]).save
  end

  def Action.validated_user(user_id, old_email)
  end

  def  Action.set_first_call_for_user(from, till)
    calls = Call.count(:all, :select=>"distinct(user_id)" , :conditions=>["calls.calldate <= '#{till}' AND user_id >= 0"])

    actions = Action.count(:all, :select=>"distinct(user_id)", :conditions=>["action='first_call' AND date <= '#{till}'"])
    if calls.to_i > actions.to_i
      sql = "select calls.id, calldate, card_id, user_id from calls
                  JOIN (SELECT users.id FROM users
                        LEFT OUTER JOIN actions ON(users.id = actions.user_id AND actions.action = 'first_call')
                        WHERE actions.id IS NULL) as users ON (users.id = calls.user_id)
                  WHERE user_id != -1 AND calldate != '0000-00-00 00:00:00'
                  GROUP BY calls.user_id
                  ORDER BY calls.id ASC"
      res3 = ActiveRecord::Base.connection.select_all(sql)
      for r in res3
        Action.add_action_hash(r['user_id'], {:action=>"first_call", :date=> r['calldate'] , :data=>r['id'], :data2=>r['card_id']})
      end
    end
    calls_size = Action.count(:all, :select=>"distinct(user_id)", :conditions=>["action='first_call' AND date BETWEEN '#{from}' AND '#{till}'"])
    return calls_size
  end


  def Action.actions_order_by(options)
    case options[:order_by].to_s.strip.to_s
    when "user"  then     order_by = "users.first_name"
    when "type"  then     order_by = "actions.action"
    when "date"  then     order_by = "actions.date"
    when "data"  then     order_by = "actions.data"
    when "data2" then     order_by = "actions.data2"
    when "data3" then     order_by = "actions.data3"
    when "data4" then     order_by = "actions.data4"
    when "processed" then order_by = "actions.processed"
    when "target" then    order_by = "actions.target_type, actions.target_id "
    else
      order_by = options[:order_by] ? options[:order_by] : "actions.action"
      options[:order_desc] = options[:order_desc] ? options[:order_desc] : 0
    end
    order_by += " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by += " DESC"if options[:order_desc].to_i == 1 and order_by != ""
    return order_by
  end

  
  def Action.condition_for_action_log_list(current_user, a1, a2, s_int_ch, options)
    #conditions
    cond_arr = []
    join = ""
   current_user.usertype == 'admin' ? cond = [] : cond = ["actions.action NOT in ('bad_login')"]

    if current_user.usertype == 'reseller'
      cond << "users.owner_id = ?"
      cond_arr << current_user.id
    end
    
    if !s_int_ch or s_int_ch.to_i != 1
      cond << "actions.date BETWEEN ? AND ?"
      cond_arr << a1.to_s + ' 00:00:00'
      cond_arr << a2.to_s + ' 23:59:59'
      if options[:s_type].to_s != "all"
        cond << "actions.action = ? "
        cond_arr << options[:s_type].to_s
      end
      if options[:s_user].to_i != -1
        cond << "actions.user_id = ? "
        cond_arr << options[:s_user].to_i
      end
      unless options[:s_did].blank?
        join << " JOIN dids ON (actions.data = dids.id)"
        cond << "dids.id = ?"
        cond_arr << options[:s_did]
        if options[:s_type].to_s == "all"
          cond << "actions.action LIKE 'did%'"
        end
      end
      if options[:s_processed].to_i != -1
        cond << "actions.processed = ? "
        cond_arr << options[:s_processed].to_s
      end
    else
      options[:s_type] = 'error'
      cond << "actions.action = ? "
      cond_arr << 'error'
      cond << "actions.processed = ? "
      cond_arr << 0
    end

    [:s_target_type, :s_target_id].each do |condition|
      unless options[condition].blank?
        cond << "#{condition.to_s.match(/\As_(.*)\Z/)[1]} = ?"
        cond_arr << options[condition]
      end
    end

    #ticket #5173 - hide hourly actions
    #Note that NULL != 'hourly..' will return FALSE, thats why additional OR is needed 
    cond << "(actions.data4 != 'hourly_actions_cooldown_time' OR actions.data4 IS NULL)"

    join << " JOIN users on (actions.user_id = users.id)"

    return cond,cond_arr,join
  end
end
