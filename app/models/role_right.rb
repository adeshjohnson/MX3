class RoleRight < ActiveRecord::Base
  belongs_to :role;
  belongs_to :right;
# returns right by role and right ID  
  def RoleRight::get_right(role_id, right_id)
    if role_id_i = role_id.to_i and right_id_i = right_id.to_i
      role_right = RoleRight.find(:first, :conditions => "role_id = #{role_id_i} and right_id = #{right_id_i}")
    end
    if role_right
      return role_right.permission
    else       
      return 0
    end
  end 
# changes rights  
  def RoleRight::update_right(role_id, right_id, value)
    roleright = RoleRight.find(:first, :conditions=>"role_id = #{role_id.to_i} and right_id = #{right_id.to_i}")
    roleright.permission = value.to_i
    roleright.save
  end	
# returns authorization for controller_action  
  def RoleRight::get_authorization(role, controller, action)
    #sql = "SELECT role_rights.permission FROM role_rights left join rights ON role_rights.right_id = rights.id left join roles on role_rights.role_id = roles.id WHERE roles.name = '#{role.to_s}' AND rights.controller = '#{controller.to_s}' AND rights.action = '#{action.to_s}';"
    #sql = "SELECT role_rights.permission FROM role_rights where role_id = (select id from roles where name = '#{role.to_s}' LIMIT 1) AND right_id = (SELECT id from rights where controller = '#{controller.to_s}' and rights.action = '#{action.to_s}' LIMIT 1);"
    sql = "SELECT role_rights.permission FROM role_rights where role_id = #{role.to_s} AND right_id = (SELECT id from rights where controller = '#{controller.to_s}' and rights.action = '#{action.to_s}' LIMIT 1);"
    rez = ActiveRecord::Base.connection.select_all(sql)
    if rez.size == 0 and Kernel.const_get(controller.to_s.camelize.to_s + "Controller").new.respond_to?(action.to_s)
      new_right(controller, action, controller.capitalize+"_"+action)
      rez = ActiveRecord::Base.connection.select_all(sql) 
    end 
    if rez[0] and rez[0]["permission"]
      return rez[0]["permission"].to_i
    end
    return 0
  end
# returns whole permissions and user roles table
  def RoleRight::get_auth_list
    sql = "SELECT role_rights.id, name, controller, action, permission FROM role_rights left join rights ON role_rights.right_id = rights.id left join roles on role_rights.role_id = roles.id order by controller, action, name;"
    return ActiveRecord::Base.connection.select_all(sql)
  end
# adds new right and creates it coresonding enteries for each role  
  def RoleRight::new_right(controller, action, description)
    sql = "SELECT COUNT(*) as num FROM rights where controller = '#{controller}' AND action = '#{action}';"
    rez = ActiveRecord::Base.connection.select_all(sql)
    if (rez[0]["num"].to_i == 0)
      right = Right.new()
      right.controller=controller.to_s
      right.action =action.to_s
      right.description = description
      right.saved = 1
      if right.save
        roles =Role.find(:all)
        for role in roles do
          role_right = RoleRight.new
          role_right.role_id = role.id
          role_right.right_id = right.id
          #2011-03-18 [2:33:19 PM EEST] MK: tik adminui turi buti 1
          if role.name.downcase == 'admin'  or role.name.downcase == 'accountant' or role.name.downcase == 'reseller' or role.name.downcase == 'user'
            role_right.permission = 1
          else
           role_right.permission = 0  
          end
          role_right.save
        end
      end
    end
  end
end