# -*- encoding : utf-8 -*-
module PaymentsHelper
  include Paypal::Helpers
  include WebMoney::Helpers
  include Linkpoint::Helpers
  include Cyberplat::Helpers
  include Ouroboros::Helpers

  def currency_exchange_rate(payment)
    Currency.where(name: payment.currency).try(:first).exchange_rate
  end
end
