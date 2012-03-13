# -*- encoding : utf-8 -*-
class Lcrprovider < ActiveRecord::Base
=begin
=end
  def self.clone_providers(lcr, original_lcr_id)
    query = "INSERT INTO lcrproviders (lcr_id, provider_id, active, priority, percent)
             SELECT #{lcr.id}, lcrproviders.provider_id, lcrproviders.active, lcrproviders.priority, lcrproviders.percent 
             FROM   lcrproviders
             WHERE  lcrproviders.lcr_id = #{original_lcr_id}"
    ActiveRecord::Base.connection.execute(query)
  end

end
