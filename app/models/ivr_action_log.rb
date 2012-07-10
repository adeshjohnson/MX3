class IvrActionLog < ActiveRecord::Base
  belongs_to :adnumber

  def  IvrActionLog.link_logs_with_numbers
    ActiveRecord::Base.connection.execute('UPDATE ivr_action_logs, adnumbers SET adnumber_id = adnumbers.id WHERE adnumber_id IS NULL AND ivr_action_logs.uniqueid = adnumbers.uniqueid;')
  end

end