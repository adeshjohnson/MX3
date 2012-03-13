# -*- encoding : utf-8 -*-
class CommonUseProvider < ActiveRecord::Base
  def self.table_name() "common_use_providers" end
  belongs_to :user, :foreign_key => 'reseller_id'
  belongs_to :provider, :foreign_key => 'provider_id'
  belongs_to :tariff, :foreign_key => 'tariff_id'
 
=begin
  Check whether all providers are common for both users.
  1.if any user has any own providers this would automaticaly mean that users have some providers
  that are not in common.
  2.if both users have no common use prviders or only one user has common use provider, other does 
  not, that automaticaly means that users have some providers that are not common
  3.ONLY if both users DO NOT HAVE OWN providers, and HAVE at least one COMMON USE provider, and every
  provider is common to both users, ONLY then both users have common user providers.
  It does not matter in what order you supply parameters(resellerA, resellerB)

  *Returns*
  +boolean+ true or false depending whether both users have only providers that are common for them both
=end
  def self.common_use_providers?(resellerA, resellerB)
    if resellerA.is_reseller? and resellerB.is_reseller?
       if resellerA.has_own_providers? or resellerB.has_own_providers?
         return false
       else
         query = "SELECT GROUP_CONCAT(provider_id ORDER BY provider_id) provider_list 
                  FROM   common_use_providers 
                  WHERE  reseller_id IN (#{resellerA.id}, #{resellerB.id})
                  GROUP BY reseller_id"
         #We should get two lists of common use providers associated with both resellers.
         #If providers[0] != providers[1], would mean that the supplied resellers does 
         #not have identical common use providers. but if providers[0] = providers[1], 
         #it would mean that both providers have same common use providers. 
         #to compare those provider_id lists we convert then to arrays.
         providers = CommonUseProvider.find_by_sql(query)
         if providers.size == 2
           providers[0].provider_list.split(',') == providers[1].provider_list.split(',')
         else
            false
         end 
       end
    else
       raise "Both users has to be resellers"
    end
  end 

end
