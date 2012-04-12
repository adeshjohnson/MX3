# -*- encoding : utf-8 -*-
class Did < ActiveRecord::Base

  belongs_to :device
  belongs_to :user
  has_many :didrates
  belongs_to :dialplan
  belongs_to :provider
  has_many :activecalls
  has_many :calls
  has_many :first_call, :class_name => 'Call', :foreign_key => 'did_id', :limit => 1

  validates_uniqueness_of :did, :message => _("DID_must_be_unique")
  validates_presence_of :did, :message => _("Enter_DID")
  validates_format_of :did, :with => /^\d+$/, :message => _('DID_must_consist_only_of_digits'), :on => :create

  before_create :validate_provider
  before_save :validate_device, :validate_user
  before_destroy :find_if_used_in_calls

  def validate_provider
    if !['admin', 'accountant'].include?(User.current.usertype)
      c_u = User.current
      if c_u.usertype == 'reseller' and provider and c_u.own_providers.to_i == 1 and !c_u.providers.find(:first, :conditions => "providers.id = #{provider.id}") and provider.id != Confline.get_value("DID_default_provider_to_resellers").to_i
        errors.add(:provider, _("Provider_not_found"))
        return false
      end

      if c_u.usertype == 'reseller' and provider and c_u.own_providers.to_i == 0 and provider.id.to_i != Confline.get_value("DID_default_provider_to_resellers").to_i
        errors.add(:provider, _("Provider_not_found"))
        return false
      end

    end
  end

  def validate_device
    #logger.info "etfffffff"
    if User.current and !['admin', 'accountant'].include?(User.current.usertype)
      if User.current.usertype == 'reseller' and device and !User.current.load_users_devices(:first, :conditions => "devices.id = #{device.id}")
        errors.add(:device, _("Device_not_found"))
        return false
      end
    end
  end

  def validate_user
    if User.current and !['admin', 'accountant'].include?(User.current.usertype)
      if User.current.usertype == 'reseller' and status == 'reserved' and user and !User.find(:first, :conditions => "users.id = #{user.id} and users.owner_id = #{User.current.id}")
        errors.add(:user, _("User_not_found"))
        return false
      end
    end
  end


  def reseller
    @attributes["reseller"] ||= User.find(:first, :conditions => ["users.id = ? and users.usertype='reseller'", self.reseller_id])
  end

  def reseller=(reseller)
    @attributes["reseller"] = reseller
    @attributes["reseller_id"] = reseller.id if reseller.class == User
  end

  def did_prov_rates(t ='')
    did_check_rates('provider', t)
  end

  def did_incoming_rates(t ='')
    did_check_rates('incoming', t)
  end

  def did_owner_rates(t ='')
    did_check_rates('owner', t)
  end

  def did_check_rates(type, t)
    cond = t ? ["did_id = ? AND rate_type = ? AND daytype = ?", self.id, type, t] : ["did_id = ? AND rate_type = ?", self.id, type]
    Didrate.find(:all, :conditions => cond, :order => 'start_time ASC')
  end

  def check_did_rates
    r_size = Didrate.find(:all, :conditions => ['did_id = ?', id], :group => "rate_type")

    if !r_size or r_size.size < 3
      ['provider', 'incoming', 'owner'].each { |rtype|
        if !Didrate.find(:first, :conditions => ['did_id = ? AND rate_type = ? ', id, rtype])
          dr = Didrate.new(:did_id => id, :rate_type => rtype.to_s)
          dr.save
        end
      }
    end
  end

  def make_free
    self.user_id = 0
    self.device_id = 0
    self.dialplan_id = 0
    self.reseller_id = 0
    self.status = "free"
    self.save
  end

  def make_free_for_reseller
    self.user_id = 0
    self.device_id = 0
    self.dialplan_id = 0
    self.status = "free"
    self.save
  end

  def assign(device_id)
    dev = Device.find(device_id)
    if dev.primary_did_id == 0
      dev.primary_did_id = self.id
      dev.save
    end

    self.device_id = device_id
    self.status = "active"
    self.save
  end

  def close
    dev = Device.find(:first, :conditions => ["id = ?", device_id])

    if dev and dev.primary_did_id == self.id
      dev.primary_did_id = 0
      dev.save
      #dev.update_cid(self.device.name)
    end

    self.status = "closed"
    self.closed_till = (Time.now + Confline.get_value("Days_for_did_close").to_i.days).strftime("%Y-%m-%d %H:%M:%S")
    self.save

  end

  def reserve(user_id)
    did_user = User.find(:first, :conditions => ["id = ?", user_id])
    if did_user and did_user.is_reseller?
      self.update_attributes({:reseller_id => did_user.id, :user_id => 0, :device_id => 0, :status => "free"})
    else
      self.update_attributes({:user_id => user_id, :status => "reserved"})
    end
  end

  def terminate
    self.user_id = 0
    self.device_id = 0
    self.reseller_id = 0
    self.status = "terminated"
    self.save
  end

  #debug

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def Did::get_dids_price(user_id, period_start = nil, period_end = nil)
    if period_start and period_end
      sqlDid = "SELECT dids.did AS 'did', SUM(calls.did_price) AS 'did_price', COUNT(*) as 'quantity' 
                FROM calls JOIN dids ON calls.dst = dids.did 
                WHERE did_price > 0 AND calls.user_id = #{user_id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' GROUP BY dids.did"
    else
      sqlDid = "SELECT dids.did AS 'did', SUM(calls.did_price) AS 'did_price', COUNT(*) as 'quantity' 
                FROM calls JOIN dids ON calls.dst = dids.did 
                WHERE did_price > 0 AND calls.user_id = #{user_id} AND calls.disposition = 'ANSWERED' GROUP BY dids.did"
    end
    dids = Call.find_by_sql(sqlDid)
  end

  def Did::get_dids(user_id, period_start = nil, period_end = nil)
    if period_start and period_end
      sqlDid = "SELECT *
                FROM calls JOIN dids ON calls.dst = dids.did 
                WHERE did_price > 0 AND calls.user_id = #{user_id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' GROUP BY dids.did"
    else
      sqlDid = "SELECT *
                FROM calls JOIN dids ON calls.dst = dids.did 
                WHERE did_price > 0 AND calls.user_id = #{user_id} AND calls.disposition = 'ANSWERED' GROUP BY dids.did"
    end
    dids = Call.find_by_sql(sqlDid)
  end

  # returns sum of did_inc_price for a particular user
  def Did::get_did_inc_price_sum(user_id, period_start = nil, period_end = nil)
    if period_start and period_end
      sqlDid = "SELECT SUM(calls.did_inc_price) AS 'did_inc_price', COUNT(*) as 'quantity' 
                FROM calls
                WHERE did_inc_price > 0 AND calls.user_id = #{user_id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' "
    else
      sqlDid = "SELECT SUM(calls.did_inc_price) AS 'did_inc_price', COUNT(*) as 'quantity' 
                FROM calls
                WHERE did_inc_price > 0 AND calls.user_id = #{user_id} AND calls.disposition = 'ANSWERED' "
    end
    dids = Call.find_by_sql(sqlDid)
  end

  def Did::get_did_inc(user_id, period_start = nil, period_end = nil)
    if period_start and period_end
      sqlDid = "SELECT * 
                FROM calls
                WHERE did_inc_price > 0 AND calls.user_id = #{user_id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' "
    else
      sqlDid = "SELECT * 
                FROM calls
                WHERE did_inc_price > 0 AND calls.user_id = #{user_id} AND calls.disposition = 'ANSWERED' "
    end
    dids = Call.find_by_sql(sqlDid)
  end

  def Did.find_all_for_select
    if User.current.usertype == 'reseller'
      find(:all, :select => "id, did", :conditions => ['reseller_id= ?', User.current.id])
    else
      find(:all, :select => "id, did")
    end
  end

  def Did.free_dids_for_select(id = nil)
    if User.current.usertype == 'reseller'
      reseller = User.current.id
    else
      reseller = 0
    end
    find(:all, :select => "id, did", :conditions => "status = 'free' and reseller_id = #{reseller} #{" AND id != #{id} " if id.to_i > 0 }", :order => 'did ASC')
  end

  def Did.forward_dids_for_select(id = nil)
    if User.current.usertype == 'reseller'
      reseller = User.current.id
    else
      reseller = 0
    end
    find(:all, :select => "id, did", :conditions => "dialplan_id != 0 and reseller_id = #{reseller} #{" AND id != #{id} " if id.to_i > 0 }", :order => 'did ASC')
  end

=begin
  Checks whether did has associated calls with if or not.

  *Returns*
  *boolean* - true if did has no associated calls with it, else returns false
=end
  def find_if_used_in_calls
    Call.where("did_id = #{self.id}").first ? true : false
  end

end
