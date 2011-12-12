class SmsLcr < ActiveRecord::Base
  
  def sms_providers(order = nil)
    
    if order
      if order.to_s.downcase == "asc"
        sql = "SELECT sms_providers.* FROM sms_providers, sms_lcrproviders WHERE sms_providers.id = sms_lcrproviders.sms_provider_id AND sms_lcrproviders.sms_lcr_id = #{self.id} ORDER BY sms_lcrproviders.priority ASC;"
      end
      if order.to_s.downcase == "desc"
        sql = "SELECT sms_providers.* FROM sms_providers, sms_lcrproviders WHERE sms_providers.id = sms_lcrproviders.sms_provider_id AND sms_lcrproviders.sms_lcr_id = #{self.id} ORDER BY sms_lcrproviders.priority DESC"
      end
    else
      sql = "SELECT sms_providers.* FROM sms_providers, sms_lcrproviders WHERE sms_providers.id = sms_lcrproviders.sms_provider_id AND sms_lcrproviders.sms_lcr_id = #{self.id} ORDER BY sms_providers.name ASC;"
    end
  
    return SmsProvider.find_by_sql(sql)
  end
  
  
    def active_sms_providers
      SmsProvider.find_by_sql ["SELECT sms_providers.* FROM sms_providers, sms_lcrproviders WHERE sms_providers.id = sms_lcrproviders.sms_provider_id AND active = 1 AND sms_lcrproviders.sms_lcr_id = ? ORDER BY sms_providers.name ASC", self.id] 
    end

    def add_sms_provider(prov)
      sql = 'INSERT INTO sms_lcrproviders (sms_lcr_id, sms_provider_id) VALUES (\'' + self.id.to_s + '\', \'' + prov.id.to_s + '\')'
      res = ActiveRecord::Base.connection.insert(sql) 
    end

    def remove_sms_provider(prov_id)
      sql = "DELETE FROM sms_lcrproviders WHERE sms_lcr_id = '" + self.id.to_s + "' AND sms_provider_id = '" + prov_id.to_s + "'"
      res = ActiveRecord::Base.connection.insert(sql) 
    end

    def sms_provider_active(provider_id)
      sql = "SELECT active FROM sms_lcrproviders WHERE sms_lcr_id = '#{self.id}' AND sms_provider_id = '#{provider_id}' "
      res = ActiveRecord::Base.connection.select_value(sql)      
      res == "1"
    end
    
    
end
