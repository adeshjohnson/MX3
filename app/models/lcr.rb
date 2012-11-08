# -*- encoding : utf-8 -*-
class Lcr < ActiveRecord::Base
  has_many :lcr_partials #, :dependent => :destroy
  belongs_to :user
  has_many :lcrproviders #, :dependent => :destroy

  #validates_uniqueness_of :name

=begin rdoc

=end
  before_destroy :validate_before_destroy
  after_save :equalize_percent

  def validate_before_destroy

    if User.find(:all, :conditions => ["lcr_id = ?", id]).size > 0
      errors.add(:users, _('LCR_not_deleted_because_it_is_used_by_some_user(s)'))
      return false
    end

    lrules= Locationrule.find(:all, :conditions => "lcr_id='#{id}'")
    if lrules.size.to_i > 0
      errors.add(:locationrules, lrules.size.to_s + " " + _('locationrules_are_using_this_lcr_cant_delete'))
      return false
    end

    if self.lcr_partials.count > 0
      errors.add(:lcr_partials, self.lcr_partials.count.to_s + " " + _('lcr_partials_are_using_this_lcr_cant_delete'))
      return false
    end
  end

  def providers(order = nil)
    order1 = ""
    if self.order.to_s == "percent"
      order1= " lcrproviders.percent DESC, providers.id asc; "
    else
      if self.order.to_s == "priority"
        order1= " lcrproviders.priority ASC, providers.id asc; "
      else
        if order.to_s.downcase == "asc" or order.to_s.downcase == "desc"
          order1= " lcrproviders.priority #{order}; "
        else
          order1 = " providers.name ASC; "
        end
      end
    end

    sql = "SELECT providers.* , lcrproviders.percent, lcrproviders.priority FROM providers JOIN lcrproviders ON (providers.id = lcrproviders.provider_id) WHERE lcrproviders.lcr_id = #{self.id} ORDER BY #{order1}"
    return Provider.find_by_sql(sql)
  end

  def failover_provider
    sql = "SELECT providers.* FROM providers JOIN lcrs ON (providers.id = lcrs.failover_provider_id) WHERE lcrs.id = #{self.id}"
    Provider.find_by_sql(sql)[0]
  end

  def failover_provider=(provider)
    if provider
      self.failover_provider_id = provider.id
    else
      self.failover_provider_id = nil
    end
  end

  def active_providers
    Provider.find_by_sql ["SELECT providers.* FROM providers, lcrproviders WHERE providers.id = lcrproviders.provider_id AND active = 1 AND lcrproviders.lcr_id = ? AND providers.hidden = 0 ORDER BY providers.name ASC", self.id]
  end

  def add_provider(prov)
    if self.order.to_s == "percent"
      @prs = Lcrprovider.find(:all, :conditions => ["lcr_id = ?", self.id])
      if @prs
        lcr_percent = 10000 / (@prs.size + 1)
        for pr in @prs
          pr.percent = lcr_percent
          pr.save
        end
      else
        lcr_percent = 10000
      end
      Lcrprovider.create({:lcr_id => id, :provider_id => prov.id.to_i, :percent => lcr_percent})
    else
      lprov = Lcrprovider.find(:first, :conditions => ["lcr_id = ?", self.id], :order => "priority desc")
      Lcrprovider.create({:lcr_id => id, :provider_id => prov.id.to_i, :priority => (lprov ? lprov.priority.to_i + 1 : 1)})
    end
  end

  def remove_provider(prov_id)
    if self.order.to_s == "percent"
      @pr2 = Lcrprovider.find(:first, :conditions => ["lcr_id = ? AND provider_id = ?", self.id.to_s, prov_id.to_s])
      if @pr2
        @prs = Lcrprovider.find(:all, :conditions => ["lcr_id = ? AND id != ?", self.id.to_s, @pr2.id])
        if @prs.size > 0
          lcr_percent = 10000 / @prs.size
          for pr in @prs
            pr.percent = lcr_percent
            pr.save
          end
        end
      end
    end
    Lcrprovider.destroy_all(["lcr_id = ? AND provider_id = ?", self.id.to_s, prov_id.to_s])
  end

  def provider_active(provider_id)
    sql = "SELECT active FROM lcrproviders WHERE lcr_id = '#{self.id}' AND provider_id = '#{provider_id}' "
    res = ActiveRecord::Base.connection.select_value(sql)
    res.to_i == 1
  end

  def lcr_partials_destinations
    sql = "SELECT directions.*, lcr_partials.id as lid, lcr_partials.prefix as prefix, lcr_partials.lcr_id, lcrs.name as 'lname', lcrs.order, lcrs.id as 'lcr_id', destinations.subcode as 'dest_subcode', destinations.name as 'dest_name' FROM lcr_partials
                LEFT JOIN lcrs on (lcrs.id = lcr_partials.lcr_id)
                LEFT JOIN destinations on (destinations.prefix = lcr_partials.prefix)
                LEFT JOIN directions on (destinations.direction_code = directions.code)
              WHERE main_lcr_id = '#{self.id}' ORDER BY directions.name ASC, lcr_partials.prefix ASC"
    MorLog.my_debug sql
    return ActiveRecord::Base.connection.select_all(sql)
  end

  def equalize_percent
    if order_changed? and order == "percent"
      providers = Lcrprovider.find(:all, :select => "lcrproviders.*", :joins => "RIGHT JOIN providers ON (providers.id = lcrproviders.provider_id)", :conditions => ["lcr_id = ?", self.id])
      percent = 10000/providers.size if providers and providers.size > 0
      providers.each { |provider|
        provider.percent = percent
        provider.save
      }
    end
  end

  def Lcr.lcrs_order_by(params, options)
    case params[:order_by].to_s.strip
      when "id"
        order_by = " lcrs.id "
      when "name"
        order_by = " lcrs.name "
      when "order"
        order_by = " lcrs.order "
      else
        options[:order_by] ? order_by = "name" : order_by = "name"
        options[:order_desc] = 1
    end
    order_by += " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by += " DESC" if options[:order_desc].to_i == 1 and order_by != ""
    return order_by

  end

  def provider_change_status(prov_id)
    value = self.provider_active(prov_id) ? 0 : 1
    Lcrprovider.update_all("active = #{value}", ['lcr_id = ? AND provider_id = ?', id, prov_id])
    return value
  end

  def lcr_name
    (User.current.lcr_id == id and User.current.usertype == 'reseller') ? _('DEFAULT_LCR') : self.name
  end

  def make_tariff(options={})
    # if lrc contains common use provider, use admins tariff fo reseller

    s = []
    # select fields , csv collums
    s << SqlExport.column_escape_null("directions.name", "dir_name")
    s << SqlExport.column_escape_null("destinations.name", "name")
    s << "prefix, subcode"

    t_name = "Temp_#{id}_#{Time.now().to_i}"

    if options[:current_user].usertype == 'reseller' and options[:current_user].tariff.purpose == 'user'

      tariffs = Tariff.find_by_sql("SELECT DISTINCT(providers.tariff_id) as tid FROM lcrproviders
                                   left JOIN providers ON (providers.id = provider_id AND providers.common_use = 0)
                                    left JOIN tariffs ON (tariffs.id = providers.tariff_id)
                                  WHERE lcr_id = #{id} and tariff_id is not null")

      t_ids = tariffs.map { |i| i.tid }
      create_temp_table = "CREATE TABLE #{t_name}_2 AS (SELECT  destinationgroup_id, #{SqlExport.replace_dec("CAST(MIN( price / exchange_rate) AS DECIMAL(15,10))", options[:column_dem], 'rate_min')}, #{SqlExport.replace_dec("CAST(MAX( price / exchange_rate) AS DECIMAL(15,10))", options[:column_dem], 'rate_max')} FROM rates
                           JOIN aratedetails ON (rates.id = rate_id)
                           JOIN tariffs ON (tariffs.id = tariff_id)
                           JOIN currencies ON (currencies.name = tariffs.currency)
                     WHERE tariff_id IN (#{options[:current_user].tariff_id}) group by destinationgroup_id);"
      ActiveRecord::Base.connection.execute(create_temp_table)
      cretate_table_2 = " CREATE TABLE #{t_name}_1 AS (SELECT destination_id as did, #{SqlExport.replace_dec("CAST(MIN( rate / exchange_rate) AS DECIMAL(15,10))", options[:column_dem], 'rate_min')}, #{SqlExport.replace_dec("CAST(MAX( rate / exchange_rate) AS DECIMAL(15,10))", options[:column_dem], 'rate_max')} FROM rates
                           JOIN ratedetails ON (rates.id = rate_id)
                           JOIN tariffs ON (tariffs.id = tariff_id)
                           JOIN currencies ON (currencies.name = tariffs.currency)
                     WHERE tariff_id IN (#{t_ids.size.to_i > 0 ? t_ids.join(' , ') : -100}) GROUP BY destination_id);"
      ActiveRecord::Base.connection.execute(cretate_table_2)
      sql_m = "SELECT #{s.join(' , ')} ,  rate_min, rate_max FROM (
                SELECT destinations.id as vi, rate_min,rate_max from destinations
                    JOIN #{t_name}_2 ON (#{t_name}_2.destinationgroup_id = destinations.destinationgroup_id)
                    UNION ALL
                    SELECT did AS vi , rate_min, rate_max FROM #{t_name}_1 ) AS V
      			 JOIN destinations ON (destinations.id =  V.vi)
             LEFT JOIN directions ON (destinations.direction_code = directions.code)
             GROUP BY vi ORDER BY dir_name ASC"
    else
      cond = " tariff_id IN (SELECT DISTINCT(providers.tariff_id) FROM lcrproviders
                                    JOIN providers ON (providers.id = provider_id)
                                  WHERE lcr_id = #{id} ) AND tariffs.owner_id = #{options[:current_user].id} "
      if options[:current_user].usertype == 'reseller'
        cond = " (tariff_id IN (SELECT DISTINCT(providers.tariff_id) FROM lcrproviders
                                    JOIN providers ON (providers.id = provider_id)
                                  WHERE lcr_id = #{id} ) AND tariffs.owner_id = #{options[:current_user].id}) OR tariffs.id = #{options[:current_user].tariff_id}  "
      end

      sql_m = "SELECT #{s.join(' , ')},
                      CAST(MIN(rate / exchange_rate) AS DECIMAL(15,10)) AS rate_min, 
                      CAST(MAX(rate / exchange_rate) AS DECIMAL(15,10)) AS rate_max 
            FROM rates
            JOIN ratedetails ON (rates.id = rate_id)
            JOIN tariffs ON (tariffs.id = tariff_id)
            JOIN currencies ON (currencies.name = tariffs.currency)
	    JOIN destinations ON (rates.destination_id = destinations.id)
            LEFT JOIN directions ON (destinations.direction_code = directions.code)
            WHERE #{cond} 
            GROUP BY destination_id
            #{'HAVING rate_min != 0 AND rate_max != 0' if Confline.get_value('Show_zero_rates_in_LCR_tariff_export').to_i == 0} 
            ORDER BY dir_name ASC"

    end

    filename = "Make_LCR_tariff-#{SqlExport.clean_filename(name)}-#{options[:curr]}-#{Time.now().to_i}_#{options[:rand]}"
    sql = "SELECT dir_name, name, subcode, prefix, 
                  #{SqlExport.replace_dec('rate_min', options[:column_dem], 'rate_min')},
                  #{SqlExport.replace_dec('rate_max', options[:column_dem], 'rate_max')} "
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
                FIELDS TERMINATED BY '#{options[:collumn_separator]}' OPTIONALLY ENCLOSED BY '#{''}'
                ESCAPED BY '#{"\\\\"}'
            LINES TERMINATED BY '#{"\\n"}' "
    end
    sql += " FROM (#{sql_m}) AS c"

    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      MorLog.my_debug(sql)
      MorLog.my_debug("------------------------------------------------------------------------")
      MorLog.my_debug(mysql_res.to_yaml)
      filename += mysql_res.inspect
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{t_name}_2;")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{t_name}_1;")
    return filename
  end

  def new_location(cut, add, dst)
    loc_dst = Location.nice_locilization(cut, add, dst)
    # read LCR Partials
    sql = "SELECT lcr_partials.prefix as 'prefix', lcrs.id as 'lcr_id', lcrs.order FROM lcr_partials JOIN lcrs ON (lcrs.id = lcr_partials.lcr_id) WHERE main_lcr_id = '#{id}' AND prefix=SUBSTRING('#{loc_dst}',1,LENGTH(prefix)) ORDER BY LENGTH(prefix) DESC LIMIT 1;"
    #my_debug sql
    ActiveRecord::Base.connection.select_one(sql)

  end

=begin
  Create identical lcrs - clone all lcrs from resellerA and assign them to resellerB. As well as 
  information associated with lcr - data in lcr_partials and lcrproviders tables. In case both
  resellers does not have identical list of providers or one of them does not have any providers 
  at all return false, i dont think it's necesary to raise an exception, though it would be an option. 
  Note: three insert into .. select .. statements would be enough for this operation but, since there 
  is no way to identify which ones lcrs are new and whats theyr id so at this moment we have to generate
  queries in a loop. Though doing it this way is more rails/oo way, butto do this task in only three 
  queries would be posible if say lcr.name would be unique for each user.

  *Params*
  +resellerA+ User instance where usertype == reseller, reseller who's lcrs should be cloned.
  +resellerB+ User instance where usertype == reseller, reseller to who new lcrs should be assigned
  +lcr_list+ array of lcr_ids ie array containing numbers greater than 0. any non numeric thing or 
    number less than 1 will be silently ignored.

  *Retuns*
  +
=end
  def self.clone_lcrs(resellerA, resellerB, lcr_list)
    if not CommonUseProvider.common_use_providers?(resellerA, resellerB)
      return false
    else
      #construct where clause, which speficies user_id of lcr specifies lcr id if
      #at least one valid lcr id is given in lcr_list.
      query_condition = "user_id = #{resellerA.id}"
      if lcr_list and lcr_list.size > 0
        lcr_list.reject! { |lcr_id| lcr_id.to_i == 0 }
        lcr_list = lcr_list.join(',')
        if lcr_list.length > 0
          query_condition += " AND id IN (#{lcr_list})"
        end
      end
      #find all resellerA's lcrs and iterate through them, cloning each lcr
      #and cloning partials
      resellerA_lcrs = Lcr.find(:all, :conditions => [query_condition])
      if resellerA_lcrs
        resellerA_lcrs.each do |original_lcr|
          new_lcr = Lcr.new
          new_lcr.name = original_lcr.name
          new_lcr.order = original_lcr.order
          new_lcr.user_id = resellerB.id
          new_lcr.first_provider_percent_limit = original_lcr.first_provider_percent_limit
          if new_lcr.save
            LcrPartial.clone_partials(new_lcr, original_lcr.id)
            Lcrprovider.clone_providers(new_lcr, original_lcr.id)
            return true
          else
            return false
          end
        end
        return true
      else
        return false
      end
    end
  end

=begin
  Check whether no failover provider should be used for this lcr
  
  *Returns*
  +boolean+ - true if no failover providers should be user, false otherwise 

=end
  def no_failover?
    (self.no_failover.to_i != 0 ? true : false)
  end

  def destroy_all
    lrules= Locationrule.find(:all, :conditions => "lcr_id='#{id}'")
    lrules.each { |lr| lr.destroy } if lrules
    lpt = self.lcr_partials
    lpt.each { |t| t.destroy } if lpt
    lcrptov = self.lcrproviders
    lcrptov.each { |p| p.destroy } if lcrptov
  end

end
