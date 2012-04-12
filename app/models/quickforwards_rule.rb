# -*- encoding : utf-8 -*-
class QuickforwardsRule < ActiveRecord::Base
  has_many :users
  belongs_to :user

  validates_presence_of :name, :message => _('Name_cannot_be_blank')
  #validates_presence_of :rule_regexp, :message=> _('Regexp_cannot_be_blank')

  before_create :q_before_create

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


end
