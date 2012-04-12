# -*- encoding : utf-8 -*-
class Monitoring < ActiveRecord::Base
  has_and_belongs_to_many :users
  belongs_to :owner, :class_name => 'User', :foreign_key => 'owner_id'

  # Period in past type to differentiate between minutes hours and days
  attr_writer :period_in_past_type
  # This is set if we're updating monitoring for single user. That means we need to create a new one and make one association.
  attr_accessor :user
  # Used to differentiate between new record and existent one
  attr_accessor :existent_record

  MONITORING_TYPES = {
    1 => 'Monitoring_call_price_sum_over_past_period',
    2 => 'Monitoring_simultaneous_calls_over_past_period'
  }.freeze

  validate do |monitoring|
    monitoring.amount_must_be_greater_than_zero
    monitoring.period_must_be_greater_than_thirty_minutes
    monitoring.must_have_at_least_one_action
    monitoring.monitoring_type_must_be_specified
  end

  before_create :m_before_create
  before_update :m_before_update
  after_create :m_after_create
  after_update :m_after_update
  after_initialize :m_after_initialize
 
  def m_before_create
    !self.is_duplicate? if !self.user_type.to_s.blank?
    self.owner_id = User.current.get_correct_owner_id
    ur = User.find(:first, :conditions=>{:id =>self.user})
    if ur and ur.owner_id != self.owner_id
      errors.add(:owner, _('Dont_be_so_smart'))
      return false
    end
  end

  def m_before_update
    !self.is_duplicate?
  end

  def m_after_create
    self.associate
    self.reload
    self.add_monitoring_action('create')
  end

  def m_after_update
    self.reload
    self.add_monitoring_action('update')
  end


  def add_monitoring_action(act)
    case act
    when 'create'
      typ = 'created'
    when 'update'
      typ = 'updated'
    when 'destroy'
      typ = 'destroyed'
    end
    Action.add_action_hash(User.current,
      { :action => "monitoring_#{act}",
        :data => "Monitoring #{typ}",
        :data2 => "period: #{self.parse_period} | limit: #{self.amount} #{Currency.get_default.name}",
        :data3 => "email: #{self.email} | block: #{self.block} | users: #{( self.users.any? ) ? self.users.map(&:username).join(" ") : _(self.user_type.capitalize).downcase}",
        :target_id => self.id,
        :target_type => "monitoring"
      })
  end

  # we should ensure monitoring uniqueness (validation does not fit here by design)
  def self.new_or_existent_from_params(params)
    monit = new(params)

    if existent = find(:first, {:conditions => { :period_in_past => monit.period_in_past, :mtype => monit.mtype, :block => monit.block, :email => monit.email, :amount => monit.amount, :user_type => monit.user_type, :monitoring_type => monit.monitoring_type}})
      existent.existent_record = true
      existent.user = monit.user
      return existent
    else
      monit.existent_record = false
      return monit
    end
  end

  def parse_period
    case self.period_in_past_type
    when "minutes"
      _("Thirty_minutes")
    when "hours"
      "#{self.period_in_past / 60} #{_('Hour_hours')}"
    when "days"
      "#{self.period_in_past / 1440} #{_('Day_days')}"
    end
  end

  def is_duplicate?
    typ = self.user_type.to_s.blank? ? " IS " : ' = '
    if Monitoring.find(:first, {:conditions =>["period_in_past=? AND mtype=? AND block=? AND email=? AND amount=? AND user_type#{typ}? AND id!=? AND owner_id =?",  self.period_in_past, self.mtype,  self.block,  self.email,  self.amount, self.user_type, self.id, self.owner_id]})
      return true
    else
      return false
    end
  end

  def amount_must_be_greater_than_zero
    if ['above', 'bellow'].include? self.monitoring_type and (!self.amount or self.amount <= 0.0)
      errors.add(:amount, _('Amount_must_be_greater_than_zero'))
      return false
    else
      return true
    end
  end

  def monitoring_type_must_be_specified
    unless ['above', 'bellow', 'simultaneous'].include? self.monitoring_type
      errors.add(:amount, _('Choose_monitoring_type'))
      return false
    end 
  end

  def period_must_be_greater_than_thirty_minutes
    if !self.period_in_past or self.period_in_past < 30
      errors.add(:amount, _('Period_must_be_greater_than_thirty_minutes'))
      return false
    end
  end

  def must_have_at_least_one_action
    if !self.email and !self.block
      errors.add(:block, _('Monitoring_must_either_be_blocking_or_notifying'))
      return false
    end
  end

  def period_in_past_type
    # if period is in minutes (less than 1 hour)
    @period_in_past_type ||= if period_in_past.blank? or period_in_past < 60
      "minutes"
      # if period is in hours (between 1 and 23hours)
    elsif period_in_past >= 60 and period_in_past < 1380
      "hours"
      # if period is in days (more than 23 hours)
    else
      "days"
    end
  end

  def m_after_initialize
    if self.monitoring_type == 'simultaneous'
      self.mtype = 2
    else
      self.mtype = 1 # monitoring type: calls price sum in past period, change me when new monitoring types will be added!
    end
  end

  # associates or deassociates user with monitoring
  def associate
    # we were adding new monitoring system-wide
    if user_type.blank?
      user = User.find_by_id(@user)
      user.monitorings << self unless user.monitorings.include?(self)
    end
  end

  def destroy_or_deassociate(user = nil)
    # means we delete monitoring for all users
    if user.blank?
      self.destroy
      # means that we deassociate single user with monitoring
    else
      self.users.delete(User.find_by_id(user))
      # if there are no users left destory monitoring
      if self.users.empty?
        self.destroy
      end
    end
  end

  def monitoring_types
    MONITORING_TYPES[mtype]
  end

  def block_user?
    block
  end

  def send_email?
    email
  end

  def existent?
    @existent_record
  end

  def simultaneous_calls
    find_all_users_sql = self.owner_id == 0 ? '' : " AND users.owner_id = #{self.owner_id} "

    if user_type && user_type =~ /postpaid|prepaid/ # monitoring for postpaids and prepaids
      users = User.find(:all,
        :select => 'callsA.dst dst, callA.calldate calldateA, callsA.src srcA, callsB.calldate calldateB, callsB.dst dstB',
        :conditions => ["callsA.calldate between callsB.calldate and callsB.calldate + INTERVAL callsB.duration SECOND AND callsA.uniqueid != callsB.uniqueid AND users.blocked = 0 AND users.postpaid = ? AND users.ignore_global_monitorings = 0 #{find_all_users_sql}", ((self.user_type == "postpaid") ? 1 : 0) ],
        :joins => "JOIN calls callsA ON (callsA.user_id = users.id AND callsA.calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))
                   JOIN calls callsB ON (callsA.dst = callsB.dst AND callsA.calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))")
    elsif user_type && user_type =~ /all/ # monitoring for all users
      users = User.find(:all,
        :select => 'callsA.dst dst, callA.calldate calldateA, callsA.src srcA, callsB.calldate calldateB, callsB.dst dstB',
        :conditions => ["callsA.calldate between callsB.calldate and callsB.calldate + INTERVAL callsB.duration SECOND AND callsA.uniqueid != callsB.uniqueid AND users.blocked = 0 AND users.ignore_global_monitorings = 0 #{find_all_users_sql}"],
        :group => "users.id",
        :joins => "JOIN calls callsA ON (callsA.user_id = users.id AND callsA.calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))
                   JOIN calls callsB ON (callsA.dst = callsB.dst AND callsA.calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))")
    else # monitoring for individual users
      users = User.find(:all,
        :select => 'callsA.dst dst, callA.calldate calldateA, callsA.src srcA, callsB.calldate calldateB, callsB.dst dstB',
        :conditions => ["callsA.calldate between callsB.calldate and callsB.calldate + INTERVAL callsB.duration SECOND AND callsA.uniqueid != callsB.uniqueid AND users.blocked = 0 AND users.ignore_global_monitorings = 0 #{find_all_users_sql}", self.id],
        :joins => "JOIN calls callsA ON (callsA.user_id = users.id AND callsA.calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))
                   JOIN calls callsB ON (callsA.dst = callsB.dst AND callsA.calldate > DATE_SUB(NOW(), INTERVAL #{self.period_in_past.to_i} MINUTE))")
    end
    return users
  end

end
