# -*- encoding : utf-8 -*-
class Usergroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :user

  before_create :check_menager_size_in_group

    def check_menager_size_in_group
      if Usergroup.count(:all, :conditions=>['group_id=? AND gusertype = "manager"', self.group_id]).to_i > 0 and self.gusertype == 'manager'
        errors.add(:gusertype, _("Call_Shop_can_have_only_one_manager"))
        return false
      end
    end

end
