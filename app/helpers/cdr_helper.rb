# -*- encoding : utf-8 -*-
module CdrHelper


  def clean_value(value)
    cv = value.to_s.gsub("\"", "")
    cv
  end


  def nice_cdr_import_error(er)
    error = ""
    case er.to_i
      when 1
        error = _('CLI_is_not_number')
      when 2
        error = _('CDR_exist_in_db_match_caldate_dst_src')
      when 3
        error = _('Destination_is_not_numerical_value')
      when 4
        error = _('Invalid_calldate')
      when 5
        error = _('Billsec_is_not_numerical_value')
    end
    error
  end
end
