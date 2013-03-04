# -*- encoding : utf-8 -*-
class Address < ActiveRecord::Base
  belongs_to :direction
  has_one :cc_client

  validates :email, :uniqueness => {:message => _('Email_Must_Be_Unique')}, :allow_nil => true

  before_save :address_before_save

  def address_before_save

    if self.email.to_s.length > 0 and !Email.address_validation(self.email)
      errors.add(:email, _("Please_enter_correct_email"))
      return false
    end
  end
end
