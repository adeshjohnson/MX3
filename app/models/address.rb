class Address < ActiveRecord::Base
  belongs_to :direction
  has_one :cc_client
  
    def before_save

    if self.email.to_s.length > 0 and !Email.address_validation(self.email)
      errors.add(:email, _("Please_enter_correct_email")) 
      return false
    end
  end
end
