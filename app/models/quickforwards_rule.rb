# -*- encoding : utf-8 -*-
class QuickforwardsRule < ActiveRecord::Base
  has_many :users
  belongs_to :user

  validates_presence_of :name, :message => _('Name_cannot_be_blank')
  validates_format_of :rule_regexp, :with => /^[0-9\[\]\%\|\,]*$/, :message => _('Invalid_regexp')
  #validates_presence_of :rule_regexp, :message=> _('Regexp_cannot_be_blank')

  before_create :q_before_create

  before_save :check_prefix_regexp , :check_collisions_with_dids

  def q_before_create
    self.user_id = User.current.id
  end

  def will_macht
    rules = []
    ruls = rule_regexp.delete('%').to_s.split("|")
    ruls.each { |r|
      unless r.include?("[")
        rules << r.to_s + 'xxxxxxxxx'
      else
        numb = r.split("[")
        nn = numb[1].split(",")
        nn.each { |n|
          rules << numb[0].to_s + n.to_i.to_s + 'xxxxxxxxx'
        }
      end
    }
    return rules
  end

  def check_prefix_regexp
    begin
      QuickforwardsRule.find(:all, :conditions=>["rule_regexp REGEXP ?", self.rule_regexp])
    rescue
      errors.add(:prefix,_('Invalid_regexp'))
      return false
    end

    self.q_before_create if self.new_record?
  end

  def check_collisions_with_dids
    if rule_regexp.blank?
      regexp = '$'
    else
      regexp = rule_regexp.delete('%')
    end

    unless User.current.usertype == "reseller"
      dids = Did.includes(:dialplan).where("dids.did REGEXP('^(#{regexp})') AND dids.reseller_id != 0 AND (dialplans.dptype != 'quickforwarddids' OR (dialplans.id IS NULL))")
      if dids and dids.size.to_i > 0
        errors.add(:prefix,_('Collisions_with_Dids'))
        return false
      end
    end
  end

end
