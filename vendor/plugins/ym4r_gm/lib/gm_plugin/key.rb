module Ym4r
  module GmPlugin
    class ApiKey  
      def self.get(options = {})
        Confline.my_debug("Key request")
        key = Confline.get_value("Google_Key")
        return key
      end
    end
  end
end
