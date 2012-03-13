# -*- encoding : utf-8 -*-
class Didrate < ActiveRecord::Base

  belongs_to :did


  def did_rate_details
    Didrate.find(:all, :conditions=>['did_id=? and rate_type=? and daytype = ?', did_id, rate_type, daytype], :order=>'start_time ASC')
  end

  def did_rate_details_all
    Didrate.find(:all, :conditions=>['did_id=? and rate_type=?', did_id, rate_type], :order=>'start_time ASC')
  end
end
