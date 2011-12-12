class Location < ActiveRecord::Base

  has_many :locationrules, :order => "name ASC"
  has_many :devices


  validates_presence_of :name, :message=> _('Name_cannot_be_blank')

  def before_create
    current = User.current
    if current
      if current.usertype.to_s == 'admin'
        self.user_id ||= current.id
      else
        self.user_id = current.id
      end
    end
  end

  
  def destroy_all
    for rule in locationrules
      rule.destroy
    end
    self.destroy
  end

  def Location.nice_locilization(cut, add, dst)
    start = 0
    start = cut.length.to_i if cut
    add.to_s + dst[start, dst.length.to_i].to_s
  end

  end
