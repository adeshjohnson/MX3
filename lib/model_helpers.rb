# -*- encoding : utf-8 -*-
module UniversalHelpers
  def sanitize_attributes
    attributes.each{ |key, value|
      if value.class == String
        @attributes[key] = CGI.escape(value)
      end
    }
  end
end
