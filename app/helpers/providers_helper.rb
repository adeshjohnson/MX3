# -*- encoding : utf-8 -*-
module ProvidersHelper

  def check_alive(prov = nil)
    if prov and ['ip','hostname'].member? prov.type and prov.tech == 'SIP'
      case prov.alive
        when 1; b_check
        when 0; b_cross
      end
    end
  end
end
