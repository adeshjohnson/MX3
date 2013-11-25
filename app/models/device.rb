# -*- encoding : utf-8 -*-
class Device < ActiveRecord::Base

  # all this nonsense based on http://www.ruby-forum.com/topic/101557
  self.inheritance_column = :_type_disabled # we have devices.type column for asterisk 1.8 support, so we need this to allow such column

  # getter for the "type" column
  def device_ror_type
    self[:type]
  end

  # setter for the "type" column
  def device_ror_type=(s)
    self[:type] = s
  end

  #=====================================================================

  attr_accessor :device_ip_authentication_record
  attr_accessor :device_old_name_record
  attr_accessor :device_old_server_record
  attr_accessor :tmp_codec_cache

  belongs_to :user
  has_many :extlines, :order => "exten ASC, priority ASC"
  has_many :dids
  belongs_to :devicegroup
  has_many :callerids
  belongs_to :location
  has_one :voicemail_box
  has_many :callflows
  has_many :pdffaxemails
  has_one :provider
  has_many :activecalls, :foreign_key => "src_device_id"
  has_many :ringgroups_devices
  has_many :devicerules
  has_many :server_devices, :dependent => :destroy
  has_many :servers, :through => :server_devices

  before_validation :check_device_username, :on => :create

  validates_presence_of :name, :message => _('Device_must_have_name')
  validates_presence_of :extension, :message => _('Device_must_have_extension')
  validates_uniqueness_of :extension, :message => _('Device_extension_must_be_unique')
  #validates_uniqueness_of :username, :scope => [:username, :secret, :ipaddr, :port, :device_type], :message => _('Device_Username_Must_Be_Unique'), :if => :with_owner_credentials
  validates_format_of :max_timeout, :with => /^[0-9]+$/, :message => _('Device_Call_Timeout_must_be_greater_than_or_equal_to_0')
  validates_numericality_of :port, :message => _("Port_must_be_number"), :if => Proc.new{ |o| not o.port.blank? }

  # before_create :check_callshop_user
  before_save :uniqueness_check, :validate_extension_from_pbx, :ensure_server_id, :random_password, :check_and_set_defaults, :check_password, :ip_must_be_unique_on_save, :check_language, :check_location_id, :check_dymanic_and_ip, :set_qualify_if_ip_auth, :validate_trunk, :update_mwi, :ast18, :t38pt_normalize, :check_subnet
  before_update :uniqueness_check, :validate_fax_device_codecs, :check_subnet
  after_create :create_codecs, :device_after_create
  after_save :device_after_save#, :prune_device #do not prune devices after save! it abuses AMI and crashes live calls (#11709)! prune_device is done in device_update->configure_extensions->prune_device

=begin
  #3239 dont know whats the reason to keep two identical fields, but just keep in mind that one is 1/0
  #other yes/no and their values has to be the same
  # MK: subscribemwi is used by Asterisk 1.4, enable_mwi by Asterisk 1.8
=end
  def update_mwi
    self.subscribemwi = ((self.enable_mwi == 1) ? 'yes' : 'no')
  end

=begin
  Resellers are allowed to assign dids to trunk only if appropriate settings is set by admin.
  In case device allready has assigned dids, it cannot be set to trunk if reseller does not have
  rights to assign dids to trunk.
=end
  def validate_trunk
    if self.user and self.user.owner.usertype == "reseller"
      allowed_to_assign_did = self.user.owner.allowed_to_assign_did_to_trunk?
      has_assigned_did = (not self.dids.empty?)
      if self.user.owner.usertype == "reseller" and self.is_trunk? and has_assigned_did and not allowed_to_assign_did
        self.errors.add(:trunk, _('Did_is_assigned_to_device'))
        return false
      end
    end
  end

=begin
  Device may be blocked by core if there are more than one simultaneous call

  Returns
  *boolean* true if device can be blocked
=end
  def block_callerid?
    (block_callerid.to_i > 1)
  end

=begin
  Only valid arguments for block_callerid is 0 or integer greater than 1
  if params  are invalid we set it to 0

  Params
  *simalutaneous_calls* limit of simultaneous calls when core should automaticaly
    block device
=end
  def block_callerid=(simultaneous_calls)
    simultaneous_calls = simultaneous_calls.to_s.strip.to_i
    simultaneous_calls = simultaneous_calls < 2 ? 0 : simultaneous_calls
    write_attribute(:block_callerid, simultaneous_calls)
  end

=begin
  Note that this method is written mostly thinking about using it in views so dont
  expect any logic beyound that.

  Returns
  *simultaneous_calls* if block_callerid is set to smth less than 2 retun empty string
    else return that number
=end
  def block_callerid
    simultaneous_calls = read_attribute(:block_callerid).to_i
    simultaneous_calls < 2 ? '' : simultaneous_calls
  end

  def is_trunk?
    return self.istrunk.to_i > 0
  end

=begin
  Returs
  *boolean* true if srtp encryption is set for device, otherwise false
=end
  def srtp_encryption?
    self.encryption.to_s == 'yes'
  end

=begin
  Returs
  *boolean* true if t38 support is set for device, otherwise false
=end
  def t38_support?
    self.t38pt_udptl == "yes"
  end

=begin
  if username is blank it means that ip authentication is enabled and there's
  no need to check for valid passwords.
  server device is an exception, so there's no need to check whether it's pass is valid or not.
  TODO: each device type should have separate class. there might be PasswordlessDevice
=end
  def check_password
    unless self.server_device? or self.username.blank? or self.provider or ["dahdi", "virtual", "h323"].include?(self.device_type.downcase)
      if self.name and self.secret.to_s == self.name.to_s
        errors.add(:secret, _("Name_And_Secret_Cannot_Be_Equal"))
        return false
      end

      if self.secret.to_s.length < 8 and Confline.get_value("Allow_short_passwords_in_devices").to_i == 0
        errors.add(:secret, _("Password_is_too_short"))
        return false
      end
    end
  end

  def validate_fax_device_codecs
    valid_codecs_count = self.codecs.count { |codec| ['alaw', 'ulaw'].include? codec.name }
    if self.device_type == 'FAX' and valid_codecs_count == 0
      self.errors.add(:devicecodecs, 'Fax_device_has_to_have_at_least_one_codec_enabled')
      return false
    else
      return true
    end
  end

  def validate_extension_from_pbx
    if Dialplan.find(:first, :conditions => {:dptype => "pbxfunction", :data2 => extension})
      errors.add(:extension, _('Device_extension_must_be_unique'))
      return false
    end
  end

  def check_language
    if self.language.to_s.blank?
      self.language = 'en'
    end
  end

  def check_location_id
    if self.user and self.user.owner_id != 0
      #if old location id - create and set
      value = Confline.get_value("Default_device_location_id", self.user.owner_id)
      if value.blank? or value.to_i == 1 or !value
        owner = User.where(:id => self.user.owner_id).first
        owner.after_create_localization
      else
        #if new - only update devices with location 1
        self.user.owner.update_resellers_device_location(value)
      end
    end
  end

  def check_and_set_defaults
    if self.device_type
      if ["sip", "iax2"].include?(self.device_type.downcase)
        self.nat ||= "yes"
        self.canreinvite ||= "no"
      end
    end
  end

  # checks if server with such id exists
  def ensure_server_id
    if self.server_id.blank? or !Server.where(:id => self.server_id).first
      default = Confline.get_value("Default_device_server_id")
      if !default.blank?
        self.server_id = default
      else
        if server = Server.order("id ASC").first
          Confline.set_value("Default_device_server_id", server.id)
          self.server_id = server.id
        else
          errors.add(:server, _("Server_Not_Found"))
          return false
        end
      end
    end
  end

  def check_callshop_user(flash)
    user = self.user
    if user and user.callshops.size.to_i != 0 and user.devices.size.to_i > 0 and (defined?(CS_Active) and CS_Active == 1)
      flash += " <br> " +_('User_in_CallShop_can_have_only_one_Device_creating_more_is_dangerous')
    end
    return flash
  end

  def random_password
    if  (self.device_type.to_s == 'FAX' or self.device_type.to_s == 'Virtual') and self.secret.blank?
      self.secret = ApplicationController::random_password(10).to_s
    end
  end

  # converting callerid like "name" <number> to number
  def callerid_number
    cid = self.callerid
    cidn = ""

    if self.callerid and cid.index('<') and cid.index('>') and cid.index('<') >= 0 and cid.index('>') > 0
      cidn = cid[cid.index('<')+1, cid.index('>')-cid.index('<')-1]
    end

    cidn
  end

  def check_device_username
    if self.username_must_be_unique_on_creation
      username = self.username; name = self.username
      while Device.where(:username => username).first
        username = self.generate_rand_name(name, 2)
      end
      self.username = username
    end
    if self.virtual?
      username = self.username;
      while Device.where(:username => username).first
        username = self.generate_rand_name('', 12)
      end
      self.username = username
    end
  end

  def virtual?
    device_type == 'Virtual'
  end

  def generate_rand_name(string, size)
    chars = '123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    str = ''
    size.times { |i| str << chars[rand(chars.length)] }
    string + str
  end

=begin
  Every device has to have ONE voicemail box, so after saveing it we should create
  voicemail. lookin' at device_after_create and thinking it's plain stupid, huh?
  Note that i do not check whether self.user is not nil, because if it would be nil,
  it would mean that referential integrity was broken and so miskate was made by breaking it
  not by trusting that it wouldnt be broken.
=end
  def device_after_save
    write_attribute(:accountcode, id)
    sql = "UPDATE devices SET accountcode = id WHERE id = #{id};"
    ActiveRecord::Base.connection.update(sql)
    user = self.user
    if user and self.voicemail_box.blank?
      email = Confline.get_value("Default_device_voicemail_box_email", user.owner_id)
      email = user.address.email if user.address and user.address.email.to_s.size > 0
      create_vm(extension, Confline.get_value("Default_device_voicemail_box_password", user.owner_id), user.first_name + " " + user.last_name, email)
    end
  end

  def device_after_create
    #device_after_save
    if self.user
      user = self.user
      curr_id = User.current ? User.current.id : self.user.owner_id
      Action.add_action_hash(curr_id, {:target_id => id, :target_type => "device", :action => "device_created"})
      #------- VM ----------
      email = Confline.get_value("Default_device_voicemail_box_email", user.owner_id)
      email = user.address.email if user.address and user.address.email.to_s.size > 0
      create_vm(extension, Confline.get_value("Default_device_voicemail_box_password", user.owner_id), user.first_name + " " + user.last_name, email)
      dev = user.devices.size.to_i #Device.count(:all, :conditions=>"user_id = #{user.id}")
      if dev.to_i == 1
        user.primary_device_id = id
        user.save
      end
      self.update_cid(Confline.get_value("Default_device_cid_name", user.owner_id), Confline.get_value("Default_device_cid_number", user.owner_id))  unless self.callerid
    end

    if self.virtual?
      self.extension = self.username = self.name = 'virtual_' + self.id.to_i.to_s
      self.save
    end

    if self.device_type == "H323"
      self.username = ""
      self.secret = ""
      if !self.name.include?('ipauth')
        name = self.generate_rand_name('ipauth', 8)
        while Device.where(['name= ? and id != ?', name, self.id]).first
          name = self.generate_rand_name('ipauth', 8)
        end
        self.name = name
      end
      self.save
    end
  end


  #================== CODECS =========================


  def create_codecs
    owner = self.user_id > 0 ? self.user.owner_id : 0
    for codec in Codec.all
      if Confline.get_value("Default_device_codec_#{codec.name}", owner).to_i == 1
        pc = Devicecodec.new
        pc.codec_id = codec.id
        pc.device_id = self.id
        pc.priority = Confline.get_value2("Default_device_codec_#{codec.name}", owner).to_i
        pc.save
      end
    end
    self.update_codecs
  end

  def codec?(codec)
    sql = "SELECT codecs.name FROM devicecodecs, codecs WHERE devicecodecs.device_id = '" + self.id.to_s + "' AND devicecodecs.codec_id = codecs.id GROUP BY codecs.name HAVING COUNT(*) = 1"
    self.tmp_codec_cache = (self.tmp_codec_cache || ActiveRecord::Base.connection.select_values(sql))
    self.tmp_codec_cache.include? codec.to_s
  end

  def codecs
    res = Codec.select("*").joins("LEFT JOIN devicecodecs ON (devicecodecs.codec_id = codecs.id)").where("devicecodecs.device_id = #{self.id.to_s}").order("devicecodecs.priority").all
    codecs = []
    for i in 0..res.size-1
      codecs << Codec.where(:id => res[i]["codec_id"]).first
    end
    codecs
  end

  def codecs_order(type)
    cond = self.device_type.to_s == 'FAX' ? ' AND codecs.name IN ("alaw", "ulaw") ' : ''
    Codec.find_by_sql("SELECT codecs.*,  IF(devicecodecs.priority is null, 100, devicecodecs.priority)  as bb FROM codecs  LEFT Join devicecodecs on (devicecodecs.codec_id = codecs.id and devicecodecs.device_id = #{self.id.to_i})  where codec_type = '#{type}' #{cond} ORDER BY bb asc, codecs.id")
  end


  def update_codecs_with_priority(codecs, ifsave = true)
    dc = {}
    Devicecodec.find(:all, :conditions => ["device_id = ?", self.id]).each { |c| dc[c.codec_id] = c.priority; c.destroy }
    Codec.find(:all).each { |codec| Devicecodec.new(:codec_id => codec.id, :device_id => self.id, :priority => dc[codec.id].to_i).save if codecs[codec.name] == "1" }
    self.update_codecs(ifsave)
  end


  def update_codecs(ifsave = true)
    cl = []
    self.codecs.each { |codec| cl << codec.name }
    cl << "all" if cl.size.to_i == 0
    self.allow = cl.join(';')
    self.save if ifsave
  end

  #================== END OF CODECS =========================

  def update_cid(cid_name, cid_number, ifsave = true)

    #   if cid_number
    #     cid = cid_number
    #   else
    #     if (self.primary_did_id != 0)and(primary_did = Did.find(self.primary_did_id))
    #        cid = primary_did.did.to_s
    #       else
    #          cid = self.username.to_s
    #         end
    #        end

    #        self.callerid = nil
    #        if cid_name and cid_number
    #  		  self.callerid = "\"" + cid_name.to_s + "\"" + " <" + cid_number + ">" if cid_name.length > 0 and cid_number.length > 0
    #		end
    #		self.save

    cid_name = "" if not cid_name
    cid_number = "" if not cid_number

    self.callerid = nil unless self.callerid

    if cid_name.length > 0 and cid_number.length > 0
      self.callerid = "\"" + cid_name.to_s + "\"" + " <" + cid_number.to_s + ">"
    end

    if cid_name.length > 0 and cid_number.length == 0
      self.callerid = "\"" + cid_name.to_s + "\""
    end

    if cid_name.length == 0 and cid_number.length == 0
      self.callerid = ''
    end

    if cid_name.length == 0 and cid_number.length > 0
      self.callerid = "<" + cid_number.to_s + ">"
    end

    self.save if ifsave

  end

  #======================= CALLS =============================

  def all_calls
    Call.where(:src_device_id => self.id)
  end

  def any_calls
    Call.where(:src_device_id => self.id).limit(1)
  end

  def calls(type, date_from, date_till)
    #possible types:
    # all +
    #    local
    #    external
    #       incoming
    #         missed +
    #         missed_not_processed +
    #       outgoing
    #         answered
    #         failed
    #           busy
    #           no_answer
    #           error


    if type == "all"
      @calls = Call.find(:all, :conditions => ["src_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered"
      @calls = Call.find(:all, :conditions => ["billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "noanswer"
      @calls = Call.find(:all, :conditions => ["src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed"
      @calls = Call.find(:all, :conditions => ["src_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy"
      @calls = Call.find(:all, :conditions => ["src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed"
      @calls = Call.find(:all, :conditions => ["src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed_not_processed"
      @calls = Call.find(:all, :conditions => ["processed = '0' AND src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    #---incoming---

    if type == "all_inc"
      @calls = Call.find(:all, :conditions => ["dst_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_inc"
      @calls = Call.find(:all, :conditions => ["billsec > 0 AND dst_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "noanswer_inc"
      @calls = Call.find(:all, :conditions => ["dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed_inc"
      @calls = Call.find(:all, :conditions => ["dst_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy_inc"
      @calls = Call.find(:all, :conditions => ["dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed_inc"
      @calls = Call.find(:all, :conditions => ["dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed_not_processed_inc"
      @calls = Call.find(:all, :conditions => ["processed = '0' AND dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    #--not used---

    if type == "incoming"
      @calls = Call.find(:all, :conditions => ["user_price >= 0 AND dst_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "outgoing"
      @calls = Call.find(:all, :conditions => ["user_price >= 0 AND src_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    @calls
  end

  def total_calls(type, date_from, date_till)

    if type == "all"
      t_calls = Call.count(:all, :conditions => ["(src_device_id = ? OR dst_device_id =?) AND user_id IS NOT NULL " + date_query(date_from, date_till), self.id, self.id], :order => " calldate DESC")
    end

    if type == "answered"
      t_calls = Call.count(:all, :conditions => ["billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_out"
      t_calls = Call.count(:all, :conditions => ["src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "no_answer_out"
      t_calls = Call.count(:all, :conditions => ["src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy_out"
      t_calls = Call.count(:all, :conditions => ["src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed_out"
      t_calls = Call.count(:all, :conditions => ["src_device_id = ?  AND user_id IS NOT NULL AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_inc"
      t_calls = Call.count(:all, :conditions => ["dst_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "no_answer_inc"
      t_calls = Call.count(:all, :conditions => ["dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy_inc"
      t_calls = Call.count(:all, :conditions => ["dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed_inc"
      t_calls = Call.count(:all, :conditions => ["dst_device_id = ? AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    if type == "missed_not_processed"
      t_calls = Call.count(:all, :conditions => ["processed = '0' AND dst_device_id =? AND #{Call.nice_answered_cond_sql(false)}" + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "incoming"
      t_calls = Call.count(:all, :conditions => ["dst_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "outgoing"
      t_calls = Call.count(:all, :conditions => ["src_device_id =? AND user_id IS NOT NULL " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    t_calls
  end


  def total_duration(type, date_from, date_till)

    if type == "answered"
      t_duration = Call.sum(:duration, :conditions => ["billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_out"
      t_duration = Call.sum(:duration, :conditions => ["billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_inc"
      t_duration = Call.sum(:duration, :conditions => ["billsec > 0 AND dst_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    t_duration = 0 if t_duration == nil
    t_duration
  end


  def total_billsec(type, date_from, date_till)

    if type == "answered"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec2 FROM calls WHERE (billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == "answered_out"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == "answered_inc"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND dst_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (billsec > 0 AND dst_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end


    t_billsec = 0 if t_billsec == nil
    t_billsec
  end


  # forms sql part for date selection

  def date_query(date_from, date_till)
    # date query
    if date_from == ""
      date_sql = ""
    else
      if date_from.length > 11
        date_sql = "AND calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'"
      else
        date_sql = "AND calldate BETWEEN '" + date_from.to_s + " 00:00:00' AND '" + date_till.to_s + " 23:59:59'"
      end
    end
    date_sql
  end

  def destroy_everything
    err = []
    if self.all_calls.size == 0

      for email in self.pdffaxemails do
        email.destroy
      end

      for cid in self.callerids do
        cid.destroy
      end

      Extline.delete_all(["device_id = ?", self.id])

      err = self.prune_device_in_server

      self.destroy_vm
      self.destroy
    end
    err
  end


  def prune_device_in_all_servers(dv_name = nil, reload = 1)
    dv_name = name if dv_name.nil?
    err= []
    # clean Realtime mess
    servers = Server.find(:all)
    for server in servers
      begin
        server.prune_peer(dv_name, reload)
      rescue Exception => e
        err << e.message
      end
    end
    err
  end

  def prune_device_in_server(dv_name = nil, reload = 1, serverid = nil)
    dv_name = name if dv_name.nil?
    serverid = server_id if serverid.nil?
    err= []
    # clean Realtime mess http://trac.kolmisoft.com/trac/ticket/5092
    server = Server.find(:first, :conditions => {:server_id => serverid})
    begin
      server.prune_peer(dv_name, reload) if server
    rescue Exception => e
      err << e.message
    end
    err
  end

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  #--------------- VoiceMail--------------
  #

  def voicemail_box
    VoicemailBox.find(:first, :conditions => "device_id = #{self.id}") if self.id
  end

  def destroy_vm
    if self.voicemail_box
      vm_id = self.voicemail_box.id
      sql = "DELETE FROM voicemail_boxes WHERE uniqueid = '#{vm_id}'"
      res = ActiveRecord::Base.connection.update(sql)
      #self.voicemail_box.destroy
    end
  end

  # Check if device is a detectable fax
  def has_fax_detect
    flow = Callflow.find(:all, :conditions => ["data = ? and data2 = 'fax' and action = 'fax_detect'", self.id])
    return flow if flow.size > 0
    return nil
  end

  # Check if device has calls forwarded to it
  def has_forwarded_calls
    flow = Callflow.find(:all, :conditions => ["data = ? and data2 = 'local' and action = 'forward'", self.id])
    return flow if flow.size > 0
    return nil
  end

  def dialplans
    return Dialplan.where("(dptype = 'authbypin' and data5 = '#{self.id}') or (dptype != 'authbypin' and data3 = '#{self.id}')")
  end

  # Check if device is used by location rules
  def used_by_location_rules
    Locationrule.where(:device_id => self.id).first
  end

  def uniqueness_check
    if self.provider
      fields	= %w{ username secret ipaddr port device_type }
      matches	= ["device_id != ? AND providers.user_id != #{User.current.id}", self.id]
    else
      fields	= %w{ username } # why only username?
      matches	= ["host = 'dynamic' AND devices.id != ?", self.id]
    end

    query 	= Hash[fields.map {|field| [field.to_sym, self[field.to_sym].to_s] }]

    filter_active	= Confline.get_value("Disalow_Duplicate_Device_Usernames", 0).to_i == 1
    zero_duplicates	= (
      Device.where(query)
      .joins('LEFT JOIN providers on providers.device_id = devices.id')
      .where(matches)
      .reject{ |dev| not self.provider and dev.username.blank? }
      .size.zero?
    )

    if filter_active and not zero_duplicates
      errors.add(:username, _('Device_Username_Must_Be_Unique')) and return false
    end
  end

  def username_must_be_unique_on_creation
    self.device_ip_authentication_record.to_i == 0 and self.provider and Confline.get_value("Disalow_Duplicate_Device_Usernamess").to_i == 1
  end

  def dynamic?
    (ipaddr.blank? or ipaddr.to_s == "0.0.0.0") ? true : false
  end

  def ip_must_be_unique_on_save
    idi = self.id
    curr_id = User.current ? User.current.id : self.user.owner_id
    message = if User.current and User.current.usertype == 'admin'
                _('When_IP_Authentication_checked_IP_must_be_unique') + '. ' +
                _('ip_is_used_by')
              else
                _('This_IP_is_not_available') +
                "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Authentication' target='_blank'>" +
                "<img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' /></a>"
              end

    cond = if ipaddr.blank?
             ['devices.id != ? AND host = ? AND providers.user_id != ? and ipaddr != "" and ipaddr != "0.0.0.0"', idi, host, curr_id]
           else
             ['devices.id != ? AND (host = ? OR ipaddr = ?) AND providers.user_id != ? and ipaddr != "" and ipaddr != "0.0.0.0"', idi, host, ipaddr, curr_id]
           end

    #    check device wihs is provider with providers devices
    providers_device_with_ip = Device.joins("JOIN providers ON (providers.device_id = devices.id)").where(cond).first

    if self.device_ip_authentication_record.to_i == 1 and self.provider and providers_device_with_ip and !self.virtual?
      if User.current.usertype == 'admin'
        message << " #{nice_device_user(providers_device_with_ip)} in Device: #{nice_device(providers_device_with_ip)}."
      end

      errors.add(:ip_authentication, message)
      return false
    end

    #      check self device  or another devices with ip auth on
    condd = self.device_ip_authentication_record.to_i == 1 ? '' : ' and devices.username = "" '

    cond22 = if ipaddr.blank?
               #      check device host with another owner devices
               ['devices.id != ? AND host = ? and users.owner_id != ?  and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0"' + condd, idi, host, curr_id]
             else
               #      check device IP and Host with another owner devices
               ['devices.id != ? AND (host = ? OR ipaddr = ?) and users.owner_id != ? and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0"' + condd, idi, host, ipaddr, curr_id]
             end

    #    check device IP with another user providers IP's with have ip auth on, 0.0.0.0 not included
    device_with_ip = Device.joins("JOIN users ON (user_id = users.id)").where(cond22).first

    if device_with_ip and !self.dynamic? and !self.virtual?
      if User.current.usertype == 'admin'
        message << " #{nice_device_user(device_with_ip)} in Device: #{nice_device(device_with_ip)}."
      end

      errors.add(:ip_authentication, message)
      return false
    end

    #    check device IP with another user providers IP's with have ip auth on, 0.0.0.0 not included
    provider_with_ip = Provider.joins("JOIN devices ON (providers.device_id = devices.id)").where(["server_ip = ? and devices.username = '' and server_ip != '0.0.0.0' and devices.id != ?  and ipaddr != '' AND providers.user_id != ? and ipaddr != '0.0.0.0'", ipaddr, idi, curr_id]).first

    if provider_with_ip and !self.virtual?
      if User.current.usertype == 'admin'
        message << " #{nice_device_user(provider_with_ip)} in Provider: #{nice_provider(provider_with_ip)}."
      end

      errors.add(:ip_authentication, message)
      return false
    end

    #    check device with providers port, dont allow dublicates in providers and devices combinations
    if self.provider
      message2 = (User.current and User.current.usertype == 'admin') ? _("Device_with_such_IP_and_Port_already_exist") + ' ' + _('Please_check_this_link_to_see_how_it_can_be_resolved') + "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Configure_Provider_which_can_make_calls' target='_blank'><img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' /></a>" : _('This_IP_and_port_is_not_available') + "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Authentication' target='_blank'><img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' /></a>"

      cond3 = if ipaddr.blank?
                ['devices.id != ? AND host = ? and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=? AND providers.id IS NULL' + condd, idi, host, port]
              else
                ['devices.id != ? AND (host = ? OR ipaddr = ?) and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=? AND providers.id IS NULL' + condd, idi, host, ipaddr, port]
              end

      if Device.count(:all, :joins => ['JOIN users ON (user_id = users.id) LEFT JOIN providers ON (providers.device_id = devices.id)'], :conditions => cond3).to_i > 0 and !self.virtual?
        errors.add(:ip_authentication, message2)
        return false
      end

    else
      message2 = (User.current and User.current.usertype == 'admin') ? _("Provider_with_such_IP_and_Port_already_exist") + ' ' + _('Please_check_this_link_to_see_how_it_can_be_resolved') + "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Configure_Provider_which_can_make_calls' target='_blank'><img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' /></a>" : _('This_IP_and_port_is_not_available') + "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Authentication' target='_blank'><img alt='Help' src='#{Web_Dir}/assets/icons/help.png' title='#{_('Help')}' /></a>"

      cond3 = if ipaddr.blank?
                ['devices.id != ? AND host = ? and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=? ' + condd, idi, host, port]
              else
                ['devices.id != ? AND (host = ? OR ipaddr = ?) and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=?' + condd, idi, host, ipaddr, port]
              end

      if Provider.count(:all, :joins => ['JOIN devices ON (device_id = devices.id)'], :conditions => cond3).to_i > 0 and !self.virtual?
        errors.add(:ip_authentication, message2)
        return false
      end
    end
  end

  def set_qualify_if_ip_auth
    if username.to_s.blank?
      self.qualify = 'no'
    end
  end

  def check_dymanic_and_ip
    if username.to_s.blank? and host.to_s == 'dynamic'
      errors.add(:host, _("When_IP_Authentication_checked_Host_cannot_be_dynamic"))
      return false
    end
  end

  def username_must_be_unique
    Confline.get_value("Disalow_Duplicate_Device_Usernames").to_i == 1 and self.device_ip_authentication_record.to_i == 0 and !self.provider
  end

  def provider_device_username_unique?
    Confline.get_value("Disalow_Duplicate_Device_Usernames").to_i == 1 and self.device_ip_authentication_record.to_i == 0 and self.provider and !self.username.blank?
  end

  def username_must_be_unique_check
    if self.device_type != "H323"
      self.username_must_be_unique or self.provider_device_username_unique?
    else
      false
    end
  end

  def Device.validate_perims(options={})
    permits = "0.0.0.0/0.0.0.0"
    if options[:ip1].size > 0 and options[:mask1].size > 0
      unless Device.validate_ip(options[:ip1].to_s) and Device.validate_ip(options[:mask1].to_s)
        return nil
      end
      permits = options[:ip1].strip + "/" + options[:mask1].strip
      if options[:ip2].size > 0 and options[:mask2].size > 0
        unless Device.validate_ip(options[:ip2]) and Device.validate_ip(options[:mask2])
          return nil
        end
        permits += ";" + options[:ip2].strip + "/" + options[:mask2].strip
        if options[:ip3].size > 0 and options[:mask3].size > 0
          unless Device.validate_ip(options[:ip3]) and Device.validate_ip(options[:mask3])
            return nil
          end
          permits += ";" + options[:ip3].strip + "/" + options[:mask3].strip
        end
      end
    end
    return permits
  end

  def Device.validate_permits_ip(ip_arr)
    err = true
    ip_arr.each { |ip|
      if ip and !ip.blank? and !Device.validate_ip(ip)
        err = false
      end
    }
    return err
  end

  def Device::validate_ip(ip)
    ip.gsub(/(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)/, "").to_s.length == 0 ? true : false
  end

  def Device.find_all_for_select(current_user_id = nil, options={})

    jn = ''
    jn += ' JOIN dids ON (dids.device_id = devices.id) ' if options[:include_did].to_i == 1
    if current_user_id
      return Device.select("devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username").joins("LEFT JOIN users ON (users.id = devices.user_id) #{jn}").where(["device_type != 'FAX' AND (users.owner_id = ? OR users.id = ?) AND name not like 'mor_server_%' AND user_id > -1", current_user_id, current_user_id]).all
    else
      return Device.select("id, description, extension, device_type, istrunk, name, ani, username").where("device_type != 'FAX' AND name not like 'mor_server_%' AND user_id > -1").joins(jn).all
    end
  end

  def device_ip_authentication?
    @device_ip_authentication_record
  end

  def load_device_types(options = {})
    Devicetype.find(:all).map { |type|
      (options.has_key?(type.name) and options[type.name] == false and self.device_type != type.name) ? nil : type
    }.compact
  end


  def perims_split
    ip1 = ""
    mask1 = ""
    ip2 = ""
    mask2 = ""
    ip3 = ""
    mask3 = ""

    data = permit.split(';')
    if data[0]
      rp = data[0].split('/')
      ip1 = rp[0]
      mask1 = rp[1]
    end

    if data[1]
      rp = data[1].split('/')
      ip2 = rp[0]
      mask2 = rp[1]
    end

    if data[2]
      rp = data[2].split('/')
      ip3 = rp[0]
      mask3 = rp[1]
    end
    return ip1, mask1, ip2, mask2, ip3, mask3
  end


  def Device.calleridpresentation
    [
        [_('Presentation_Allowed_Not_Screened'), 'allowed_not_screened'], [_('Presentation_Allowed_Passed_Screen'), 'allowed_passed_screen'],
        [_('Presentation_Allowed_Failed_Screen'), 'allowed_failed_screen'], [_('Presentation_Allowed_Network_Number'), 'allowed'],
        [_('Presentation_Prohibited_Not_Screened'), 'prohib_not_screened'], [_('Presentation_Prohibited_Passed_Screen'), 'prohib_passed_screen'],
        [_('Presentation_Prohibited_Failed_Screen'), 'prohib_failed_screen'], [_('Presentation_Prohibited_Network_Number'), 'prohib'],
        [_('Number_Unavailable'), 'unavailable']
    ]
  end

  def validate_before_destroy(current_user, allow_edit)
    notice = ''
    unless user
      notice = _("User_was_not_found")
    end

    if current_user.usertype == 'accountant' and !allow_edit and notice.blank?
      notice = _('You_have_no_editing_permission')
    end

    if self.has_fax_detect and notice.blank?
      notice = _('Cant_delete_device_has_fax_detect')
    end

    if self.has_forwarded_calls and notice.blank?
      notice = _('Cant_delete_device_has_forwarded_calls')
    end

    if self.any_calls.size > 0 and notice.blank?
      notice = _('Cant_delete_device_has_calls')
    end

    if self.dialplans.size > 0 and notice.blank?
      notice = _('Cant_delete_device_has_dialplans')
    end

    if self.used_by_location_rules and notice.blank?
      notice = _('One_or_more_location_rules_are_using_this_device')
    end
    notice
  end

  def destroy_all
    Extline.delete_all(["device_id = ?", id])

    #deleting association with dids
    if dids = Did.find(:all, :conditions => ["device_id =?", id])
      for did in dids
        did.device_id = "0"
        did.save
      end
    end

    #destroying device connection to servers
    for sd in ServerDevice.where("device_id = ?", id).all
      sd.destroy
    end

    #destroying codecs
    for dc in Devicecodec.find(:all, :conditions => ["device_id = ?", id])
      dc.destroy
    end

    #destroying rules
    for dr in Devicerule.find(:all, :conditions => ["device_id = ?", id])
      dr.destroy
    end

    user = user
    self.destroy_everything
  end

  def Device.validate_before_create(current_user, user, params, allow_dahdi, allow_virtual)
    notice = ''

    unless user
      notice =_('User_was_not_found')
    end

    if current_user.usertype == 'accountant' and notice.blank?
      s ={}
      group = current_user.acc_group
      if group
        rights = AccRight.find(
            :all,
            :select => "acc_rights.name, acc_group_rights.value",
            :joins => "LEFT JOIN acc_group_rights ON (acc_group_rights.acc_right_id = acc_rights.id AND acc_group_rights.acc_group_id = #{group.id})",
            :conditions => ["acc_rights.right_type = ?", group.group_type]
        )
        short = {"accountant" => "acc", "reseller" => "res"}
        rights.each { |right|
          name = "#{short[current_user.usertype]}_#{right[:name].downcase}".to_sym
          if right[:value].nil?
            s[name] = 0
          else
            s[name] = ((right[:value].to_i >= 2 and group.only_view) ? 1 : right[:value].to_i)
          end
        }

        params = current_user.sanitize_device_params_by_accountant_permissions(s, params, self.dup)
      else
        s[:acc_device_create] = 0
      end
      if  notice.blank? and s[:acc_device_create] != 2
        notice = _('Dont_be_so_smart')
      end
    end

    params[:device][:description]=params[:device][:description].strip if params[:device][:description]

    params[:device][:pin]=params[:device][:pin].strip if params[:device][:pin]

    #    if current_user.usertype == 'reseller' and Confline.get_value('Allow_resellers_change_device_PIN').to_i == 0
    #      params[:device][:pin] = nil
    #    end

    if  notice.blank? and params[:device][:extension] and Device.find(:first, :conditions => ["extension = ?", params[:device][:extension]])
      notice = _('Extension_is_used')

    else
      #pin
      if  notice.blank? and (Device.find(:first, :conditions => [" pin = ?", params[:device][:pin]]) and params[:device][:pin].to_s != "")
        notice = _('Pin_is_already_used')

      end
      if  notice.blank? and !params[:device][:pin].to_s.blank? and params[:device][:pin].to_s.strip.scan(/[^0-9 ]/).compact.size > 0
        notice = _('Pin_must_be_numeric')
      end
    end


    if notice.blank? and params[:device][:devicegroup_id] and !Devicegroup.find(:first, :conditions => {:id => params[:device][:devicegroup_id], :user_id => user.id})
      notice = _('Device_group_invalid')
    end

    type_array = ['SIP', 'IAX2', 'FAX', 'H323', '']
    type_array << "dahdi" if allow_dahdi
    type_array << "Virtual" if allow_virtual
    if notice.blank? and !type_array.include?(params[:device][:device_type].to_s)
      notice = _('Device_type_invalid')
    end
    return notice, params
  end

=begin
  only SIP and IAX devices can have name. but only first two can be authenticated by ip.
  users can not see SIP/IAX2 device's username if ip
  authentication is set. and we determine whether ip auth is set by checking if username is empty.

  *Returns*
    *boolean* true or false depending whether we should show username or not
=end
  def show_username?
    (not username.blank? and (device_type == "SIP" or device_type == "IAX2"))
  end


  def dids_numbers
    numbers = []
    self.dids.each { |d| numbers << d.did } if self.dids and self.dids.size.to_i > 0
    numbers
  end

  def cid_number
    numbers = []
    self.callerids.each { |d| numbers << [d.cli, d.id] } if self.callerids and self.callerids.size.to_i > 0
    numbers
  end

  def device_caller_id_number
    device_caller_id_number = 1
    device_caller_id_number = 3 if cid_from_dids.to_i == 1
    device_caller_id_number = 4 if control_callerid_by_cids.to_i != 0
    device_caller_id_number = 5 if callerid_advanced_control.to_i == 1
    device_caller_id_number
  end

=begin
  check whether device belongs to server

  *Returns*
  boolean - true if device belongs to server, else false
=end
  def server_device?
    self.name =~ /mor_server_\d+/ ? true : false
  end

  DefaultPort={'SIP' => 5060, 'IAX2' => 4569, 'H323' => 1720}

=begin
  Check whether port is valid for supplied technology, at this moment only ilegal
  ports are those that are less than 1.

  *Returns*
  +valid+ true if port is valid, else false
=end
  def self.valid_port?(port, technology)
    if port.to_i < 1
      return false
    elsif technology == 'SIP'
      return true
    elsif technology == 'IAX'
      return true
    else
      return true
    end
  end

  def device_old_name
    @device_old_name_record
  end

  def device_old_server
    @device_old_server_record
  end

  def set_old_name
    self.device_old_name_record = name
    self.device_old_server_record = server_id
  end

=begin
  Check whether device belongs to provider. This would mean that
  device cannot have user associated with it.
  UPDATE: Seems like that's not true, if provider is assigned to user,
  then provider device's user_id is set to that user. Support said that
  they just check device.name

  *Returns*
  +boolean+ true if device belongs to provider, othervise false
=end
  def belongs_to_provider?
    self.user_id == -1 or self.name =~ /^prov/
  end

=begin
  Set time limit per day option for the device. In database it is saved in seconds but this
  method is expecting minutes tu be passed to it. If negative or none numeric params would be
  passed it will be converted to 0. if float would be passed as param, decimal part would be
  striped.

  *Params*
  +minutes+ integer, time interval in minutes.
=end
  def time_limit_per_day=(minutes)
    minutes = (minutes.to_i < 0) ? 0 : minutes.to_i
    seconds = minutes * 60
    write_attribute(:time_limit_per_day, seconds)
  end

=begin
  Get time limit per day expressed in minutes. In database it is saves in seconds, sho we just
  convert to minutes by deviding by 60. Obviuosly this is OOD mistake, we should use so sort of
  'time interval' instance..

  *Returns*
  +minutes+ integer, time interval in minutes
=end
  def time_limit_per_day
    (read_attribute(:time_limit_per_day) / 60).to_i
  end

=begin
  Callerid control by cids is concidered enabled if callerid is not 0, cause this value should
  be id of device's clid
=end
  def control_callerid_by_cids?
    self.control_callerid_by_cids.to_i != 0
  end

=begin
  Check whether fax device supports T.38. Keep in mind that calling this method is valid only if
  it is fax device, else exception should be rised.
=end
  def t38support?
    #if self.device_type == 'FAX'
    self.t38pt_udptl.to_i == 1
    #else
    #  raise 'Only fax devices support T.38 protocol'
    #end
  end

  def is_dahdi?
    return self.device_type == 'dahdi'
  end

  def create_server_devices(servers)

    if servers
      ss = []
      servers.each { |s|
        sd = ServerDevice.where("server_id = #{s[0].to_i} AND device_id = #{id}").first
        if not sd
          server_device = ServerDevice.new({:server_id => s[0].to_i, :device_id => id})
          server_device.save
        end
        ss << s[0].to_i
      }
      ActiveRecord::Base.connection.execute("DELETE FROM server_devices WHERE device_id = '#{id}' AND server_id NOT IN (#{ss.join(',')})")
    end
  end

  def ast18
  # tweaks for Asterisk 1.8
    if defined?(AST_18) and AST_18.to_i == 1
      self.auth = "md5" if self.device_type.upcase == "IAX2"
    end
  end

  # this method just cleans server from device
  # used in device_update action
  # only when device name or server_id changes
  def sip_prune_realtime_peer(device_name, device_server_id)

    return if self.device_type != "SIP"

    server = Server.find(device_server_id.to_s)
    if server and server.active == 1
      rami_server = Rami::Server.new({'host' => server.server_ip, 'username' => server.ami_username, 'secret' => server.ami_secret})
      rami_server.console = 1
      rami_server.event_cache = 100
      rami_server.run
      client = Rami::Client.new(rami_server)
      client.timeout = 3

      t = client.command("sip prune realtime peer " + device_name.to_s)

      client.respond_to?(:stop) ? client.stop : false
    end
  end

  private

=begin
  Note INSERT IGNORE INTO, thats because voicemail boxes should have unique constraint set, so if
  one tries to insert duplicate record, no exception would be risen and INSERT stetement would be ignored
=end
  def create_vm(mailbox, pass, fullname, email)
    vm = (self.voicemail_box.blank? ? VoicemailBox.new : self.voicemail_box)
    vm.device_id = self.id
    vm.mailbox = mailbox
    vm.password = pass
    vm.callback = ""
    vm.dialout = ""
    vm.pager = ""
    fullname = fullname.gsub("'", "")
    vm.context = "default"
    if email
      vm.email = email
    else
      vm.email = Confline.get_value("Company_Email")
    end
    #vm.save

    if self.voicemail_box.blank?
      sql = "INSERT IGNORE INTO voicemail_boxes (device_id, mailbox, password, fullname, context, email, pager, dialout, callback) VALUES ('#{self.id}', '#{mailbox}', '#{pass}', '#{fullname}', 'default', '#{vm.email}', '', '', '');"
      res = ActiveRecord::Base.connection.insert(sql)
    end

    vm = VoicemailBox.find(:first, :conditions => "device_id = '#{self.id}' AND fullname = '#{fullname}' AND email = '#{vm.email}'")

    vm
  end

# not used anywhere
=begin
  def prune_device
    if device_old_name_record != name and ['SIP', 'IAX2'].include?(device_type.to_s)
      MorLog.my_debug("Device_name_changed ID:#{id}, old_name:#{device_olde_name_record}, new_name:#{name}", 1)
      if self.provider
        MorLog.my_debug("Provider_name_changed ID:#{id} prune:#{device_olde_name_record}, no reload", 1)
        #clean the mess from all servers and do not reload (0)
        self.prune_device_in_all_servers(device_olde_name_record, 0)
        #clean the mess from all servers and reload (1)
        MorLog.my_debug("Provider_name_changed ID:#{id} prune:#{name}, reload", 1)
        self.prune_device_in_all_servers(name, 1)
      else
        if device_old_server_record != server_id
          MorLog.my_debug("Device_name_changed ID:#{id} prune:#{device_olde_name_record}, no reload old server :#{device_old_server_record}", 1)
          #clean the mess from old server and do not reload (0)
          self.prune_device_in_server(device_olde_name_record, 0, device_old_server_record)
        end
        MorLog.my_debug("Device_name_changed ID:#{id} prune:#{device_olde_name_record}, no reload", 1)
        #clean the mess from server and do not reload (0)
        self.prune_device_in_server(device_olde_name_record, 0)
        #clean the mess from server and reload (1)
        MorLog.my_debug("Device_name_changed ID:#{id} prune:#{name}, reload", 1)
        self.prune_device_in_server(name, 1)
      end
      self.device_olde_name_record = name
    end
  end
=end

=begin
  #ticket #5133
=end
  def cid_number=(value)
    @cid_number = value
  end

  def Device.integrity_recheck_devices
    ccl_active = Confline.get_value("CCL_Active").to_i
    Device.count(:all, :conditions =>  "host='dynamic' and insecure like '%invite%'  and insecure != 'invite'").to_i > 0 and ccl_active == 0 ? 1 : 0
  end

  def t38pt_normalize
    if ["fec", "redundancy","none"].include? self.t38pt_udptl
        self.t38pt_udptl = "yes, " << self.t38pt_udptl
    end
  end

  def check_subnet
    # ip has subnet set?
    if seek = ipaddr =~ /\//
      # checking if subnet is within allowed range
      unless (24..32).member?(ipaddr[seek.to_i+1,ipaddr.length].to_i)
        errors.add(:ipaddr, _('ip_prefix_size_should_be_between_24_and_32'))
        return false
      end
    end
  end

  def nice_device(device)
    dev = ''
    dev = device.device_type.to_s
    dev <<  "/" + device.name.to_s if device.name and !dev.include?(device.name.to_s)
    dev
  end

  def nice_provider(provider)
    prov = ''
    prov = provider.tech.to_s
    prov <<  "/" + provider.name.to_s if provider.name and !prov.include?(provider.name.to_s)
    prov
  end

  def nice_device_user(device)
    if device.user_id == -1
      device_prov = Provider.where(:device_id => device.id).first
      dev_user = device_prov ? "Provider: #{nice_provider(device_prov)}" : "Provider"
    else
      device_user = User.where(:id => device.user_id).first
      dev_user = "User: #{device_user.username.to_s}"
      dev_user = "User: #{device_user.first_name.to_s} #{device_user.last_name.to_s}" if device_user.first_name.to_s.length + device_user.last_name.to_s.length > 0
    end

    dev_user
  end
end
