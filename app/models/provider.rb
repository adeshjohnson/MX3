# -*- encoding : utf-8 -*-
class Provider < ActiveRecord::Base

  include SqlExport

  belongs_to :tariff
  belongs_to :device
  belongs_to :terminator
  has_many :providerrules
  has_many :calls
  has_many :dids
  belongs_to :device
  belongs_to :user
  has_many :lcrproviders
  has_many :common_use_providers
  has_many :serverproviders

  attr_protected :user_id
  attr_accessor :old_register_record
  attr_accessor :old_register_extension_record
  attr_accessor :old_register_line_record

  # old validates_format_of :server_ip, :with => /(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)?$)|dynamic/ , :message =>  _("Hostname_is_not_valid")
  validates_format_of :server_ip, :with => /(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$)|^dynamic$|^$/, :message => _("Hostname_is_not_valid")
  validates_presence_of :name, :message => _("Provider_should_have_name")
  validates_format_of :port, :with => /^\d+$|^$/, :message => _("Provider_port_is_not_valid")
  validates_uniqueness_of :name, :message => _('Provider_Name_Must_Be_Unique')
  #skype provider must have skype name, no blank field allowed
  validates_presence_of :login, :message => _("Skype_provider_should_have_name"), :if => lambda { |o| o.tech == "Skype" }

  before_save :before_save_timeout, :check_location_id, :check_login
  before_destroy :provider_before_destroy

  def before_save_timeout
    self.timeout = 30 if self.timeout.to_i < 30
    true
  end

  def check_login
    if self.device and self.device.device_ip_authentication_record == 0 and login.blank?
      errors.add(:login, _('Provider_should_have_login'))
      return false
    end
  end

  def check_location_id
    if self.user and self.user.id != 0
      #if old location id - create and set
      value = Confline.get_value("Default_device_location_id", self.user.id)
      if value.blank? or value.to_i == 1 or !value
        self.user.after_create_localization
      else
        #if new - only update devices with location 1
        self.user.update_resellers_device_location(value)
      end
    end
  end

  def provider_before_destroy
    if Call.count(:conditions => ["provider_id = ?", self.id]) > 0
      errors.add(:calls, _('Provider_has_calls'))
      return false
    end

    if self.dids and self.dids.size > 0
      errors.add(:dids, _('Cant_delete_provider_it_has_dids'))
      return false
    end

    for rule in self.providerrules
      rule.destroy
    end

    self.device.destroy if self.device
  end

  def after_create
    if tech == 'Skype' and Provider.count(:all, :conditions => ['tech = "Skype"']).to_i == 1
      Confline.set_value("Skype_Default_Provider", id, 0)
    end
  end

  def type
    return "dynamic" if self.server_ip == "dynamic"
    return "hostname" if self.device.ipaddr.to_s == ""
    return "ip"
  end

  def network(type, host, ip, port)
    case type
      when "hostname"
        self.server_ip = host
        device = self.device
        #device.name = "prov" + device.id.to_s
        device.host = host.to_s
        device.ipaddr = ""
        self.port = device.port = port
      when "ip"
        self.server_ip = host
        device = self.device
        #device.name = "prov" + device.id.to_s
        device.host = host.to_s
        device.ipaddr = ip.to_s
        self.port = device.port = port
      when "dynamic"
        self.server_ip = "dynamic"
        device = self.device
        self.login.to_s.length > 0 ? device.name = self.login : device.name = "prov" + device.id.to_s
        device.host = "dynamic"
        device.ipaddr = ""
        self.port = device.port = ""
      else
        return false
    end
    return true
  end

  # is provider active in some LCR?
  # nil - provider does not belong to this LCR
  # 0 - disabled
  # 1 - active
  def active?(lcr_id)
    if lcrprov = Lcrprovider.find(:first, :conditions => "provider_id = #{self.id} AND lcr_id = #{lcr_id.to_i}")
      return lcrprov.active
    else
      return nil
    end
  end

  def validate

  end

  def serverprovider
    Serverprovider.find(:all, :conditions => ["server_id=?", self.id])
  end

  def servers
    servers = Server.find_by_sql("SELECT servers.* FROM servers, serverproviders WHERE serverproviders.provider_id = '#{self.id.to_s}' AND serverproviders.server_id = servers.server_id ORDER BY servers.server_id;")
  end

  def hangup(date_start, date_end)
    hangup = Hangupcausecode.find_by_sql("SELECT hangupcausecodes.* FROM hangupcausecodes, calls WHERE (calls.provider_id = '#{self.id}' and calls.callertype = 'Local') OR (calls.did_provider_id = '#{self.id}' and calls.callertype = 'Outside') AND hangupcausecodes.code = calls.hangupcause AND calls.calldate BETWEEN '#{date_start}' AND '#{date_end}' ORDER BY hangupcausecodes.id;")
  end

  def calls(date_start, date_end)
    calls = Call.find_by_sql("SELECT calls.* FROM calls WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}' ) AND calls.calldate BETWEEN '#{date_start}' AND '#{date_end}';")
  end

  def hangupcalls(hangupcausecode)
    hangupcalls = Call.find_by_sql("SELECT calls.* FROM calls WHERE (calls.provider_id = '#{self.id}'  OR calls.did_provider_id = '#{self.id}') AND calls.hangupcause = '#{hangupcausecode.to_s}' AND calls.calldate BETWEEN '#{date_start}' AND '#{date_end}' ORDER BY calls.id;")
  end

  def codec?(codec)
    sql = "SELECT COUNT(*) as 'count' FROM providercodecs, codecs WHERE providercodecs.provider_id = '" + self.id.to_s + "' AND providercodecs.codec_id = codecs.id AND codecs.name = '" + codec.to_s + "'"
    res = ActiveRecord::Base.connection.select_one(sql)
    res['count'] == '1'
  end

  def codecs_order(type, options={})
    if options[:skype]
      Codec.find_by_sql("SELECT codecs.*,  IF(providercodecs.priority is null, 100, providercodecs.priority)  as bb FROM codecs  LEFT Join providercodecs on (providercodecs.codec_id = codecs.id and providercodecs.provider_id = #{self.id.to_i})  where codec_type = '#{type}' AND name IN('g729', 'alaw', 'ulaw') ORDER BY bb asc, codecs.id")
    else
      Codec.find_by_sql("SELECT codecs.*,  IF(providercodecs.priority is null, 100, providercodecs.priority)  as bb FROM codecs  LEFT Join providercodecs on (providercodecs.codec_id = codecs.id and providercodecs.provider_id = #{self.id.to_i})  where codec_type = '#{type}' ORDER BY bb asc, codecs.id")
    end
  end

  def codecs
    sql = "SELECT * FROM codecs, providercodecs WHERE providercodecs.provider_id = '" + self.id.to_s + "' AND providercodecs.codec_id = codecs.id ORDER BY providercodecs.priority"
    res = ActiveRecord::Base.connection.select_all(sql)
    codecs = []
    for i in 0..res.size-1
      codecs << Codec.find(res[i]["codec_id"])
    end
    codecs
  end

  def update_codecs_with_priority(codecs)
    dc = {}
    Providercodec.find(:all, :conditions => ["provider_id = ?", self.id]).each { |c| dc[c.codec_id] = c.priority; c.destroy }
    Codec.find(:all).each { |codec| Providercodec.new(:codec_id => codec.id, :provider_id => self.id, :priority => dc[codec.id].to_i).save if codecs[codec.name] == "1" }
    self.update_device_codecs
  end

  def update_device_codecs
    Devicecodec.find(:all, :conditions => ["device_id = ?", self.device.id]).each { |codec| codec.destroy }
    self.codecs.each_with_index { |codec, index| Devicecodec.new(:device_id => self.device.id, :codec_id => codec.id, :priority => index.to_i).save }
    self.device.update_codecs if self.device
  end


  def calls_count(date_start, date_end)
    Call.count_by_sql "SELECT COUNT(calls.id) FROM calls WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}'"
  end

  def calls_answered_count(date_start, date_end)
    Call.count_by_sql "SELECT COUNT(calls.id) FROM calls WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'ANSWERED'"
  end

  def calls_no_answer_count(date_start, date_end)
    Call.count_by_sql "SELECT COUNT(calls.id) FROM calls WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'NO ANSWER'"
  end

  def calls_busy_count(date_start, date_end)
    Call.count_by_sql "SELECT COUNT(calls.id) FROM calls WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'BUSY'"
  end

  def calls_failed_count(date_start, date_end)
    Call.count_by_sql "SELECT COUNT(calls.id) FROM calls WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'FAILED'"
  end

  def calls_billsec_sum(date_start, date_end)
    sql = "SELECT SUM(calls.provider_billsec) FROM  calls  WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'ANSWERED'"
    res = ActiveRecord::Base.connection.select_value(sql)
  end

  def calls_price_sum(date_start, date_end)
    sql = "SELECT SUM(calls.provider_price) FROM  calls  WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'ANSWERED'"
    res = ActiveRecord::Base.connection.select_value(sql)
  end

  def calls_user_price_sum(date_start, date_end)
    sql = "SELECT SUM(calls.user_price) FROM  calls  WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'ANSWERED'"
    res = ActiveRecord::Base.connection.select_value(sql)
  end

  def calls_reseller_price_sum(date_start, date_end)
    sql = "SELECT SUM(calls.reseller_price) FROM  calls  WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}') AND calldate BETWEEN '#{date_start}' AND '#{date_end}' AND disposition = 'ANSWERED'"
    res = ActiveRecord::Base.connection.select_value(sql)
  end

  #    Calls.count_by_sql "SELECT COUNT(calls.id) FROM calls WHERE calls.provider_id = '#{self.id}' AND status = 'completed'"

  def reload
    exceptions = []
    for server in self.servers
      begin
        server.ami_cmd('sip reload')
        server.ami_cmd('iax2 reload')
      rescue Exception => e
        exceptions << e
      end
    end
    exceptions
  end


  def h323_reload
    exceptions = []
    for server in self.servers
      begin
        server.ami_cmd('h.323 reload')
      rescue Exception => e
        exceptions << e
      end
    end
    exceptions
  end

  def skype_reload
    exceptions = []
    for server in self.servers
      begin
        server.ami_cmd('reload chan_skype.so')
      rescue Exception => e
        exceptions << e
      end
    end
    exceptions
  end

  def provider_calls_csv(options = {})
    sep = Confline.get_value("CSV_Separator", 0).to_s
    dec = Confline.get_value("CSV_Decimal", 0).to_s

    if options[:direction] == "incoming"
      disposition = " (calls.did_provider_id = #{self.id} OR calls.src_device_id = #{self.device_id} )"
    else
      disposition = " calls.provider_id = #{self.id} "
    end

    disposition += " AND disposition = '#{options[:call_type]}' " if options[:call_type] != "all"
    disposition += " AND calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}'"
    #   csv_header = [_("date"), _("called_from"), _("called_to"),_("Destination"), _("duration"), _("Billsec"), _("hangup_cause"), _("User_Price")+"("+options[:show_currency].to_s+")",  _("Provider_price")+"("+options[:show_currency]+")", _("Profit")+"("+options[:show_currency]+")", _("Margin %"), _("Markup %")]
    exrate = Currency.count_exchange_rate(options[:default_currency], options[:show_currency])

    #    fm1 = " ROUND("
    #    fm2 =" ,#{options[:nice_number_digits]}) "

    r1 = dec == "." ? "" : "replace("
    r2 = dec == "." ? "" : ", '.', '#{dec}')"
    n1 = "#{r1}" #"#{r1} FORMAT("
    n2 = "#{r2}" #",#{options[:nice_number_digits]})#{r2}"
    c1 = options[:default_currency] != options[:show_currency] ? " * #{exrate.to_f} " : ""

    select2 = []
    format = Confline.get_value('Date_format', 0).gsub('M', 'i')
    select2 << SqlExport.nice_date('calldate', {:reference => 'calldate', :format => format, :tz => options[:tx]})
    select2 << "src , dst , direction , duration , billsec , disposition , #{n1}provider_price3#{n2} as provider_price3, #{n1}user_price3#{n2} as user_price3"
    select2 << "#{n1}(user_price3-provider_price3)#{n2} as 'profit'"

    select = []
    select << "calls.calldate"
    select << "IF(#{options[:show_full_src].to_i} = 1 AND CHAR_LENGTH(clid)>0 AND clid REGEXP'\"' , CONCAT(src, '  ' ,REPLACE(SUBSTRING_INDEX(clid, '\"', 2), '\"', '('), ')'), src) as 'src'"
    select << "calls.dst"
    select << "CONCAT(IF(directions.name IS NULL, '',directions.name), ' ', IF(destinations.name IS NULL, '',destinations.name), ' ', IF(destinations.subcode IS NULL, '',destinations.subcode)) as 'direction'"

    select << "IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) as 'duration'"
    if  options[:direction].to_s == "incoming"
      select << "calls.did_billsec as 'billsec'"
      select << "calls.disposition"
      select << "IF(calls.provider_price IS NOT NULL, calls.did_prov_price#{c1}, 0) as 'provider_price3'"
      select2 << "'0' as 'm1'"
      select2 << "'0' as 'm2'"
    else
      select << "IF(calls.billsec = 0 AND calls.real_billsec > 0, calls.real_billsec, calls.billsec) as 'billsec'"
      select << "calls.disposition"
      select << "IF(calls.provider_price IS NOT NULL, calls.provider_price#{c1}, 0) as 'provider_price3'"
      select2 << "IF( (((user_price3-provider_price3) / user_price3 ) *100) IS NULL, 0,  #{n1}(((user_price3-provider_price3) / user_price3 ) *100) #{n2}) as 'm1'"
      select2 << "IF(( ((user_price3 / provider_price3) *100)-100 ) IS NULL, 0 ,   #{n1}( ((user_price3 / provider_price3) *100)-100 ) #{n2}) as 'm2'"
    end

    select << "IF(calls.reseller_id > 0, calls.reseller_price#{c1} , calls.user_price#{c1}) as 'user_price3'"

    filename = "CDR-#{SqlExport.clean_filename(self.name)}-#{options[:date_from].gsub(" ", "_").gsub(":", "_")}-#{options[:date_till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}-#{rand(20000).to_i}-#{options[:direction]}-#{options[:show_currency]}"

    sql = "SELECT * "
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    sql += " FROM ("+
        #         "SELECT '#{csv_header.join("'"+sep+"'")}'"+
        #       " UNION "+
        "SELECT #{select2.join(" , ")}  FROM
            ((SELECT #{select.join(" , ")}
      FROM calls LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (directions.code = destinations.direction_code)
      WHERE #{disposition}
      ORDER BY calls.calldate DESC)) as temp_a) as temp_c;"

    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      filename += mysql_res.to_yaml.to_s
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    return filename
  end


  #========== DEBUG ===================
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end


  def Provider.providers_order_by(options)
    case options[:order_by].to_s.strip.to_s
      when "name"
        order_by = "providers.name"
      when "id"
        order_by = "providers.id"
      when "tech"
        order_by = "providers.tech"
      when "channel"
        order_by = "providers.channel"
      when "login"
        order_by = "providers.login"
      when "password"
        order_by = "providers.password"
      when "server_ip"
        order_by = "providers.server_ip"
      when "tariff"
        order_by = "tariffs.name"
      else
        options[:order_by] ? order_by = options[:order_by] : order_by = "providers.name"
        options[:order_desc] = 1
    end
    order_by += " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by += " DESC" if options[:order_desc].to_i == 1 and order_by != ""
    return order_by
  end

  def Provider.find_all_for_select
    find(:all, :select => "id, name", :order => 'providers.name ASC')
  end


  def Provider.find_all_with_calls_for_stats(current_user, options={})
    s = []

    s << 'providers.id, providers.name, providers.tech'
    s << 'COUNT(b.id) as pcalls'
    s << "SUM(IF(b.DISPOSITION='ANSWERED',1,0)) AS 'answered'"
    s << "SUM(IF(b.DISPOSITION='BUSY',1,0)) AS 'busy'"
    s << "SUM(IF(b.DISPOSITION='NO ANSWER',1,0)) AS 'no_answer'"
    s << "SUM(IF(b.DISPOSITION='FAILED' AND hangupcause < 200 ,1,0)) AS 'failed'"
    s << "SUM(IF(b.DISPOSITION='FAILED' AND hangupcause > 199 ,1,0)) AS 'failed_locally'"
    s << "SUM(b.billsec) AS billsec"
    if current_user.is_admin?
      con = ''
      s << "SUM(b.provider_price) as 'selfcost_price'"
      s << "SUM(IF(b.reseller_id > 0, b.reseller_price, b.user_price)) AS 'sel_price'"
      s << "SUM(IF(b.reseller_id > 0, b.reseller_price, b.user_price) - b.provider_price ) AS 'profit'"
    else
      con = "OR (providers.common_use = 1 AND providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id}))"
      s << "SUM(IF(providers.common_use = 1, b.reseller_price,b.provider_price)) as 'selfcost_price'"
      s << "SUM(b.user_price) AS 'sel_price'"
      s << "SUM(b.user_price - IF(providers.common_use = 1, b.reseller_price,b.provider_price)) AS 'profit'"
    end

    jcond = ["calls.calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}'"]
    jcond << "calls.prefix = '#{options[:s_prefix]}'" if !options[:s_prefix].blank?

    if current_user.is_reseller?
      jcond << "(calls.reseller_id = #{current_user.id} OR calls.user_id = #{current_user.id})"
    end


    joins = []
    joins << "LEFT JOIN (SELECT calls.id, calls.DISPOSITION, calls.hangupcause, calls.did_provider_id, IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) as 'billsec', calls.provider_id, calls.provider_price, calls.user_price, calls.reseller_price, calls.reseller_id FROM calls
    WHERE  #{jcond.join(' AND ')} )
    as b ON (b.provider_id = providers.id OR b.did_provider_id = providers.id)"

    cond = ["(providers.user_id = #{current_user.id} #{con})"]
    cond << "providers.id = #{options[:p_id]}" if options[:p_id]

    sql = "SELECT #{s.join(' , ')} FROM providers
            #{joins.join(' ')}
            WHERE #{cond.join(' AND ')} 
            GROUP BY providers.id ORDER BY providers.name ASC"
    Provider.find_by_sql(sql)
  end


  def set_old
    self.old_register_record = self.register
    self.old_register_extension_record = self.reg_extension
    self.old_register_line_record = self.reg_line
  end

  def change_register_params?
    self.old_register_record != self.register or self.old_register_extension_record != self.reg_extension or self.old_register_line_record != self.reg_line
  end

  def old_register;
    @old_register_record;
  end

  def old_register_extension;
    @old_register_extension_record;
  end

  def old_register_line;
    @old_register_line_record;
  end

  def create_serverproviders(servers)

    if servers
      ss = []
      servers.each { |s|
        sp = Serverprovider.find(:first, :conditions => "server_id = #{s[0].to_i} AND provider_id = #{id}")
        if not sp
          serverprovider = Serverprovider.new({:server_id => s[0].to_i, :provider_id => id})
          serverprovider.save
        end
        ss << s[0].to_i
      }
      ActiveRecord::Base.connection.execute("DELETE FROM serverproviders WHERE provider_id = '#{id}' AND server_id NOT IN (#{ss.join(',')})")
    end
  end
end
