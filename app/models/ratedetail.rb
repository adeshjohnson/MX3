# -*- encoding : utf-8 -*-
class Ratedetail < ActiveRecord::Base

  def Ratedetail.find_all_from_id_with_exrate(options={})
    if options[:rates] and options[:rates].size.to_i > 0
      sql = "SELECT ratedetails.*, rate * #{options[:exrate].to_d} as erate, connection_fee * #{options[:exrate].to_d} as conee #{', directions.*' if options[:directions]}  #{', directions.name as dname' if options[:directions]} #{', destinations.*' if options[:destinations]} FROM ratedetails join rates on (rates.id = ratedetails.rate_id) join destinations on (rates.destination_id = destinations.id) join directions on (destinations.direction_code = directions.code) where rate_id in (#{(options[:rates].collect { |r| r.id }).join(' , ')}) ORDER BY directions.name ASC, destinations.prefix ASC, ratedetails.daytype DESC, ratedetails.start_time ASC, rates.id  ASC"
      ratesd = Ratedetail.find_by_sql(sql)
      return ratesd
    end
  end

end
