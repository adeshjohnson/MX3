# -*- encoding : utf-8 -*-
module Ouroboros
  module OuroborosPayment
    
=begin rdoc

=end
    
    def OuroborosPayment::format_policy(ob_max_amount = nil, retry_count = nil,completion = nil, completion_over = nil)
      policy = []
      policy << "amount_limit-#{sprintf("%0.0f", ob_max_amount.to_f*100)}" if ob_max_amount and ob_max_amount > 0
      policy << "retry_count-#{retry_count}" if retry_count and retry_count.to_s.length > 0
      policy << "completion-#{completion}" if completion and completion.to_s.length > 0
      policy << "completion_over-#{sprintf("%0.0f",completion_over.to_f*100)}" if completion_over and completion_over.to_s.length > 0 and completion_over.to_i > 0
      policy
    end
    
    
=begin rdoc

=end
    
    def OuroborosPayment::format_amount(param_amount, min_amount, max_amount)
      if param_amount and param_amount.to_f > min_amount.to_f
        amount = param_amount.to_f
      else
        amount = min_amount.to_f
      end
      
      if max_amount and max_amount.to_f > 0.0 and max_amount.to_f > min_amount.to_f and amount.to_f > max_amount.to_f
        amount = max_amount.to_f
      end 
      amount
    end
  end
end
