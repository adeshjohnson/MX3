# -*- encoding : utf-8 -*-
class Didrate < ActiveRecord::Base

  belongs_to :did


  def did_rate_details
    Didrate.find(:all, :conditions => ['did_id=? and rate_type=? and daytype = ?', did_id, rate_type, daytype], :order => 'start_time ASC')
  end

  def did_rate_details_all
    Didrate.find(:all, :conditions => ['did_id=? and rate_type=?', did_id, rate_type], :order => 'start_time ASC')
  end

  def Didrate.find_hours_for_select(options={})
    cond = []; var =[]
    if options[:d_search].to_s == 'true'
      if !options[:did].blank?
        cond  << 'dids.did LIKE ?'
        var  << options[:did]
      end
    else
      cond = ['dids.did Between ? AND ?']
      var = [options[:did_from], options[:did_till]]
    end
    cond << 'daytype = ?'; var << [options[:day]]
    Didrate.includes(:did).where([cond.join(' AND ')] + var).group('didrates.start_time, didrates.end_time').order('didrates.start_time').all
  end
end
