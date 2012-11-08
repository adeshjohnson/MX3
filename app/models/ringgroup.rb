# -*- encoding : utf-8 -*-
class Ringgroup < ActiveRecord::Base
  belongs_to :user
  has_many :ringgroups_devices
  has_one :dialplan, :conditions => ['dptype = "ringgroup"'], :foreign_key => "data1"
  belongs_to :did

  before_save :set_user_id

  validates_presence_of :name, :message => _('Name_cannot_be_blank'), :on => :save

  def set_user_id
    self.user_id = User.current.id
  end

  def devices
    # Device.find(:all, :include=>[:ringgroups_devices], :conditions=>["ringgroup_id=? AND name not like 'mor_server_%'", id] , :order=>'priority ASC')
    Device.joins("Left join ringgroups_devices on (ringgroups_devices.device_id = devices.id)").where(["ringgroup_id=? AND name not like 'mor_server_%'", id]).order('priority ASC').all
  end

  def free_devices(dev_id = -1)
    if dev_id.to_i > 0
      Device.find(:all, :select => 'devices.*', :conditions => ['id NOT IN (SELECT device_id FROM ringgroups_devices WHERE ringgroup_id = ?) AND user_id = ? AND name not like "mor_server_%"', id, dev_id])
    else
      Device.find(:all, :select => 'devices.*', :conditions => ['id NOT IN (SELECT device_id FROM ringgroups_devices WHERE ringgroup_id = ?) AND name not like "mor_server_%"', id])
    end
  end

  def update_exline(ext = -1)
    exten = ext.to_i > 0 ? ext : self.dialplan.data2

    devices = self.devices
    appdata = ''
    if devices
      devices.each_with_index { |d, i|
        # all devices will be dialed over Local, not only Virtual for CCL compatibility
        #if d.device_type.to_s == 'Virtual'
          if i > 0
            appdata += "&Local/#{d.name}@mor_local"
          else
            appdata += "Local/#{d.name}@mor_local"
          end
        #else
          #if i > 0
          #  appdata += "&#{d.device_type}/#{d.name}"
          #else
          #  appdata += "#{d.device_type}/#{d.name}"
          #end
        #end
      }
    end

    appdata += "|#{self.timeout}|#{self.options}"

    Extline.delete_all(["exten = ? AND app = ?", exten, 'Dial'])
    Extline.delete_all(["exten = ? AND app = ?", exten, 'Goto'])
    Extline.delete_all(["exten = ? AND app = ?", exten, 'Set'])
    i = 1
    if !cid_prefix.blank?
      Extline.mcreate('mor_local', i, 'Set', "CALLERID(NAME)=#{cid_prefix}${CALLERID(NAME)}", self.dialplan.data2, "0")
      i+=1
    end
    Extline.mcreate('mor_local', i, 'Dial', appdata, self.dialplan.data2, "0")
    i+=1
    Extline.mcreate('mor_local', i, 'Goto', "mor|#{self.did.did}|1", self.dialplan.data2, "0") if self.did_id != 0
  end

  def delete_exline
    exten = self.dialplan.data2
    Extline.delete_all(["exten = ? AND app =?", exten, 'Dial'])
  end


  def Ringgroup.create_default(name)
    Ringgroup.create({:name => name, :strategy => "ringall"})
  end


  def Ringgroup.ringgroups_order_by(params, options)
    case params[:order_by].to_s.strip
      when "id"
        order_by = " ringgroups.id "
      when "name"
        order_by = " dialplans.name "
      when "extension"
        order_by = " dialplans.data2 "
      when "comment"
        order_by = " ringgroups.comment "
      when "ring_time"
        order_by = " ringgroups.timeout "
      when "options"
        order_by = " ringgroups.options "
      when "strategy"
        order_by = " ringgroups.strategy "
      when "prefix"
        order_by = " ringgroups.cid_prefix "
      #when "extension" :  order_by = " ringgroups.extension "
      else
        options[:order_by] ? order_by = "dialplans.name" : order_by = "dialplans.name"
        options[:order_desc] = 1
    end
    order_by += " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by += " DESC" if options[:order_desc].to_i == 1 and order_by != ""
    return order_by

  end
end
