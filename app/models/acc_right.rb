# -*- encoding : utf-8 -*-
class AccRight < ActiveRecord::Base
  attr_protected :right_type

  has_many :acc_group_rights, :dependent => :destroy
end
