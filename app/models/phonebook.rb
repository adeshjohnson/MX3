# -*- encoding : utf-8 -*-
class Phonebook < ActiveRecord::Base
  belongs_to :user

  validates_format_of :number, :with => /\A\d+\Z/, :message => _('Phonebook_number_must_be_numeric')
  validates_format_of :speeddial, :with => /\A\d+\Z/, :message => _('Speeddial_must_be_numeric')
  validates_length_of :speeddial, :minimum => 2, :message => _('Speeddial_can_only_be_2_and_more_digits')
  before_save :validate_speeddial_uniqueness

  def Phonebook.user_phonebooks(user)
    Phonebook.find(:all, :conditions => "(user_id = #{user.id} or user_id = 0) AND card_id = 0", :order => "name ASC")
  end

  private
=begin
  Phonebooks speeddial mus be unique for each user, but we have to remember that
  admin's phonebooks are global, so setting unique on user_id and speeddial is not 
  an option - speeddial has to be unique for phonebooks user and for admin.
  If phonebook is beeing updated(it has id) we should exclude information about it. 
  In case phonebooks owner is admin phonebooks must be globay unique, hence there is 
  no other condition, except for excluding phonebook itself(if it's already created) 
  But note that if phonebooks is associated with calling card it's user_id is set to 0, 
  0 is admin's id, so we have to exclude cards that are associated with callingcards. 
  And make sure that they are unique for that certain calling card
=end
  def validate_speeddial_uniqueness
    condition = "speeddial = '#{self.speeddial}'"
    if self.user.is_admin?
      if self.id
        condition += " AND id != #{self.id} "
      end
    else
      condition += " AND user_id IN (0, #{user.id})"
      if self.id
        condition += " AND id != #{self.id}"
      end
    end
    condition += " AND card_id = #{self.card_id}"
    count = Phonebook.count(:conditions => condition)
    if count == 0
      return true
    else
      errors.add(:speeddial, _('Speed_dial_must_be_unique'))
      return false
    end
  end
end

=begin
  If card_id is set to 0, it means that phonebook is not associated with card, otherwise it is 
  associated with some card. please note that in that case user_id is set to 0(that's admins id), 
  but in this case it means that it is not assigned to any user.
=end
  def assigned_to_card?
    self.card_id != 0
  end
