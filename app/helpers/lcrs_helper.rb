# -*- encoding : utf-8 -*-
module LcrsHelper
  
  def lcrpartial_destinations_providers(lcr_id)
    lcr = current_user.load_lcrs(:first, :conditions=>"id=#{lcr_id}")
    code = []
    if lcr
      lcr.providers("asc").each{|p| code << p.name.to_s + " (" + p.tech + ")"}
    end
    code.join('<br />')
  end  
end
