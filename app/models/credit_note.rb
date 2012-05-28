# -*- encoding : utf-8 -*-
class CreditNote < ActiveRecord::Base
  belongs_to :user
  has_one :payment
  has_one :tax

  #No need to unpay credit note if it is deleted.
  #before_destroy :unpay

  validates_presence_of :issue_date, :message => _('Credit_note_must_have_issue_date')
  validates_presence_of :price, :message => _('Price_has_to_be_specified_and_greater_than_0') #gal nereikia?
  validates_numericality_of :price, :greater_than_or_equal_to => 0, :message => _('Price_has_to_be_specified_and_greater_than_0')
  validates_presence_of :price, :message => _('Price_with_tax_has_to_be_greater_than_0') #gal nereikia?
  validates_numericality_of :price, :greater_than_or_equal_to => 0, :message => _('Price_with_tax_has_to_be_greater_than_0')
  validates_uniqueness_of :payment_id, :message => _('Payment_must_be_unique'), :allow_nil => true

=begin
  if payment has not been made already, then paid credit note has to have set
  pay_date
  status='paid'
  new payment associated with it. 
  amount equal to credit note price has to be aded to users whitch is associated
  with credit note.
=end
  def pay
    unless self.payment_id
      payment = create_payment
      self.payment_id = payment.id
      self.status = 'paid'
      self.pay_date = Time.now
      self.save
      add_to_balance
    end
  end

=begin
  If payment was made and now we want to unpay - we have to delete payment and
  remove money from user's balance.
  But if there is no payment made, just method was called, we shouldnt destroy any payments
  or remove from balance, just set status to unpaid and pay pay_date to nil.
  Unpaid note's status has to be 'unpaid', pay_date and payment_id has to be set
  to NULL.
  TODO: make some kind of better association so that we could jus write 
  self.payment.destroy insted of Payment.destroy(self.payment_id); self.payment_id = nil
=end
  def unpay
    self.status = 'unpaid'
    self.pay_date = nil
    if self.payment_id
      Payment.destroy(self.payment_id)
      self.payment_id = nil
      remove_from_balance
    end
    self.save
  end

=begin
  *Returns*
  boolean, true or false depending whethter credit note is already paid or not
=end
  def paid?
    self.status == 'paid'
  end

=begin
  When price changes we must recalculate price with tax
  TODO: we cannot change price, especialy for paid notes.
  make this method private and set it only through constructor

  *Params*
  +price+ numeric datatype, price of note without taxs, in current
  users currency
=end

  def price= price
    if User.current and User.current.currency
      converted_price = (price.to_f / User.current.currency.exchange_rate.to_f).to_f
    else
      converted_price = price
    end
    write_attribute(:price, converted_price)
    self.price_with_vat = calculate_price_with_vat
  end

=begin
  Returns price converted to currency if current user has set it, else returns credit note
  price in system currency

  *Returns*
  +price+ float, credit note price without taxs
=end
  def price
    price = read_attribute(:price)
    if User.current and User.current.currency
      price.to_f * User.current.currency.exchange_rate.to_f
    else
      price.to_f
    end
  end

=begin
  Returns price with vat converted to currency if current user has set it, else returns
  credit note price with vat in system currency

  *Returns*
  +price+ float, credit note's price including taxs
=end
  def price_with_vat
    price = read_attribute(:price_with_vat)
    if User.current and User.current.currency
      price.to_f * User.current.currency.exchange_rate.to_f
    else
      price.to_f
    end
  end

=begin
  Before saveing issue date convert it from user time to system time
  TODO: should be private, because user can set issue date only when creating note
=end
  def issue_date= datetime
    write_attribute(:issue_date, User.current.system_time(datetime))
  end

=begin
  Convert issue date that is saved in system time to user's time

  *Returns*
  +issue_date+
=end
  def issue_date
    issue_date = read_attribute(:issue_date)
    User.current.user_time(issue_date)
  end

=begin
  Convert pay date that is saved in system time to user's time, if paydate is
  nil return it without any conversions

  *Returns*
  +pay_date+ datetime when note was paid in current users timezone
=end
  def pay_date
    datetime = read_attribute(:pay_date)
    if datetime
      User.current.user_time(datetime)
    end
  end

=begin
  Whenever user changes, price with tax has to be recalculated.
  So that we wouldn't loose information about taxes that were set
  at this moment we clone it and save for future references.
  Tax records that are no longer needed can not be destroyed
  because at this moment i can not know whether changes to the
  credit note will be saved or not. But there shoulnt be any
  situations where credit note user should/could be changed.
  TODO: make this method private and assign user only through
  constructor

  *Params*
  +user+ instance of User class
=end
  def user=(user)
    if self.user_id != user.id
      self.user_id = user.id
      @tax = user.get_tax.dup # this is nasty but could not figure out how to do it the right way
      @tax.save
      self.tax_id = @tax.id
      self.price_with_vat = calculate_price_with_vat
    end
  end

=begin
  List of credit note financial data(count of notes, price sum, price with vat sum) in 
  system currency grouped by theyr status. 

  *Params*
  +owner_id+ owner of users that the user is interested, but might be nil if 
     current user is ordinary user
  +user_id+ user that has credit note assigned to, might be nil if admin, reseller
     or accountant is not interested in specific user. but has to be specified if 
     user is of type 'user'
  +status+ if valid status of credit note, or none. valid are 'paid', 'unpaid', 
     'all'. might be nil, in that case all statuses will be selected  
  +from_date, till_date+ date as string
  +usertype+ boolean, true if user that is interested in financial statements is of type 'user'

  *Returns*
  +credit_notes* array or smth iterable of CreditNote instances, that has count, 
     price, price, with_vat and status
=end
  def self.financial_statements(owner_id, user_id, status, from_date, till_date, ordinary_user=true)
    #if user not is of type 'user' he must supply user_id. or else invalid params are supplied
    if ordinary_user and not user_id
      raise "invalid parameters, 'user' must supply his own id"
    end

    select = ["SELECT COUNT(*) AS count, SUM(price) AS price, SUM(price_with_vat) as price_with_vat, status"]
    select << "FROM credit_notes"
    condition = ["issue_date BETWEEN '#{from_date}' AND '#{till_date}'"]
    if not ordinary_user
      select << "JOIN users ON users.id = credit_notes.user_id"
      condition << "owner_id = #{owner_id}"
    end
    condition << "user_id = #{user_id}" if user_id and user_id != 'all'
    if status != 'all' and ['paid', 'unpaid'].include? status
      condition << "status = '#{status}'"
    end
    group_by = " GROUP BY status"

    query = select.join("\n") + ' WHERE ' + condition.join(" AND\n") + group_by
    Device.find_by_sql(query)
  end


  private

=begin
  When saveing pay date convert it from user time to system time. unless it is nil
  then save it as it is. Only way to set pay date is when setting note to payd, so no
  one outside class(pay method) cannot set pay date, that is why this method is private

  *Params*
  +date+
=end
  def pay_date= datetime
    if datetime
      datetime = User.current.system_time(datetime)
    end
    write_attribute(:pay_date, datetime)
  end

=begin
  It is posible to calculate price with tax only if tax and price
  are specified. Else this function can not calculate any meaningful
  value and returns nil. The catch is that null value cannot be saved
  to database.
  Method is created so that it does not take any params(like price or tax)
  intentionaly. So that the only way to change price with tax would be by
  changeing user or price.
  No tax conversion are applied here, price has to be set in right currency
  before calculating taxs.

  *Returns*
  +price_with_tax+ float, price(in system currency) with tax. but only if tax
  and price are specified, else nil if one of them is not specified.
=end
  def calculate_price_with_vat
    if @tax and self.price
      if User.current and User.current.currency
        converted_price = (self.price.to_f / User.current.currency.exchange_rate.to_f).to_f
      else
        converted_price = self.price
      end
      price_with_vat = @tax.apply_tax(converted_price)
      return price_with_vat
    else
      nil
    end
  end

=begin
  when credit note is paid, we have to create payment of type 'credit note' and
  associate it with credit note. this method should be executed only once, so if
  payment was already associated with note no way we can create one more payment.
  To be 100% sure creating payment and making association(and adding price amount
  to users balance) should be done in transaction..
  Note that self.price and self.price_with_vat returns price in current users
  currency, so we shloud set payment.currency to exaclty that currency name(strange
  association huh?).
=end
  def create_payment
    unless self.payment_id
      payment = Payment.new
      payment.paymenttype = 'credit note'
      payment.amount = self.price
      payment.currency = User.current.currency.name
      payment.date_added = Time.now
      payment.shipped_at = Time.now
      payment.completed = 1
      payment.user_id = self.user.id
      payment.owner_id = self.user.owner_id
      payment.tax = tax.count_tax_amount(self.price)
      payment.save
      return payment
    end
  end

=begin
  very nasty but coudnt figure out how to make propper relationships to work
=end
  def tax
    Tax.find(self.tax_id)
  end

=begin
  When credit note is paid, it's price has to be added to user's balance
=end
  def add_to_balance
    self.user.balance += self.price
    self.user.save
  end

=begin
  When credit note is unpaid, it's price has to be subtracted to user's balance
=end
  def remove_from_balance
    self.user.balance -= self.price
    self.user.save
  end

end
