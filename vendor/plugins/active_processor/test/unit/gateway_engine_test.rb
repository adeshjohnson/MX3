# -*- encoding : utf-8 -*-
require 'test/test_helper'

class GatewayEngineTest < Test::Unit::TestCase

  context "Gateway engine" do
    setup do
      # Let's decouple from real configuration
      ActiveProcessor.configuration = mock
      ActiveProcessor.stubs(:log).returns(true)
      ActiveProcessor.configuration.stubs(:data).returns(
          {
              'enabled' => {
                  'gateways' => ['bogus'],
                  'integrations' => ['bogus', 'two_checkout']
              },
              'gateways' => {
                  'bogus' => {
                      'config' => {
                          'fields' => {
                              'login' => {'as' => "input_field", 'position' => 3, 'for' => 'authentication', 'value' => 'afaf', 'validates' => {'with' => /\w+/, 'message' => 'some_error'}},
                              'password' => {'as' => "af", 'position' => 4}
                          }
                      },
                      'form' => {
                          'fields' => {
                              'login' => {'as' => "input_field", 'position' => 3, 'value' => 'afaf', 'validates' => {'with' => /\w+/, 'message' => 'some_error'}},
                          }
                      }
                  }
              },
              'integrations' => {
                  'bogus' => {
                      'config' => {
                          'fields' => {
                              'login' => {'as' => "input_field", 'position' => 3, 'for' => "authentication", 'value' => 'ofof'}
                          }
                      }
                  },
                  'two_checkout' => {
                      'config' => {
                          'fields' => {
                              'login' => {'as' => "input_field", 'position' => 3, 'for' => "authentication"}
                          }
                      }
                  }
              }
          }
      )
    end

    should "find multiple gateways" do
      GatewayEngine.expects(:find).with(:all).returns([stub, stub])
      @gateways = GatewayEngine.find(:all)
      assert_instance_of Array, @gateways
      assert_equal 2, @gateways.size
    end

    should "return corrent gateway size" do
      @engine = GatewayEngine.find(:enabled)
      assert_equal 3, @engine.size
    end

    should "allow to set user by method call" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      @engine.for_user(1)
      assert_equal @engine.user, 1
    end

    should "allow to set params using finder" do
      @engine = GatewayEngine.find(:first, {:engine => :gateways, :gateway => :bogus, :post_to => '/abc', :for_user => 1, :template => "/somewhere"})
      assert_equal @engine.engine, :gateways
      assert_equal @engine.gateway, :bogus
      assert_equal @engine.template, "/somewhere"
      assert_equal @engine.post_to, '/abc'
      assert_equal @engine.user, 1
    end

    should "allow to set params using block" do
      @engine = GatewayEngine.new do |e|
        e.engine = :gateways
        e.gateway = :bogus
        e.user = 1
      end
      assert_equal @engine.engine, :gateways
      assert_equal @engine.gateway, :bogus
      assert_equal @engine.user, 1
    end

    should "invoke callback when user is being set" do
      GatewayEngine.class_eval do
        def on_gateways_user_set
          @user = 8
        end
      end
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus}).for_user(88)
      assert_equal 8, @engine.user
    end

    should "invoke general (engine indepedant) callback when user is being set" do
      GatewayEngine.class_eval do
        def on_user_set
          @user = 9
        end
      end
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus}).for_user(77)
      assert_equal 9, @engine.user
    end

    should "invoke callback which is passed by string" do
      GatewayEngine.class_eval do
        def on_string_callback
          @user = 10
        end

        # define method to call private one :) ugly?
        def callback_method
          run("on", "string", "callback")
        end
      end
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus}).for_user(88)
      assert_equal 10, @engine.callback_method
    end

    should "return know when the user is set" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_equal false, @engine.user_is_set?
      @engine.for_user(1)
      assert_equal true, @engine.user_is_set?
    end

    #should "return all enabled gateways" do
    #assert_equal GatewayEngine.find(:enabled).to_hash, {"integrations"=>{"test_integration"=>[["login",{"position"=>3, "as"=>"input_field", "for"=>"authentication"}]]},"gateways"=>{"test_gateway"=>[["login", {"position"=>3, "as"=>"input_field", "for"=>"authentication"}],["password", {"position"=>4, "as"=>"af"}]]}}
    #end

    should "invoke enabled find callback" do
      GatewayEngine.class_eval do
        def on_enabled_find
          @user = 13
        end
      end
      @engine = GatewayEngine.find(:enabled)
      @engine.to_hash
      assert_equal 13, @engine.user
    end

    should "successfully query gateway field" do
      @engine = GatewayEngine.find(:enabled)
      assert_equal "afaf", @engine.query(:engine => :gateways, :gateway => :bogus, :field => :login, :scope => :config)
    end

    should "successfully query gateway" do
      @engine = GatewayEngine.find(:enabled)
      assert_instance_of ActiveProcessor::PaymentEngines::Gateway, @engine.query(:engine => :gateways, :gateway => :bogus)
    end

    should "successfully query whole engine" do
      @engine = GatewayEngine.find(:enabled)
      assert_equal 1, @engine.query(:engine => :gateways).keys.size
      assert_equal 2, @engine.query(:engine => :integrations).keys.size
    end

    should "allow filter usage" do
      @engine = GatewayEngine.find(:enabled)
      assert_equal 1, @engine.some_filter("bogus").size
      assert_equal 0, @engine.some_other_filter("integrations").size
    end

    should "successfully return first gateway if no query parameters set" do
      @engine = GatewayEngine.find(:enabled)
      assert_instance_of ActiveProcessor::PaymentEngines::Integration, @engine.query
    end

    should "validate update values" do
      GatewayEngine.class_eval do
        def on_before_update;
        end

        def on_after_update;
        end
      end

      @engine = GatewayEngine.find(:enabled)
      @engine.update_with(:config, {
          'gateways' => {'bogus' => {'login' => "!!!"}}
      })

      assert_equal 1, @engine.query(:engine => :gateways, :gateway => :bogus).errors.size
      assert_equal true, @engine.query(:engine => :gateways, :gateway => :bogus).errors.values.include?("some_error")
    end

    should "update values" do
      GatewayEngine.class_eval do
        def on_before_config_update;
        end

        def on_after_config_update;
        end
      end

      @engine = GatewayEngine.find(:enabled)
      @engine.update_with(:config, {
          'gateways' => {'bogus' => {'login' => "123"}},
          'integrations' => {'bogus' => {'login' => "456"}},
      })
      assert_equal "123", @engine.query(:engine => :gateways, :gateway => :bogus).get(:config, 'login')
      assert_equal "456", @engine.query(:engine => :integrations, :gateway => :bogus).get(:config, 'login')
    end

    should "invoke callback before update" do
      # we'll modify the value that was passed
      GatewayEngine.class_eval do
        def on_before_config_update
          @params['gateways']['bogus']['login'] = '789'
        end

        def on_after_config_update;
        end
      end
      @engine = GatewayEngine.find(:enabled)
      @engine.update_with(:config, {
          'gateways' => {'bogus' => {'login' => "123"}},
          'integrations' => {'bogus' => {'login' => "456"}},
      })
      assert_equal "789", @engine.query(:engine => :gateways, :gateway => :bogus).get(:config, 'login')
    end

    should "invoke callback after update" do
      # we'll modify the value that was passed
      GatewayEngine.class_eval do
        def on_after_config_update
          @gateways['gateways']['bogus'].set(:config, {'login' => '10'})
        end
      end

      @engine = GatewayEngine.find(:enabled)
      @engine.update_with(:config, {
          'gateways' => {'bogus' => {'login' => "123"}},
          'integrations' => {'bogus' => {'login' => "456"}},
      })

      assert_equal "10", @engine.query(:engine => :gateways, :gateway => :bogus).get(:config, 'login')
    end

    should "allow to pay using a gateway" do
      @engine = GatewayEngine.find(:enabled)

      ActiveProcessor::PaymentEngines::Gateway.any_instance.expects(:valid?).returns(true)
      ActiveProcessor::PaymentEngines::Gateway.any_instance.expects(:pay).returns(true)

      assert_equal true, @engine.pay_with(@engine.query({:engine => :gateways, :gateway => :bogus}), "127.0.0.1", {'gateways' => {'bogus' => {'login' => '1'}}})
    end

    should "not allow to pay if payment validation fails" do
      @engine = GatewayEngine.find(:enabled)

      ActiveProcessor::PaymentEngines::Gateway.any_instance.expects(:valid?).returns(false)

      assert_equal false, @engine.pay_with(@engine.query({:engine => :gateways, :gateway => :bogus}), "127.0.0.1", {'gateways' => {'bogus' => {'login' => '1'}}})
    end

    should "not pay if payment action fails" do
      @engine = GatewayEngine.find(:enabled)

      ActiveProcessor::PaymentEngines::Gateway.any_instance.expects(:valid?).returns(true)
      ActiveProcessor::PaymentEngines::Gateway.any_instance.expects(:pay).returns(false)

      assert_equal false, @engine.pay_with(@engine.query({:engine => :gateways, :gateway => :bogus}), "127.0.0.1", {'gateways' => {'bogus' => {'login' => '1'}}})
    end

    context "with set engine" do
      setup do
        ActiveProcessor.configuration = mock
        ActiveProcessor.configuration.stubs(:data).returns(
            {
                'enabled' => {
                    'gateways' => ['bogus', 'authorize_net']
                },
                'gateways' => {
                    'bogus' => {'config' => {'fields' => {'login' => {'some' => 4, 'position' => 3}}}},
                    'authorize_net' => {'config' => {'fields' => {'password' => {'other' => 5, 'position' => 4}}}}
                }
            }
        )
      end

      should "return all gateways" do
        @engine = GatewayEngine.new(:all, {:engine => :gateways})
        assert_equal 2, @engine.to_hash.values.inject(0) { |s, gws| s += gws.size }
      end

      should "raise error if that engine is not present" do
        assert_raise (ActiveProcessor::GatewayEngineError) {GatewayEngine.new(:first, {:engine => :non_existent, :gateway => :bogus}).to_hash}
      end

      should "invoke all find callback" do
        GatewayEngine.class_eval do
          def on_all_find
            @user = 11
          end
        end
        @engine = GatewayEngine.find(:all, {:engine => :gateways})
        @engine.to_hash
        assert_equal 11, @engine.user
      end
    end

    context "with correctly set engine, gateway" do
      setup do
        ActiveProcessor.configuration = mock
        ActiveProcessor.configuration.stubs(:data).returns(
            {
                'enabled' => {
                    'gateways' => ['bogus']
                },
                'gateways' => {
                    'bogus' => {
                        'config' => {
                            "fields" => {
                                'login' => {'as' => "input_field", 'position' => 3, 'for' => "authentication", 'value' => 'test'}
                            }
                        },
                    },
                }
            }
        )
      end

      should "return concrete gateway" do
        @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
        assert_instance_of ActiveProcessor::PaymentEngines::Gateway, @engine.to_hash['gateways']['bogus']
      end

      should "invoke first find callback" do
        GatewayEngine.class_eval do
          def on_first_find
            @user = 12
          end
        end
        @engine = GatewayEngine.find(:first, {:engine => :gateways, :gateway => :bogus})
        @engine.to_hash
        assert_equal 12, @engine.user
      end

      should "return corrent gateway size" do
        @engine = GatewayEngine.find(:first, {:engine => :gateways, :gateway => :bogus})
        assert_equal 1, @engine.size
      end

      context "and fields set for exclusion and inclusion" do
        setup do
          ActiveProcessor.configuration = mock
          ActiveProcessor.configuration.stubs(:data).returns(
              {
                  'enabled' => {
                      'gateways' => ['bogus']
                  },
                  'gateways' => {
                      'bogus' => {
                          'config' => {
                              "fields" => {
                                  'login' => {'as' => "input_field", 'position' => 3, 'for' => "authentication"}
                              },
                              "excludes" => ['login'],
                              "includes" => {
                                  'field' => {'as' => "input_field", 'value' => "opa", 'position' => 2}
                              },
                          }
                      },
                  }
              }
          )
        end

        should "exclude the field" do
          @engine = GatewayEngine.find(:enabled)
          assert_equal "opa", @engine.query(:engine => :gateways, :gateway => :bogus, :field => :field, :scope => :config)
        end

        should "raise an error if specified field is missing" do
          @engine = GatewayEngine.find(:enabled)
          assert_raises(ActiveProcessor::GatewayEngineError) { @engine.query(:engine => :gateways, :gateway => :bogus, :field => :non_existent, :scope => :config) }
        end

      end

      should "display configuration form" do
        @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
        ActiveProcessor.configuration.stubs(:translate_func).returns(lambda { |s| "translated" })
        assert_match /(.*)form(.*)/, @engine.display_form
      end

      should "display configuration form when given a block" do
        @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
        assert_equal 'update', @engine.display_form { |ge, h| ge.post_to }
      end
    end

    context "with incorrectly set engine, gateway" do
      setup do
        ActiveProcessor.configuration = mock
        ActiveProcessor.configuration.stubs(:data).returns(
            {
                'enabled' => {
                    'gateways' => ['bogus']
                },
                'gateways' => {
                    'bogus' => {:some => :setting},
                }
            }
        )
      end

      should "raise error rwhen they're not set at all" do
        assert_raise (ActiveProcessor::GatewayEngineError) {GatewayEngine.new.to_hash}
      end

      should "raise error when engine is non-present" do
        assert_raise (ActiveProcessor::GatewayEngineError) {GatewayEngine.new(:first, {:engine => :non_existent, :gateway => :bogus}).to_hash}
      end

      should "raise error when gateway is not enabled" do
        assert_raise (ActiveProcessor::GatewayEngineError) {GatewayEngine.new(:first, {:engine => :gateways, :gateway => :non_existent}).to_hash}
      end
    end

  end

end
