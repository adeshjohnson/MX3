# -*- encoding : utf-8 -*-
class AccGroup < ActiveRecord::Base
  attr_protected :group_type
  has_many :users
  has_many :acc_group_rights, :dependent => :destroy
  validates_presence_of :name, :message => _("Group_Name_Must_Be_Set")
  validates_uniqueness_of :name, :message => _("Group_Name_Must_Be_Unique")

  before_destroy :acc_group_before_destroy
=begin rdoc
 Performs validation before destroy
=end

  def acc_group_before_destroy
    if User.find(:first, :conditions => ["acc_group_id = ?", self.id])
      errors.add(:users, _("Group_has_assigned_users"))
      return false
    end
    return true
  end

  def self.accountants
    self.find(:all, :conditions => ["group_type = 'accountant'"])
  end

  def self.resellers
    self.find(:all, :conditions => ["group_type = 'reseller'"])
  end

  def create_empty_permissions
    AccRight.find(:all, :conditions => ["right_type = ?", self.group_type]).each do |acc_right|
      AccGroupRight.create(:acc_group_id => self.id, :acc_right_id => acc_right.id, :value => 0)
    end
  end
end
