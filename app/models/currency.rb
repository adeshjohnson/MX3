class Currency < ActiveRecord::Base

  has_many :users

  validates_length_of :name,  :maximum => 5 , :message => _('Currency_Name_is_to_long_Max_5_Simbols')
  validates_numericality_of :exchange_rate, :greater_than=>0.to_f, :on => :create, :message => _('Currency_exchange_rate_canot_be_blank')
  validates_presence_of :name, :message => _('Currency_must_have_name')
  validates_uniqueness_of :name,  :message => _('Currency_Name_Must_Be_Unique')

  def tariffs
    Tariff.find_by_sql ["SELECT tariffs.id FROM tariffs WHERE currency = ? UNION SELECT sms_tariffs.id FROM sms_tariffs WHERE currency = ?", self.name, self.name]
  end

  def Currency::get_active
    Currency.find(:all, :conditions => ["active = '1'"])
  end

  def Currency.count_exchange_rate(curr1, curr2)
    if curr1 == curr2
      return 1.0
    else
      curr1 = Currency.find(:first, :conditions => ["name = ?", curr1]) if curr1.class != Currency
      curr2 = Currency.find(:first, :conditions => ["name = ?", curr2]) if curr2.class != Currency
      if curr2 and curr1
        return curr2.exchange_rate.to_f / curr1.exchange_rate.to_f
      else
        return 0.0
      end
    end
  end

  def Currency.count_exchange_prices(options={})
    if options[:exrate].to_f > 0.to_f
      new_prices = []
      options[:prices].each{|p|new_prices << p.to_f * options[:exrate].to_f}
      return *new_prices
    else
      return *options[:prices]
    end
  end

=begin rdoc
 Wrapper method. For future caching.
=end

  def Currency.get_by_name(name)
    Currency.find(:first, :conditions => ["name = ?", name])
  end

  def Currency.get_default
    Currency.find(:first, :conditions => "id = 1")
  end

  def set_default_currency
    begin
      transaction do
        old_curr = Currency.get_default
        temp_curr = old_curr.clone
        old_curr.name = self.name
        old_curr.full_name= self.full_name
        old_curr.exchange_rate = 1
        old_curr.active = 1
        old_curr.save(false)
        self.name = temp_curr.name
        self.active = 0
        self.full_name = temp_curr.full_name
        self.save(false)
        Currency.update_currency_rates
        return old_curr.name
      end
    rescue Exception => e
      return false
    end
  end

  def Currency.update_currency_rates(id = -1)
    require 'net/http'
    default_currency = Currency.get_default
    par = []
    arr= id.to_i  > 0 ?{:conditions=>["id=?", id]} : {:conditions=>["curr_update=1 AND id != 1"]}
    currencies = Currency.find(:all, arr)
    if currencies
      currencies.each{|cur| par << "s=" + default_currency.name.strip.to_s + cur.name.strip.to_s + "=X"}
      par << "f=l1"
      Net::HTTP.start("download.finance.yahoo.com") { |http| resp = http.get('/d/quotes.csv?'+par.join('&').to_s) ; @file = resp.body}
      @file.each_with_index{|cur, i| currencies[i].exchange_rate= cur.to_f; currencies[i].last_update = Time.now; currencies[i].save }
      Action.add_action(User.current.id, "Currency updated", id)
    end  
  end

  def update_rate
    begin
      transaction do
        Currency.update_currency_rates(self.id)
      end
    rescue Exception => e
      return false
    end
  end

  def Currency.check_first_for_active
    c = Currency.get_default
    if c.active == 0
      c.active = 1
      c.save
    end
  end

end