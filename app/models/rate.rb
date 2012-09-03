# -*- encoding : utf-8 -*-
class Rate < ActiveRecord::Base

  belongs_to :destination
  belongs_to :destinationgroup
  belongs_to :tariff
  has_many :ratedetails, :order => "daytype DESC, start_time ASC"
  has_many :aratedetails, :order => "id ASC"

  validates_presence_of :tariff_id
  validates_presence_of :destination_id

  def ratedetails_by_daytype(daytype)
    Ratedetail.find(:all, :conditions => "rate_id = #{self.id} AND daytype = '#{daytype}'", :order => "daytype DESC, start_time ASC")
  end

  def aratedetails_by_daytype(daytype)
    Aratedetail.find(:all, :conditions => "rate_id = #{self.id} AND daytype = '#{daytype}'", :order => "daytype DESC, start_time ASC")
  end

  def destroy_everything

    #rate details
    for rd in self.ratedetails
      rd.destroy
    end

    #advanced rate details
    for ard in self.aratedetails
      ard.destroy
    end

    self.destroy
  end

  def Rate.get_personal_rate_details(tariff, dg, user_id, exrate)
    rate = dg.rate(tariff.id)
    arates = []
    arates = Aratedetail.find(:all, :conditions => "rate_id = #{rate.id} AND artype = 'minute'", :order => "price DESC") if rate

    #check for custom rates
    crates = []
    crate = Customrate.find(:first, :conditions => "user_id = '#{user_id}' AND destinationgroup_id = '#{dg.id}'")
    if crate && crate[0]
      crates = Acustratedetail.find(:all, :condition => "customrate_id = '#{crate[0].id}'", :order => "price DESC")
      arates = crates if crates[0]
    end
    arate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [arates[0].price.to_d]}) if arates[0]
    return arates, crates, arate_cur
  end


=begin rdoc

=end

  def Rate.get_provider_rate(call, direction, exrate)
    prov_price = direction == "incoming" ? call.did_prov_price : call.provider_price
    rate_cur, rate_cpr = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d, prov_price.to_d]})
    return rate_cur, rate_cpr
  end

  def Rate.get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.find(:all, :conditions => "rate_id = #{rate.id.to_s}", :order => "rate DESC")
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({:exrate => exrate, :prices => [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]})
    end
    return @rate_details, @rate_cur
  end

  def Rate.get_user_rate_details(rate, exrate)
    @arate_details = Aratedetail.find(:all, :conditions => "rate_id = #{rate.id.to_s} AND artype = 'minute'", :order => "price DESC")
    @arate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [@arate_details[0]['price'].to_d]}) if @arate_details.size > 0
    return @arate_details, @arate_cur
  end
end
