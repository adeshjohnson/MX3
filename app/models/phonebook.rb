class Phonebook < ActiveRecord::Base
  belongs_to :user

  validates_format_of :number, :with => /\A\d+\Z/, :message => _('Phonebook_number_must_be_numeric')
  validates_format_of :speeddial, :with => /\A\d+\Z/, :message => _('Speeddial_must_be_numeric')
  validates_length_of :speeddial, :minimum => 2, :message => _('Speeddial_can_only_be_2_and_more_digits')

  def Phonebook.user_phonebooks(user)
    Phonebook.find(:all, :conditions => "(user_id = #{user.id} or user_id = 0) AND card_id = 0", :order => "name ASC")
  end
end
