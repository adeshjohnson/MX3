class Lcr < ActiveRecord::Base
  has_many :lcr_partials
  belongs_to :user
  has_many :lcrproviders

  validates_uniqueness_of :name

=begin rdoc

=end

  def before_destroy

    if User.find(:all, :conditions => ["lcr_id = ?",id]).size > 0
      errors.add(:users, _('Lcr_not_deleted'))
      return false
    end

    lrules= Locationrule.find(:all, :conditions=>"lcr_id='#{id}'")
    if lrules.size.to_i > 0
      errors.add(:locationrules, lrules.size.to_s + " " + _('locationrules_are_using_this_lcr_cant_delete'))
      return false
    end

    if self.lcr_partials.count > 0
      errors.add(:lcr_partials, self.lcr_partials.count.to_s + " " + _('lcr_partials_are_using_this_lcr_cant_delete'))
      return false
    end

    for partial in self.lcr_partials
      partial.destroy
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


  def active_providers
    Provider.find_by_sql ["SELECT providers.* FROM providers, lcrproviders WHERE providers.id = lcrproviders.provider_id AND active = 1 AND lcrproviders.lcr_id = ? AND providers.hidden = 0 ORDER BY providers.name ASC", self.id]
  end

  def add_provider(prov)
    if self.order.to_s == "percent"
      @pr = Lcrprovider.find(:first, :conditions=>["lcr_id = ?", self.id], :order=>"percent asc")
      if @pr
        proc = @pr.percent.to_i / 2.to_i
        @pr.percent % 2 == 1 ? i = 1 : i = 0
        @pr.percent = proc.to_i + i.to_i
        @pr.save
      else
        proc = 10000
      end
      Lcrprovider.create({:lcr_id=>id, :provider_id=>prov.id.to_i, :percent=>proc.to_i})
    else
      lprov = Lcrprovider.find(:first, :conditions=>["lcr_id = ?", self.id], :order=>"priority desc")
      Lcrprovider.create({:lcr_id=>id, :provider_id=>prov.id.to_i, :priority=>(lprov ? lprov.priority.to_i + 1 : 1)})
    end
  end

  def remove_provider(prov_id)
    if self.order.to_s == "percent"
      @pr2 = Lcrprovider.find(:first, :conditions=>["lcr_id = ? AND provider_id = ?",self.id.to_s,  prov_id.to_s])
      if @pr2
        @pr = Lcrprovider.find(:first, :conditions=>["lcr_id = ? AND id != ?", self.id.to_s, @pr2.id], :order=>"percent desc")

        if @pr
          @pr.percent =@pr.percent.to_f + @pr2.percent.to_f
          @pr.save
        end
      end
    end
    Lcrprovider.destroy_all(["lcr_id = ? AND provider_id = ?",self.id.to_s, prov_id.to_s] )
  end

  def provider_active(provider_id)
    sql = "SELECT active FROM lcrproviders WHERE lcr_id = '#{self.id}' AND provider_id = '#{provider_id}' "
    res = ActiveRecord::Base.connection.select_value(sql)
    res == "1"
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
    providers = Lcrprovider.find(:all, :select => "lcrproviders.*", :joins => "RIGHT JOIN providers ON (providers.id = lcrproviders.provider_id)", :conditions => ["lcr_id = ?", self.id])
    percent = 10000/providers.size if providers and providers.size > 0
    sum = 0
    providers.each{  |provider|
      provider.percent = percent
      provider.save
      sum += percent
    }
    providers[0].percent = 10000 - sum + percent and providers[0].save if providers.size > 2 and 10000/providers.size*providers.size != 10000
  end

  def Lcr.lcrs_order_by(params, options)
    case params[:order_by].to_s.strip.to_s
    when "id" :     order_by = " lcrs.id "
    when "name" :   order_by = " lcrs.name "
    when "order" :  order_by = " lcrs.order "
    else
      options[:order_by] ? order_by = "name" : order_by = "name"
      options[:order_desc] = 1
    end
    order_by += " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by += " DESC"if options[:order_desc].to_i == 1 and order_by != ""
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

      t_ids = tariffs.map{|i| i.tid}
      create_temp_table = "CREATE TABLE #{t_name}_2 AS (SELECT  destinationgroup_id, #{SqlExport.replace_dec("MIN( price * exchange_rate)", options[:collumn_dem],'rate_min' )}, #{SqlExport.replace_dec("MIN( price * exchange_rate)", options[:collumn_dem],'rate_max' )} FROM rates
                           JOIN aratedetails ON (rates.id = rate_id)
                           JOIN tariffs ON (tariffs.id = tariff_id)
                           JOIN currencies ON (currencies.name = tariffs.currency)
                     WHERE tariff_id IN (#{options[:current_user].tariff_id}) group by destinationgroup_id);"
      ActiveRecord::Base.connection.execute(create_temp_table)
      cretate_table_2 = " CREATE TABLE #{t_name}_1 AS (SELECT destination_id as did, #{SqlExport.replace_dec("MIN( rate * exchange_rate)", options[:collumn_dem],'rate_min' )}, #{SqlExport.replace_dec("MAX( rate * exchange_rate)", options[:collumn_dem],'rate_max' )} FROM rates
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
        cond =   " (tariff_id IN (SELECT DISTINCT(providers.tariff_id) FROM lcrproviders
                                    JOIN providers ON (providers.id = provider_id)
                                  WHERE lcr_id = #{id} ) AND tariffs.owner_id = #{options[:current_user].id}) OR tariffs.id = #{options[:current_user].tariff_id}  "
      end

      sql_m = "SELECT #{s.join(' , ')} , #{SqlExport.replace_dec("MIN( rate * exchange_rate)", options[:collumn_dem],'rate_min' )}, #{SqlExport.replace_dec("MAX( rate * exchange_rate)", options[:collumn_dem],'rate_max' )} FROM rates
            JOIN ratedetails ON (rates.id = rate_id)
            JOIN tariffs ON (tariffs.id = tariff_id)
            JOIN currencies ON (currencies.name = tariffs.currency)
			      JOIN destinations ON (rates.destination_id = destinations.id)
            LEFT JOIN directions ON (destinations.direction_code = directions.code)
            WHERE #{cond} GROUP BY destination_id ORDER BY dir_name ASC"

    end

    filename = "Make_LCR_tariff-#{SqlExport.clean_filename(name)}-#{options[:curr]}-#{Time.now().to_i}_#{options[:rand]}"
    sql = "SELECT * "
    if options[:test] != 1
      sql +=    " INTO OUTFILE '/tmp/#{filename}.csv'
                FIELDS TERMINATED BY '#{options[:collumn_separator]}' OPTIONALLY ENCLOSED BY '#{''}'
                ESCAPED BY '#{"\\\\"}'
            LINES TERMINATED BY '#{"\\n"}' "
    end
    dont_show_zero = 'WHERE rate_min != 0 AND rate_max != 0' if  Confline.get_value('Show_zero_rates_in_LCR_tariff_export').to_i == 0
    sql += " FROM (#{sql_m}) AS c #{dont_show_zero}"

    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      MorLog.my_debug(sql)
      MorLog.my_debug("------------------------------------------------------------------------")
      MorLog.my_debug(mysql_res.to_yaml)
      filename += mysql_res.to_yaml.to_s
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{t_name}_2;")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{t_name}_1;")
    return filename
  end

  def new_location(cut, add, dst)
    loc_dst = Location.nice_locilization(cut, add,dst)
    # read LCR Partials
    sql = "SELECT lcr_partials.prefix as 'prefix', lcrs.id as 'lcr_id', lcrs.order FROM lcr_partials JOIN lcrs ON (lcrs.id = lcr_partials.lcr_id) WHERE main_lcr_id = '#{id}' AND prefix=SUBSTRING('#{loc_dst}',1,LENGTH(prefix)) ORDER BY LENGTH(prefix) DESC LIMIT 1;"
    #my_debug sql
    ActiveRecord::Base.connection.select_one(sql)

  end

end
