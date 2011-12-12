class CcGhostminutepercent < ActiveRecord::Base
  def self.table_name() "cc_gmps" end
  belongs_to :cardgroup


end