# -*- encoding : utf-8 -*-
class Cardgroup < ActiveRecord::Base
  belongs_to :tariff
  belongs_to :lcr
  belongs_to :location
  belongs_to :tax, :dependent => :destroy
  belongs_to :owner, :class_name => 'User', :foreign_key => 'owner_id'

  has_many :cards, :order => "number ASC", :dependent => :destroy
  has_many :cc_ghostminutepercents, :dependent => :destroy

  validates_uniqueness_of :name, :message => _('Cardgroup_name_must_be_unique')
  validates_presence_of :name, :message => _('Cardgroup_must_have_name')
  validates_presence_of :tariff, :message => _('Cardgroup_must_have_name')

  attr_protected :owner_id
  before_save :before_save_dates, :check_location_id, :validate_pin_length
  before_save :before_save_dates, :check_location_id, :validate_pin_length
  before_destroy :validate_before_destroy

  default_scope where(:hidden => 0)


  def validate_pin_length
    if (0..30).include?(self.pin_length.to_i)
      return true
    else
      errors.add(:pin_length, _('Pin_length_can_be_between_0_and_30'))
      return false
    end
  end


  def before_save_dates
    self.valid_from = (Date.today.to_s + " 00:00:00") if self.valid_from.blank? or self.valid_from.to_s == '0000-00-00 00:00:00'
    self.valid_till = (Date.today.to_s + " 23:59:59") if self.valid_till.blank? or self.valid_till.to_s == '0000-00-00 00:00:00'
  end

  def check_location_id
    if self.owner and self.owner.id != 0
      #if old location id - create and set
      value = Confline.get_value("Default_device_location_id", self.owner.id)
      if value.blank? or value.to_i == 1 or !value
        self.owner.after_create_localization
      else
#if new - only update devices with location 1
        self.owner.update_resellers_cardgroup_location(value)
      end
    end
  end

  def delete_all_cards
    for c in self.cards
      c.destroy
    end
  end

  def validate_before_destroy
    if Dialplan.count(:all, :conditions => {:data2 => pin_length, :data1 => number_length, :dptype => 'callingcard'}).to_i > 0 and Cardgroup.count(:all, :conditions => {:pin_length => pin_length, :number_length => number_length, :hidden=>0, :owner_id=>owner_id}).to_i < 2
      errors.add(:dialplan, _('Cardgroup_is_associated_with_dialplans'))
      return false
    end
    if Dialplan.count(:all, :conditions => {:data7 => id, :data6 => 1, :dptype => 'authbypin'}).to_i > 0
      errors.add(:dialplan, _('Cardgroup_is_used_in_ANI_PIN_Dialplan'))
      return false
    end
  end

  def destroy_or_hide

    if Card.where(['cardgroup_id = ? AND number NOT LIKE "DELETED%"', id]).first
      if Card.count(:all, :conditions => ['user_id != -1 AND cardgroup_id = ?', id]) > 0
        distrobutor_cards = Card.find(:all, :conditions => ['user_id != -1 AND cardgroup_id = ?', id])
        for dsc in distrobutor_cards
          c_u_id = dsc.id
          dsc.user_id = -1
          dsc.save
          Action.add_action_hash(User.current, {:action => 'card_separated_from_user', :target_id => dsc.id, :target_type => 'Card', :data => c_u_id})
        end
      end


      Card.delete_and_hide_from_sql({:cardgroup_id => id, :start_num => self.first_start_number, :end_num => self.last_end_number})

    end

    unless Card.where( ['cardgroup_id = ?', id]).first
      # destroy ghost minute percent records
      gmps = self.cc_ghostminutepercents
      if gmps and gmps.size.to_i > 0
        for gmp in gmps
          gmp.destroy
        end
      end
      Action.add_action_hash(User.current, {:action => 'calling_card_group_deleted', :target_id => id, :target_type => 'CardGroup'})
      self.destroy
    else
      self.hidden = 1
      self.save
      Action.add_action_hash(User.current, {:action => 'calling_card_group_deleted_and_hidden', :target_id => id, :target_type => 'CardGroup'})
    end

  end

  def first_start_number
    Card.where(['cardgroup_id =? AND number NOT LIKE "DELETED%"', id]).order('number ASC').first.number.to_s
  end

  def last_end_number
    Card.where(['cardgroup_id =? AND number NOT LIKE "DELETED%"', id]).order('number DESC').first.number.to_s
  end

  def is_owned_by?(user)
    owner_id == user.id
  end

  def is_not_owned_by?(user)
    owner_id != user.id
  end

  def groups_salable_card
    Card.find(:first, :conditions => ["cardgroup_id = ? AND sold = 0", self.id], :order => "rand()")
  end

  def assign_default_tax(tax={}, opt ={})
    options = {
        :save => true
    }.merge(opt)
    if !tax or tax == {}
      if self.owner_id
        new_tax = User.where({:id => self.owner_id}).first.get_tax.dup
      else
        new_tax = Confline.get_default_tax(0)
      end
    else
      new_tax = Tax.new(tax)
    end
    logger.fatal new_tax.to_yaml
    new_tax.save if options[:save] == true
    self.tax_id = new_tax.id
    self.save if options[:save] == true
  end

  def get_tax
    self.assign_default_tax if self.tax.nil? or self.tax_id.to_i == 0 or !self.tax
    self.tax
  end

  def Cardgroup.set_tax(tax, owner_id)
    cardgroups = Cardgroup.includes([:tax]).where(["owner_id = ?", owner_id]).all
    for cardgroup in cardgroups
      if !cardgroup.tax
        cardgroup.tax = Tax.new
      end
      cg_tax = cardgroup.tax
      cg_tax.update_attributes(tax)
      cg_tax.save
      cardgroup.save
    end
    true
  end

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b
    end
  end

  def price= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:price, b)
  end

  # converted attributes for user in current user currency
  def setup_fee
    b = read_attribute(:setup_fee)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b
    end
  end

  def setup_fee= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:setup_fee, b)
  end

  def daily_charge
    b = read_attribute(:daily_charge)
    if User.current and User.current.currency
      b.to_f * User.current.currency.exchange_rate.to_f
    else
      b
    end
  end

  def daily_charge= value
    if User.current and User.current.currency
      b = (value.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      b = value
    end
    write_attribute(:daily_charge, b)
  end

  def fix_when_is_rendering
    self.setup_fee = setup_fee * User.current.currency.exchange_rate.to_f
    self.daily_charge = daily_charge * User.current.currency.exchange_rate.to_f
  end


  def analize_card_import(name, options)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV analize_file #{name}", 1)
    arr = {}
    current_user = User.current.id
    arr[:calls_in_db] = Call.count(:all, :conditions => {:reseller_id => current_user}).to_i

    # set error flag on dublicates number | code : 1
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 1 WHERE col_#{options[:imp_number]} IN (SELECT prf FROM (select col_#{options[:imp_number]} as prf, count(*) as u from #{name} group by col_#{options[:imp_number]}  having u > 1) as imf )")

    # set error flag on dublicates pin | code : 2
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 2 WHERE col_#{options[:imp_pin]} IN (SELECT prf FROM (select col_#{options[:imp_pin]} as prf, count(*) as u from #{name} group by col_#{options[:imp_pin]}  having u > 1) as imf )")


    # set error flag on not int number | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 3 WHERE replace(col_#{options[:imp_number]}, '\\r', '') REGEXP '^[0-9]+$' = 0")

    # set error flag on not int pin | code : 4
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 4 WHERE replace(col_#{options[:imp_pin]}, '\\r', '') REGEXP '^[0-9]+$' = 0")

    if  options[:imp_balance] >= 0
      # set error flag on not int balance | code : 5
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 5 WHERE replace(col_#{options[:imp_balance]}, '\\r', '') REGEXP '^[0-9.\-]+$' = 0")
    end

    # set error flag on length number | code : 6
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 6 WHERE LENGTH(replace(col_#{options[:imp_number]}, '\\r', '')) != #{number_length.to_i}")

    # set error flag on length pin | code : 7
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 7 WHERE LENGTH(replace(col_#{options[:imp_pin]}, '\\r', '')) != #{pin_length.to_i}")

    # set not_found_in_db flag
    ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN cards ON (cards.pin = replace(col_#{options[:imp_pin]}, '\\r', '') AND cards.cardgroup_id = #{id} AND cards.number = replace(col_#{options[:imp_number]}, '\\r', '')) SET not_found_in_db = 1 WHERE cards.id IS NULL AND f_error = 0")

    arr[:bad_cards] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 1").to_i
    arr[:cards_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 AND not_found_in_db = 1").to_i
    arr[:existing_cards_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 AND not_found_in_db = 0").to_i
    arr[:card_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0").to_i
    return arr
  end

  def create_from_csv(current_user, name, options)
    CsvImportDb.log_swap('create_cards_start')
    MorLog.my_debug("CSV create_cards #{name}", 1)
    count = 0

    s = []; ss=[]
    ["pin", "number", "cardgroup_id", "owner_id", 'sold', 'language', 'balance'].each { |col|

      case col
        when "cardgroup_id"
          s << id
        when "owner_id"
          so = current_user.usertype == 'accountant' ? 0 : current_user.id
          s << so
        when "balance"
          if options[:imp_balance] >= 0
            s << "replace(col_#{options["imp_#{col}".to_sym]}, '\\r', '')"
          else
            s << price
          end
        when 'sold'
          s << 0
        when 'language'
          s << '"eng"'
        else
          s << 'replace(col_' + (options["imp_#{col}".to_sym]).to_s + ", '\\r', '')"
      end
      ss << col
    }

    in_rd = "INSERT INTO cards (#{ss.join(',')})
                SELECT #{s.join(',')} FROM #{name}
                WHERE f_error = 0 AND not_found_in_db = 1"
    begin
      ActiveRecord::Base.connection.execute(in_rd)
      count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 AND not_found_in_db = 1").to_i
    end
    MorLog.my_debug("Created cards")
    CsvImportDb.log_swap('create_cards_end')
    errors = ActiveRecord::Base.connection.select_all("SELECT * FROM #{name} where f_error = 1")
    return count, errors
  end

=begin
  This is THE method to create cards. Probably only Cardgroup instance shoud create
  cards, because card has to have valid cardgroup. we could call it some sort of
  card factory. By default card would by created with balance equal to this cargroup
  price and it's owner same as this cardgroup owner.

  *Params*
  +hash+ - hash or parameters to create new card, note that some params are set
    to default values by the cardgroup

  *Returns*
  +Card instance+ that is not saved to database yet(!)
=end
  def create_card(details = {})
    card = Card.new({:cardgroup_id => self.id, :balance => self.price, :owner_id => self.owner_id}.merge(details))
    card.set_unique_number if not details.has_key?(:number) and card.number.to_i == 0
    card.set_unique_pin if not details.has_key?(:pin) and not card.pin
    return card
  end

  def free_cards_size
    self.cards ? self.cards.count(:all, :conditions => {:sold => 0}).to_i : 0
  end

end
