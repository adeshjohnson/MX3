# -*- encoding : utf-8 -*-
class Stat < ActiveRecord::Base

  def self.find_rates_and_tariffs_by_number(user_id, id, phrase)
    sql= "select * from (SELECT tariffs.`name` as tariffs_name , tariffs.`purpose` , tariffs.`currency`,
    ratedetails.`start_time` , ratedetails.`end_time` , ratedetails.`rate` ,
    destinations.`prefix` , destinations.`direction_code` , destinations.`subcode` , destinations.`name` ,
    aratedetails.`price`, aratedetails.`start_time` as arate_start_time ,aratedetails.`end_time` as arate_end_time
    FROM rates
    LEFT OUTER JOIN tariffs ON tariffs.id = rates.tariff_id
    LEFT OUTER JOIN ratedetails ON ratedetails.rate_id = rates.id
    LEFT OUTER JOIN aratedetails ON aratedetails.rate_id = rates.id
    LEFT OUTER JOIN destinations ON (destinations.id = rates.destination_id or destinations.destinationgroup_id = rates.destinationgroup_id) and destinations.prefix in (#{phrase.join(",")})
    WHERE (
    (destination_id in (#{id.join(",")}) or rates.destinationgroup_id in (select destinationgroup_id from destinations where id in (#{id.join(",")})))
    AND tariffs.owner_id = #{user_id}) order by LENGTH(prefix) desc) as v group by tariffs_name order by purpose"
    ActiveRecord::Base.connection.select_all(sql)
  end

end
