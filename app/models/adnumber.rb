# -*- encoding : utf-8 -*-
class Adnumber < ActiveRecord::Base
  belongs_to :campaign
  has_many :ivr_action_logs
end
