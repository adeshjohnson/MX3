class Role < ActiveRecord::Base
  has_many :role_rights, :dependent => :delete_all;
end
