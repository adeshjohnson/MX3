# -*- encoding : utf-8 -*-
module CardsHelper

  def nice_card_import_error(er)
    error = ""
    case er.to_i
      when 1
        error = _('Number_is_duplicate')
      when 2
        error = _('Pin_is_duplicate')
      when 3
        error = _('Number_is_not_numerical_value')
      when 4
        error = _('Pin_is_not_numerical_value')
      when 5
        error = _('No_balance')
      when 6
        error = _('Number_length_not_match_Calling_Cards_Group_number_length')
      when 7
        error = _('Pin_length_not_match_Calling_Cards_Group_number_length')
    end
    error
  end
end
