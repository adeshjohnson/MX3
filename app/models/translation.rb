# -*- encoding : utf-8 -*-
class Translation < ActiveRecord::Base
  has_many :user_translations, :dependent => :destroy

  def self.default
    t = find(:first, :order => "position ASC")
    return t ? t.name : "English"
  end

  def Translation.get_actyve
    Translation.find(:all, :conditions => {:active => 1}, :order => 'short_name ASC')
  end
end
