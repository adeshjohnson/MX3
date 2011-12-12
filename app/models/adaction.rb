class Adaction < ActiveRecord::Base
  belongs_to :campaign

  def file_name
    data.to_s.split(".")[0]
  end
end
  