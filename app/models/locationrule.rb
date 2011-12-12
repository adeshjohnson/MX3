class Locationrule < ActiveRecord::Base

  belongs_to :location
  belongs_to :tariff
  belongs_to :lcr
  belongs_to :did
  belongs_to :device

  def before_save
    current = User.current
    if current
      usertype = current.usertype
      if ['admin', 'accountant'].include?(usertype)
        uid = 0
      else
        uid = User.current.id
      end
      if !['admin', 'accountant'].include?(usertype)
        unless location.user_id == uid
          errors.add(:location, _("Location_error"))
          return false
        end
      end
    end
    if cut.blank? and add.blank?
      errors.add(:cut_add, _("Cut_and_Add_canot_be_empty"))
      return false
    end
  end

  validates_uniqueness_of :cut, :scope => [:add, :location_id], :message => _('Rule_Must_Be_Unique'), :if => :check_min_and_max
  validates_presence_of :name, :message => _('Rule_must_have_name')


  def check_min_and_max
    Locationrule.count(:all, :conditions=>["NOT ((? < minlen AND ? < minlen) OR (? > maxlen and ? > maxlen ) ) AND location_id = ? AND locationrules.add = ? and cut = ? AND id != ? AND lr_type = ?", minlen, maxlen, minlen, maxlen,location_id,add, cut, id.to_i, lr_type]).to_i > 0
  end

end
