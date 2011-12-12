module PaymentsHelper
    include Paypal::Helpers
    include WebMoney::Helpers
    include Linkpoint::Helpers
    include Cyberplat::Helpers
    include Ouroboros::Helpers
end
