# -*- encoding : utf-8 -*-
class FlatrateDestination < ActiveRecord::Base
  belongs_to :service
  belongs_to :destination
end

