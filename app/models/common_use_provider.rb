class CommonUseProvider < ActiveRecord::Base
  def self.table_name() "common_use_providers" end
  belongs_to :user, :foreign_key => 'reseller_id'
  belongs_to :provider, :foreign_key => 'provider_id'
  belongs_to :tariff, :foreign_key => 'tariff_id'
  

end