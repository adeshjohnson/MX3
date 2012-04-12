# -*- encoding : utf-8 -*-
class Providerrule < ActiveRecord::Base
  belongs_to :provider

  def before_transformation
    bt = "_" + self.start.to_s
    if self.length == 0
      bt += "X."
    else
      (self.length - self.start.length).times do
        bt += "X"
      end
    end
    bt
  end

  def after_transformation
    at = self.before_transformation
    at = "_" + self.add + at[self.cut + 1, at.length - self.cut - 1]
    at
  end

end
