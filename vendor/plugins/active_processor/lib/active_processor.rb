# -*- encoding : utf-8 -*-
# ActiveProcessor

require 'forwardable'
require 'ostruct'
require 'yaml'

require 'pp'

require 'rubygems'
gem 'actionpack' #, "<= 1.13.6"
gem 'activesupport' #, '<= 1.4.4'

#require 'action_controller'
#require 'action_view'
#require 'active_support'
#require 'action_pack'

begin
  require 'active_merchant'
rescue LoadError
  # in case we fail to load active_merchant as gem, load it as plugin
  # assuming that is is in vendor/plugins directory
  $:.unshift File.expand_path('../../../active_merchant/lib/', __FILE__)
  require 'active_merchant'
end

# custom libs
$:.unshift File.expand_path('../../vendor/google4r-checkout/lib', __FILE__)
$:.unshift File.expand_path('../../vendor/ideal/lib', __FILE__)

require 'google4r'
require 'active_merchant_ideal'

require 'active_processor/configuration'
require 'active_processor/core_ext'
require 'active_processor/routes'

require 'active_processor/form_helper'

require 'active_processor/gateway_engine'
require 'active_processor/payment_engine'

require 'active_processor/payment_engines/gateway'
require 'active_processor/payment_engines/integration'
require 'active_processor/payment_engines/google_checkout'
