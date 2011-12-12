class FlatrateData < ActiveRecord::Base
  belongs_to :subscription
  set_table_name "flatrate_data"
end