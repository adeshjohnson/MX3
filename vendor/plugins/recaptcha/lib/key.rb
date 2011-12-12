module Ambethia
  module ReCaptcha
    class ReKey
      def self.get_private(options = {})
        Confline.my_debug("reCAPTCHA_private request")
        key = Confline.get_value("reCAPTCHA_private_key")
        return key
      end
      def self.get_public(options = {})
        Confline.my_debug("reCAPTCHA_public request")
        key = Confline.get_value("reCAPTCHA_public_key")
        return key
      end
    end
  end
end
