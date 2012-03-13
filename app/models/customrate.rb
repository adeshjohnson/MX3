# -*- encoding : utf-8 -*-
class Customrate < ActiveRecord::Base

  belongs_to :user
  has_many :acustratedetails
  belongs_to :destinationgroup


    def acustratedetails_by_daytype(daytype)
      Acustratedetail.find(:all, :conditions => "customrate_id = #{self.id} AND daytype = '#{daytype}'", :order => "daytype DESC, start_time ASC")
    end

  def destroy_all
    for acr in self.acustratedetails
      acr.destroy
    end
    self.destroy
  end

end
