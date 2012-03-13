# -*- encoding : utf-8 -*-
class Pbxfunction < ActiveRecord::Base

  has_many :dialplans, :class_name => 'Dialplan', :foreign_key => 'data1'
  belongs_to :user

  before_save :pbx_before_save

  def pbx_before_save
    self.user_id = User.current.id
  end

  def dialplans
    Dialplan.find(:all, :conditions => "data1 = #{self.id}", :order => "#{self.name}")
    
  end
  
end
