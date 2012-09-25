class ServerDevice < ActiveRecord::Base
  belongs_to :device
  belongs_to :server
end
