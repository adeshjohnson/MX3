# -*- encoding : utf-8 -*-
class Currency < ActiveRecord::Base

  has_many :users

  validates_length_of :name, :maximum => 5, :message => _('Currency_Name_is_to_long_Max_5_Symbols')
  validates_numericality_of :exchange_rate, :greater_than => 0.to_d, :on => :create, :message => _('Currency_exchange_rate_cannot_be_blank')
  validates_presence_of :name, :message => _('Currency_must_have_name')
  validates_uniqueness_of :name, :message => _('Currency_Name_Must_Be_Unique')

  before_save :is_used_by_users?

  def tariffs
    Tariff.find_by_sql ["SELECT tariffs.id FROM tariffs WHERE currency = ? UNION SELECT sms_tariffs.id FROM sms_tariffs WHERE currency = ?", self.name, self.name]
  end

  def is_used_by_users?
    if active == 0 and not users.count.zero?
      errors.add(:active, _('currency_is_used_by_users')) and return false
    end
  end

  def Currency::get_active
    Currency.find(:all, :conditions => ["active = '1'"])
  end

  def Currency.count_exchange_rate(curr1, curr2)
    #curr1 is ko
    #curr2 i ka
    if curr1 == curr2
      return 1.0
    else
      curr1 = Currency.find(:first, :conditions => ["name = ?", curr1]) if curr1.class != Currency
      curr2 = Currency.find(:first, :conditions => ["name = ?", curr2]) if curr2.class != Currency
      if curr2 and curr1 and curr1.exchange_rate.to_d != 0.0
        # preventing ruby Infinity number
        balance = curr2.exchange_rate.to_d / curr1.exchange_rate.to_d
        balance.to_s == "Infinity" ? balance = 0.to_d : false
        return balance
      else
        return 0.0
      end
    end
  end

  def Currency.count_exchange_prices(options={})
    if options[:exrate].to_d > 0.to_d
      new_prices = []
      options[:prices].each { |p| new_prices << p.to_d * options[:exrate].to_d }
      a = new_prices #.to_sentence
    else
      a = options[:prices] #.to_sentence
    end
    if a.size == 1
      return a[0]
    else
      return *a
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
    old_curr = Currency.get_default
    begin
      transaction do
        change_default_currency(old_curr, self)
        notice = Currency.update_currency_rates
        if notice
          return old_curr.name
        else
          change_default_currency(old_curr, self)
          return false
        end
      end
    rescue Exception => e
      change_default_currency(old_curr, self)
      return false
    end
  end

  # Action is called from daily_actions and from GUI -> Settings
  # If it is called from daily_actions there will be no session, so user.current is undefined.

  def Currency.update_currency_rates(id = -1)
    require 'net/http'
    default_currency = Currency.get_default
    par = []
    notice = true
    arr= id.to_i > 0 ? {:conditions => ["id=?", id]} : {:conditions => ["curr_update=1 AND id != 1"]}
    currencies = Currency.find(:all, arr)
    if currencies and not currencies.empty?
      currencies.each { |cur| par << "s=" + default_currency.name.to_s.strip + cur.name.to_s.strip + '=X' }
      par << 'f=l1'
      index = 0
      connection_closed = 'Server Connection Closed'

      begin
        index += 1
        Net::HTTP.start('download.finance.yahoo.com') { |http| resp = http.get('/d/quotes.csv?'+par.join('&').to_s); @file = resp.body }
      end while @file.include?(connection_closed) and index < 5

      if !@file.include?(connection_closed)
        f = @file.split("\r\n")
        f.each_with_index { |cur, i|
          currency = cur.to_d
          currencies[i].exchange_rate= (currency == 0 ? 1 : currency)
          currencies[i].last_update = Time.now
          currencies[i].save
          if currency == 0
            Action.add_action_hash(User.current ? User.current.id : 0, {:target_id => currencies[i].id, :target_type => 'currency', :action => 'failed_to_update_currency', :data => currencies[i].exchange_rate})
          end
        }
        Action.add_action(User.current ? User.current.id : 0, 'Currency updated', id)
      else
        Action.add_action(User.current ? User.current.id : 0, 'Failed to update currency', id)
        notice = false
      end
    end
    return notice
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

  def change_default_currency(old_curr, new_curr)
          temp_curr = old_curr.dup
          old_curr.assign_attributes({
            name: new_curr.name,
            full_name: new_curr.full_name,
            exchange_rate: 1,
            active: 1
          })
          old_curr.save(validate: false)
          new_curr.assign_attributes({
            name: temp_curr.name,
            active: 0,
            full_name: temp_curr.full_name
          })
          new_curr.save(validate: false)
  end

end
