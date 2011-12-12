class RinggroupsDevice < ActiveRecord::Base
  belongs_to :ringroup
  belongs_to :device
end