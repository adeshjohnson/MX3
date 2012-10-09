# -*- encoding : utf-8 -*-
class ServerDevice < ActiveRecord::Base
  belongs_to :device
  belongs_to :server
end
