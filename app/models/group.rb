# -*- encoding : utf-8 -*-
class Group < ActiveRecord::Base
  has_many :usergroups, :dependent => :destroy
  belongs_to :user, :foreign_key => 'owner_id'
  belongs_to :translation

  def users
    User.find_by_sql ["SELECT users.* FROM users, usergroups WHERE users.id = usergroups.user_id AND usergroups.group_id = ? ORDER BY gusertype ASC, position ASC", self.id]
  end

  def simple_users
    User.find_by_sql ["SELECT users.* FROM users, usergroups WHERE users.id = usergroups.user_id AND usergroups.group_id = ? AND usergroups.gusertype = 'user' ORDER BY gusertype ASC, position ASC", self.id]
  end

  def manager_users
    User.find_by_sql ["SELECT users.* FROM users, usergroups WHERE users.id = usergroups.user_id AND usergroups.group_id = ? AND usergroups.gusertype = 'manager' ORDER BY gusertype ASC, position ASC", self.id]
  end

  def move_member(member, direction)
    unless (users.last == member and direction == "down") || (users.first == member and direction == "up")
      current_member = Usergroup.find(:first, :conditions => {:group_id => self.id, :user_id => member.id})
      if current_member.gusertype == "user"
        if direction == "down"
          following_member = Usergroup.find(:first, :conditions => {:group_id => self.id, :position => current_member.position + 1})
          current_member.update_attribute(:position, current_member.position + 1)
          following_member.update_attribute(:position, following_member.position - 1)
        else
          previous_member = Usergroup.find(:first, :conditions => {:group_id => self.id, :position => current_member.position - 1})
          current_member.update_attribute(:position, current_member.position - 1)
          previous_member.update_attribute(:position, previous_member.position + 1) if previous_member
        end
        true
      else
        false
      end
    else
      false
    end
  end

  def logged_users
    lu=[]
    for user in self.users
      lu << user if user.logged == 1
    end
    lu
  end

  def gusertype(user)
    ut = ""
    if self.users.include?(user)
      #my_debug "self.users.include?(user): true"
      ut = ActiveRecord::Base.connection.select_value("SELECT gusertype FROM usergroups WHERE group_id='" + self.id.to_s + "' AND user_id='" + user.id.to_s + "'").to_s
    end
    ut
  end

  ##==============================================================

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

end
