# -*- encoding : utf-8 -*-
#--
# Project:   google_checkout4r 
# File:      test/unit/reset_items_shipping_information_command_test.rb
# Author:    Tony Chan <api.htchan at gmail dot com>
# Copyright: (c) 2007 by Dan Dukeson
# License:   MIT License as follows:
#
# Permission is hereby granted, free of charge, to any person obtaining 
# a copy of this software and associated documentation files (the 
# "Software"), to deal in the Software without restriction, including 
# without limitation the rights to use, copy, modify, merge, publish, 
# distribute, sublicense, and/or sell copies of the Software, and to permit
# persons to whom the Software is furnished to do so, subject to the 
# following conditions:
#
# The above copyright notice and this permission notice shall be included 
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
#++

require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

require 'google4r/checkout'

require 'test/frontend_configuration'

# Tests for the ResetItemsShippingInformationCommand class.
class Google4R::Checkout::ResetItemsShippingInformationCommandTest < Test::Unit::TestCase
  include Google4R::Checkout

  def setup
    @frontend = Frontend.new(FRONTEND_CONFIGURATION)
    @command = @frontend.create_reset_items_shipping_information_command

    @command.google_order_number = '841171949013218'
    @command.send_email = true
    @item_info1 = ItemInfo.new('A1')
    @item_info2 = ItemInfo.new('B2')
    @command.item_info_arr = [@item_info1, @item_info2]
    

    @sample_xml=%Q{<?xml version='1.0' encoding='UTF-8'?>
<reset-items-shipping-information xmlns='http://checkout.google.com/schema/2' google-order-number='841171949013218'>
  <item-ids>
    <item-id>
      <merchant-item-id>A1</merchant-item-id>
    </item-id>
    <item-id>
      <merchant-item-id>B2</merchant-item-id>
    </item-id>
  </item-ids>
  <send-email>true</send-email>
</reset-items-shipping-information>}
  end

  def test_behaves_correctly
    [ :google_order_number, :item_info_arr, :send_email,
      :google_order_number=, :item_info_arr=, :send_email= ].each do |symbol|
      assert_respond_to @command, symbol
    end
  end

  def test_xml_send_email
    assert_strings_equal(@sample_xml, @command.to_xml)
  end

  def test_accessors
    assert_equal('841171949013218', @command.google_order_number)
    assert @command.send_email
  end

  def test_to_xml_does_not_raise_exception
    assert_nothing_raised { @command.to_xml }
  end

end
