# -*- encoding : utf-8 -*-
class Hangupcausecode < ActiveRecord::Base

  def clean_description
    description.to_s.gsub("<b>", "").gsub("</b>", "").gsub("<br>", ". ")
  end

  def Hangupcausecode.find_all_for_select
    find(:all, :select => "id, description")
  end

  def Hangupcausecode.end_array(value = -1)
    arr = []
    arr[0] = _('Leave_as_it_is')
    arr[1] = _('1_unallocated_number_/_404_Not_Found')
    arr[2] = _('2_no_route_to_network_/_404_Not_Found')
    arr[3] = _('3_no_route_to_destination_/_404_Not_Found')
    arr[17] = _('17_user_busy_/_486_Busy_here')
    arr[18] = _('18_no_user_responding_/_408_Request_Timeout')
    arr[19] = _('19_no_answer_from_the_user_/_480_Temporarily_unavailable')
    arr[20] = _('20_subscriber_absent_/_480_Temporarily_unavailable')
    arr[21] = _('21_call_rejected_/_403_Forbidden')
    arr[22] = _('22_number_changed_(w/_diagnostic)_/_301_Moved_Permanently')
    arr[23] = _('23_redirection_to_new_destination_/_410_Gone')
    arr[26] = _('26_non-selected_user_clearing_/_404_Not_Found')
    arr[27] = _('27_destination_out_of_order_/_502_Bad_Gateway')
    arr[28] = _('28_address_incomplete_/_484_Address_incomplete')
    arr[29] = _('29_facility_rejected_/_501_Not_implemented')
    arr[31] = _('31_normal_unspecified_/_480_Temporarily_unavailable')
    if value.to_i > -1
      arr[value.to_i]
    else
      arr
    end
  end
end
