# -*- encoding : utf-8 -*-
class Destinationgroup < ActiveRecord::Base

  has_many :destinations, :order => "prefix ASC" #, :foreign_key => "prefix", :order => "prefix ASC"
  has_many :rates
  has_many :customrates

  validates_presence_of :name


  # destinations which haven't assigned to destination group by first letter
  def free_destinations_by_st(st)
    adests = Destination.find_by_sql ["SELECT destinations.* FROM destinations, directions WHERE destinations.destinationgroup_id = 0 AND directions.code = destinations.direction_code AND directions.name like ? ORDER BY directions.name ASC, destinations.prefix ASC", st.to_s+'%']
    dests = self.destinations
    fdests = []
    fdests = adests - dests
  end

  def rate(tariff_id)
    Rate.where("tariff_id = #{tariff_id} AND destinationgroup_id = #{self.id}").first
  end

  def custom_rate(user_id)
    Customrate.find(:first, :conditions => "user_id = #{user_id} AND destinationgroup_id = #{self.id}")
  end

  def Destinationgroup.find_with_rates
    sql = "SELECT destinationgroups.*, customrates  FROM destinationgroups LEFT JOIN customrates ON (customrates.destinationgroup_id = destinationgroups.id) ORDER BY name ASC, desttype ASC"
    Destinationgroup.find_by_sql(sql)
  end

  def Destinationgroup.destinationgroups_order_by(params, options)
    case options[:order_by].to_s.strip.to_s
      when "country"
        order_by = "dgn"
      when "prefix"
        order_by = "prefix"
      when "destination"
        order_by = "name"
      else
        order_by = options[:order_by]
    end
    if order_by != ""
      order_by += (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
    end
    return order_by
  end
end
