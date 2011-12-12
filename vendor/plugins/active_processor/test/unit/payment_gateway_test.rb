require 'test/test_helper'
 
class PaymentGatewayTest < Test::Unit::TestCase

  context "Payment gateway" do
    setup do
      ActiveProcessor.configuration = mock
      ActiveProcessor.stubs(:log).returns(true)
      ActiveProcessor.configuration.stubs(:data).returns({ 
          'enabled' => {
            'gateways' => ['bogus'],
            'integrations' => ['bogus']
          },
          'gateways' => {
            'bogus' => {
              'config' => {
                'fields' => {
                  'login' => { 'position' => 3, 'for' => 'authentication', 'html_options' => { 'value' => 'login' } },
                  'password' => { 'position' => 4, 'for' => 'authentication', 'html_options' => { 'value' => 'password' } },
                  'min_amount' => { 'position' => 5, 'html_options' => { 'value' => 10 } },
                  'max_amount' => { 'position' => 6, 'html_options' => {'value' => 20 } },
                  'test' => { 'position' => 6, 'html_options' => { 'value' => 0 } }
                }
              },
              'form' => {
                'fields' => {
                  'login' => { 'position' => 3, 'as' => 'input_field', 'validates' => { 'with' => /\d+/ , 'message' => 'some_error' } },
                  'amount' => { 'position' => 3, 'as' => 'input_field' },
                  'currency' => { 'position' => 3, 'as' => 'input_field' },
                  'address[street]' => { 'position' => 99, 'as' => 'input_field', 'for' => 'authorization', 'html_options' => { 'value' => '1' } },
                  'address[number]' => { 'position' => 99, 'as' => 'input_field', 'for' => 'authorization', 'html_options' => { 'value' => '2' } },
                  'default_currency' => { 'position' => 4, 'as' => 'input_field' },
                  'password' => { 'position' => 4, 'as' => 'input_field' }
                }
              }
            }
          },
          'integrations' => {
            'bogus' => {
              'config' => {
                'fields' => {
                  'login' => { 'position' => 3 },
                  'password' => { 'position' => 4 },
                  'min_amount' => { 'position' => 5, 'html_options' => { 'value' => 1 } },
                  'max_amount' => { 'position' => 6, 'html_options' => {'value' => 3 } }
                }
              },
              'form' => {
                'fields' => {
                  'amount' => { 'position' => 3, 'as' => 'input_field' },
                  'currency' => { 'position' => 3, 'as' => 'input_field' },
                  'default_currency' => { 'position' => 4, 'as' => 'input_field' },
                }
              },
              'settings' => {
                'default_currency' => 'USD'
              }
            }
          }
        })
    end

    #should "allow to iterate through attributes using block" do
    #@engine = GatewayEngine.new(:first, {:engine => :integrations, :gateway => :bogus})
    #@engine.query.each_field_for(:config) { |field, options| options.merge!({ 'position' => 5 }) }
    #assert_equal @engine.query.fields, {"config"=>{"min_amount"=>{"position"=>5, "html_options"=>{"value"=>1}},"max_amount"=>{"position"=>5, "html_options"=>{"value"=>"0"}},"login"=>{"position"=>5},"password"=>{"position"=>5}},"form"=>{"amount"=>{"position"=>3, "as"=>"input_field"},"currency"=>{"position"=>3, "as"=>"input_field"},"default_currency"=>{"position"=>4, "as"=>"input_field"}}}
    #end

    should "display gateway's display name from active merchant (delegated method)" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_equal "Bogus", @engine.query.display_name
    end

    should "display integrations's display name" do
      @engine = GatewayEngine.new(:first, {:engine => :integrations, :gateway => :bogus})
      assert_equal "Bogus", @engine.query.display_name
    end

    should "display payment form" do
      @gateway = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus}).query
      ActiveProcessor.configuration.stubs(:translate_func).returns(lambda{|s| "translated"})
      assert_match /(.*)form(.*)/, @gateway.display_form
    end

    # TODO fix me, test assume's that credit card type select is present
    should "include custom defined fields in form" do
      @gateway = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus}).query
      ActiveProcessor.configuration.stubs(:translate_func).returns(lambda{|s| "translated"})
      assert_match /(.*)gateways_bogus_credit_card_type(.*)/, @gateway.display_form
    end

    should "display payment form when given a block" do
      @gateway = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus}).query
      assert_equal '/payment_gateways/gateways/bogus/pay', @gateway.display_form { |ge, h| ge.post_to("") }
    end

    should "return false if credit card is invalid" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      credit_card = mock()
      credit_card.expects(:valid?).returns(false)
      ActiveMerchant::Billing::CreditCard.expects(:new).returns(credit_card)

      assert_equal false, @engine.query.valid?({ "gateways" => { "bogus" => { "login" => "3", "amount" => 10 } } })
      assert_equal 1, @engine.query.errors.size
    end

    should "return false if invalid form value is specified is invalid" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      credit_card = mock()
      credit_card.expects(:valid?).returns(true)
      ActiveMerchant::Billing::CreditCard.expects(:new).returns(credit_card)

      assert_equal false, @engine.query.valid?({ "gateways" => { "bogus" => { "login" => "abc", "amount" => 10 } } })
      assert_equal 1, @engine.query.errors.size
    end

    should "return false if minimum amount is less than specified in form" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      credit_card = mock()
      credit_card.expects(:valid?).returns(true)
      ActiveMerchant::Billing::CreditCard.expects(:new).returns(credit_card)

      assert_equal false, @engine.query.valid?({ "gateways" => { "bogus" => { "login" => "1", "currency" => "EUR", "default_currency" => "USD", "amount" => 3 } } })
      assert_equal 1, @engine.query.errors.size
    end

    should "return false if maximum amount is less than specified in form" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      credit_card = mock()
      credit_card.expects(:valid?).returns(true)
      ActiveMerchant::Billing::CreditCard.expects(:new).returns(credit_card)

      assert_equal false, @engine.query.valid?({ "gateways" => { "bogus" => { "login" => "1", "currency" => "EUR", "default_currency" => "USD", "amount" => 100 } } })
      assert_equal 1, @engine.query.errors.size
    end

    should "return true if payment was successful" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      ActiveProcessor.configuration.stubs(:calculate_tax).returns(lambda {|a, b| 0.0 })
      gw = mock()
      gw.expects(:authorize).returns(OpenStruct.new(:success? => true))
      gw.expects(:capture).returns(true)
      ActiveMerchant::Billing::BogusGateway.expects(:new).returns(gw)

      assert_equal true, @engine.query.pay(1, "127.0.0.1", { "gateways" => { "bogus" => { "login" => "1", "currency" => "EUR", "default_currency" => "USD", "amount" => 3, "address" => { "street" => "street", "number" => "12345" }  } } })
    end

    should "return false in case of authorization failure" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      ActiveProcessor.configuration.stubs(:calculate_tax).returns(lambda {|a, b| 0.0 })
      gw = mock()
      gw.expects(:authorize).returns(OpenStruct.new(:success? => false))
      ActiveMerchant::Billing::BogusGateway.expects(:new).returns(gw)

      assert_equal false, @engine.query.pay(1, "127.0.0.1", { "gateways" => { "bogus" => { "login" => "1", "crrency" => "EUR", "default_currency" => "USD", "amount" => 3, "address" => { "street" => "street", "number" => "12345" } } } })
    end

    should "return false in case of payment failure" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      ActiveProcessor.configuration.stubs(:calculate_tax).returns(lambda {|a, b| 0.0 })
      @engine.query.instance_variable_set '@credit_card', OpenStruct.new(:number => 10)

      assert_equal false, @engine.query.pay(1, "127.0.0.1", { "gateways" => { "bogus" => { "login" => "1", "currency" => "EUR", "default_currency" => "USD", "amount" => 3, "address" => { "street" => "street", "number" => "12345" } } } })
    end

    should "allow to set hash variables" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      @engine.query.set(:form, {'address' => {'street' => 'val' } })

      assert_equal "val", @engine.query.get(:form, 'address[street]')
    end

    should "validate minimum amount of integration gateway" do
      @engine = GatewayEngine.new(:first, {:engine => :integrations, :gateway => :bogus})
      assert_equal false, @engine.query.valid?({'integrations' => { 'bogus' => { 'amount' => 0, 'currency' => "USD" } } })
      assert_equal 1, @engine.query.errors.size
    end

    should "validate maximum amount of integration gateway" do
      @engine = GatewayEngine.new(:first, {:engine => :integrations, :gateway => :bogus})
      assert_equal false, @engine.query.valid?({'integrations' => { 'bogus' => { 'amount' => 100, 'currency' => "USD" } } })
      assert_equal 1, @engine.query.errors.size
    end

    should "create calculate payment values on pay" do
      @engine = GatewayEngine.new(:first, {:engine => :integrations, :gateway => :bogus})
      ActiveProcessor.configuration.stubs(:calculate_tax).returns(lambda {|a, b| b*1.1 })
      @engine.query.pay(0, "127.0.0.1", {'integrations' => { 'bogus' => { 'amount' => 1, 'currency' => "USD" } } })
      assert_equal 1.1, @engine.query.payment.amount
      assert_equal 100, @engine.query.payment.money
      assert_equal 1.0, @engine.query.payment.orig_amount
      assert_equal 1.1, @engine.query.payment.orig_with_tax
      assert_equal 10, @engine.query.payment.tax
    end

    should "properly set urls" do
      @engine = GatewayEngine.new(:first, {:engine => :integrations, :gateway => :bogus})
      ActiveProcessor.configuration.stubs(:host).returns("http://localhost")
      assert_equal "/payment_gateways/integrations/bogus/notify", @engine.query.notify_url
      assert_equal "/payments/personal_payments", @engine.query.return_url
      assert_equal "/callc/main", @engine.query.cancel_return_url
    end

    context "named google checkout" do
      setup do
        ActiveProcessor.configuration = mock
        ActiveProcessor.configuration.stubs(:data).returns({ 
            'enabled' => {
              'google_checkout' => ['google_checkout'],
            },
            'google_checkout' => {
              'google_checkout' => {
                'settings' => {
                  'name' => 'Google Checkout',
                  'default_currency' => 'USD'
                },
                'config' => {
                  'fields' => {
                    'min_amount' => { 'position' => 1, 'html_options' => {'value' => '1' } },
                    'max_amount' => { 'position' => 6, 'html_options' => {'value' => '10' } },
                    'merchant_id' => { 'position' => 3, 'html_options' => { 'value' => 'id' }, 'for' => 'authentication' },
                    'merchant_key' => { 'position' => 4, 'html_options' => { 'value' => 'key' }, 'for' => 'authentication' },
                    'use_sandbox' => { 'position' => 5, 'html_options' => { 'value' => true }, 'for' => 'authentication' },
                  }
                },
                'form' => {
                  'fields' => {
                    'amount' => { 'position' => 3, 'as' => 'input_field' },
                    'currency' => { 'position' => 3, 'as' => 'input_field' },
                  }
                }
              }
            }
          })
      end
      should "successfully initialize with valid values" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        @engine.query.init
        assert_instance_of Google4R::Checkout::Frontend, @engine.query.instance
      end

      should "return gateway name" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        assert_equal "Google Checkout", @engine.query.display_name
      end

      should "return notification handler after initialization" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        assert_instance_of Google4R::Checkout::NotificationHandler, @engine.query.notification_handler
      end

      should "return true if validations is successfull" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        assert_equal true, @engine.query.valid?({'google_checkout' => { 'google_checkout' => { 'amount' => '1', 'currency' => 'USD' } } })
      end

      should "return false if validations is unsuccessfull" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        assert_equal false, @engine.query.valid?({'google_checkout' => { 'google_checkout' => { 'amount' => '0', 'currency' => 'USD' } } })
      end

      should "return false if maximum amount validation is unsuccessfull" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        assert_equal false, @engine.query.valid?({'google_checkout' => { 'google_checkout' => { 'amount' => '100', 'currency' => 'USD' } } })
      end

      should "return an url from google" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        response = mock()
        response.stubs(:redirect_url).returns('http://someurl')
        @engine.query.instance_variable_set(:@response, response)
        assert_match /http/, @engine.query.redirect_url
      end

      should "build payment on pay" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        ActiveProcessor.configuration.expects(:calculate_tax).once.returns(lambda{|a,b| 110.0})
        ActiveProcessor.configuration.expects(:calculate_tax).once.returns(lambda{|a,b| 1.1})

        @engine.query.pay(0, "127.0.0.1", {'google_checkout' => { 'google_checkout' => { 'amount' => '1', 'currency' => 'USD' } } })
        assert_equal 100.0, @engine.query.payment.money
        assert_equal 10.0, @engine.query.payment.tax
        assert_equal 1.0, @engine.query.payment.orig_amount
        assert_equal 1.1, @engine.query.payment.orig_with_tax
        assert_equal 110.0, @engine.query.payment.amount
      end

      should "build payment on pay convert into float" do
        @engine = GatewayEngine.new(:first, {:engine => :google_checkout, :gateway => :google_checkout})
        ActiveProcessor.configuration.expects(:calculate_tax).once.returns(lambda{|a,b| 110.0})
        ActiveProcessor.configuration.expects(:calculate_tax).once.returns(lambda{|a,b| 1.1})

        @engine.query.pay(0, "127.0.0.1", {'google_checkout' => { 'google_checkout' => { 'amount' => '1', 'currency' => 'USD' } } })
        assert_equal 100.0, @engine.query.payment.money
        assert_equal nil, @engine.query.payment.tax
        assert_equal 1.0, @engine.query.payment.orig_amount
        assert_equal nil, @engine.query.payment.orig_with_tax
        assert_equal 110.0, @engine.query.payment.amount
      end


    end

  end
end
