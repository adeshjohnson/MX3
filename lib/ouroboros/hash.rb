# -*- encoding : utf-8 -*-
module Ouroboros
  module Hash
    
=begin rdoc
Generates hash using params from Ouroboros shop.
*Params*:
* params - params hash.
* secret_key - Ouroboros secret key.
*Returns*:
* hash - MD5 hash that can be compared with has from Oronboros response.
=end
    
    def Hash::reply_hash(params, secret_key) 
      hash_string = ""
      hash_string << params[:tid].to_s
      hash_string << params[:order_id].to_s
      hash_string << params[:card].to_s
      hash_string << params[:amount].to_s
      hash_string << secret_key.to_s
      #MorLog.my_debug(hash_string)
      Digest::MD5.hexdigest(hash_string)
    end
    
=begin rdoc
Generates signature that can be sent to Ouroboros gateway.
*Params*: 
* opt - hash containing params for Ouroboros request.
*Returns*:
* signature - MD5 hash that can be used to sign request.
=end
    
    def Hash::format_signature(opt)
      hash_string = ""
      hash_string << opt[:mch_code]
      hash_string << opt[:order_id]       if opt[:order_id]
      hash_string << opt[:amount] 
      hash_string << opt[:currency]       if opt[:currency]
      hash_string << opt[:dept_code]      if opt[:dept_code]
      hash_string << opt[:payment_policy] if opt[:payment_policy]
      hash_string << opt[:secret_key]
      #MorLog.my_debug(hash_string)
      Digest::MD5.hexdigest(hash_string)
    end
  end
end
