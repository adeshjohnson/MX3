# -*- encoding : utf-8 -*-
class AccGroupRight < ActiveRecord::Base
#  set_table_name "acc_group_rights"

  belongs_to :acc_group
  belongs_to :acc_right
end
