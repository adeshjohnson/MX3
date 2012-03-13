# -*- encoding : utf-8 -*-
class Right < ActiveRecord::Base
  has_many :role_rights, :dependent => :delete_all;
  validates_uniqueness_of :controller, :scope => :action
end
