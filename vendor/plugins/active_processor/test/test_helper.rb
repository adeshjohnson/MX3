#!/usr/bin/env ruby
$:.unshift File.expand_path('../../lib', __FILE__)

require 'test/unit'
require 'rubygems'
require 'pp'
require 'shoulda'
require 'mocha'
require 'active_processor'

begin require 'leftright'; rescue LoadError; end

# Class definitions for testing

class GatewayEngine
  include ActiveProcessor::GatewayEngine

  filter :some_filter, lambda { |rec, u| rec.gateway == u }
  filter :some_other_filter, lambda { |rec, u| rec.engine == u }

  field :gateways, :form, :credit_card_type, { :as => 'select', :position => 50, :html_options => { :value => "abc" } }
  field :gateways, :form, :test, { :as => 'input_field', :position => 50, :html_options => { :value => "abc" } }

  field :gateways, :form, :afaf, lambda { { :as => 'input_field', :position => 50, :html_options => { :value => ["a","b","c"].join } } }
end

class TaxTableFactory
  def effective_tax_tables_at(time)
    table = Google4R::Checkout::TaxTable.new(false)
    [ table ]
  end
end

Rails = OpenStruct.new(:env => "test") # can we fix this by requiring normal rails? :|
