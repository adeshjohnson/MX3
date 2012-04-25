# -*- encoding : utf-8 -*-
class User < ActiveRecord::Base
  include SqlExport
  include UniversalHelpers
  require "digest/sha2"
  require 'uri'
  require 'net/http'

  cattr_accessor :current
  cattr_accessor :current_user

  cattr_accessor :system_time_offset

  has_many :devices, :conditions => "devices.accountcode != 0 and devices.name not like 'mor_server_%'", :include => [:user, :provider]
  has_many :actions
  belongs_to :lcr
  belongs_to :tariff
  belongs_to :sms_lcr
  has_many :lcrs
  belongs_to :sms_tariff
  has_many :phonebooks
  belongs_to :address
  has_many :devicegroups, :order => :added
  has_many :subscriptions, :order => :added
  has_many :payments, :conditions => "card = 0", :order => "date_added DESC"
  has_many :campaigns, :order => "name"
  has_many :invoices, :order => "period_start ASC"
  has_many :customrates
  has_many :vouchers
  #has_many :emails
  has_many :dids
  has_many :usergroups, :dependent => :destroy
  belongs_to :tax, :dependent => :destroy
  belongs_to :acc_group
  has_many :groups
  has_many :usergroups
  has_many :cs_invoices, :conditions => ["state = 'unpaid'"]
  has_many :all_cs_invoices, :class_name => 'CsInvoice'
  #has_and_belongs_to_many :callshops, :join_table => "usergroups", :association_foreign_key => "group_id"
  has_many :callshops, :through => :usergroups, :foreign_key => "group_id", :source => :group

  has_many :providers, :dependent => :destroy
  has_many :terminators, :dependent => :destroy
  has_many :user_translations, :dependent => :destroy, :order => "user_translations.position ASC"
  has_many :dialplans, :dependent => :destroy
  has_many :pbxfunctions, :dependent => :destroy
  belongs_to :currency
  belongs_to :quickforwards_rule
  has_many :quickforwards_rules, :order => "name ASC"
  has_many :locations, :order => "name ASC"
  # warning balance sound
  has_one :ivr_sound_file, :foreign_key => "warning_balance_sound_file_id"
  has_and_belongs_to_many :monitorings
  has_many :ivrs
  has_many :owned_monitorings, :class_name => 'Monitoring', :foreign_key => 'owner_id'
  has_many :ivr_timeperiods
  has_many :ivr_voices
  has_many :ivr_sound_files
  has_many :cron_settings
  has_many :ringgroups, :include => [:dialplan, :did]
  has_many :common_use_providers
  has_many :cards
  has_many :sms_provider_tariffs, :class_name => 'SmsTariff', :foreign_key => 'owner_id', :conditions => "tariff_type = 'provider'", :order => 'name ASC'

  validates_uniqueness_of :username, :message => _('Username_has_already_been_taken')
  validates_presence_of :username, :message => _('Username_cannot_be_blank')
  #validates_presence_of :first_name, :last_name
  #
  before_save :user_before_save
  before_create :user_before_create
  before_destroy :user_before_destroy

  after_create :after_create_localization, :after_create_user
  after_save :after_create_localization, :check_address

  def after_create_localization
    logger.fatal('after_create checkin usertype and location.size')
    logger.fatal(usertype.to_yaml)
    #uses resellers id
    if usertype.to_s == 'reseller'
      logger.fatal "Ddddddddddddddddddddddddddddddddddddd"
      locations = Location.find(:first, :conditions => ['user_id=? and name=?', id, 'Default location'])
      if locations.blank?
        #create new default location  if reseller has no localization
        create_reseller_localization
      else
        #if reseller has localization but default location id = 1, it means he has no new default location. lets create it
        value = Confline.get_value("Default_device_location_id", id)
        if locations.id != value.to_i and (!value.blank? or value != 1)
          Confline.set_value("Default_device_location_id", locations.id, id) if value.to_i == 1
        elsif value.blank? or value.to_i == 1
          create_reseller_localization
        end
      end
      create_reseller_conflines
      create_reseller_emails
    end
  end


  def after_create_user
    devgroup = Devicegroup.new
    devgroup.init_primary(id, "primary", address_id)

    Action.add_action_hash(owner_id, {:target_id => id, :target_type => "user", :action => "user_created"})
  end

  def check_address
    unless address
      a = Address.create()
      self.address_id = a.id
      self.save
    end
  end


  def create_reseller_localization
    logger.fatal(' in create_reseller_localization')
    logger.fatal(id.to_yaml)
    #uses resellers id
    loc = Location.new({:name => 'Default location', :user_id => id})
    loc.user_id = id
    loc.save
    logger.fatal('Location created')
    #delete confline if exists device with location id = 1 and replace with new location id
    Confline.delete_all("owner_id = #{id} and name = 'Default_device_location_id'")
    Confline.new_confline("Default_device_location_id", loc.id, id)
    logger.fatal('confline')
    logger.fatal(Confline.get_value("Default_device_location_id", id))
    logger.fatal(id)
    all_default_rules = Locationrule.find(:all, :conditions => "location_id = 1")

    for default_rules in all_default_rules
      rule = Locationrule.new({:name => default_rules.name, :enabled => 1, :lr_type => default_rules.lr_type})
      rule.location_id = loc.id
      rule.cut = default_rules.cut if default_rules.cut
      rule.add = default_rules.add if default_rules.add
      rule.minlen = default_rules.minlen if !default_rules.minlen.blank?
      rule.maxlen = default_rules.maxlen if !default_rules.maxlen.blank?
      rule.save
      logger.fatal('rule created')
    end
    logger.fatal('going to update_resellers_device_location')
    #and update devices
    update_resellers_device_location(loc.id)
    logger.fatal "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr"
  end

  def update_resellers_device_location(locationid)

    logger.fatal('in update_resellers_device_location')
    logger.fatal(locationid.to_yaml)
    logger.fatal('reseller id')
    logger.fatal(id.to_yaml)

    #uses new default location id and resellers id
    Device.update_all "location_id = #{locationid.to_i}", "(user_id IN (SELECT id from users where owner_id = #{id}) OR id IN (SELECT device_id FROM providers WHERE user_id = #{id})) and location_id = 1"
    logger.fatal('updated all devices')
    update_resellers_cardgroup_location(locationid)
  end

  def update_resellers_cardgroup_location(locationid)
    logger.fatal('in update_resellers_cardgroup_location')
    logger.fatal(locationid.to_yaml)
    logger.fatal('reseller id')
    logger.fatal(id.to_yaml)

    #uses new default location id and resellers id
    Cardgroup.update_all "location_id = #{locationid}", "owner_id = #{id} and location_id = 1"
    logger.fatal('updated all cardgroups')
  end

  def user_before_save
    if address and address.email.to_s.length > 0 and !Email.address_validation(address.email)
      errors.add(:email, _("Please_enter_correct_email"))
      return false
    end

    if recordings_email.to_s.length > 0 and !Email.address_validation(recordings_email)
      errors.add(:email, _("Please_enter_correct_recordings_email"))
      return false
    end

    if usertype.to_s != 'reseller'
      own_providers = 0
    end

  end

  def user_before_create

    if password == Digest::SHA1.hexdigest('')
      errors.add(:password, _("Please_enter_password"))
      return false
    end

    if password == Digest::SHA1.hexdigest(username)
      errors.add(:password, _("Please_enter_password_not_equal_to_username"))
      return false
    end

  end

  def user_before_destroy
    monitorings.each do |mon|
      mon.destroy if mon.users.size == 1
    end
  end

  def default_translation
    if is_admin? or is_reseller?
      trans = user_translations.find(:first, :include => [:translation], :conditions => "user_translations.active = 1", :order => 'user_translations.position ASC')
      unless trans
        return owner.default_translation
      else
        return trans.translation
      end
    else
      return owner.default_translation
    end
  end

  def active_translations
    if is_admin? or is_reseller?
      trans = user_translations.find(:all, :include => [:translation], :conditions => "user_translations.active = 1", :order => 'user_translations.position ASC')
      unless trans and trans.size != 0
        return owner.active_translations
      else
        return trans.collect(&:translation)
      end
    else
      return owner.active_translations
    end
  end

  def all_translations
    if is_admin? or is_reseller?
      trans = user_translations.find(:all, :include => [:translation])
      unless trans and trans.size != 0
        return owner.active_translations.collect(&:translation)
      else
        return trans.collect(&:translation)
      end
    else
      return owner.active_translations.collect(&:translation)
    end
  end

  def load_user_translations
    ut = user_translations
    unless ut and ut.size != 0
      clone_owner_translations
      return user_translations(true)
    end
    ut
  end

  def clone_owner_translations
    UserTranslation.find(:all, :conditions => ["user_id = ?", owner_id]).each do |ut|
      UserTranslation.create(:user_id => id, :translation_id => ut.translation_id, :position => ut.position, :active => ut.active)
    end
  end

  def hide_destination_end
    attributes["hide_destination_end"] == -1 ? Confline.get_value("Hide_Destination_End", owner_id).to_i : attributes["hide_destination_end"]
  end

=begin
  Check whether user is admin type, only one user can be system admin,
  valid admin user has to got id = 0 and his usertype has to be set to 'admin'

  *Returns*
  +boolean+ - true if user is admin, otherwise false
=end
  def is_admin?
    usertype == "admin" and id == 0
  end

  def is_not_admin?
    usertype != "admin" and id != 0
  end

  def is_accountant?
    usertype == "accountant"
  end

  def is_not_accountant?
    usertype != "accountant"
  end

  def is_reseller?
    usertype == "reseller"
  end

  def is_not_reseller?
    !is_reseller?
  end

=begin
  Check whether user is of type 'user'

  *Returns*
  +boolean+ true if user is ordinary user, false otherwise
=end
  def is_user?
    usertype == 'user'
  end

  def fax_devices
    Device.find(:all, :conditions => "user_id = #{id} AND device_type = 'FAX' AND name not like 'mor_server_%'")
  end

  def reseller_users
    User.find(:all, :select => "*, #{SqlExport.nice_user_sql}", :conditions => "owner_id = #{id}", :order => "nice_user ASC")
  end

  def owner
    @attributes["owner"] ||= User.find(:first, :conditions => ["id = ?", owner_id])
  end

  def owner= (owner)
    @attributes["owner"] = owner
  end

  def all_calls
    Call.find(:all, :conditions => "user_id = '#{id}'")
  end

  def groups
    Group.find_by_sql ["SELECT groups.* FROM groups, usergroups WHERE groups.id = usergroups.group_id AND usergroups.user_id = ? ORDER BY groups.name ASC", id]
  end


  # retrieve calls for user
  #
  # available call types:
  #
  # all
  # answered
  # busy
  # no answer
  # failed
  # missed
  # missed_inc
  # missed_inc_all
  # missed_not_processed_inc
  #
  # directions: incoming/outgoing
  # *Params*
  #
  # *<tt>options[:limit]</tt> - number of values to be returned.
  # *<tt>options[:offset]</tt> - return starts from this possition.

  def calls(type, date_from, date_till, direction = "outgoing", order_by = "calldate", order = "DESC", device = nil, options = {})
    calls = []
    # ------ handle call type --------
    call_type_sql = " AND disposition = '#{type}' "
    if type == "all"
      call_type_sql = ""
    end
    # special case
    if type[0..5] == "missed"
      call_type_sql = " AND disposition != 'ANSWERED'"

      if type[7..19] == "not_processed"
        call_type_sql += " AND processed = 0 "
      end

    end

    # ---------- handle device ---------
    device_sql = ""
    if device
      if direction == "incoming"
        device_sql= " AND dst_device_id = #{device.id} "
      else
        device_sql = " AND src_device_id = #{device.id} "
      end
    end


    # ---------- handle Hangupcausecode ---------
    hgc_sql = ""
    if options[:hgc]
      hgc_sql= " AND calls.hangupcause = #{options[:hgc].code} "
    end


    # -------- handle resellers ---------
    reseller_sql = ""
    #if usertype == "reseller"
    #reseller_sql = " OR calls.reseller_id = #{id} "
    #end


    find = ['calls.*']
    find << "DATE_FORMAT(calldate, \"%Y-%m-%d %H:%i:%S\") as `formated_calldate`" if options[:format_calldate]
    from = []
    if options[:providers] == true
      find << "providers.name as 'provider_name'"
      from << "LEFT JOIN providers ON (providers.id = calls.provider_id)"
    end

    if options[:destinations] == true
      find << "destinations.subcode AS 'destination_subcode'"
      find << "destinations.name AS 'destination_name'"
      find << "directions.name AS 'direction_name'"

      from << "LEFT JOIN destinations ON (destinations.prefix = calls.prefix)"
      from << "LEFT JOIN directions ON (directions.code = destinations.direction_code)"
    end
    if options[:count] == true
      find = ["COUNT(*) AS 'total_count'"]
    end
    # -------- retrieve calls -----------
    sql = ""
    if direction == "incoming" #incoming calls
      sql = "SELECT #{ find.join(',') } FROM calls #{from.join(' ')} JOIN devices ON (devices.id = calls.dst_device_id) LEFT JOIN dids ON (calls.did_id = dids.id) WHERE (calls.card_id = 0 AND (((devices.user_id = #{id}) OR (dids.user_id = #{id})) #{reseller_sql} )#{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}')))  ORDER BY #{order_by} #{order} #{ 'LIMIT ' + options[:offset].to_s + ', ' + options[:limit].to_s if (options[:limit] and options[:offset])};"
    else # outgoing calls
      sql = "SELECT #{ find.join(',') } FROM calls #{from.join(' ')} WHERE (calls.card_id = 0 AND (calls.user_id = #{id} #{reseller_sql}) #{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'))) ORDER BY #{order_by} #{order} #{ 'LIMIT ' + options[:offset].to_s + ', ' + options[:limit].to_s if (options[:limit] and options[:offset]) };"
    end
    Call.find_by_sql(sql)
  end


=begin rdoc
 Similar to @user.calls. Instead it returns total number of calls and sum of basic calls params.
=end

  def calls_total_stats(type, date_from, date_till, direction = "outgoing", device = nil, usertype = "user", hgc =nil)
    calls = []

    # ------ handle call type --------
    call_type_sql = " AND disposition = '#{type}' "
    if type == "all"
      call_type_sql = ""
    end

    # special case
    if type[0..5] == "missed"
      call_type_sql = " AND disposition != 'ANSWERED'"

      if type[7..19] == "not_processed"
        call_type_sql += " AND processed = 0 "
      end
    end

    # ---------- handle device ---------
    device_sql = ""
    if device
      if direction == "incoming"
        device_sql= " AND dst_device_id = #{device.id} "
      else
        device_sql = " AND src_device_id = #{device.id} "
      end
    end

    # ---------- handle Hangupcausecode ---------
    hgc_sql = ""
    if hgc
      hgc_sql= " AND hangupcause = #{hgc.code} "
    end

    # -------- handle resellers ---------
    reseller_sql = ""
    #if usertype == "reseller"
    #reseller_sql = " OR calls.reseller_id = #{id} "
    #end

    # -------- retrieve calls -----------
    if direction == "incoming"
      #incoming calls
      sql = "SELECT
          COUNT(*) AS 'total_calls',
          SUM(IF(calls.disposition = 'ANSWERED', 1, 0)) AS 'total_answered_calls',
          SUM(IF(calls.disposition = 'ANSWERED',calls.duration, 0)) AS 'total_duration',
          SUM(IF(calls.billsec > 0,calls.billsec, CEIL(calls.real_billsec) )) AS 'total_billsec',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.user_price')}, 0)) AS 'total_user_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.provider_price')}, 0)) AS 'total_provider_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.reseller_price')}, 0)) AS 'total_reseller_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_price')}, 0)) AS 'total_did_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_prov_price')}, 0)) AS 'total_did_prov_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_inc_price')}, 0)) AS 'total_did_inc_price'
          FROM calls JOIN devices ON (devices.id = calls.dst_device_id) LEFT JOIN dids ON (calls.did_id = dids.id) WHERE (calls.card_id = 0 AND (devices.user_id = #{id} OR (dids.user_id = #{id}) )#{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}')));"
      #MorLog.my_debug(sql)
      calls = Call.find_by_sql(sql)
    else
      # outgoing calls
      calls = Call.find_by_sql("SELECT
          COUNT(*) AS 'total_calls',
          SUM(IF(calls.disposition = 'ANSWERED', 1, 0)) AS 'total_answered_calls',
          SUM(IF(calls.disposition = 'ANSWERED',calls.duration, 0)) AS 'total_duration',
          SUM(IF(calls.billsec > 0,calls.billsec, CEIL(calls.real_billsec) )) AS 'total_billsec',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.user_price')}, 0)) AS 'total_user_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.provider_price')}, 0)) AS 'total_provider_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.reseller_price')}, 0)) AS 'total_reseller_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_price')}, 0)) AS 'total_did_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_prov_price')}, 0)) AS 'total_did_prov_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_inc_price')}, 0)) AS 'total_did_inc_price'
          FROM calls WHERE (calls.card_id = 0 AND (calls.user_id = #{id} #{reseller_sql}) #{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}')));")
    end
    calls[0]
  end


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

  def total_calls(type, date_from, date_till)
    t_calls = 0
    for dev in devices
      t_calls += dev.total_calls(type, date_from, date_till)
    end
    t_calls
  end

  def total_duration(type, date_from, date_till)
    t_duration = 0
    for dev in devices
      t_duration += dev.total_duration(type, date_from, date_till)
    end
    t_duration
  end


  def total_billsec(type, date_from, date_till)
    t_billsec = 0
    for dev in devices
      t_billsec += dev.total_billsec(type, date_from, date_till)
    end
    t_billsec
  end

  def manager_in_groups
    groups = []
    #my_debug "groups.size: "+groups.size.to_s
    for group in groups
      groups << group if group.gusertype(self) == "manager"
      #my_debug "group.gusertype(self): "+group.gusertype(self).to_s
    end
    groups
  end


  def last_login
    Action.find(:first, :conditions => ["user_id = ? AND action = 'login'", id], :order => "date DESC")
  end


  def normative_perc(date)
    date_s = date.strftime("%Y-%m-%d")

    sql =
        'SELECT users.id, users.calltime_normative as \'normative\', COUNT(distinct calls.id) as \'calls\', SUM(calls.duration) as \'duration\'' +
            'FROM users join devices on (users.id = devices.user_id AND users.id = '+ id.to_s + ') left join calls on ((calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' +
            'AND calls.calldate BETWEEN \'' + date_s + ' 00:00:00\' AND \'' + date_s + ' 23:59:59\') AND disposition = \'ANSWERED\''+
            'GROUP BY users.id, users.calltime_normative'

    res = ActiveRecord::Base.connection.select_all(sql)

    tn = 0

    if res[0]
      tn = (res[0]["duration"].to_f * 100 / (res[0]["normative"].to_f * 3600)) if res[0]["normative"].to_f > 0
    end

    tn.round.to_s
  end


  def new_calls(date)
    #    date_s = date #.strftime("%Y-%m-%d")
    #
    #    sql =
    #      'SELECT A.* FROM (SELECT calls.* FROM calls, devices WHERE calls.calldate BETWEEN \'' + date_s + ' 00:00:00\' AND \''+ date_s +' 23:59:59\' ' +
    #      'AND calls.src_device_id = devices.id AND devices.user_id  = \'' + id.to_s + '\' AND calls.disposition = \'ANSWERED\') as A ' +
    #      'left join calls on (calls.dst = A.dst AND calls.calldate < \'' + date_s + ' 00:00:00\')' +
    #      'GROUP BY A.dst HAVING COUNT(distinct calls.id) = 0 ORDER BY A.calldate DESC'
    #
    #    res = ActiveRecord::Base.connection.select_all(sql)
    #
    #    res
    Call.last_calls_csv({:user => self, :from => date.to_s + ' 00:00:00', :till => date.to_s + ' 23:59:59', :call_type => 'answered', :current_user => self, :pdf => 1, :order => 'calldate'})
  end

  def months_normative(month)
    date_s = month.to_s #.strftime("%Y-%m-%d") #format '2006-09'

    sql =

        'SELECT SUM(calls.duration) * 100 / (B.total_days * users.calltime_normative * 3600) AS \'percent\' '+

            'FROM calls join devices ON ((calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) AND devices.user_id = \'' + id.to_s + '\') join users ON (users.id = devices.user_id) join ' +

            ' (SELECT COUNT(A.days) AS \'total_days\' ' +
            '       FROM (SELECT SUBSTRING(calls.calldate,1,10) AS \'days\' ' +
            '           FROM calls join devices ON ((calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) AND devices.user_id = \'' + id.to_s + '\') ' +
            '           WHERE calls.calldate BETWEEN \'' + date_s + '-01 00:00:00\' AND \'' + date_s + '-31 23:59:59\' AND calls.disposition = \'ANSWERED\' ' +
            '           GROUP BY SUBSTRING(calls.calldate,1,10)) 	AS A ) 	AS B ' +

            'WHERE calls.calldate BETWEEN \'' + date_s + '-01 00:00:00\' AND \'' + date_s + '-31 23:59:59\' AND calls.disposition = \'ANSWERED\' ' +

            ' GROUP BY B.total_days, users.calltime_normative '

    #my_debug(sql)

    res = ActiveRecord::Base.connection.select_all(sql)

    if res[0]
      mn = res[0]["percent"].to_i
    else
      mn = 0
    end

    #saving to temporary table
    month_plan_perc = mn
    month_plan_updated = Time.now
    save

    mn.to_i.to_s
  end


  def this_months_normative

    month_plan_perc

  end


  def primary_device_group
    Devicegroup.find(:first, :conditions => "user_id = #{id}", :order => "added ASC")
  end


  def destroy_everything

    if payments.size == 0 and all_calls.size == 0 and dids.size == 0 and invoices.size == 0 and vouchers.size == 0 and reseller_users.size == 0
      #flash[:notice] = 'Cant_delete_user_it_has_payments'
      #redirect_to :controller => "users", :action => 'list'

      conflines = Confline.find(:all, :conditions => ["owner_id = '#{id}'"])
      for conf in conflines
        conf.destroy
      end


      for dev in devices
        if dev.provider
          dev.user_id = -1
          dev.save
        else
          dev.destroy_everything
        end
      end

      for devgr in devicegroups
        devgr.destroy_everything
      end

      address.destroy if address
      destroy

    end
  end

  def email
    addr = address
    addr ? addr.email.to_s : ""
  end

  def forwards_before_call
    Callflow.find_by_sql("SELECT callflows.* FROM callflows JOIN devices ON (devices.user_id = #{id} AND callflows.device_id = devices.id) WHERE action = 'forward' AND cf_type = 'before_call' AND data2 = 'local';")
  end

=begin
 create conflines to user, if conflines exist they will be set to admin values
=end

  def create_reseller_conflines
    resellers_device_location = Confline.get_value("Default_device_location_id", id)
    if usertype == "reseller" and !Confline.get_value("Default_device_type", id).to_s.blank?
      #sql = "DELETE FROM conflines WHERE owner_id = #{id}"
      #ActiveRecord::Base.connection.execute(sql)
      Confline.delete_all("owner_id = #{id} AND name like 'Default_device%'")
      Confline.new_confline('Company', Confline.get_value('Company'), id)
      Confline.new_confline('Company_Email', Confline.get_value('Company_Email'), id)
      Confline.new_confline('Version', Confline.get_value('Version'), id)
      Confline.new_confline('Copyright_Title', Confline.get_value('Copyright_Title'), id)
      Confline.new_confline('Admin_Browser_Title', Confline.get_value('Admin_Browser_Title'), id)
      Confline.new_confline('Logo_Picture', Confline.get_value('Logo_Picture'), id)
      Confline.new_confline('Show_Rates_Without_Tax', "0", id)
      #payments
      Confline.new_confline('Paypal_Default_Currency', Confline.get_value('Paypal_Default_Currenc'), id)
      Confline.new_confline('WebMoney_Default_Currency', Confline.get_value('WebMoney_Default_Currency'), id)
      Confline.new_confline('WebMoney_SIM_MODE', Confline.get_value('WebMoney_SIM_MODE'), id)
      Confline.new_confline('Paypal_Enabled', Confline.get_value('Paypal_Enabled'), id)
      Confline.new_confline('PayPal_Email', Confline.get_value('PayPal_Email'), id)
      Confline.new_confline('Paypal_Default_Currency', Confline.get_value('Paypal_Default_Currency'), id)
      Confline.new_confline('PayPal_Default_Amount', Confline.get_value('PayPal_Default_Amount'), id)
      Confline.new_confline('PayPal_Min_Amount', Confline.get_value('PayPal_Min_Amount'), id)
      Confline.new_confline('PayPal_Test', Confline.get_value('PayPal_Test'), id)
      Confline.new_confline('WebMoney_Enabled', Confline.get_value('WebMoney_Enabled'), id)
      Confline.new_confline('WebMoney_Purse', Confline.get_value('WebMoney_Purse'), id)
      Confline.new_confline('WebMoney_Default_Amount', Confline.get_value('WebMoney_Default_Amount'), id)
      Confline.new_confline('WebMoney_Min_Amount', Confline.get_value('WebMoney_Min_Amount'), id)
      Confline.new_confline('WebMoney_Test', Confline.get_value('WebMoney_Test'), id)
      #Default_device
      Confline.new_confline('Default_device_type', Confline.get_value("Default_device_type", 0), id)
      Confline.new_confline("Default_device_dtmfmode", Confline.get_value("Default_device_dtmfmode", 0), id)
      Confline.new_confline("Default_device_works_not_logged", Confline.get_value("Default_device_works_not_logged", 0), id)
      #set device location id to resellers default location id if exists or use admins Global location id
      if resellers_device_location
        Confline.new_confline("Default_device_location_id", resellers_device_location, id)
      else
        Confline.new_confline("Default_device_location_id", Confline.get_value("Default_device_location_id", 0), id)
      end

      Confline.new_confline("Default_device_timeout", Confline.get_value("Default_device_timeout", 0), id)
      Confline.new_confline("Default_device_record", Confline.get_value("Default_device_record", 0), id)
      Confline.new_confline("Default_device_call_limit", Confline.get_value("Default_device_call_limit", 0), id)
      Confline.new_confline("Default_device_nat", Confline.get_value("Default_device_nat", 0), id)
      Confline.new_confline("Default_device_voicemail_active", Confline.get_value("Default_device_voicemail_active", 0), id)
      Confline.new_confline("Default_device_trustrpid", Confline.get_value("Default_device_trustrpid", 0), id)
      Confline.new_confline("Default_device_sendrpid", Confline.get_value("Default_device_sendrpid", 0), id)
      Confline.new_confline("Default_device_t38pt_udptl", Confline.get_value("Default_device_t38pt_udptl", 0), id)
      Confline.new_confline("Default_device_promiscredir", Confline.get_value("Default_device_promiscredir", 0), id)
      Confline.new_confline("Default_device_progressinband", Confline.get_value("Default_device_progressinband", 0), id)
      Confline.new_confline("Default_device_videosupport", Confline.get_value("Default_device_videosupport", 0), id)
      Confline.new_confline("Default_device_allow_duplicate_calls", Confline.get_value("Default_device_allow_duplicate_calls", 0), id)
      Confline.new_confline("Default_device_tell_balance", Confline.get_value("Default_device_tell_balance", 0), id)
      Confline.new_confline("Default_device_tell_time", Confline.get_value("Default_device_tell_time", 0), id)
      Confline.new_confline("Default_device_tell_rtime_when_left", Confline.get_value("Default_device_tell_rtime_when_left", 0), id)
      Confline.new_confline("Default_device_repeat_rtime_every", Confline.get_value("Default_device_repeat_rtime_every", 0), id)
      Confline.new_confline("Default_device_permits", Confline.get_value("Default_device_permits", 0), id)
      Confline.new_confline("Default_device_qualify", Confline.get_value("Default_device_qualify", 0), id)
      Confline.new_confline("Default_device_host", Confline.get_value("Default_device_host", 0), id)
      Confline.new_confline("Default_device_ipaddr", Confline.get_value("Default_device_ipaddr", 0), id)
      Confline.new_confline("Default_device_port", Confline.get_value("Default_device_port", 0), id)
      Confline.new_confline("Default_device_regseconds", Confline.get_value("Default_device_regseconds", 0), id)
      Confline.new_confline("Default_device_canreinvite", Confline.get_value("Default_device_canreinvite", 0), id)
      Confline.new_confline("Default_device_canreinvite", Confline.get_value("Default_device_canreinvite", 0), id)
      Confline.new_confline("Default_device_istrunk", Confline.get_value("Default_device_istrunk", 0), id)
      Confline.new_confline("Default_device_ani", Confline.get_value("Default_device_ani", 0), id)
      Confline.new_confline("Default_device_callgroup", Confline.get_value("Default_device_callgroup", 0), id)
      Confline.new_confline("Default_device_pickupgroup", Confline.get_value("Default_device_pickupgroup", 0), id)
      Confline.new_confline("Default_device_fromuser", Confline.get_value("Default_device_fromuser", 0), id)
      Confline.new_confline("Default_device_fromuser", Confline.get_value("Default_device_fromdomain", 0), id)
      Confline.new_confline("Default_device_insecure", Confline.get_value("Default_device_insecure", 0), id)
      Confline.new_confline("Default_device_process_sipchaninfo", Confline.get_value("Default_device_process_sipchaninfo", 0), id)
      Confline.new_confline("Default_device_voicemail_box_email", Confline.get_value("Default_device_voicemail_box_email", 0), id)
      Confline.new_confline("Default_device_voicemail_box_password", Confline.get_value("Default_device_voicemail_box_password", 0), id)
      Confline.new_confline("Default_device_fake_ring", Confline.get_value("Default_device_fake_ring", 0), id)
      Confline.new_confline("Default_device_save_call_log", Confline.get_value("Default_device_save_call_log", 0), id)
      Confline.new_confline("Default_device_use_ani_for_cli", Confline.get_value("Default_device_use_ani_for_cli", 0), id)

      #------------ codecs ----------------

      for codec in Codec.find(:all)
        Confline.new_confline("Default_device_codec_#{codec.name}", Confline.get_value("Default_device_codec_#{codec.name}", 0), id)
      end
      Confline.new_confline("Default_device_cid_name", Confline.get_value("Default_device_cid_name", 0), id)
      Confline.new_confline("Default_device_cid_number", Confline.get_value("Default_device_cid_number", 0), id)

      Confline.new_confline("CSV_Separator", Confline.get_value("CSV_Separator", 0), id)
      Confline.new_confline("CSV_Decimal", Confline.get_value("CSV_Decimal", 0), id)

      # ---------- emails -----------------
      create_reseler_emails
    end


  end

  def create_reseler_emails
    Confline.new_confline("Email_Batch_Size", Confline.get_value("Email_Batch_Size", 0).to_i, id)
    Confline.new_confline("Email_from", Confline.get_value("Email_from", 0).to_s, id)
    Confline.new_confline("Email_Smtp_Server", Confline.get_value("Email_Smtp_Server", 0), id)
    Confline.new_confline("Email_Domain", Confline.get_value("Email_Domain", 0), id)
    Confline.new_confline("Email_Login", Confline.get_value("Email_Login", 0), id)
    Confline.set_value2("Email_Login", 1, self.id)
    Confline.new_confline("Email_Password", Confline.get_value("Email_Password", 0), id)
    Confline.set_value2("Email_Password", 1, self.id)
    Confline.new_confline("Email_port", Confline.get_value("Email_port", 0), id)
  end

  def User.exists_resellers_confline_settings(id)
    con = Confline.find(:first, :conditions => "name = 'Email_Login' AND owner_id = #{id}")
    unless con
      reseller = User.find_by_id(id)
      reseller.create_reseler_emails
    else
      reseller = User.find_by_id(id)
      reseller.check_reseller_emails
    end
  end

  def create_reseller_emails
    emails = Email.find(:all, :conditions => "owner_id = 0 AND template = 1 AND (name != 'recording_new' and name != 'recording_delete') ")
    for email in emails
      em = Email.new()
      em.name = email.name
      em.subject = email.subject
      em.body = email.body
      em.template =1
      em.date_created = Time.now.to_s
      em.owner_id = id
      em.save
    end
  end

  def check_reseller_emails
    con = Confline.find(:first, :conditions => ["name = 'Email_From' and owner_id=?", id])
    if con
      con.name = "Email_from"
      con.save
    end
    emails = Email.find(:all,
                        :select => "emails.*",
                        :joins => "LEFT JOIN (select * from emails where owner_id = #{id} and template =1) as b ON (b.name = emails.name)",
                        :conditions => "emails.owner_id = 0 AND emails.template = 1 AND b.id IS NULL AND (emails.name != 'recording_new' AND emails.name != 'recording_delete')")
    for email in emails
      MorLog.my_debug("FIXING RESELLER EMAILS: #{id} Email not found: #{email.id}")
      em = Email.new()
      em.name = email.name
      em.subject = email.subject
      em.body = email.body
      em.template =1
      em.date_created = Time.now.to_s
      em.owner_id = id
      em.save
    end

  end

  def check_default_user_conflines
    if usertype == "reseller"

      conflines = Confline.find(:all, :conditions => "name LIKE 'Default_device%' AND owner_id = 0")
      for confline in conflines
        if not Confline.find(:first, :conditions => "name = '#{confline.name}' AND owner_id = #{id}")
          Confline.new_confline(confline.name, confline.value, id)
        end
      end

    end
  end

  def User::get_hash(user_id)
    user = User.find(user_id.to_i)
    return user.uniquehash if user and user.uniquehash and user.uniquehash.length > 0
    user.uniquehash = ApplicationController::random_password(10)
    user.save
    return user.uniquehash
  end

=begin rdoc
 Returns user hash. If user has no hash yet generates new one and returns it.
=end

  def get_hash
    return(uniquehash) if (uniquehash and uniquehash.length > 0)
    uniquehash = ApplicationController::random_password(10)
    save
    return uniquehash
  end

  #debug
  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def get_owner()
    owner = User.find(owner_id)
    return owner
  end


  def primary_device
    Device.find(:first, :conditions => ["id = ?", primary_device_id])
  end


  def quick_stats(month_t, last_day, day_t)

    month_calls = 0
    month_billsec = 0
    month_selfcost = 0
    month_cost = 0

    day_calls = 0
    day_billsec = 0
    day_selfcost = 0
    day_cost = 0

    if usertype == "admin"

      # ---- month ----

      # calls from admin users
      sql_res = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.provider_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE reseller_id = 0 AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59';"
      res = ActiveRecord::Base.connection.select_all(sql_res)

      #calls from reseller users
      sql_res2 = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.provider_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.reseller_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE reseller_id != 0 AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59';"
      res2 = ActiveRecord::Base.connection.select_all(sql_res2)

      month_calls = res[0]['calls_count'].to_i + res2[0]['calls_count'].to_i
      month_billsec = res[0]['sum_billsec'].to_i + res2[0]['sum_billsec'].to_i
      month_selfcost = res[0]['call_selfcost'].to_f + res2[0]['call_selfcost'].to_f
      month_cost = res[0]['call_cost'].to_f + res2[0]['call_cost'].to_f

      # ---- day ----

      # calls from admin users
      sql_res = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.provider_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE reseller_id = 0 AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59';"
      res = ActiveRecord::Base.connection.select_all(sql_res)

      #calls from reseller users
      sql_res2 = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.provider_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.reseller_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE reseller_id != 0 AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59';"
      res2 = ActiveRecord::Base.connection.select_all(sql_res2)

      day_calls = res[0]['calls_count'].to_i + res2[0]['calls_count'].to_i
      day_billsec = res[0]['sum_billsec'].to_i + res2[0]['sum_billsec'].to_i
      day_selfcost = res[0]['call_selfcost'].to_f + res2[0]['call_selfcost'].to_f
      day_cost = res[0]['call_cost'].to_f + res2[0]['call_cost'].to_f

    end

    if usertype == "reseller"

      # ---- month ----

      # calls from reseller
      sql_res = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE user_id = #{id} AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59';"
      res = ActiveRecord::Base.connection.select_all(sql_res)

      #calls from reseller users
      sql_res2 = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.reseller_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE reseller_id = #{id} AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59';"
      res2 = ActiveRecord::Base.connection.select_all(sql_res2)

      month_calls = res[0]['calls_count'].to_i + res2[0]['calls_count'].to_i
      month_billsec = res[0]['sum_billsec'].to_i + res2[0]['sum_billsec'].to_i
      month_selfcost = res[0]['call_selfcost'].to_f + res2[0]['call_selfcost'].to_f
      month_cost = res[0]['call_cost'].to_f + res2[0]['call_cost'].to_f

      # ---- day ----

      # calls from reseller
      sql_res = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE user_id = #{id} AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59';"
      res = ActiveRecord::Base.connection.select_all(sql_res)

      #calls from reseller users
      sql_res2 = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.reseller_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE reseller_id = #{id} AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59';"
      res2 = ActiveRecord::Base.connection.select_all(sql_res2)

      day_calls = res[0]['calls_count'].to_i + res2[0]['calls_count'].to_i
      day_billsec = res[0]['sum_billsec'].to_i + res2[0]['sum_billsec'].to_i
      day_selfcost = res[0]['call_selfcost'].to_f + res2[0]['call_selfcost'].to_f
      day_cost = res[0]['call_cost'].to_f + res2[0]['call_cost'].to_f

    end

    if usertype != "admin" and usertype != "reseller"

      # ---- month ----

      # calls from user
      sql_res = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE user_id = #{id} AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59';"
      res = ActiveRecord::Base.connection.select_all(sql_res)

      month_calls = res[0]['calls_count'].to_i
      month_billsec = res[0]['sum_billsec'].to_i
      month_selfcost = res[0]['call_selfcost'].to_f
      month_cost = res[0]['call_cost'].to_f

      # ---- day ----

      # calls from user
      sql_res = "SELECT COUNT(calls.id) as 'calls_count', SUM(calls.billsec) as 'sum_billsec', #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_selfcost'})}, #{SqlExport.replace_price('SUM(calls.user_price)', {:reference => 'call_cost'})} FROM calls USE INDEX (calldate) WHERE user_id = #{id} AND calls.disposition= 'ANSWERED' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59';"
      res = ActiveRecord::Base.connection.select_all(sql_res)

      day_calls = res[0]['calls_count'].to_i
      day_billsec = res[0]['sum_billsec'].to_i
      day_selfcost = res[0]['call_selfcost'].to_f
      day_cost = res[0]['call_cost'].to_f

    end

    return month_calls, month_billsec, month_selfcost, month_cost, day_calls, day_billsec, day_selfcost, day_cost
  end


  # finds total outgoing calls made by this user and price for these calls in period
  # period is in string format date-time
  def own_outgoing_calls_stats_in_period(period_start, period_end, calldate_index = 0)

    total_calls = 0
    calls_price = 0
    zero_calls_sql = invoice_zero_calls_sql
    up = SqlExport.user_price_sql
    #val = ActiveRecord::Base.connection.select_all("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls JOIN devices ON (calls.src_device_id = devices.id) WHERE disposition = 'ANSWERED' and devices.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};")
    val = ActiveRecord::Base.connection.select_all("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls WHERE disposition = 'ANSWERED' and calls.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};")
    val2 = ActiveRecord::Base.connection.select_all("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls JOIN devices ON (calls.dst_device_id = devices.id) WHERE disposition = 'ANSWERED' and devices.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};")
    #MorLog.my_debug("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls JOIN devices ON (calls.src_device_id = devices.id) WHERE disposition = 'ANSWERED' and devices.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};", 1)
    MorLog.my_debug("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls WHERE disposition = 'ANSWERED' and calls.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};", 1)
    MorLog.my_debug("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls JOIN devices ON (calls.dst_device_id = devices.id) WHERE disposition = 'ANSWERED' and devices.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};", 1)

    if val
      total_calls += val[0]['calls'].to_i
      calls_price += val[0]['price'].to_f
    end

    if val2
      total_calls += val2[0]['calls'].to_i
      calls_price += val2[0]['price'].to_f
    end

    return total_calls.to_i, calls_price.to_f
  end


  # finds total outgoing calls made by this reseller users and price for these calls in period
  # period is in string format date-time
  def users_outgoing_calls_stats_in_period(period_start, period_end, calldate_index = 0)
    total_calls = 0
    calls_price = 0
    sql = "SELECT count(calls.id) as calls, SUM(#{SqlExport.admin_reseller_price_sql}) as price
           FROM calls
           #{SqlExport.left_join_reseler_providers_to_calls_sql}
           LEFT JOIN devices ON (dst_device_id = devices.id)
           LEFT JOIN users ON (devices.user_id = users.id)
           WHERE disposition = 'ANSWERED'
           and (calls.reseller_id = #{id} or users.owner_id = #{id})
           AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{invoice_zero_calls_sql(SqlExport.reseller_price_sql)}"
    res = ActiveRecord::Base.connection.select_all(sql)

    if res[0]
      total_calls = res[0]["calls"].to_i
      calls_price = res[0]["price"].to_f
    end
    return total_calls, calls_price
  end


  # finds total incoming calls RECEIVED by this user and price for these calls in period
  # period is in string format date-time
  def incoming_received_calls_stats_in_period(period_start, period_end, calldate_index = 0)

    total_calls = 0
    calls_price = 0

    sql = "SELECT count(calls.id) as calls, #{SqlExport.replace_price("SUM(#{SqlExport.user_price_sql})", {:reference => 'price'})}
                  FROM calls
                  JOIN devices ON (calls.dst_device_id = devices.id)
                  WHERE disposition = 'ANSWERED' AND calldate BETWEEN '#{period_start}' AND '#{period_end}' AND devices.user_id = #{id} AND calls.did_price > 0;"

    res = ActiveRecord::Base.connection.select_all(sql)

    if res[0]
      total_calls = res[0]["calls"]
      calls_price = res[0]["price"]
    end

    return total_calls.to_i, calls_price.to_f
  end


  # finds total incoming calls MADE by this user and price for these calls in period (DID incoming)
  # period is in string format date-time
  def incoming_made_calls_stats_in_period(period_start, period_end, calldate_index = 0)

    total_calls = 0
    calls_price = 0

    sql = "SELECT count(calls.id) as calls, #{SqlExport.replace_price("SUM(#{SqlExport.user_price_sql})", {:reference => 'price'})}
                  FROM calls
                  JOIN devices ON (calls.src_device_id = devices.id)
                  WHERE disposition = 'ANSWERED' AND calldate BETWEEN '#{period_start}' AND '#{period_end}' AND devices.user_id = #{id} AND calls.did_inc_price > 0;"

    res = ActiveRecord::Base.connection.select_all(sql)

    if res[0]
      total_calls = res[0]["calls"]
      calls_price = res[0]["price"]
    end

    return total_calls.to_i, calls_price.to_f
  end

  # finds subscriptions in given period
  # period is in string format date-time
  def subscriptions_in_period(period_start, period_end)
    period_start = period_start.to_s(:db) if period_start.class == Time or period_start.class == Date
    period_end = period_end.to_s(:db) if period_end.class == Time or period_end.class == Date
    subs = Subscription.find(:all, :include => [:service], :conditions => ["(? BETWEEN activation_start AND activation_end OR ? BETWEEN activation_start AND activation_end OR (activation_start > ? AND activation_end < ?)) AND subscriptions.user_id = ?", period_start, period_end, period_start, period_end, id])
    subs
  end


  # gets parameters for CSV file
  def csv_params

    owner_id = owner_id
    owner_id = id if usertype == "reseller"
    sep = Confline.get_value("CSV_Separator", owner_id).to_s
    dec = Confline.get_value("CSV_Decimal", owner_id).to_s

    sep = Confline.get_value("CSV_Separator", 0).to_s if sep.to_s.length == 0
    dec = Confline.get_value("CSV_Decimal", 0).to_s if dec.to_s.length == 0

    sep = "," if sep.blank?
    dec = "." if dec.blank?

    return sep, dec
  end


  def create_default_device(options={})
    owner_id = self.owner_id

    fextension = options[:free_ext]
    device = Device.new({:user_id => id, :devicegroup_id => options[:dev_group].to_i, :context => "mor_local", :device_type => options[:device_type].to_s, :extension => fextension, :pin => options[:pin].to_s, :secret => options[:secret].to_s})
    device.description = options[:description] if options[:description]
    device.device_ip_authentication_record = options[:device_ip_authentication_record] if options[:device_ip_authentication_record]
    device.username = options[:username] ? options[:username] : fextension
    device.name = options[:username] ? options[:username] : fextension
    device.dtmfmode = Confline.get_value("Default_device_dtmfmode", owner_id).to_s
    device.works_not_logged = Confline.get_value("Default_device_works_not_logged", owner_id).to_i
    if owner_id != 0
      #kvieciam metoda
      owner = User.where({:id => owner_id}).first
      owner.after_create_localization if owner
      #after this value should be default location and reseller gets new default location if did not have it
    end


    # if reseller and location id == 1, create default location and set new location id
    set_location_id = Confline.get_value("Default_device_location_id", owner_id)
    if (set_location_id.blank? or set_location_id.to_i == 1) and owner and owner.is_reseller?
      device.check_location_id
      device.location_id = Confline.get_value("Default_device_location_id", owner_id).to_i

      logger.fatal('setting location_id:')
      logger.fatal(Confline.get_value("Default_device_location_id", owner_id))
      logger.fatal('now device location id:')
      logger.fatal(device.location_id.to_yaml)

    else
      device.location_id = set_location_id
    end

    device.timeout = Confline.get_value("Default_device_timeout", owner_id)

    device.record = Confline.get_value("Default_device_record", owner_id).to_i
    device.recording_to_email = Confline.get_value("Default_device_recording_to_email", owner_id).to_i
    device.recording_keep = Confline.get_value("Default_device_recording_keep", owner_id).to_i
    device.record_forced = Confline.get_value("Default_device_record_forced", owner_id).to_i
    device.recording_email = Confline.get_value("Default_device_recording_email", owner_id).to_s

    device.call_limit = Confline.get_value("Default_device_call_limit", owner_id)
    device.server_id = Confline.get_value("Default_device_server_id")


    device.nat = Confline.get_value("Default_device_nat", owner_id).to_s

    device.voicemail_active = Confline.get_value("Default_device_voicemail_active", owner_id).to_i

    device.trustrpid = Confline.get_value("Default_device_trustrpid", owner_id).to_s
    device.sendrpid = Confline.get_value("Default_device_sendrpid", owner_id).to_s
    device.t38pt_udptl = Confline.get_value("Default_device_t38pt_udptl", owner_id).to_s
    device.promiscredir = Confline.get_value("Default_device_promiscredir", owner_id).to_s
    device.promiscredir = "no" if device.promiscredir != "yes" or device.promiscredir != "no"
    device.progressinband = Confline.get_value("Default_device_progressinband", owner_id).to_s
    device.videosupport = Confline.get_value("Default_device_videosupport", owner_id).to_s
    device.allow_duplicate_calls = Confline.get_value("Default_device_allow_duplicate_calls", owner_id).to_i
    device.tell_balance = Confline.get_value("Default_device_tell_balance", owner_id).to_i
    device.tell_time = Confline.get_value("Default_device_tell_time", owner_id).to_i
    device.tell_rtime_when_left = Confline.get_value("Default_device_tell_rtime_when_left", owner_id).to_i
    device.repeat_rtime_every = Confline.get_value("Default_device_repeat_rtime_every", owner_id).to_i

    device.permit = Confline.get_value("Default_device_permits", owner_id).to_s
    device.qualify = Confline.get_value("Default_device_qualify", owner_id)

    device.host = Confline.get_value("Default_device_host", owner_id).to_s
    device.host = "0.0.0.0" if  options[:device_type] == "H323"
    device.ipaddr = Confline.get_value("Default_device_ipaddr", owner_id).to_s
    device.ipaddr = "0.0.0.0" if  options[:device_type] == "H323"

    device.port = Confline.get_value("Default_device_port", owner_id).to_i
    device.port = "1720" if  options[:device_type] == "H323"

    device.regseconds = Confline.get_value("Default_device_regseconds", owner_id).to_i
    device.canreinvite = Confline.get_value("Default_device_canreinvite", owner_id).to_s
    device.transfer = Confline.get_value("Default_device_canreinvite", owner_id).to_s
    device.istrunk = Confline.get_value("Default_device_istrunk", owner_id).to_i
    device.ani = Confline.get_value("Default_device_ani", owner_id).to_i
    device.callgroup = Confline.get_value("Default_device_callgroup", owner_id).to_s.blank? ? nil : Confline.get_value("Default_device_callgroup", owner_id).to_i

    device.pickupgroup = Confline.get_value("Default_device_pickupgroup", owner_id).to_s.blank? ? nil : Confline.get_value("Default_device_pickupgroup", owner_id).to_i
    device.fromuser = Confline.get_value("Default_device_fromuser", owner_id).to_s

    device.fromdomain = Confline.get_value("Default_device_fromdomain", owner_id).to_s
    device.grace_time = Confline.get_value("Default_device_grace_time", owner_id).to_s
    device.insecure = Confline.get_value("Default_device_insecure", owner_id).to_s
    device.process_sipchaninfo = Confline.get_value("Default_device_process_sipchaninfo", owner_id).to_i
    device.fake_ring = Confline.get_value("Default_device_fake_ring", owner_id).to_i
    device.enable_mwi = Confline.get_value("Default_device_enable_mwi", owner_id).to_i
    device.save_call_log = Confline.get_value("Default_device_save_call_log", owner_id).to_i
    device.use_ani_for_cli = Confline.get_value("Default_device_use_ani_for_cli", owner_id)
    device.calleridpres = Confline.get_value("Default_device_calleridpres", owner_id).to_s
    device.change_failed_code_to = Confline.get_value("Default_device_change_failed_code_to", owner_id).to_i
    device.max_timeout = Confline.get_value("Default_device_max_timeout", owner_id).to_i
    device.language = Confline.get_value("Default_device_language", owner_id).to_s
    if not device.works_not_logged
      device.works_not_logged = 1
    end

    if device.save

      #      device.accountcode = device.id
      #      device.save(false)


      #------- VM ----------

      pass = Confline.get_value("Default_device_voicemail_box_password", owner_id)
      pass = random_digit_password(4) if pass.to_s.length == 0

      email = Confline.get_value("Default_device_voicemail_box_email", owner_id)
      address = address
      email = address.email if address and address.email.to_s.size > 0
      device.update_cid(Confline.get_value("Default_device_cid_name", owner_id), Confline.get_value("Default_device_cid_number", owner_id), false)
      primary_device_id = device.id
      # configure_extensions(device.id)
    end

    return device

  end

=begin rdoc

=end

  def assign_default_tax(taxs={}, opt ={})
    options = {
        :save => true
    }.merge(opt)
    if !taxs or taxs == {}
      if owner_id == 0
        new_tax = Confline.get_default_tax(0)
      else
        new_tax = User.find_by_id(owner_id).get_tax.dup
      end
    else
      new_tax = Tax.new(taxs)
    end
    logger.fatal new_tax.to_yaml
    new_tax.save if options[:save] == true
    self.tax_id = new_tax.id
    self.save if options[:save] == true
  end

  def assign_default_tax2
    owner = owner_id
    tax ={
        :tax1_enabled => 1,
        :tax2_enabled => Confline.get_value2("Tax_2", owner).to_i,
        :tax3_enabled => Confline.get_value2("Tax_3", owner).to_i,
        :tax4_enabled => Confline.get_value2("Tax_4", owner).to_i,
        :tax1_name => Confline.get_value("Tax_1", owner),
        :tax2_name => Confline.get_value("Tax_2", owner),
        :tax3_name => Confline.get_value("Tax_3", owner),
        :tax4_name => Confline.get_value("Tax_4", owner),
        :total_tax_name => Confline.get_value("Total_tax_name", owner),
        :tax1_value => Confline.get_value("Tax_1_Value", owner).to_f,
        :tax2_value => Confline.get_value("Tax_2_Value", owner).to_f,
        :tax3_value => Confline.get_value("Tax_3_Value", owner).to_f,
        :tax4_value => Confline.get_value("Tax_4_Value", owner).to_f,
        :compound_tax => Confline.get_value("Tax_compound", owner).to_i
    }

    tax[:total_tax_name] = "TAX" if tax[:total_tax_name].blank?
    tax[:tax1_name] = tax[:total_tax_name].to_s if tax[:tax1_name].blank?
    assign_default_tax(tax, {:save => true})
  end


=begin rdoc

=end

  def random_digit_password(size = 8)
    chars = ((0..9).to_a)
    (1..size).collect { |a| chars[rand(chars.size)] }.join
  end

  def get_tax
    self.assign_default_tax if tax.nil?
    self.tax
  end

  def user_type
    postpaid == 1 ? "postpaid" : "prepaid"
  end

  def pay_subscriptions(year, month)
    changed = 0
    all_data = []
    MorLog.my_debug("---#{username}-----------------------------------------")

    return all_data if blocked.to_i == 1
    time = Time.mktime(year, month, 1, 23, 59, 59)
    time = time.next_month if user_type == "prepaid"

    MorLog.my_debug("  #{time.year}-#{time.month}")
    period_start_with_time = time.beginning_of_month
    period_end_with_time = time.end_of_month.change(:hour => 23, :min => 59, :sec => 59)

    subscriptions = subscriptions_in_period(period_start_with_time, period_end_with_time)
    MorLog.my_debug("  Found subscriptions : #{subscriptions.size}")
    b=0
    subscriptions.each { |sub|
      if !Action.find(:first, :conditions => ["action = 'subscription_paid' AND user_id = ? AND data = ? AND target_id = ?", id, "#{time.year}-#{time.month}", sub.id])
        changed = 1
        sub_price = sub.price_for_period(period_start_with_time, period_end_with_time)

        Action.new(:user_id => id, :target_id => sub.id, :target_type => "subscription", :date => Time.now, :action => "subscription_paid", :data => "#{time.year}-#{time.month}", :data2 => sub_price).save

        # if setting does not allow dropping bellow zero and balance got bellow 0
        setting_disallow_balance_drop_below_zero = Confline.get_value("Disallow_prepaid_user_balance_drop_below_zero", owner_id)
        balance_left = balance - sub_price
        if user_type == "prepaid" and balance_left.to_f < 0.to_f and setting_disallow_balance_drop_below_zero.to_i == 1
          # and block user
          MorLog.my_debug("  Blocking prepaid user and sending email")
          block_and_send_email
        else
          # pay subsciption
          b += sub_price
        end

        MorLog.my_debug("  Paying subscription: #{sub.service.name} Price: #{sub_price} balance left #{balance}")
        all_data << {:price => sub_price, :subscription => sub, :msg => "Paid now"}
        Payment.subscription_payment(self, sub_price)

        # what is the purpose of this Action? It marks subscription as paid for next month and ruins the billing!
        # Action.new(:user_id => id, :target_id => sub.id, :target_type =>"subscription", :date => Time.now, :action => "subscription_paid", :data => "#{Time.now.year}-#{Time.now.month}", :data2=>sub_price).save
      else
        MorLog.my_debug("  Service already paid: #{sub.service.name}")
        #all_data << {:price => 0, :price_with_tax => 0, :subscription => sub, :msg => "Alraedy payed"}
      end
    }
    self.balance -= b
    if postpaid? and (balance + credit < 0) and not credit_unlimited?
      changed = 1
      MorLog.my_debug("  Blocking postpaid user and sending email")
      block_and_send_email
    end

    save if changed.to_i == 1
    MorLog.my_debug("-END-#{username}-----------------------------------------")

    return all_data
  end

  def user_calls_to_csv(options={})
    options[:hide_finances] ||= false
    sep, dec = csv_params

    disposition = []
    if options[:direction] == "incoming"
      disposition << " ((devices.user_id = #{id} )  OR (dids.user_id = #{id}))"
      disposition << " calls.dst_device_id = #{options[:device].id} " if options[:device]
    else
      disposition << " calls.user_id = #{id}"
      disposition << " calls.src_device_id = #{options[:device].id} " if options[:device]
    end

    disposition << " disposition = '#{options[:call_type]}' " if options[:call_type] != "all"
    disposition << " calls.hangupcause = #{options[:hgc].code} " if options[:hgc]
    disposition << " calls.card_id = 0"
    disposition << " calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}'"

    default_currency = options[:default_currency]
    show_currency = options[:show_currency]
    if default_currency != show_currency
      curr3er = Currency.find(:first, :select => "exchange_rate as 'ex'", :conditions => "name = '#{show_currency}'")
    end

    #    fm1 = " ROUND("
    #    fm2 =" ,#{options[:nice_number_digits]}) "

    r1 = dec == "." ? "" : "replace("
    r2 = dec == "." ? "" : ", '.', '#{dec}')"
    n1 = "#{r1}" #"#{r1} FORMAT("
    n2 = "#{r2}" #",#{options[:nice_number_digits]})#{r2}"
    c1 = default_currency != show_currency ? " * #{curr3er.ex.to_f} " : ""

    select = []
    select2 = []
    format = Confline.get_value('Date_format', owner_id).gsub('M', 'i')
    select2 << SqlExport.nice_date('calldate', {:reference => 'calldate', :format => format, :tz => options[:tx]})
    select2 << "src, dst, direction"
    select2 << "prov_name" if options[:usertype] == "admin"
    select2 << "duration, disposition"

    select << "calls.calldate"
    select << "IF(#{options[:show_full_src].to_i} = 1 AND CHAR_LENGTH(clid)>0 AND clid REGEXP'\"' , CONCAT(src, '  ' ,REPLACE(SUBSTRING_INDEX(clid, '\"', 2), '\"', '('), ')'), src) as 'src'"

    options[:usertype] == 'user' ? select << hide_dst_for_user_sql(self, "csv", "calls.dst", {:as => "dst"}) : select << "calls.dst"

    select << "CONCAT(IF(directions.name IS NULL, '',directions.name), ' ', IF(destinations.name IS NULL, '',destinations.name), ' ', IF(destinations.subcode IS NULL, '',destinations.subcode)) as 'direction'"
    select << "IF(providers.name IS NULL, '', providers.name) as 'prov_name' " if options[:usertype] == "admin"
    select << "IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) as 'duration'"
    select << "calls.disposition"
    unless options[:hide_finances]
      if options[:direction] == "incoming"
        if options[:usertype] == "admin"
          select2 << SqlExport.replace_price("#{n1}user_price3#{n2}", {:reference => 'user_price3'})
          select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {:reference => 'provider_price3'})
          select2 << SqlExport.replace_price("#{n1}did_price3#{n2}", {:reference => 'did_price3'})
          select2 << SqlExport.replace_price("#{n1}(user_price3+provider_price3+did_price3)#{n2}", {:reference => 'profit'})
          select << "#{n1}calls.did_prov_price#{c1}#{n2} as 'user_price3'"
          select << "#{n1}calls.did_inc_price#{c1}#{n2} as 'provider_price3'"
          select << "#{n1}calls.did_price#{c1}#{n2} as 'did_price3'"
        end
        if options[:usertype] == "reseller"
          select2 << SqlExport.replace_price("#{n1}did_price3#{n2}", {:reference => 'did_price3'})
          select << "#{n1}calls.did_price#{c1}#{n2} as 'did_price3'"
        end
        if options[:usertype] == "user"
          select2 << SqlExport.replace_price("#{n1}user_price3#{n2}", {:reference => 'user_price3'})
          select << "#{n1} calls.did_price #{c1} #{n2} as 'user_price3'"
        end
      else
        select2 << SqlExport.replace_price("#{n1}user_price3#{n2}", {:reference => 'user_price3'})
        select << "#{n1} calls.user_price #{c1} #{n2} as 'user_price3'" if options[:usertype] != "admin"
        if options[:usertype] == "admin"
          select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {:reference => 'provider_price3'})
          select2 << SqlExport.replace_price("#{n1}(user_price3-provider_price3)#{n2}", {:reference => 'profit'})
          select << "IF(calls.reseller_id > 0, calls.reseller_price#{c1} , calls.user_price#{c1}) as 'user_price3'"
          select << "IF(calls.provider_price IS NOT NULL, calls.provider_price#{c1}, 0) as 'provider_price3'"
        end
        if options[:usertype] == "reseller"
          select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {:reference => 'provider_price3'})
          select << "IF(calls.reseller_id = 0, calls.user_price#{c1}, calls.reseller_price#{c1}) as 'provider_price3'"
          select2 << SqlExport.replace_price("#{n1}(user_price3-provider_price3)#{n2}", {:reference => 'profit'})
        end
        if options[:usertype] != "user"
          select2 << "IF( (((user_price3-provider_price3) / user_price3 ) *100) IS NULL, 0,  #{n1}(((user_price3-provider_price3) / user_price3 ) *100) #{n2}) as 'm1'"
          select2 << "IF(( ((user_price3 / provider_price3) *100)-100 ) IS NULL, 0 ,   #{n1}( ((user_price3 / provider_price3) *100)-100 )#{n2}) as 'm2'"
        end
      end
    end
    if options[:usertype] == "admin"
      select << "calls.originator_ip as 'oip'"
      select << "calls.terminator_ip as 'tip'"
      select << "IF(calls.real_duration = 0, duration, real_duration) as 'real_duration2'"
      select << "IF(calls.real_billsec = 0, billsec, real_billsec) as 'real_billsec2'"

      select2 << "oip"
      select2 << "tip"
      select2 << "#{n1}real_duration2#{n2} as real_duration2"
      select2 << "#{n1}real_billsec2#{n2} as real_billsec2"
    end

    jn = []
    jn << "LEFT JOIN destinations ON (calls.prefix = destinations.prefix)"
    jn << "LEFT JOIN directions ON (directions.code = destinations.direction_code)"
    jn << "JOIN devices ON (devices.id = calls.dst_device_id)" if options[:direction] == "incoming"
    jn << "LEFT JOIN dids ON (calls.did_id = dids.id)" if options[:direction] == "incoming"
    jn << "LEFT JOIN providers ON (providers.id = calls.provider_id)" if options[:usertype] == "admin"

    filename = "CDR-#{id.to_s.gsub(" ", "_")}-#{options[:date_from].gsub(" ", "_").gsub(":", "_")}-#{options[:date_till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_f.to_s.gsub(".", "")}-#{options[:direction]}-#{show_currency}"

    sql = "SELECT * "
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    disp = disposition.join(" AND ")
    disp = "(#{disp}) OR (calls.reseller_id = #{id} AND calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}')" if options[:reseller].to_i == 1

    sql += " FROM ("+
        "SELECT #{select2.join(" , ")}  FROM
            ((SELECT #{select.join(" , ")}
      FROM calls  #{jn.join(" ")}
      WHERE #{disp}
      ORDER BY calls.calldate DESC)) as temp_a) as temp_c;"

    #  MorLog.my_debug(sql)

    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      filename += mysql_res.to_yaml.to_s
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    return filename
  end

  def user_last_calls_order(options={})
    cond = []
    cond << "(calldate BETWEEN '#{options[:from]}' AND '#{options[:till]}')"
    cond << "(dst_device_id = #{options[:device].id} OR src_device_id = #{options[:device].id})" if options[:device].to_i > 0
    cond << " disposition = '#{options[:call_type]}' " if options[:call_type] != "all"
    cond << " calls.hangupcause = #{options[:hgc].code} " if options[:hgc]

    cond << "(calls.reseller_id = '#{id}' OR devices.user_id = '#{id}')" if usertype=='reseller'
    cond << "devices.user_id = '#{id}'" if usertype=='user'

    jn = []
    jn << 'LEFT JOIN users ON (calls.user_id = users.id)'
    jn << 'LEFT JOIN users AS resellers ON (calls.reseller_id = resellers.id)'
    jn << 'LEFT JOIN providers ON (calls.provider_id = providers.id)'
    jn << 'LEFT JOIN dids ON (calls.did_id = dids.id)'
    jn << 'LEFT JOIN cards ON (calls.card_id = cards.id)'
    jn << 'JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' if usertype!='admin' and usertype != "accountant"
    jn2 = 'JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' if usertype!='admin' and usertype != "accountant"
    select = usertype=='reseller' ? ' DISTINCT calls.*' : 'calls.*'

    if options[:csv] == 1
      s =[]
      format = Confline.get_value('Date_format', owner_id).gsub('M', 'i')
      s << SqlExport.nice_date('calldate', {:reference => 'calldate', :format => format, :tz => time_zone})
      s << "calls.src"
      options[:usertype] == 'user' ? s << hide_dst_for_user_sql(self, "csv", "calls.dst", {:as => "dst"}) : s << "calls.dst"
      s << "IF(calls.billsec = 0, IF(calls.real_billsec = 0, 0, calls.real_billsec) ,calls.billsec)"
      if usertype != 'user' or (Confline.get_value('Show_HGC_for_Resellers').to_i == 1 and usertype == 'reseller')
        s << "CONCAT(calls.disposition, '(', calls.hangupcause, ')')"
      else
        s << 'calls.disposition'
      end
      if usertype == "admin" or usertype == "accountant"
        s << "calls.server_id"
        s << "IF(providers.name IS NULL, '', providers.name)"
        s << "IF(calls.provider_rate IS NULL, 0, calls.provider_rate), IF(calls.provider_price IS NULL, 0, calls.provider_price)" if options[:can_see_finances]
        if (defined?(RS_Active) and RS_Active.to_i == 1)
          s << "CONCAT(resellers.first_name, ' ',resellers.last_name )"
          s << "IF(calls.reseller_rate IS NULL, 0 , #{SqlExport.replace_price('calls.reseller_rate')}), IF(calls.reseller_price IS NULL, 0 , #{SqlExport.replace_price('calls.reseller_price')})" if options[:can_see_finances]
        end

        s << "IF(calls.card_id = 0 ,CONCAT(IF(users.first_name IS NULL, ' ', users.first_name), ' ', IF(users.last_name IS NULL, ' ', users.last_name)  ), CONCAT('Card/#', cards.number))"
        s << "IF(calls.user_rate IS NULL, 0, #{SqlExport.replace_price('calls.user_rate')}), IF(calls.user_price IS NULL, 0, #{SqlExport.replace_price('calls.user_price')})" if options[:can_see_finances]
        s << "IF(dids.did IS NULL, '' , dids.did)"
        s << "IF(calls.did_prov_price IS NULL, 0, #{SqlExport.replace_price('calls.did_prov_price')}), IF(calls.did_inc_price IS NULL, 0, #{SqlExport.replace_price('calls.did_inc_price')}), IF(calls.did_price IS NULL, 0 , #{SqlExport.replace_price('calls.did_price')})" if options[:can_see_finances]
      end
      if show_billing_info == 1 and options[:can_see_finances]
        if usertype == 'reseller'
          s << "IF(calls.reseller_price != 0 , IF(calls.reseller_price IS NULL, 0, #{SqlExport.replace_price('calls.reseller_price')}), IF(calls.did_price IS NULL, 0, #{SqlExport.replace_price('calls.did_price')}))"
        end
        if usertype == 'user'
          s << "IF(calls.user_price != 0 , IF(calls.user_price IS NULL, 0, #{SqlExport.replace_price('calls.user_price')}), IF(calls.did_price IS NULL, 0, #{SqlExport.replace_price('calls.did_price')}))"
        end
      end
      filename = "Last_calls-#{id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
      sep, dec = csv_params
      sql = "SELECT * "
      if options[:test] != 1
        sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
      end
      sql += " FROM (SELECT #{s.join(', ')} FROM calls  #{jn.join(' ')}  WHERE #{cond.join(' AND ')} ORDER BY #{options[:order]} ) as C"

      if options[:test].to_i == 1
        mysql_res = ActiveRecord::Base.connection.select_all(sql)
        filename += mysql_res.to_yaml.to_s
      else
        mysql_res = ActiveRecord::Base.connection.execute(sql)
      end
      return filename
    else
      calls = Call.find(:all, :select => select, :conditions => cond.join(' AND '), :joins => jn.join(' '), :order => options[:order], :limit => "#{((options[:page].to_i - 1) * options[:items_per_page]).to_i}, #{options[:items_per_page]}")
      calls_t = Call.count(:all, :conditions => cond.join(' AND '), :joins => jn2)
      return calls, calls_t.to_i
    end
  end

  def update_voicemail_boxes
    device_ids = Device.find(:all, :select => "id", :conditions => ["user_id = ?", id]).map(&:id)
    VoicemailBox.update_all(["fullname = ?", [first_name.to_s, last_name.to_s].join(" ")], "device_id in (#{device_ids.join(", ")})") if device_ids.size > 0
  end

  def User.check_users_balance
    User.update_all("warning_email_sent = '0'", "warning_email_active = '1' AND warning_email_sent = '1' AND balance > warning_email_balance")
  end

  def get_invoices_status
    invoice = send_invoice_types

    if (invoice % 2) ==1
      if prepaid?
        prepaid = "Prepaid_"
      else
        prepaid= ""
      end
      invoice = Confline.get_value("#{prepaid}Invoice_default").to_i
    end
    invoice >= 256 ? i8= 256 : i8=0
    invoice = invoice - i8
    invoice >= 128 ? i7= 128 : i7=0
    invoice = invoice - i7
    invoice >= 64 ? i6= 64 : i6=0
    invoice = invoice - i6
    invoice >= 32 ? i5= 32 : i5=0
    invoice = invoice - i5
    invoice >= 16 ? i4= 16 : i4=0
    invoice = invoice - i4
    invoice >= 8 ? i3= 8 : i3=0
    invoice = invoice - i3
    invoice >= 4 ? i2= 4 : i2=0
    invoice = invoice - i2
    invoice >= 2 ? i1= 2 : i1=0

    return i1, i2, i3, i4, i5, i6, i7, i8
  end

  def User.find_all_for_select(owner_id = nil, options ={})
    opts = {:select => "id, username, first_name, last_name, #{SqlExport.nice_user_sql}", :order => "nice_user"}
    opts[:select] += ", "+options[:select] unless options[:select].blank?
    if owner_id and
        if options[:exclude_owner] == true
          opts[:conditions] = ["users.owner_id = ? AND hidden=0", owner_id]
        else
          opts[:conditions] = ["users.id = ? or users.owner_id = ? AND hidden=0", owner_id, owner_id]
        end

    end
    return User.find(:all, opts)
  end

  def find_all_for_select(options = {})
    User.find_all_for_select(id, options)
  end

  def activecalls
    Activecall.find(:all, :joins => "LEFT JOIN devices ON activecalls.src_device_id = devices.id OR activecalls.dst_device_id = devices.id LEFT JOIN users ON devices.user_id = users.id", :conditions => ["devices.user_id = ?", id])
  end

  def booth_status
    # we assume that booth is occupied if user has present calls
    @booth_status ||= if cs_invoices.any? && activecalls_since(cs_invoices.first.created_at, {:ongoing => true}).any?
                        "occupied"
                        # we assume that booth is reserved if there are invoices but there are no calls
                      elsif cs_invoices.any?
                        "reserved"
                      else
                        "free"
                      end

    @booth_status
  end

  def activecalls_since(time, options = {})
    Activecall.find(
        :all,
        :joins => "LEFT JOIN devices ON activecalls.src_device_id = devices.id OR activecalls.dst_device_id = devices.id LEFT JOIN users ON devices.user_id = users.id",
        :conditions => ["devices.user_id = ? AND start_time > ? #{"AND answer_time IS NOT NULL" if options[:ongoing]}", id, time.strftime("%Y-%m-%d %H:%M:%S")])
  end

  def active_booth_calls
    returning call_count = 0 do
      active_calls = calls("answered", cs_invoices.first.created_at.strftime("%Y-%m-%d %H:%M:%S"), Time.now.strftime("%Y-%m-%d %H:%M:%S"))
      call_count = active_calls.size if active_calls.any?
    end
  end

  def can_send_sms?
    out = true
    if sms_service_active == 0 or not sms_tariff or not sms_lcr
      out = false
    end
    out
  end

  def reseller_allow_providers_tariff?
    is_reseller? and own_providers == 1
  end

  def is_allow_manage_providers?
    is_admin? or reseller_allow_providers_tariff?
  end

  def can_own_providers?
    own_providers == 1
  end

  def load_lcrs(*arr)
    if is_accountant?
      if arr[1] and arr[1].include?(:conditions)
        arr[1][:conditions] += ' AND user_id = 0 '
      else
        arr[1][:conditions] = 'user_id = 0'
      end
      Lcr.find(*arr)
    else
      if !own_providers? and is_reseller?
        if arr[1] and arr[1].include?(:conditions)
          arr[1][:conditions] += " AND id = #{lcr_id} "
        else
          arr[1][:conditions] = "id = #{lcr_id}"
        end
        Lcr.find(*arr)
      else
        lcrs.find(*arr)
      end
      #      if usertype == 'reseller'
      #        if arr[1] and arr[1].include?(:conditions)
      #          arr[1][:conditions] += " AND (user_id = #{id} OR id = #{lcr_id})"
      #        else
      #          arr[1][:conditions] = " user_id = #{id} OR id = #{lcr_id}"
      #        end
      #        Lcr.find(*arr)
      #      else
      #        lcrs.find(*arr)
      #      end

    end
  end

  def safe_attributtes(params, id)
    if ['reseller', 'user'].include?(usertype)
      allow_params = [:time_zone, :spy_device_id, :currency_id, :password, :warning_email_balance, :warning_email_hour, :first_name, :last_name, :clientid, :taxation_country, :vat_number, :acc_group_id]
      allow_params += [:accounting_number, :generate_invoice, :username, :tariff_id, :postpaid, :call_limit, :blocked, :agreement_number, :language, :warning_balance_sound_file_id, :warning_balance_call, :quickforwards_rule_id] if usertype == 'reseller' and id.to_i != id.to_i
      allow_params += [:lcr_id] if params[:lcr_id] and reseller_allow_providers_tariff? and id.to_i != id.to_i and User.current.load_lcrs(:first, :conditions => "id = #{params[:lcr_id]}")
      unless check_for_own_providers
        allow_params +=[:recording_hdd_quota, :recordings_email, :hide_destination_end, :cyberplat_active,]
      end
      return params.reject { |key, value| !allow_params.include?(key.to_sym) }
    else
      return params
    end
  end

  def load_providers(*arr)
    if is_reseller?
      if arr[1] and arr[1].include?(:conditions)
        arr[1][:conditions] += " AND (user_id = #{id} OR (common_use = 1 and providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{id})))"
      else
        arr[1][:conditions] = "(user_id = #{id} OR (common_use = 1 and providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{id})))"
      end
      Provider.find(*arr)
    else
      providers.find(*arr)
    end
  end

  # also counts providers for terminator
  def load_terminators
    if is_reseller?
      Terminator.find_by_sql("SELECT terminators.*, count(providers.id) AS providers_size
FROM terminators
LEFT JOIN providers ON (providers.terminator_id = terminators.id)
WHERE terminators.user_id = #{id} or providers.common_use = 1 AND providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{id})
GROUP BY terminators.id;")
    else
      Terminator.find_by_sql("SELECT terminators.*, count(providers.id) AS providers_size
FROM terminators
LEFT JOIN providers ON (providers.terminator_id = terminators.id)
WHERE terminators.user_id = 0
GROUP BY terminators.id;")
    end
  end

  def load_terminator(term_id)
    if is_reseller?
      Terminator.find_by_sql("SELECT terminators.* FROM terminators
WHERE terminators.id = #{term_id} AND (terminators.user_id = #{id} OR terminators.id IN
(SELECT terminator_id FROM providers WHERE providers.common_use = 1))
LIMIT 1;")[0]
    else
      Terminator.find(:first, :conditions => ["terminators.id = ? AND terminators.user_id = 0", term_id])
    end
  end

  def load_terminators_ids
    if is_reseller?
      Terminator.find_by_sql("SELECT terminators.id
FROM terminators
LEFT JOIN providers ON (providers.terminator_id = terminators.id)
WHERE terminators.user_id = #{id} or providers.common_use = 1
GROUP BY terminators.id;").map { |t| t.id }
    else
      Terminator.find(:all, :conditions => ["terminators.user_id = 0",]).map(&:id)
    end
  end

  def check_for_own_providers
    o = false
    if reseller_allow_providers_tariff? or (usertype == 'user' and owner and owner.reseller_allow_providers_tariff?)
      o = true
    end
    return o
  end

  def load_users(*arr)
    if arr[1] and arr[1].include?(:select)
      arr[1][:select] += " #{SqlExport.nice_user_sql}"
    else
      arr[1]= {} if not arr[1]
      arr[1][:select] = "*, #{SqlExport.nice_user_sql}"
    end

    arr[1][:order] = 'nice_user'

    if is_reseller?
      if arr[1] and arr[1].include?(:conditions)
        arr[1][:conditions] += " AND (user_id = #{id} AND hidden = 0)"
      else
        arr[1]= {} if not arr[1]
        arr[1][:conditions] = "owner_id = #{id} AND hidden = 0"
      end
      User.find(*arr)
    else
      User.find(*arr)
    end
  end

  def load_users_devices(*arr)
    if is_reseller?
      arr[1][:joins] ||= ""
      arr[1][:joins] += "LEFT JOIN users ON (devices.user_id = users.id)"
      arr[1][:select] = "devices.*"
      if arr[1] and arr[1].include?(:conditions)
        arr[1][:conditions] += " AND (users.owner_id = #{id} AND users.hidden = 0)"
      else
        arr[1][:conditions] = "users.owner_id = #{id} AND users.hidden = 0"
      end
      Device.find(*arr)
    else
      Device.find(*arr)
    end
  end

  def load_dids(*arr)
    if is_reseller?
      if arr[1] and arr[1].include?(:conditions)
        arr[1][:conditions] += " AND (dids.reseller_id = #{id})"
      else
        if arr[1]
          arr[1][:conditions] = "dids.reseller_id = #{id}"
        else
          arr << {:conditions => "dids.reseller_id = #{id}"}
        end
      end
      Did.find(*arr)
    else
      Did.find(*arr)
    end
  end


  def User.users_order_by(params, options)
    case options[:order_by].to_s.strip.to_s
      when "acc" then
        order_by = "users.id"
      when "nice_user" then
        order_by = "nice_user"
      when "user" then
        order_by = "nice_user"
      when "username" then
        order_by = "users.username"
      when "usertype" then
        order_by = "users.usertype"
      when "balance" then
        order_by = "users.balance"
      when "account_type" then
        order_by = "users.postpaid"
      else
        order_by = options[:order_by]
    end
    if order_by != ""
      order_by += (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
    end
    return order_by
  end

  def convert_curr(rate)
    rate * User.current.currency.exchange_rate.to_f
  end

  # converted attributes for user in current user currency
  def balance
    b = read_attribute(:balance)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b.to_f
    end
  end

  def balance= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:balance, b)
  end

  def credit
    c = read_attribute(:credit)
    if User.current and User.current.currency
      c.to_f != -1.to_f ? c.to_f * User.current.currency.exchange_rate.to_f : -1.to_f
    else
      c
    end
  end

=begin
  TODO: prepaid user cannot have credit set especialy if credit is something invalid
  like 20, -1 etc. maybe 0 could be set but i doubt that, cause PREPAID USER DOES 
  NOT HAVE CREDIT how is it posible to set something one does not have??? well at
  least we should rise exception, if not hide this method. but not today cause this
  might break to many things
=end
  def credit= value
    #if prepaid?
    #  raise "Cannot set credit for prepaid user"
    if User.current and User.current.currency
      c = value == -1 ? -1 : (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      c = value
    end
    write_attribute(:credit, c)
  end

  def warning_email_balance
    b = read_attribute(:warning_email_balance)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b.to_f
    end
  end

  def warning_email_balance= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:warning_email_balance, b)
  end

  def fix_when_is_rendering
    if User.current and self
      self.balance = self.balance.to_f * User.current.currency.exchange_rate.to_f
      self.credit = self.credit.to_f * User.current.currency.exchange_rate.to_f if credit != -1
      self.warning_email_balance = self.warning_email_balance.to_f * User.current.currency.exchange_rate.to_f
    end
  end


  def find_sound_files_for_ivrs(id = nil)
    if id
      res = ivr_sound_files.find(:all, :conditions => {:ivr_voice_id => id})
    else
      res = ivr_sound_files
    end
    if res == nil or res.size == 0
      return {}
    end
    res
  end

  def load_tariffs
    owner = get_correct_owner_id

    #@sms_tariffs = SmsTariff.find(:all, :conditions => "(tariff_type = 'user') AND owner_id = '#{owner}' ", :order => "tariff_type ASC, name ASC")
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end

    Tariff.find(:all, :conditions => "owner_id = '#{owner}' #{cond} ", :order => "purpose ASC, name ASC")

  end


  def User.create_from_registration(params, owner, reg_ip, free_ext, pin, pasw, nan, api=0)
    user = Confline.get_default_object(User, owner.id)
    user.recording_enabled = 0 if !user.recording_enabled
    user.recording_forced_enabled = 0 if !user.recording_forced_enabled
    user.username = params[:username]
    user.password = Digest::SHA1.hexdigest(params[:password])
    user.usertype = "user"
    user.first_name = params[:first_name]
    user.last_name = params[:last_name]
    user.clientid = params[:client_id] if params[:client_id].to_s != ""
    user.agreement_date = Time.now.to_s(:db)
    user.agreement_number = nan
    user.vat_number = params[:vat_number] if params[:vat_number].to_s != ""
    user.owner_id = owner.id
    user.acc_group_id = 0
    #looking at code below and thinking 'FUBAR'? well mor currencies/money 
    #is FUBAR, that's just a hack to get around. ticket #5041
    user.balance = owner.to_system_currency(owner.to_system_currency(user.balance))

    user.credit = 0 if user.prepaid?
    if user.owner_id != 0
      reseller = User.find_by_id(user.owner_id)
      if reseller and reseller.own_providers.to_i == 1
        lcr_id = Confline.get_value("Default_User_lcr_id", reseller.id)
        if reseller.load_lcrs(:first, :conditions => ['id=?', lcr_id])
          user.lcr_id = lcr_id
        end
      else
        user.lcr_id = reseller.lcr_id if reseller
      end
      user.allow_loss_calls = reseller.allow_loss_calls if reseller
    end

    address = Confline.get_default_object(Address, owner.id)
    address.direction_id = params[:country_id] if params[:country_id].to_s != ""
    address.state = params[:state] if params[:state].to_s != ""
    address.county = params[:county] if params[:county].to_s != ""
    address.city = params[:city] if params[:city].to_s != ""
    address.postcode = params[:postcode] if params[:postcode].to_s != ""
    address.address = params[:address] if params[:address].to_s != ""
    address.phone = params[:phone] if params[:phone].to_s != ""
    address.mob_phone = params[:mob_phone] if params[:mob_phone].to_s != ""
    address.fax = params[:fax] if params[:fax].to_s != ""
    address.email = params[:email] if params[:email].to_s != ""
    address.save
    #If registering through API, taxation country by default is same 
    #as country. ticket #5071
    if api == 1
      user.taxation_country = address.direction_id
    end

    tax = Confline.get_default_object(Tax, owner.id)
    tax.save
    user.tax = tax
    user.address_id = address.id
    user.save
    # my_debug @user.to_yaml
    dev_group = Devicegroup.new
    dev_group.user_id = user.id
    dev_group.address_id = address.id
    dev_group.name = "primary"
    dev_group.added = Time.now
    dev_group.primary = 1
    dev_group.save

    if Confline.get_value("Allow_registration_username_passwords_in_devices").to_i == 1
      device = user.create_default_device({:device_type => params[:device_type], :dev_group => dev_group.id, :free_ext => free_ext, :secret => params[:password], :username => user.username, :pin => pin})
    else
      device = user.create_default_device({:device_type => params[:device_type], :dev_group => dev_group.id, :free_ext => free_ext, :secret => pasw, :pin => pin})
    end
    user.save

    cb = (defined?(CALLB_Active) and (CALLB_Active == 1)) ? 1 : 0
    if params[:mob_phone].to_s.gsub(/[^0-9]/, "").length > 0
      cli = Callerid.new({:cli => params[:mob_phone].to_s.gsub(/[^0-9]/, ""), :device_id => device.id, :description => "Mobile Phone", :email_callback => cb, :added_at => Time.now})
      cli.save
    end
    if params[:phone].to_s.gsub(/[^0-9]/, "").length > 0
      cli = Callerid.new({:cli => params[:phone].to_s.gsub(/[^0-9]/, ""), :device_id => device.id, :description => "Phone", :email_callback => cb, :added_at => Time.now})
      cli.save
    end
    if params[:fax].to_s.gsub(/[^0-9]/, "").length > 0
      cli = Callerid.new({:cli => params[:fax].to_s.gsub(/[^0-9]/, ""), :device_id => device.id, :description => "Fax", :email_callback => cb, :added_at => Time.now})
      cli.save
    end

    begin
      if api.to_i == 1
        a = Thread.new {
          send_email_to_user = EmailsController.send_user_email_after_registration(user, device, params[:password], reg_ip, free_ext)
          EmailsController.send_admin_email_after_registration(user, device, params[:password], reg_ip, free_ext, owner.id)
        }
      else
        send_email_to_user = EmailsController.send_user_email_after_registration(user, device, params[:password], reg_ip, free_ext)
        EmailsController.send_admin_email_after_registration(user, device, params[:password], reg_ip, free_ext, owner.id)
      end
    rescue Exception => e
      notice = _('Email_not_sent_because_bad_system_configurations')
    end


    return user, send_email_to_user, device, notice
  end

  def User.validate_from_registration(params)
    notice = nil
    #error checking
    username = params[:username]

    if username.to_s.blank?
      notice = _('Please_enter_username')
    end

    if User.find(:first, :conditions => "username = '#{username}'") and notice.blank?
      notice = _('Such_username_is_allready_taken')
    end

    if params[:password] != params[:password2] and notice.blank?
      notice = _('Passwords_do_not_match')
    end

    if (!params[:password] or params[:password].length < 5 or (Confline.get_value("Allow_registration_username_passwords_in_devices").to_i == 1 and Confline.get_value("Allow_short_passwords_in_devices").to_i == 0 and params[:password].length < 8)) and notice.blank?
      notice = _('Password_is_too_short')
    end

    if params[:password].blank? and notice.blank?
      notice = _('Please_enter_password')
    end

    if params[:password] == username and notice.blank?
      notice = _('Please_enter_password_not_equal_to_username')
    end

    if params[:first_name].blank? and notice.blank?
      notice = _('Please_enter_first_name')
    end

    if params[:last_name].blank? and notice.blank?
      notice = _('Please_enter_last_name')
    end

    if (params[:country_id].blank? or !Direction.find(:first, :conditions => {:id => params[:country_id]})) and notice.blank?
      notice = _('Please_select_country')
    end

    if (params[:email].blank? or !Email.address_validation(params[:email])) and notice.blank?
      notice = _('Please_enter_email')
    end

    if !params[:email].to_s.blank? and Address.find(:first, :conditions => ['email=?', params[:email]]) and notice.blank?
      notice = _('This_email_address_is_already_in_use')
    end

    if params[:mob_phone].to_s.gsub(/[^0-9]/, "").length > 0 and notice.blank?
      if Callerid.count(:conditions => {:cli => params[:mob_phone].to_s.gsub(/[^0-9]/, "")}) > 0
        notice = _('User_with_mobile_phone_already_exists')
      end
    end

    if params[:phone].to_s.gsub(/[^0-9]/, "").length > 0 and notice.blank?
      if Callerid.count(:conditions => {:cli => params[:phone].to_s.gsub(/[^0-9]/, "")}) > 0
        notice = _('User_with_phone_already_exists')
      end
    end

    if params[:fax].to_s.gsub(/[^0-9]/, "").length > 0 and notice.blank?
      if Callerid.count(:conditions => {:cli => params[:fax].to_s.gsub(/[^0-9]/, "")}) > 0
        notice = _('User_with_fax_already_exists')
      end
    end

    if (!params[:device_type] or !['SIP', 'IAX2'].include?(params[:device_type])) and notice.blank?
      notice = _('Enter_device_type')
    end

    u = User.find(:first, :conditions => ["uniquehash = ?", params[:id]])
    if (!params[:id] or !u) and notice.blank?
      notice = _('Dont_be_so_smart')
    else
      if (!Tariff.find(:first, :conditions => {:owner_id => u.id}) or !Tariff.find(:first, :conditions => {:id => Confline.get_value('Default_user_tariff_id', u.id)})) and notice.blank?
        notice = _('Tariff_not_found_cannot_create')
      end
      #if u.usertype != 'reseller' and u.own_providers != 0
      u_id = u
      u_id = u = User.find(:first, :conditions => ["id=?", 0]) if u.usertype == 'reseller' and u.own_providers.to_i == 0
      if (!u_id.lcrs.find(:first) or !u_id.lcrs.find(:first, :conditions => {:id => Confline.get_value('Default_user_lcr_id', u_id.id)})) and notice.blank?
        notice = _('Lcr_not_found_cannot_create')
      end
      #end
    end

    if Confline.mor_11_extended? and notice.blank? and Confline.get_value("Registration_Enable_VAT_checking", u.id).to_i == 1
      if params[:vat_number] and params[:country_id]
        dr = Direction.find(:first, :conditions => {:id => params[:country_id]})
        if params[:vat_number].blank?
          if Confline.get_value("Registration_allow_vat_blank", u.id).to_i == 0
            notice = _('Please_fill_field_TAX_Registration_Number')
          end
        else
          if  dr and ['BG', 'CS', 'DA', 'DE', 'EL', 'EN', 'ES', 'ET', 'FI', 'FR', 'HU', 'IT', 'LT', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SL', 'SV'].include?(dr.code.to_s[0..1])
            notice = _('TAX_Registration_Number_is_not_valid') if  !User.check_vat_for_user(params[:vat_number], dr.code.to_s[0..1])
          end
        end
      end
    end

    return notice
  end

  def update_from_edit(params, current_user, tax_from_params, monitoring_a, rec_a, api = 0)
    user_old = self.dup

    if api == 1
      invoice = 0
      invoice += params[:i1].to_i if params[:i1]
      invoice += params[:i2].to_i if params[:i2]
      invoice += params[:i3].to_i if params[:i3]
      invoice += params[:i4].to_i if params[:i4]
      invoice += params[:i5].to_i if params[:i5]
      invoice += params[:i6].to_i if params[:i6]
      invoice += params[:i7].to_i if params[:i7]
      invoice += params[:i8].to_i if params[:i8]
      send_invoice_types = invoice if params[:i1] or params[:i2] or params[:i3] or params[:i4] or params[:i5] or params[:i6] or params[:i7] or params[:i8]
    else
      i1=params[:i1]
      i2=params[:i2]
      i3=params[:i3]
      i4=params[:i4]
      i5=params[:i5]
      i6=params[:i6]
      i7=params[:i7]
      i8=params[:i8]
      invoice = i1.to_i+i2.to_i+i3.to_i+i4.to_i+i5.to_i+i6.to_i+i7.to_i+i8.to_i
      send_invoice_types = invoice
    end

    update_attributes(current_user.safe_attributtes(params[:user], id))

    Action.add_action_hash(current_user.id, {:action => 'user_edited', :target_id => id, :target_type => "user"})
    if api == 1
      if params[:unlimited] and params[:unlimited].to_i == 1
        self.credit = -1
      else
        self.credit = params[:credit].to_f if params[:credit]
        self.credit = 0 if credit < 0 if params[:credit]
      end
    else
      if params[:unlimited].to_i == 1 and params[:user][:postpaid] == 1
        self.credit = -1
      else
        self.credit = params[:credit].to_f
        self.credit = 0 if credit < 0
      end

      if postpaid? and Confline.mor_11_extended?
        #prepaid user cannot have minimal charge enabled
        #if minimal charge is 0 it means it is disabled
        #so if minimal charge is not numeric or was not even supplied we convert
        #it to 0 and dont bother any more.
        #view should take case that passed value is numeric or empty string,
        #so no need to check for that either.
        #but minimal charge daytime must be supplied if minimal charge is enabled.
        #if it is disabled set datetime to nil
        self.minimal_charge = params[:minimal_charge_value].to_i
        if params[:user][:postpaid] == 0
          self.minimal_charge = 0
          self.minimal_charge_start_at = nil
        elsif params[:minimal_charge_value].to_i != 0 and params[:minimal_charge_date]
          self.year = params[:minimal_charge_date][:year].to_i
          self.month = params[:minimal_charge_date][:month].to_i
          self.minimal_charge_start_at = Date.new(year, month, 1)
        elsif params[:minimal_charge_value].to_i == 0
          self.minimal_charge_start_at = nil
        else
          #set to current datetime, when saveing model, it should cause error
          #because when minimal charge is disabled datetime should be disabled
          self.minimal_charge_start_at = Date.new(Time.now.year, Time.now.month, 1)
        end
      end
    end

    if self and user_old
      if tariff_id.to_i != user_old.tariff_id.to_i
        tariff = nil
        tariff = Tariff.find(:first, :conditions => ["id = ?", tariff_id.to_i]) if self and tariff_id.to_i > 0
        !tariff ? tariff_name = "" : tariff_name = tariff.name

        tariff_old = nil
        tariff_old = Tariff.find(:first, :conditions => ["id = ?", user_old.tariff_id.to_i]) if user_old and user_old.tariff_id.to_i > 0
        !tariff_old ? tariff_old_name = "" : tariff_old_name = tariff_old.name

        Action.add_action_hash(current_user.id, {:action => 'user_tariff_changed', :target_id => id, :target_type => "user", :data => tariff_old_name, :data2 => tariff_name})
      end

      if user_old.user_type != user_type
        Action.add_action_hash(current_user.id, {:action => 'user_type_change_to', :target_id => id, :target_type => "user", :data => user_type})
      end

      if user_old.postpaid != postpaid
        Action.add_action_hash(current_user.id, {:action => 'postpaid_change_to', :target_id => id, :target_type => "user", :data => postpaid})
      end

      if user_old.credit != credit
        Action.add_action_hash(current_user.id, {:action => 'user_credit_change', :target_id => id, :target_type => "user", :data => user_old.credit, :data2 => credit})
      end

      if user_old.lcr_id != lcr_id
        Action.add_action_hash(current_user.id, {:action => 'user_lcr_change', :target_id => id, :target_type => "user", :data => user_old.lcr_id, :data2 => lcr_id})
      end

      update_voicemail_boxes if (user_old.first_name != first_name) or (user_old.last_name != last_name)
    end

    self.password = Digest::SHA1.hexdigest(params[:password][:password]) if params[:password] and !params[:password][:password].blank?

    if api == 1
      if params[:agr_date][:year] and params[:agr_date][:month] and params[:agr_date][:day]
        self.agreement_date = params[:agr_date][:year].to_s + "-" + params[:agr_date][:month].to_s + "-" + params[:agr_date][:day].to_s
      end
    else
      self.agreement_date = params[:agr_date][:year].to_s + "-" + params[:agr_date][:month].to_s + "-" + params[:agr_date][:day].to_s
    end

    if api == 1
      if params[:block_at_date][:year] and params[:block_at_date][:month] and params[:block_at_date][:day]
        self.block_at = params[:block_at_date][:year].to_s + "-" + params[:block_at_date][:month].to_s + "-" + params[:block_at_date][:day].to_s
      end
    else
      self.block_at = params[:block_at_date][:year].to_s + "-" + params[:block_at_date][:month].to_s + "-" + params[:block_at_date][:day].to_s
    end


    if api == 1
      self.block_at_conditional = params[:block_at_conditional].to_i if  params[:block_at_conditional]
    else
      self.block_at_conditional = params[:block_at_conditional].to_i
    end


    if api == 1
      self.allow_loss_calls = params[:allow_loss_calls].to_i if params[:allow_loss_calls]
    else
      self.allow_loss_calls = params[:allow_loss_calls].to_i
    end

    if api == 1
      self.warning_email_active = params[:warning_email_active].to_i if params[:warning_email_active]
    else
      self.warning_email_active = params[:warning_email_active].to_i
    end

    if api == 1
      if params[:warning_email_balance]
        if warning_email_balance.to_f != params[:warning_email_balance].to_f
          self.warning_email_sent = 0
        end
      end
    else
      if warning_email_balance.to_f != params[:warning_email_balance].to_f
        self.warning_email_sent = 0
      end
    end

    if api == 1
      self.invoice_zero_calls = params[:show_zero_calls].to_i if params[:show_zero_calls]
    else
      self.invoice_zero_calls = params[:show_zero_calls].to_i
    end


    #provider = params[:provider].to_i

    #self.tax = Tax.new(tax_from_params)
    #self.tax.save

    unless self.tax
      self.assign_default_tax
    end

    self.tax.update_attributes(tax_from_params)
    self.tax.save

    if is_reseller?
      if api == 1
        self.own_providers = params[:own_providers].to_i if params[:own_providers]
      else
        self.own_providers = params[:own_providers].to_i
      end

    end

    # this piece of code is not necessary because following code changes lcr_id for all user of reseller
    #change LCR for all users of reseller
    if is_reseller? and own_providers.to_i == 0

      Action.add_action_hash(current_user.id, {:action => 'reseller_lcr_change', :target_id => id, :target_type => "user", :data => user_old.lcr_id, :data2 => lcr_id})


      User.find(:all, :conditions => ["owner_id = ?", id]).each { |res_user|
        res_user.lcr_id = lcr_id
        res_user.save
      }

      Cardgroup.find(:all, :conditions => ["owner_id = ?", id]).each { |cg|
        cg.lcr_id =lcr_id
        cg.save
      }

      clean_after_own_providers_disable
    end

    if monitoring_a
      if api == 1
        self.ignore_global_monitorings = params[:ignore_global_monitorings].to_i if params[:ignore_global_monitorings]
      else
        self.ignore_global_monitorings = params[:ignore_global_monitorings].to_i
      end
    end
    if api == 1
      self.block_conditional_use = params[:block_conditional_use].to_i if params[:block_conditional_use]
    else
      self.block_conditional_use = params[:block_conditional_use].to_i
    end


    if rec_a
      if api == 1
        self.recording_enabled = params[:recording_enabled].to_i if params[:recording_enabled]
      else
        self.recording_enabled = params[:recording_enabled].to_i
      end

      if api == 1
        self.recording_forced_enabled = params[:recording_forced_enabled].to_i if params[:recording_forced_enabled]
      else
        self.recording_forced_enabled = params[:recording_forced_enabled].to_i
      end

      if api == 1
        self.recording_hdd_quota = params[:user][:recording_hdd_quota].to_f * 1048576 if  params[:user][:recording_hdd_quota]
      else
        self.recording_hdd_quota = params[:user][:recording_hdd_quota].to_f * 1048576
      end

    end

    if address
      address.update_attributes(params[:address])
    else
      a = Address.create(params[:address])
      self.address_id = a.id
    end


    if params[:warning_email_active]
      if params[:user] and params[:date]
        self.warning_email_hour = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:user_warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
      end
    end

    self.save
    return self
  end

  def warning_email_hour
    b = read_attribute(:warning_email_hour)
    if b != -1
      c = b.to_f + time_zone.to_f - User.system_time_offset.to_f
      b = c.to_i > 24 ? c - 24 : c
      b = c.to_i < 0 ? c + 24 : b
    else
      b
    end
    b
  end

  def warning_email_hour= value
    if value != -1
      b = value.to_f - time_zone.to_f + User.system_time_offset.to_f
      c = b.to_i > 24 ? b - 24 : b
      c = b.to_i < 0 ? b + 24 : c
    else
      c = value
    end
    write_attribute(:warning_email_hour, c)
  end


  def validate_from_update(current_user, params, allow_edit, api = 0)
    notice = ''
    co = current_user.is_accountant? ? 0 : current_user.id
    if current_user.is_accountant? and !allow_edit
      notice = _('You_have_no_editing_permission')
    end

    if current_user.is_reseller? and !params[:user][:usertype].blank? and params[:user][:usertype].to_s != "user"
      notice = _('Dont_be_so_smart')
    end

    if current_user.is_accountant? and !params[:user][:usertype].blank? and params[:user][:usertype] == "admin"
      notice = _('Dont_be_so_smart')
    end

    if !params[:user][:tariff_id].blank? and !Tariff.find(:first, :conditions => {:id => params[:user][:tariff_id], :owner_id => co})
      notice = _('Tariff_not_found')
    end

    params[:user] = params[:user].each_value(&:strip!)
    params[:address] = params[:address].each_value(&:strip!) if params[:address]

    params[:user].delete(:balance)
    if api == 1
      if  params[:user][:generate_invoice]
        params[:user][:generate_invoice].to_i == 1 ? params[:user][:generate_invoice] = 1 : params[:user][:generate_invoice] = 0
      end
    else
      params[:user][:generate_invoice].to_i == 1 ? params[:user][:generate_invoice] = 1 : params[:user][:generate_invoice] = 0
    end


    #my_debug  "generate_invoice: " +  params[:user][:generate_invoice].to_s
    if api == 1
      if params[:user][:cyberplat_active]
        params[:cyberplat_active].to_i == 1 ? params[:user][:cyberplat_active] = 1 : params[:user][:cyberplat_active] = 0
      end
    else
      params[:cyberplat_active].to_i == 1 ? params[:user][:cyberplat_active] = 1 : params[:user][:cyberplat_active] = 0
    end


    if params[:user][:call_limit]
      params[:user][:call_limit]=params[:user][:call_limit].strip
      if params[:user][:call_limit].to_i < 0
        params[:user][:call_limit] = 0
      end
    end

    if api == 1
      if ["accountant", "reseller"].include?(params[:user][:usertype]) and params[:accountant_type]
        params[:user][:acc_group_id] = params[:accountant_type].to_i
      end
    else
      if ["accountant", "reseller"].include?(params[:user][:usertype])
        params[:user][:acc_group_id] = params[:accountant_type].to_i
      else
        params[:user][:acc_group_id] = 0
      end
    end

    # privacy
    if api == 1

      if params[:privacy]
        if !params[:privacy][:gui] and !params[:privacy][:csv] and !params[:privacy][:pdf]
          if params[:privacy][:global].to_i == 1
            params[:user][:hide_destination_end] = -1
          end
        else
          params[:user][:hide_destination_end] = params[:privacy].values.sum { |v| v.to_i }
        end
      end

    else
      if params[:privacy]
        if params[:privacy][:global].to_i == 1
          params[:user][:hide_destination_end] = -1
        else
          params[:user][:hide_destination_end] = params[:privacy].values.sum { |v| v.to_i }
        end
      end
    end


    if params[:usertype] and !['user', 'accountant', 'reseller'].include?(params[:usertype])
      params[:usertype] = usertype
    end

    ['tax2_enabled', 'tax3_enabled', 'tax4_enabled', 'own_providers', 'recording_enabled', 'recording_forced_enabled', 'compound_tax', 'show_zero_calls', 'unlimited', 'ignore_global_monitorings', 'block_conditional_use', 'warning_email_active'].each { |p|
      if params[p.to_sym].to_i > 0
        params[p.to_sym] = 1
      else
        params[p.to_sym] = 0 if params[p.to_sym]
      end
    }

    params[:user][:warning_balance_call] = params[:user][:warning_balance_call].to_i > 0 ? 1 : 0 if params[:user][:warning_balance_call]
    params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i > 0 ? 1 : 0 if params[:user][:generate_invoice]
    params[:user][:postpaid] = params[:user][:postpaid].to_i > 0 ? 1 : 0 if params[:user][:postpaid]
    params[:user][:hidden] = params[:user][:hidden].to_i > 0 ? 1 : 0 if params[:user][:hidden]
    params[:user][:blocked] = params[:user][:blocked].to_i > 0 ? 1 : 0 if params[:user][:blocked]
    params[:privacy][:global] = params[:privacy][:global].to_i > 0 ? 1 : 0 if params[:privacy]

    if current_user.is_accountant?
      s ={}
      group = current_user.acc_group
      rights = AccRight.find(
          :all,
          :select => "acc_rights.name, acc_group_rights.value",
          :joins => "LEFT JOIN acc_group_rights ON (acc_group_rights.acc_right_id = acc_rights.id AND acc_group_rights.acc_group_id = #{group.id})",
          :conditions => "acc_rights.right_type = 'accountant'"
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

      params = current_user.sanitize_user_params_by_accountant_permissions(s, params, self.dup)
      #'user[warning_balance_call]', 'user[generate_invoice]', 'privacy[global]',
    end

    return notice, params
  end

  def sanitize_user_params_by_accountant_permissions(session, params, user = nil)
    if is_accountant?
      if session[:acc_user_create_opt_1] != 2
        params[:password] = nil
      end
      {:acc_user_create_opt_2 => [:usertype],
       :acc_user_create_opt_3 => [:lcr_id],
       :acc_user_create_opt_4 => [:tariff_id],
       :acc_user_create_opt_5 => [:balance],
       :acc_user_create_opt_6 => [:postpaid, :hidden],
       :acc_user_create_opt_7 => [:call_limit]
      }.each { |option, fields|
        fields.each { |field| params[:user].except!(field) if session[option] != 2 }
      }
      params[:password] = nil if user and user.usertype == "admin"
    end
    params
  end

  def sanitize_device_params_by_accountant_permissions(session, params, user = nil)
    if is_accountant?
      params[:device] = params[:device].except(:pin) if session[:acc_device_pin].to_i != 2 if params[:device]
      params[:device] = params[:device].except(:extension) if session[:acc_device_edit_opt_1] != 2 if params[:device]
      if session[:acc_device_edit_opt_2] != 2 and params[:device]
        params[:device] = params[:device].except(:name)
        params[:device] = params[:device].except(:secret)
      end
      params = params.except(:cid_name) if session[:acc_device_edit_opt_3] != 2 if !params.blank?
      params = params.except(:cid_number) if session[:acc_device_edit_opt_4] != 2 if !params.blank?
    end
    params
  end


  def dids_for_select(status = nil)
    cond = ["dids.id > 0"]
    var = []
    cond << "dids.reseller_id = ?" and var << id if usertype == 'reseller'
    cond << "status = '#{status}' and reseller_id = 0" if !status.blank? and status == 'free'
    cond << "device_id != 0 or dialplan_id != 0" if !status.blank? and status == 'assigned'
    Did.find(:all, :conditions => [cond.join(" AND ")].concat(var), :order => "dids.did ASC")
  end

  def show_active_calls?
    (['user', 'reseller'].include?(usertype) and Confline.get_value("Show_Active_Calls_for_Users").to_i == 1) or ['admin', 'accountant'].include?(usertype)
  end

  def check_translation
    trans = Translation.find(:all, :joins => "LEFT JOIN (select translation_id from user_translations where user_id = #{id}) as ua ON (translations.id = translation_id )", :conditions => "ua.translation_id is null")
    if trans and trans.size.to_i > 0
      trans.each { |t|
        u = UserTranslation.new({:translation_id => t.id, :user_id => id, :position => t.position, :active => 0})
        u.save
      }
    end
  end

  def user_time(time)
    time + time_offset.hour
  end

  #class << self # Class methods
  #  alias :all_columns :columns
  #  def columns
  #    all_columns.reject {|c| c.name == 'time_zone'}
  #  end
  #end

  def time_zone
    self[:time_zone]
  end

  def time_zone=(s)
    self[:time_zone] = s
  end

=begin
 *Returns*
  integer - difference in hours between user time and system time
=end
  def time_offset
    time_zone - User.system_time_offset.to_i
  end

  def system_time(time, only_date = 0)
    t = time.class == 'Time' ? time : time.to_time
    if only_date == 0
      (t - time_zone.hour + User.system_time_offset.to_i.hour).to_s(:db)
    else
      (t - time_zone.hour + User.system_time_offset.to_i.hour).to_date.to_s(:db)
    end
  end


  def User.get_zones
    # Keys are Rails TimeZone names, values are TZInfo identifiers
    m = [
        ["(GMT-11:00) International Date Line West, Midway Island, Samoa", "International Date Line West", -11.0],
        #["(GMT-11:00) Midway Island"	,	"Midway Island", -11],
        #["(GMT-11:00) Samoa"	,	"Samoa", -11],
        ["(GMT-10:00) Hawaii", "Hawaii", -10.0],
        ["(GMT-09:00) Alaska", "Alaska", -9.0],
        ["(GMT-08:00) Pacific Time (US & Canada), Tijuana", "Pacific Time (US & Canada)", -8.0],
        #["(GMT-08:00) Tijuana"	,	"Tijuana", -8],
        ["(GMT-07:00) Arizona, Chihuahua, Mazatlan, Mountain Time (US & Canada)", "Arizona", -7.0],
        #["(GMT-07:00) Chihuahua"	,	"Chihuahua", -7],
        #["(GMT-07:00) Mazatlan"	,	"Mazatlan", -7],
        #["(GMT-07:00) Mountain Time (US & Canada)"	,	"Mountain Time (US & Canada)", -7],
        ["(GMT-06:00) Central Time (US & Canada), Guadalajara, Mexico City, Saskatchewan", "Central America", -6.0],
        #["(GMT-06:00) Central Time (US & Canada)"	,	"Central Time (US & Canada)", -6],
        #["(GMT-06:00) Guadalajara"	,	"Guadalajara", -6],
        #["(GMT-06:00) Mexico City"	,	"Mexico City", -6],
        #["(GMT-06:00) Monterrey"	,	"Monterrey", -6],
        #["(GMT-06:00) Saskatchewan"	,	"Saskatchewan", -6],
        ["(GMT-05:00) Bogota, Eastern Time (US & Canada), Indiana (East), Lima, Quito", "Bogota", -5.0],
        #["(GMT-05:00) Eastern Time (US & Canada)"	,	"Eastern Time (US & Canada)", -5],
        #["(GMT-05:00) Indiana (East)"	,	"Indiana (East)", -5],
        #["(GMT-05:00) Lima"	,	"Lima", -5],
        #["(GMT-05:00) Quito"	,	"Quito", -5],
        ["(GMT-04:30) Caracas", "Caracas", -4.5],
        ["(GMT-04:00) Atlantic Time (Canada), Georgetown, La Paz, Santiago", "Atlantic Time (Canada)", -4.0],
        #			["(GMT-04:00) Georgetown"	,	"Georgetown", -4],
        #			["(GMT-04:00) La Paz"	,	"La Paz", -4],
        #			["(GMT-04:00) Santiago"	,	"Santiago", -4],
        ["(GMT-03:30) Newfoundland", "Newfoundland", -3.5],
        ["(GMT-03:00) Brasilia, Buenos Aires, Greenland", "Brasilia", -3.0],
        #			["(GMT-03:00) Buenos Aires"	,	"Buenos Aires", -3],
        #			["(GMT-03:00) Greenland"	,	"Greenland", -3],
        ["(GMT-02:00) Mid-Atlantic", "Mid-Atlantic", -2.0],
        ["(GMT-01:00) Azores, Cape Verde Is", "Azores", -1.0],
        #			["(GMT-01:00) Cape Verde Is."	,	"Cape Verde Is.", -1],
        ["(GMT+00:00) Casablanca, Dublin, Edinburgh, Lisbon, London, Monrovia", "Casablanca", 0.0],
        #			["(GMT+00:00) Dublin"	,	"Dublin", 0],
        #			["(GMT+00:00) Edinburgh"	,	"Edinburgh", 0],
        #			["(GMT+00:00) Lisbon"	,	"Lisbon", 0],
        #			["(GMT+00:00) London"	,	"London", 0],
        #			["(GMT+00:00) Monrovia"	,	"Monrovia", 0],
        #["(GMT+00:00) UTC"	,	"UTC", 0],
        ["(GMT+01:00) Amsterdam, Belgrade, Berlin, Madrid, Paris, Prage,  Rome ", "Amsterdam", 1.0],
        #			["(GMT+01:00) Belgrade"	,	"Belgrade", 1],
        #			["(GMT+01:00) Berlin"	,	"Berlin", 1],
        #			["(GMT+01:00) Bern"	,	"Bern", 1],
        #			["(GMT+01:00) Bratislava"	,	"Bratislava", 1],
        #			["(GMT+01:00) Brussels"	,	"Brussels",1],
        #			["(GMT+01:00) Budapest"	,	"Budapest",1],
        #			["(GMT+01:00) Copenhagen"	,	"Copenhagen",1],
        #			["(GMT+01:00) Ljubljana"	,	"Ljubljana",1],
        #			["(GMT+01:00) Madrid"	,	"Madrid",1],
        #			["(GMT+01:00) Paris"	,	"Paris",1],
        #			["(GMT+01:00) Prague"	,	"Prague",1],
        #			["(GMT+01:00) Rome"	,	"Rome",1],
        #			["(GMT+01:00) Sarajevo"	,	"Sarajevo",1],
        #			["(GMT+01:00) Skopje"	,	"Skopje",1],
        #			["(GMT+01:00) Stockholm"	,	"Stockholm",1],
        #			["(GMT+01:00) Vienna"	,	"Vienna",1],
        #			["(GMT+01:00) Warsaw"	,	"Warsaw",1],
        #			["(GMT+01:00) West Central Africa"	,	"West Central Africa",1],
        #			["(GMT+01:00) Zagreb"	,	"Zagreb",1],
        ["(GMT+02:00) Athens, Cairo, Helsinki, Istanbul, Kyiv, Minsk, Riga, Tallinn, Vilnius", "Athens", 2.0],
        #			["(GMT+02:00) Bucharest"	,	"Bucharest",2],
        #			["(GMT+02:00) Cairo"	,	"Cairo",2],
        #			["(GMT+02:00) Harare"	,	"Harare",2],
        #			["(GMT+02:00) Helsinki"	,	"Helsinki",2],
        #			["(GMT+02:00) Istanbul"	,	"Istanbul",2],
        #			["(GMT+02:00) Jerusalem"	,	"Jerusalem",2],
        #			["(GMT+02:00) Kyiv"	,	"Kyiv",2],
        #			["(GMT+02:00) Minsk"	,	"Minsk",2],
        #			["(GMT+02:00) Pretoria"	,	"Pretoria",2],
        #			["(GMT+02:00) Riga"	,	"Riga",2],
        #			["(GMT+02:00) Sofia"	,	"Sofia",2],
        #			["(GMT+02:00) Tallinn"	,	"Tallinn",2],
        #			["(GMT+02:00) Vilnius"	,	"Vilnius",2],
        ["(GMT+03:00) Baghdad, Kuwait, Nairobi, Riyadh", "Baghdad", 3.0],
        #			["(GMT+03:00) Kuwait"	,	"Kuwait",3],
        #			["(GMT+03:00) Nairobi"	,	"Nairobi",3],
        #			["(GMT+03:00) Riyadh"	,	"Riyadh",3],
        ["(GMT+03:30) Tehran", "Tehran", 3.5],
        ["(GMT+04:00) Abu Dhabi, Baku, Moscow, Muscat, Tbilisi, Volgograd, Yerevan", "Abu Dhabi", 4.0],
        #			["(GMT+04:00) Baku"	,	"Baku",4],
        #			["(GMT+04:00) Moscow"	,	"Moscow",4],
        #			["(GMT+04:00) Muscat"	,	"Muscat",4],
        #			["(GMT+04:00) St. Petersburg"	,	"St. Petersburg",4],
        #			["(GMT+04:00) Tbilisi"	,	"Tbilisi",4],
        #			["(GMT+04:00) Volgograd"	,	"Volgograd",4],
        #			["(GMT+04:00) Yerevan"	,	"Yerevan",4],
        #["(GMT+04:30) Kabul"	,	"Kabul",4.5],
        ["(GMT+05:00) Islamabad, Karachi, Tashkent", "Islamabad", 5.0],
        #			["(GMT+05:00) Karachi"	,	"Karachi",5],
        #			["(GMT+05:00) Tashkent"	,	"Tashkent",5],
        ["(GMT+05:30) Chennai, Kolkata, Mumbai, New Delhi, Sri Jayawardenepura", "Chennai", 5.5],
        #["(GMT+05:30) Kolkata"	,	"Kolkata",5.5],
        #["(GMT+05:30) Mumbai"	,	"Mumbai",5.5],
        #["(GMT+05:30) New Delhi"	,	"New Delhi",5.5],
        #["(GMT+05:30) Sri Jayawardenepura"	,	"Sri Jayawardenepura",5.5],
        ["(GMT+05:45) Kathmandu", "Kathmandu", 5.75],
        ["(GMT+06:00) Almaty, Astana, Dhaka, Ekaterinburg", "Almaty", 6.0],
        #			["(GMT+06:00) Astana"	,	"Astana",6],
        #			["(GMT+06:00) Dhaka"	,	"Dhaka",6],
        #			["(GMT+06:00) Ekaterinburg"	,	"Ekaterinburg",6],
        ["(GMT+06:30) Rangoon", "Rangoon", 6.5],
        ["(GMT+07:00) Bangkok, Hanoi, Jakarta, Novosibirsk", "Bangkok", 7.0],
        #			["(GMT+07:00) Hanoi"	,	"Hanoi",7],
        #			["(GMT+07:00) Jakarta"	,	"Jakarta",7],
        #			["(GMT+07:00) Novosibirsk"	,	"Novosibirsk",7],
        ["(GMT+08:00) Beijing, Hong Kong, Krasnoyarsk, Kuala Lumpur, Perth, Singapore, Taipei", "Beijing", 8.0],
        #			["(GMT+08:00) Chongqing"	,	"Chongqing",8],
        #			["(GMT+08:00) Hong Kong"	,	"Hong Kong",8],
        #			["(GMT+08:00) Krasnoyarsk"	,	"Krasnoyarsk",8],
        #			["(GMT+08:00) Kuala Lumpur"	,	"Kuala Lumpur",8],
        #			["(GMT+08:00) Perth"	,	"Perth",8],
        #			["(GMT+08:00) Singapore"	,	"Singapore",8],
        #			["(GMT+08:00) Taipei"	,	"Taipei",8],
        #			["(GMT+08:00) Ulaan Bataar"	,	"Ulaan Bataar",8],
        #			["(GMT+08:00) Urumqi"	,	"Urumqi",8],
        ["(GMT+09:00) Irkutsk, Osaka, Sapporo, Seoul, Tokyo", "Irkutsk", 9.0],
        #			["(GMT+09:00) Osaka"	,	"Osaka",9],
        #			["(GMT+09:00) Sapporo"	,	"Sapporo",9],
        #			["(GMT+09:00) Seoul"	,	"Seoul",9],
        #			["(GMT+09:00) Tokyo"	,	"Tokyo",9],
        ["(GMT+09:30) Adelaide, Darwin", "Adelaide", 9.5],
        #["(GMT+09:30) Darwin"	,	"Darwin",9.5],
        ["(GMT+10:00) Brisbane, Canberra, Hobart, Melbourne, Port Moresby, Sydney, Yakutsk", "Brisbane", 10.0],
        #			["(GMT+10:00) Canberra"	,	"Canberra",10],
        #			["(GMT+10:00) Guam"	,	"Guam",10],
        #			["(GMT+10:00) Hobart"	,	"Hobart",10],
        #			["(GMT+10:00) Melbourne"	,	"Melbourne",10],
        #			["(GMT+10:00) Port Moresby"	,	"Port Moresby",10],
        #			["(GMT+10:00) Sydney"	,	"Sydney",10],
        #			["(GMT+10:00) Yakutsk"	,	"Yakutsk",10],
        ["(GMT+11:00) New Caledonia, Vladivostok", "New Caledonia", 11.0],
        #			["(GMT+11:00) Vladivostok"	,	"Vladivostok",11],
        ["(GMT+12:00) Auckland, Fiji, Kamchatka, Magadan, Marshall Is., Solomon Is., Wellington", "Auckland", 12.0],
        #			["(GMT+12:00) Fiji"	,	"Fiji",12],
        #			["(GMT+12:00) Kamchatka"	,	"Kamchatka",12],
        #			["(GMT+12:00) Magadan"	,	"Magadan",12],
        #			["(GMT+12:00) Marshall Is."	,	"Marshall Is.",12],
        #			["(GMT+12:00) Solomon Is."	,	"Solomon Is.",12],
        #			["(GMT+12:00) Wellington"	,	"Wellington",12],
        ["(GMT+13:00) Nuku'alofa", "Nuku'alofa", 13.0]]
    #}.each { |name, zone| name.freeze; zone.freeze }
    #m #.freeze.sort
  end

=begin rdoc
  check wheter user can see did in active calls. only admin has right to set this option, so
  what all users(resellers) will see depends only on admins settings

  *Returns*
  * +boolean+ - true or false depending on admin's settings
=end
  def active_calls_show_did?
    Confline.active_calls_show_did?
  end

  def alow_device_types_zap_virt
    return (usertype != "reseller" or (Confline.get_value("Resellers_Allow_Use_Zap_Device", 0).to_i != 0)), (usertype != "reseller" or (Confline.get_value("Resellers_Allow_Use_Virtual_Device", 0).to_i != 0))
  end

  def get_correct_owner_id
    if is_accountant? or is_admin?
      return 0
    elsif is_reseller?
      return id
    else
      return owner_id
    end
  end

  def get_corrected_owner_id
    (usertype == 'accountant' or usertype == 'admin') ? 0 : id
  end

  def get_price_calculation_sqls
    if is_reseller? or owner_id != 0
      up = SqlExport.user_price_sql
      rp = SqlExport.reseller_price_sql
      pp = SqlExport.reseller_provider_price_sql
    else
      up = SqlExport.admin_user_price_sql
      rp = SqlExport.admin_reseller_price_sql
      pp = SqlExport.admin_provider_price_sql
    end
    return up, rp, pp
  end

  def invoice_zero_calls_sql(up = 'calls.user_price')
    invoice_zero_calls.to_i == 0 ? " AND #{up} > 0 " : ""
  end

=begin
  Check whether postpaid user has unlimited credit.
  TODO: there is smth fishy in db, postpaid users user.credit is equals
  to -1. so guess what result would this method return if you would ask
  postpaid user whehter he has unlimited credit. TRUE!! but this is standard
  in mor, fixing this might break smth.
  TODO: should i raise exception if user is not prepaid? conceptualy
  prepaid user cannot event know about such thing as unlimited credit,
  he does not event have credit. this might break a lot of things.

  *Returns*
  +boolean+ true if user has unlimited credit number, otherwise false.
=end
  def credit_unlimited?
    #if prepaid?
    #  raise "Prepaid users do not have credit"
    credit == -1
  end

=begin
  Check whether user is of postpaid type

  *Returns*
  *boolean* - true or false depending on wheter user is postpaid
=end
  def postpaid?
    postpaid.to_i == 1
  end

=begin
  Check whether user is of prepaid type

  *Returns*
  *boolean* - true or false depending on wheter user is prepaid
=end
  def prepaid?
    not postpaid?
  end


=begin
  Information whether user is postpaid or prepaid in database is saved in database
  in as int - 0 for prepaid, 1 for postpaid. prepaid user cannot have any credit, so it
  is set to 0.
  Notice that 1)credit is set to 0 when user is set to prepaid and 2) when credit is set
  we check whether user is prepaid(and should rise exception) or not.
  TODO: should express to others that though i doublt whether it has any sense, cause user
  does not have credit(NULL, VOID etc), but not has credit equal to 0.
=end
  def set_prepaid
    credit = 0
    postpaid = 0
  end

=begin
  Information whether user is postpaid or prepaid in database is saved in database
  in as int - 0 for prepaid, 1 for postpaid. 
=end
  def set_postpaid
    postpaid = 1
  end

=begin
  Check whether minimal charge for this user is enabled

  *Returns*
  *boolean* - true or false depending on wheter minimal charge is enabled or disabled
=end
  def minimal_charge_enabled?
    minimal_charge != 0
  end


  # converted attributes for user in given currency exrate
  def converted_minimal_charge(exr)
    b = read_attribute(:minimal_charge)
    b.to_f * exr.to_f
  end

=begin
  Check whether minimal charge should be added to invoice. answer depends on whether
  minimal charge is enabled and whether invoice period is greater than setting when
  to start chargeing minimal amount. but user cannot definetly decide that - he knows
  only that minimal charge is enabled or not and that it would be logical to add minimal amount
  to invoice that's period ends earlyer than minimal charge starts.
  we're checking whether minimal_charge_start_at is not nill even when minimal_charge is enabled
  but there CANNOT be a situation where minimal charge is enabled, but date is not specified.

  *Returns*
  *boolean* - true or false depending whether minimal charge should be added to invoice
=end
  def add_on_minimal_charge? invoice_period_end
    minimal_charge_enabled? and minimal_charge_start_at and minimal_charge_start_at < invoice_period_end #Time.parse('2001-01-01 00:00:00') < invoice_period_end#Date.parse(minimal_charge_start_at) < invoice_period_end
  end

  def credit_notes(items_per_page=nil, offset=0, order_by='user_name', desc=1)
    condition = ['owner_id = ?', get_correct_owner_id]
    if ['user_name', 'number', 'issue_date', 'status', 'pay_date', 'price'].include? order_by
      order_by = order_by + " " + (desc == 1 ? "DESC" : "ASC")
    end
    if items_per_page
      CreditNote.find(:all, :include => :user, :conditions => condition, :limit => items_per_page, :offset => offset, :order => order_by)
    else
      CreditNote.find(:all, :include => :user, :conditions => condition, :order => order_by)
    end
  end

  def credit_note_count
    condition = ['owner_id = ?', get_correct_owner_id]
    CreditNote.count(:all, :include => :user, :conditions => condition)
  end

=begin
  Convert amount from user currency to system currency.
  Note to future developers - do not check whether user has associated currency,
  if he has not, this would be a major bug, all hell should brake loose.

  *Params*
  +value+ amount in user's currency

  *Returns*
  +value_in_system_currency+ float, amount converted to system currency
=end
  def to_system_currency(value)
    value.to_f / currency.exchange_rate.to_f
  end

=begin
  Check whether accountant user has rights to edit specified permission
  
  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +allow_edit+ boolean, true if accountant is allowed to edit
=end
  def accountant_allow_edit(permission)
    return accountant_right(permission) == 2
  end

=begin
  Check whether accountant user has rights to read specified permission
  
  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +allow_edit+ boolean, true if accountant is allowed to read
=end
  def accountant_allow_read(permission)
    return accountant_right(permission) > 0
  end

=begin
  Check whether reseller user has rights to read specified permission

  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +allow_edit+ boolean, true if accountant is allowed to read
=end
  def reseller_allow_read(permission)
    return reseller_right(permission) > 0
  end

  def reseller_right(permission)
    if not is_reseller?
      raise "User is not reseller"
    elsif acc_group
      right = acc_group.acc_group_rights.find(:first, :conditions => "acc_rights.name = '#{permission}'", :include => :acc_right)
      if right
        return right.value.to_i
      else
        return 0
      end
    else
      return 0
    end
  end

=begin
  Check what permission has accountant - read, write or disabled
  If user is not accountant exception will be rised.
  If user has no rights, this means that referential integrity in database is broken,
  but since it is normal in mor, jus return 0 meaning that user has no rights
  User might have acc group but some rights may be not added(or permissiona name was
  invalid) in that case return 0

  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +permission+ integer, value specified in database.

=end
  def accountant_right(permission)
    if not is_accountant?
      raise "User is not accountant"
    elsif acc_group
      right = acc_group.acc_group_rights.find(:first, :conditions => "acc_rights.name = '#{permission}'", :include => :acc_right)
      if right
        return right.value.to_i
      else
        return 0
      end
    else
      return 0
    end
  end

=begin
  Check whether reseller has any common use providers. It would be invalid to call
  this methon on user that cannot have providers, so exception should be rised.

  *Returns*
  +boolean+ true if reseller has common use providers, otherwise false
=end
  def has_own_providers?
    if is_reseller?
      common_use_provider_count > 0
    else
      raise "User is not reseller, he cannot have providers"
    end
  end

=begin
  Get users(resellers) that have only common to this user(reseller) providers. If this user has
  any own providers he it is not posible for him to have providers common with any other user. 
  If this user is not reseller raise an exception.

  *Returns*
  +Array of User instances+ all resellers that have common providers or nil if reseller has no
  other resellers that would have common providers.
=end
  def resellers_with_common_providers
    if is_reseller?
      if has_own_providers?
        return nil
      else
        #this query selects all resellers that have no own providers, hence
        #'usertype = 'reseller' AND provider_id IS NULL'
        #and joins them with common use providers of all resellers, hence that nasty
        #JOIN (SELECT ... GROUP BY reseller_id) provider_list
        #then we can filter only those users that have no own providers(but they have 
        #common use providers) by comparing 'lists' of common use providers with list
        #of 'self' common use provider 'list'.
        query = "SELECT users.*, provider_list 
                 FROM   users
                 LEFT JOIN providers ON(users.id = providers.user_id)
	         JOIN (SELECT reseller_id, 
                              GROUP_CONCAT(provider_id ORDER BY provider_id) provider_list
		       FROM   common_use_providers 
		       GROUP BY reseller_id) common_use_providers ON reseller_id = users.id
                 WHERE usertype = 'reseller' AND
                       users.id != #{id} AND
                       providers.id IS NULL AND
                       provider_list = (SELECT GROUP_CONCAT(provider_id ORDER BY provider_id) 
                                        FROM   common_use_providers 
                                        WHERE reseller_id = #{id}
                                        GROUP BY reseller_id)"
        User.find_by_sql(query)
      end
    else
      raise "User is not reseller, he cannot have providers"
    end
  end

  def integrity_recheck_user
    default_user_warning = false

    df = Confline.get_default_user_pospaid_errors
    default_user_warning = true if df and df.size.to_i > 0 #Confline.get_value('Default_User_allow_loss_calls', id).to_i == 1 and Confline.get_value('Default_User_postpaid', id).to_i == 1

    users_postpaid_and_loss_calls = User.find(:all, :conditions => ["postpaid = 1 and allow_loss_calls = 1"])

    if users_postpaid_and_loss_calls.size > 0 or default_user_warning
      return 1
    else
      Confline.set_value("Integrity_Check", 0)
      return 0
    end

  end

  def User.check_vat_for_user(vat = '', country = '')
    out = false
    begin
      b = URI.parse('http://ec.europa.eu/taxation_customs/vies/viesquer.do')
      http = Net::HTTP.new(b.host, b.port)
      request = Net::HTTP::Post.new(b.request_uri)
      request.set_form_data({'ms' => country, 'vat' => vat, 'iso' => country, 'requesterMs' => '', 'requesterIso' => '---', 'requesterVat' => ''})
      response = http.request(request)
      out = response.body.include?('Yes, valid VAT number')
    rescue

    end

    return out
  end

  def blocked?;
    blocked == 1;
  end


=begin
  Add some amount to user's balance.
  Note that after changeing balance we immediately save data to database, since we dont use
  transactions that's least what we should do. If adding amount to balance or creating
  payment fails - we do our best to revert everything... but still without using
  transactions there are lot's of ways to fail.
  Note that amount is expected to be in system's default currency, if not payment amount
  might be giberish.

  *Params*
  +amount+ amount to be added to balance and payment created with amount and tax in
   this users currency.

  *Returns*
  +boolean+ true changeing balance and creating payment succeeded, otherwise false.
     Note that no transactions are used, so if smth goes wrong data might be corrupted.
=end
  def add_to_balance(amount)
    self.balance += amount
    if self.save
      exchange_rate = Currency.count_exchange_rate(Currency.get_default.name, currency.name)
      amount *= exchange_rate
      logger.fatal amount
      tax_amount = self.get_tax.count_tax_amount(amount)
      logger.fatal tax_amount
      payment = Payment.create_for_user(self, {:paymenttype => 'Manual', :amount => amount, :tax => tax_amount, :shipped_at => Time.now, :date_added => Time.now, :completed => 1, :currency => currency.name})
      if payment.save
        return true
      else
        self.balance -= amount
        self.save
        return false
      end
    else
      return false
    end
  end


  private

=begin
  Number of common use providers that this user can use. Only reseller can have common use
  providers, returning something as nil, false, 0 would not be appropriat if this user cannot
  have providers at all, in that case we raise exception.

  *Returns*
  +integer+ 0 or more depending on how much common use providers are associated with reseller
=end
  def common_use_provider_count
    if is_reseller?
      Provider.count(:all, :conditions => ["user_id = #{id}"]).to_i
    else
      raise "User is not reseller, he cannot have providers"
    end
  end

  def block_and_send_email
    users = [self, owner]
    em= Email.find(:first, :conditions => ["name = 'block_when_no_balance' AND owner_id = ?", owner_id])
    variables = Email.email_variables(self)
    num = EmailsController::send_email(em, Confline.get_value("Email_from", owner_id), users, variables)

    # num = Email.send_email(em, users, Confline.get_value("Email_from", owner_id), 'send_email', {:assigns=>variables, :owner=>variables[:owner]})
    if num.to_s != _('Email_sent')
      Action.add_action2(id, "error", 'Cant_send_email', num.to_s)
    end
    Action.new(:user_id => id, :date => Time.now, :action => "user_blocked", :data => "insufficient funds").save
    blocked = 1
  end

  def save_with_balance;
    @save_with_balance_record;
  end

  def clean_after_own_providers_disable
    lcrs = Lcr.find(:all, :conditions => {:user_id => id})
    if lcrs
      lcrs.each { |l|
        lrules= Locationrule.find(:all, :conditions => "lcr_id='#{l.id}'")
        lrules.each { |lr| lr.destroy } if lrules
        lpt = l.lcr_partials
        lpt.each { |t| t.destroy } if lpt
        l.destroy }
    end
  end


end
