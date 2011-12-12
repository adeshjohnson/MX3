class Device < ActiveRecord::Base
  attr_accessor :device_ip_authentication_record

  belongs_to :user
  has_many :extlines, :order => "exten ASC, priority ASC"
  has_many :dids
  belongs_to :devicegroup
  has_many :callerids
  belongs_to :location
  # belongs_to :voicemail_box
  has_many :callflows
  has_many :pdffaxemails
  has_one :provider
  has_many :activecalls, :foreign_key => "src_device_id"
  has_many :ringgroups_devices


  before_validation_on_create :check_device_username

  validates_presence_of :name, :message => _('Device_must_have_name')
  validates_presence_of :extension, :message => _('Device_must_have_extension')
  validates_uniqueness_of :extension, :message => _('Device_extension_must_be_unique')
  validates_uniqueness_of :username, :message => _('Device_Username_Must_Be_Unique'), :if => :username_must_be_unique
  # validates_format_of :name, :with => /^\w+$/,  :on=>:create, :message => _('Device_username_must_consist_only_of_digits_and_letters')
  validates_format_of :max_timeout, :with => /^[0-9]+$/,   :message => _('Device_Call_Timeout_must_be_greater_than_or_equal_to_0')
  validates_numericality_of :port, :message => _("Port_must_be_number"), :if => Proc.new{|o| not o.port.blank? }

  # before_create :check_callshop_user
  before_save :ensure_server_id, :random_password, :check_and_set_defaults, :check_password, :ip_must_be_unique_on_save, :check_language, :check_location_id, :check_dymanic_and_ip
  after_create :create_codecs, :device_after_create
  after_save :device_after_save

  def check_password
    unless self.secret.blank? or self.provider or ["zap", "virtual", "h323"].include?(self.device_type.downcase)
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
        owner = User.find_by_id(self.user.owner_id)
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

  def ensure_server_id
    if self.server_id.blank? or !Server.find(:first, :conditions => ["server_id = ?", self.server_id])
      default = Confline.get_value("Default_device_server_id")
      if !default.blank?
        self.server_id = default
      else
        if server = Server.find(:first, :order => "server_id ASC")
          Confline.set_value("Default_device_server_id", server.server_id)
          self.server_id = server.server_id
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
      username = self.username ; name = self.username
      while Device.find(:first, :conditions=>{:username=>username})
        username = self.generate_rand_name(name, 2)
      end
      self.username = username
    end
  end

  def generate_rand_name(string, size)
    chars = '123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    str = ''
    size.times { |i| str << chars[rand(chars.length)] }
    string + str
  end

  def device_after_save
    write_attribute(:accountcode, id)
  end

  def device_after_create
    #device_after_save
    if self.user
      user = self.user

      Action.add_action_hash(User.current.id, {:target_id => id, :target_type => "device", :action => "device_created"})
      #------- VM ----------
      email = Confline.get_value("Default_device_voicemail_box_email", user.owner_id)
      email = user.address.email if user.address and user.address.email.to_s.size > 0
      self.create_vm(extension, Confline.get_value("Default_device_voicemail_box_password", user.owner_id), user.first_name + " " + user.last_name, email)
      dev = Device.count(:all, :conditions=>"user_id = #{user.id}")
      if dev.to_i == 1
        user.primary_device_id = id
        user.save
      end
      self.update_cid(Confline.get_value("Default_device_cid_name", user.owner_id), Confline.get_value("Default_device_cid_number", user.owner_id))
    end
  end


  #================== CODECS =========================


  def create_codecs
    owner = self.user_id > 0 ? self.user.owner_id : 0
    for codec in Codec.find(:all)
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
    sql =  "SELECT COUNT(*) as 'count' FROM devicecodecs, codecs WHERE devicecodecs.device_id = '" + self.id.to_s + "' AND devicecodecs.codec_id = codecs.id AND codecs.name = '" + codec.to_s + "'"
    res = ActiveRecord::Base.connection.select_one(sql)
    res['count'] == '1'
  end

  def codecs
    sql =  "SELECT * FROM codecs, devicecodecs WHERE devicecodecs.device_id = '" + self.id.to_s + "' AND devicecodecs.codec_id = codecs.id ORDER BY devicecodecs.priority"
    res = ActiveRecord::Base.connection.select_all(sql)
    codecs = []
    for i in 0..res.size-1
      codecs << Codec.find(res[i]["codec_id"])
    end
    codecs
  end

  def codecs_order(type)
    cond = self.device_type.to_s == 'FAX' ? ' AND codecs.name IN ("alaw", "ulaw") ' : ''
    Codec.find_by_sql("SELECT codecs.*,  IF(devicecodecs.priority is null, 100, devicecodecs.priority)  as bb FROM codecs  LEFT Join devicecodecs on (devicecodecs.codec_id = codecs.id and devicecodecs.device_id = #{self.id.to_i})  where codec_type = '#{type}' #{cond} ORDER BY bb asc, codecs.id")
  end


  def update_codecs_with_priority(codecs)
    dc = {}
    Devicecodec.find(:all, :conditions => ["device_id = ?",self.id]).each{|c| dc[c.codec_id] = c.priority; c.destroy}
    Codec.find(:all).each {|codec| Devicecodec.new(:codec_id => codec.id, :device_id=>self.id, :priority=>dc[codec.id].to_i ).save if codecs[codec.name] == "1"}
    self.update_codecs
  end


  def update_codecs
    cl = []
    self.codecs.each{|codec| cl << codec.name}
    cl << "all" if cl.size.to_i == 0
    self.allow = cl.join(';')
    self.save
  end

  #================== END OF CODECS =========================

  def update_cid(cid_name, cid_number)

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

    self.callerid = nil

    if cid_name.length > 0 and cid_number.length > 0
      self.callerid = "\"" + cid_name.to_s + "\"" + " <" + cid_number.to_s + ">"
    end

    if cid_name.length > 0 and cid_number.length == 0
      self.callerid = "\"" + cid_name.to_s + "\""
    end

    if cid_name.length == 0 and cid_number.length > 0
      self.callerid = "<" + cid_number.to_s + ">"
    end

    self.save

  end

  #======================= CALLS =============================

  def all_calls
    Call.find(:all, :conditions => "accountcode = '#{self.id}'")
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
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND src_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "noanswer"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND src_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed_not_processed"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND processed = '0' AND src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    #---incoming---

    if type == "all_inc"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND dst_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_inc"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND billsec > 0 AND dst_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "noanswer_inc"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed_inc"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND dst_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy_inc"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed_inc"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "missed_not_processed_inc"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND processed = '0' AND dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    #--not used---

    if type == "incoming"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND user_price >= 0 AND dst_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "outgoing"
      @calls = Call.find(:all, :conditions => ["calls.card_id = 0 AND user_price >= 0 AND src_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    @calls
  end

  def total_calls(type, date_from, date_till)

    if type == "all"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  (src_device_id = ? OR dst_device_id =?) AND user_id IS NOT NULL " + date_query(date_from, date_till), self.id, self.id], :order => " calldate DESC")
    end

    if type == "answered"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_out"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "no_answer_out"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy_out"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed_out"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  src_device_id = ?  AND user_id IS NOT NULL AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_inc"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  dst_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "no_answer_inc"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "busy_inc"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "failed_inc"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  dst_device_id = ? AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    if type == "missed_not_processed"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  processed = '0' AND dst_device_id =? AND #{Call.nice_answered_cond_sql(false)}" + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "incoming"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  dst_device_id =? " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "outgoing"
      t_calls = Call.count(:all, :conditions => ["calls.card_id = 0 AND  src_device_id =? AND user_id IS NOT NULL " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    t_calls
  end


  def total_duration(type, date_from, date_till)

    if type == "answered"
      t_duration = Call.sum(:duration, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_out"
      t_duration = Call.sum(:duration, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end

    if type == "answered_inc"
      t_duration = Call.sum(:duration, :conditions => ["calls.card_id = 0 AND billsec > 0 AND dst_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
    end


    t_duration = 0 if t_duration == nil
    t_duration
  end


  def total_billsec(type, date_from, date_till)

    if type == "answered"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec2 FROM calls WHERE (calls.card_id = 0 AND billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == "answered_out"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (calls.card_id = 0 AND billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == "answered_inc"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND dst_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (calls.card_id = 0 AND billsec > 0 AND dst_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
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

      Extline.destroy_all ["device_id = ?", self.id]

      err = self.prune_device_in_all_servers

      self.destroy_vm
      self.destroy
    end
    err
  end


  def prune_device_in_all_servers
    err= []
    # clean Realtime mess
    servers = Server.find(:all)
    for server in servers
      begin
        server.prune_peer(self.username)
      rescue Exception => e
        err << e.message
      end
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



  def create_vm(mailbox, pass, fullname, email)
    vm = VoicemailBox.new
    vm.device_id = self.id
    vm.mailbox = mailbox
    vm.password = pass
    fullname = fullname.gsub("'", "")
    vm.context = "default"
    if email
      vm.email = email
    else
      vm.email = Confline.get_value("Company_Email")
    end
    #vm.save

    sql = "INSERT INTO voicemail_boxes (device_id, mailbox, password, fullname, context, email, pager, dialout, callback) VALUES ('#{self.id}', '#{mailbox}', '#{pass}', '#{fullname}', 'default', '#{vm.email}', '', '', '');"
    res = ActiveRecord::Base.connection.insert(sql)

    vm = VoicemailBox.find(:first, :conditions => "device_id = '#{self.id}' AND fullname = '#{fullname}' AND email = '#{vm.email}'")

    vm
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
    flow = Callflow.find(:all, :conditions=>["data = ? and data2 = 'fax' and action = 'fax_detect'", self.id])
    return flow if flow.size > 0
    return nil
  end
  # Check if device has calls forwarded to it
  def has_forwarded_calls
    flow = Callflow.find(:all, :conditions=>["data = ? and data2 = 'local' and action = 'forward'", self.id])
    return flow if flow.size > 0
    return nil
  end

  def dialplans
    Dialplan.find(:all, :conditions=>["data3 = ?", self.id])
  end

  def username_must_be_unique_on_creation
    self.device_ip_authentication_record.to_i == 0 and !self.provider
  end

  def ip_must_be_unique_on_save

    message = (User.current and User.current.usertype == 'admin') ? _("When_IP_Authentication_checked_IP_must_be_unique") : _('This_IP_is_not_available') + "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Authentication' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>"
    cond = if ipaddr.blank?
      ['devices.id != ? AND host = ? AND providers.user_id != ? and ipaddr != "" and ipaddr != "0.0.0.0"', id, host, User.current.id]
    else
      ['devices.id != ? AND (host = ? OR ipaddr = ?) AND providers.user_id != ? and ipaddr != "" and ipaddr != "0.0.0.0"', id, host, ipaddr, User.current.id]
    end

    if self.device_ip_authentication_record.to_i == 1 and self.provider and Device.count(:all, :joins=>['JOIN providers ON (device_id = devices.id)'],:conditions=>cond).to_i > 0
      errors.add(:ip_authentication, message)
      return false
    end

    condd = self.device_ip_authentication_record.to_i == 1 ? '' : ' and devices.username = "" '
    cond22 = if ipaddr.blank?
      ['devices.id != ? AND host = ? and users.owner_id != ?  and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0"' + condd , id, host, User.current.id]
    else
      ['devices.id != ? AND (host = ? OR ipaddr = ?) and users.owner_id != ? and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0"' + condd , id, host, ipaddr, User.current.id]
    end
    if Device.count(:all, :joins=>['JOIN users ON (user_id = users.id)'],:conditions=>cond22).to_i > 0
      errors.add(:ip_authentication, message)
      return false
    end

    if Provider.count(:all, :joins=>['JOIN devices ON (device_id = devices.id)'],:conditions=>["server_ip = ? and devices.username = '' and server_ip != '0.0.0.0' and devices.id != ?  and ipaddr != '' AND providers.user_id != ? and ipaddr != '0.0.0.0'", ipaddr, id, User.current.id]).to_i > 0
      errors.add(:ip_authentication, message)
      return false
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
    ip_arr.each{|ip|
      if ip and !ip.blank?  and !Device.validate_ip(ip)
        err = false
      end
    }
    return err
  end

  def Device::validate_ip(ip)
    ip.gsub(/(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)/, "").to_s.length == 0 ? true : false
  end

  def Device.find_all_for_select(current_user_id = nil)
    if current_user_id
      return Device.find(:all, :select => "devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani", :joins => "LEFT JOIN users ON (users.id = devices.user_id)", :conditions => ["device_type != 'FAX' AND (users.owner_id = ? OR users.id = ?)", current_user_id, current_user_id])
    else
      return Device.find(:all, :select => "id, description, extension, device_type, istrunk, name, ani", :conditions => ["device_type != 'FAX'"])
    end
  end

  def device_ip_authentication?; @device_ip_authentication_record; end

  def load_device_types(options = {})
    Devicetype.find(:all).map{|type|
      (options.has_key?(type.name) and  options[type.name] == false and self.device_type != type.name) ? nil : type
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
      [_('Presentation_Allowed_Not_Screened'),'allowed_not_screened'], [_('Presentation_Allowed_Passed_Screen'),'allowed_passed_screen'],
      [_('Presentation_Allowed_Failed_Screen'),'allowed_failed_screen'],[_('Presentation_Allowed_Network_Number'),'allowed'],
      [_('Presentation_Prohibited_Not_Screened'),'prohib_not_screened'],[_('Presentation_Prohibited_Passed_Screen'),'prohib_passed_screen'],
      [_('Presentation_Prohibited_Failed_Screen'),'prohib_failed_screen'],[_('Presentation_Prohibited_Network_Number'),'prohib'],
      [_('Number_Unavailable'),'unavailable']
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
      notice = _('Cant_delete_device_has_forworded_calls')
    end

    if self.all_calls.size > 0 and notice.blank?
      notice = _('Cant_delete_device_has_calls')
    end

    if self.dialplans.size > 0 and notice.blank?
      notice = _('Cant_delete_device_has_diaplans')
    end
    notice
  end

  def destroy_all
    Extline.destroy_all ["device_id = ?", id]

    #deleting association with dids
    if dids = Did.find(:all, :conditions => ["device_id =?",id])
      for did in dids
        did.device_id = "0"
        did.save
      end
    end

    #destroying codecs
    for dc in Devicecodec.find(:all, :conditions => ["device_id = ?", id])
      dc.destroy
    end

    user = user
    self.destroy_everything
  end

  def Device.validate_before_create(current_user, user, params, allow_zap, allow_virtual)
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

        params =  current_user.sanitize_device_params_by_accountant_permissions(s, params, self.clone)
      else
        s[:acc_device_create] = 0
      end
      if  notice.blank? and  s[:acc_device_create] != 2
        notice = _('dont_be_so_smart')
      end
    end

    params[:device][:description]=params[:device][:description].strip if params[:device][:description]

    params[:device][:pin]=params[:device][:pin].strip if params[:device][:pin]

    #    if current_user.usertype == 'reseller' and Confline.get_value('Allow_resellers_change_device_PIN').to_i == 0
    #      params[:device][:pin] = nil
    #    end

    if  notice.blank? and params[:device][:extension] and Device.find(:first, :conditions => ["extension = ?", params[:device][:extension] ])
      notice = _('Extension_is_used')

    else
      #pin
      if  notice.blank? and (Device.find(:first, :conditions => [" pin = ?",  params[:device][:pin]]) and params[:device][:pin].to_s != "")
        notice = _('Pin_is_already_used')

      end
      if  notice.blank? and !params[:device][:pin].to_s.blank? and params[:device][:pin].to_s.strip.scan(/[^0-9 ]/).compact.size > 0
        notice = _('Pin_must_be_numeric')
      end
    end


    if notice.blank? and params[:device][:devicegroup_id] and !Devicegroup.find(:first, :conditions=>{:id=>params[:device][:devicegroup_id] , :user_id=>user.id})
      notice = _('Device_group_invalid')
    end

    type_array = ['SIP', 'IAX2', 'FAX','H323', 'Skype', '']
    type_array << "ZAP" if allow_zap
    type_array << "Virtual" if allow_virtual
    if notice.blank? and !type_array.include?(params[:device][:device_type].to_s)
      notice = _('Device_type_invalid')
    end
    return notice, params
  end
end
