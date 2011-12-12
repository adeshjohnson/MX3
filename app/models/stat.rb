class Stat < ActiveRecord::Base

  def self.find_rates_and_tariffs_by_number(user_id, id,phrase)
    sql=  "select * from (SELECT rates.`id` as rates_id , rates.`tariff_id` , rates.`destination_id` , rates.`destinationgroup_id` as rates_destinationgroup_id, tariffs.`id` as tariffs_id, tariffs.`name` as tariffs_name , tariffs.`purpose` ,
    tariffs.`owner_id` , tariffs.`currency` , ratedetails.`id` as rate_details_id, ratedetails.`start_time` , ratedetails.`end_time` , ratedetails.`rate` , ratedetails.`connection_fee` ,
    ratedetails.`rate_id` , ratedetails.`increment_s` , ratedetails.`min_time` , ratedetails.`daytype` , destinations.`id` as destinations_id , destinations.`prefix` ,
    destinations.`direction_code` , destinations.`subcode` , destinations.`name` , destinations.`city` , destinations.`state` ,
    destinations.`lata` , destinations.`tier` , destinations.`ocn` , destinations.`destinationgroup_id`,
    aratedetails.`id` AS arates_id, aratedetails.`from` , aratedetails.`duration` , aratedetails.`artype` , aratedetails.`round`,  aratedetails.`price`, aratedetails.`rate_id` as arate_id ,
    aratedetails.`start_time` as arate_start_time ,aratedetails.`end_time` as arate_end_time, aratedetails.`daytype` as arate_daytype
    FROM rates
    LEFT OUTER JOIN tariffs ON tariffs.id = rates.tariff_id
    LEFT OUTER JOIN ratedetails ON ratedetails.rate_id = rates.id
    LEFT OUTER JOIN aratedetails ON aratedetails.rate_id = rates.id
    LEFT OUTER JOIN destinations ON (destinations.id = rates.destination_id or destinations.destinationgroup_id = rates.destinationgroup_id) and destinations.prefix in (#{phrase.join(",")})
    WHERE (
    (destination_id in (#{id.join(",")}) or rates.destinationgroup_id in (select destinationgroup_id from destinations where id in (#{id.join(",")})))
    AND tariffs.owner_id = #{user_id}) order by LENGTH(prefix) desc) as v group by tariffs_name"
    ActiveRecord::Base.connection.select_all(sql)
  end

end
