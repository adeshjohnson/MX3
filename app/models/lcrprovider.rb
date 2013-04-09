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

  def move_lcr_prov(direction)
    if direction == "down"
      following_lcr_prov = Lcrprovider.where(:lcr_id => self.lcr_id, :priority => self.priority + 1).first
      self.update_attribute(:priority, self.priority + 1)
      following_lcr_prov.update_attribute(:priority, following_lcr_prov.priority - 1)
    else
      previous_lcr_prov = Lcrprovider.where(:lcr_id => self.lcr_id, :priority => self.priority - 1).first
      self.update_attribute(:priority, self.priority - 1)
      previous_lcr_prov.update_attribute(:priority, previous_lcr_prov.priority + 1) if previous_lcr_prov
    end
  end
end
