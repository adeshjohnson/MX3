# -*- encoding : utf-8 -*-
class Lcrprovider < ActiveRecord::Base

  def self.clone_providers(lcr, original_lcr_id)
    query = "INSERT INTO lcrproviders (lcr_id, provider_id, active, priority, percent)
             SELECT #{lcr.id}, lcrproviders.provider_id, lcrproviders.active, lcrproviders.priority, lcrproviders.percent 
             FROM   lcrproviders
             WHERE  lcrproviders.lcr_id = #{original_lcr_id}"
    ActiveRecord::Base.connection.execute(query)
  end

  def move_lcr_prov(direction)
    if direction == "down"
      following_lcr_prov = Lcrprovider.where("lcr_id = #{self.lcr_id} AND priority > #{self.priority}").order("priority").first
      old_priority = self.priority
      self.update_attribute(:priority, following_lcr_prov.priority) if following_lcr_prov
      following_lcr_prov.update_attribute(:priority, old_priority) if following_lcr_prov
    else
      previous_lcr_prov = Lcrprovider.where("lcr_id = #{self.lcr_id} AND priority < #{self.priority}").order("priority DESC").first
      old_priority = self.priority
      self.update_attribute(:priority, previous_lcr_prov.priority) if previous_lcr_prov
      previous_lcr_prov.update_attribute(:priority, old_priority) if previous_lcr_prov
    end
  end
end
