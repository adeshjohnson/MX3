# -*- encoding : utf-8 -*-
class Confline < ActiveRecord::Base

  validates_presence_of :name
  # Returns confline value of given name and user_ID
  def Confline::get_value(name, id = 0)
    cl = Confline.find(:first, :conditions => ["name = ? and owner_id  = ?", name, id])
    return cl.value if cl
    return ""
  end

  def self.by_params(*params)
    cl = Confline.find(:first, :conditions => ["name = ? and owner_id  = ?", params.slice(0..-2).join("_"), params.last])
    return cl.value if cl
    return ""
  end

  def self.by_params2(*params)
    cl = Confline.find(:first, :conditions => ["name = ? and owner_id  = ?", params.slice(0..-2).join("_"), params.last])
    return cl.value2 if cl
    return ""
  end

  def Confline::get_value2(name, id = 0)
    cl = Confline.find(:first, :conditions => ["name = ? and owner_id  = ?", name, id])
    return cl.value2 if cl
    return ""
  end

=begin rdoc
 Check whether or what setting user has set to view dids in active calls, if nothing has been
 defaults to 'do not show'

 *Params*
 * +owner_id+ - User.id that shows confline owner. if nothing has been passed default to admin

 *Returns*
 * +boolean+ - true or false depending on what user has set and whether he has set anything
=end
  def self.active_calls_show_did?(owner_id = 0)
    get_value('Active_calls_show_did', owner_id) == "1" ? true : false
  end
  
  # Sets confline value.
  def Confline::set_value(name, value = 0, id = 0)
    cl = Confline.find(:first, :conditions => ["name = ? and owner_id = ?", name, id])
    if cl
      if cl.value.to_s != value.to_s
        u = User.current ? User.current.id : -1
        Action.add_action_hash(u, {:action=>"Confline changed", :target_id=>cl.id, :target_type=>'confline', :data=>cl.value.to_s, :data2=>value.to_s, :data4=>name})
      end
      cl.value = value
      cl.save
    else
      new_confline(name, value, id)
    end
  end

  def Confline::set_value2(name, value = 0, id = 0)
    cl = Confline.find(:first, :conditions => ["name = ? and owner_id = ?", name, id])
    #logger.fatal User.current_user.to_yaml
    if cl
      if cl.value2.to_s != value.to_s
        if User.current_user
        Action.add_action_hash(User.current_user.id, {:action=>"Confline changed", :target_id=>cl.id, :target_type=>'confline', :data=>cl.value2.to_s, :data2=>value.to_s, :data3=>'value2', :data4=>name})
        else
          Action.add_action_hash(-1, {:action=>"Confline changed", :target_id=>cl.id, :target_type=>'confline', :data=>cl.value2.to_s, :data2=>value.to_s, :data3=>'value2', :data4=>name})
          end
      end
      cl.value2 = value
      cl.save
    else
      #self.my_debug("Confline missing: " + name.to_s + " ---> Created")
      Confline.new_confline2(name, value, id)
    end
  end
  # creates new confline with given params
  def Confline::new_confline(name, value, id = 0)
    confline = Confline.new()
    confline.name = name.to_s
    confline.value = value.to_s
    confline.owner_id = id
    confline.save
  end

  def Confline::new_confline2(name, value, id = 0)
    confline = Confline.new()
    confline.name = name.to_s
    confline.value2 = value.to_s
    confline.owner_id = id
    confline.save
  end

  def Confline::get_tax_number(id = 0)
    cl = Confline.find(:all, :conditions => ["name Like 'Tax_%' and value2 = '1' AND owner_id = ?" , id])
    return cl.size
  end

  def Confline::my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << "Confline.my_debug() is deprecated use MorLog.my_debug()\n"
      f << msg.to_s
      f << "\n"
    }
  end


=begin rdoc

=end

  def Confline::get(name, id = 0)
    cl = Confline.find(:first, :conditions => "name = '#{name}' and owner_id  = #{id} ")
    return cl if cl
    return nil
  end

=begin rdoc
 Sets Conflines with name format "Default_Object_action" and value = data.
 This action is used to store default objects in conflines table.

 *Params*
 * +object+ - Class name variable. User, Device etc.
 * +owner_id+ - User.id that shows confline owner.
 * +data+ - hash of object properties. +object+ has method with same name as hash key, then hash value is used as default value.
=end

  def Confline.set_default_object(object, owner_id, data)
    instance = object.new
    data.each { |key, value|
      Confline.set_value("Default_#{object.to_s}_#{sanitize_sql(key)}", value, owner_id) if instance.respond_to?(key.to_sym)
    }
  end

=begin rdoc
 Recreates +object+ from Confline fields.

 *Params*
 * +object+ - Class name variable. User, Device etc.
 * +owner_id+ - User.id that shows confline owner.

 *Returns*
 +instance+ - instance of class +object+ with set default properties
=end

  def Confline.get_default_object(object, owner_id = 0)
    instance = object.new
    attributes = Confline.find(:all, :conditions => ["name LIKE 'Default_#{object.to_s}_%' AND owner_id = ?", owner_id])
    attributes.each{ |confline|      
      val = confline.value
      key = confline.name.gsub("Default_#{object.to_s}_", "")
      if key.include?("Default_#{object.to_s.downcase.to_s}_")
        key = confline.name.gsub("Default_#{object.to_s.downcase.to_s}_", "")
      end
      if object != Device or (object == Device and (!key.include?('voicemail') and !key.include?('type')))
        instance.__send__((key+"=").to_sym, val) if instance.respond_to?(key.to_sym)
      end
    }
    instance
  end

=begin rdoc
 Returns Tax object filled with default values from conflines.

 *Params*
 * +owner_id+ - User.id that shows confline owner.

 *Returns*
 +tax+ - Tax object filled with default values.
=end

  def Confline.get_default_tax(owner_id)
    tax ={
      :tax1_enabled => 1,
      :tax2_enabled => Confline.get_value2("Tax_2",owner_id).to_i,
      :tax3_enabled => Confline.get_value2("Tax_3",owner_id).to_i,
      :tax4_enabled => Confline.get_value2("Tax_4",owner_id).to_i,
      :tax1_name => Confline.get_value("Tax_1",owner_id).to_s,
      :tax2_name => Confline.get_value("Tax_2",owner_id).to_s,
      :tax3_name => Confline.get_value("Tax_3",owner_id).to_s,
      :tax4_name => Confline.get_value("Tax_4",owner_id).to_s,
      :total_tax_name => Confline.get_value("Total_tax_name",owner_id).to_s,
      :tax1_value => Confline.get_value("Tax_1_Value",owner_id).to_f,
      :tax2_value => Confline.get_value("Tax_2_Value",owner_id).to_f,
      :tax3_value => Confline.get_value("Tax_3_Value",owner_id).to_f,
      :tax4_value => Confline.get_value("Tax_4_Value",owner_id).to_f
    }
    Tax.new(tax)
  end

  def Confline.get_csv_separator(user_id = 0)
    sep = Confline.get_value("CSV_Separator", user_id)
    sep = "," if sep.blank?
    sep
  end

  def Confline.mor_11_extended?
    1 == self.get_value("MOR_11_extend", 0).to_i
  end

=begin
  Get information about chann spy functionality, whether it is enabled or not. Only
  admin can enable/disable it, hence no user_id is specified when calling get_value.

  *Returns*
  +disabled+ boolean, true if chan_spy is disabled, else false. notice that if setting
    would not be specified, false would be returned be default, meaning that chan spy is 
    enabled by default. 
=end
  def Confline.chanspy_disabled?
    self.get_value("chanspy_disabled").to_i == 1
  end

=begin
  ERP settings are valid if login, pass and domain are set and not blank

  *Returns*
  +valid+ true if 
=end
  def self.valid_erp_settings?(user_id)
    login = Confline.get_value("ERP_login", user_id)
    pass = Confline.get_value("ERP_password", user_id)
    host = Confline.get_value("ERP_domain", user_id)

    not (host.blank? or login.blank? or pass.blank?)
  end
  
  def self.get_default_user_pospaid_errors
    ActiveRecord::Base.connection.select_all('SELECT owner_id FROM conflines WHERE name IN (\'Default_User_allow_loss_calls\', \'Default_User_postpaid\') AND value = 1 GROUP BY owner_id HAVING COUNT(*) > 1 ;')
  end

end
