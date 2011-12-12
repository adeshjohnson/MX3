class VoicemailBox < ActiveRecord::Base

  has_one :user

  set_primary_key "uniqueid" 

end
