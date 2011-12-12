require 'test/test_helper'
 
class GatewayEngineTest < Test::Unit::TestCase

  context "Form helper engine" do
    setup do
      ActiveProcessor.configuration = mock
      ActiveProcessor.configuration.stubs(:data).returns({ 
        'enabled' => {
          'gateways' => ['bogus'],
        },
        'gateways' => {
          'bogus' => {
              'config' => {
                'fields' => {
                  'login' => { 'as' => "input_field", 'position' => 3, 'for' => 'authentication', 'value' => 'afaf', 'html_options' => { 'size' => 30 } },
                  'password' => { 'as' => "password_field", 'position' => 4 },
                  'check_box' => { 'as' => "check_box", 'position' => 4 },
                  'select' => { 'as' => 'select', 'position' => 4, 'value' => ['a','b'] },
                  'text' => { 'as' => 'text', 'position' => 4, 'value' => 'abc' },
                  'hidden' => { 'as' => 'hidden_field', 'position' => 4, 'value' => 'abc' },
                  'separator' => { 'as' => 'separator', 'position' => 4, 'value' => 'abc' },
                  'card_select' => { 'as' => 'card_select', 'position' => 4, 'value' => 'abc' },
                  'before_str' => { 'as' => 'input_field', 'position' => 4, 'value' => 'abc', 'before' => "def" },
                  'before_proc' => { 'as' => 'input_field', 'position' => 4, 'value' => 'abc', 'before' => lambda { "def" } },
                  'after_str' => { 'as' => 'input_field', 'position' => 4, 'value' => 'abc', 'after' => "def" },
                  'after_proc' => { 'as' => 'input_field', 'position' => 4, 'value' => 'abc', 'after' => lambda { "def" } },
                  'plain_text' => { 'as' => 'plain_text', 'position' => 4, 'value' => 'some plain text' },
                  'payment_confirmation' => { 'as' => 'payment_confirmation', 'position' => 4 },
                  'payment_confirmation_lite' => { 'as' => 'payment_confirmation_lite', 'position' => 4 },
                  'year_select' => { 'as' => 'year_select', 'position' => 4 },
                  'month_select' => { 'as' => 'month_select', 'position' => 4 }
                }
              }
          }
        }
      })
      ActiveProcessor.configuration.stubs(:translate_func).returns( proc{ |a| a } )
    end

    should "render an input field" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<input(.*)name=\"gateways\[gateways\]\[bogus\]\[login\]\"(.*)type=\"text\"(.*)value=\"afaf\"(.*)\/>/, ActiveProcessor::FormHelper.input(@engine.query, 'login', @engine.query.fields['config']['login'])
    end

    should "render a password field" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<input(.*)name=\"gateways\[gateways\]\[bogus\]\[password\]\"(.*)type=\"password\"(.*)\/>/, ActiveProcessor::FormHelper.input(@engine.query, 'password', @engine.query.fields['config']['password'])
    end

    should "render a label" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      ActiveProcessor.configuration.stubs(:translate_func).returns(lambda{|s| "translated"})
      assert_match /<label(.*)for=\"gateways_bogus_login\"(.*)>/, ActiveProcessor::FormHelper.label(@engine.query.engine, @engine.query.name, 'login', @engine.query.fields['config']['login'])
    end

    should "render a check_box" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<input(.*)name=\"gateways\[gateways\]\[bogus\]\[password\]\"(.*)type=\"checkbox\"(.*)\/>/, ActiveProcessor::FormHelper.input(@engine.query, 'password', @engine.query.fields['config']['check_box'])
    end

    should "render a select list" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<select(.*)name=\"gateways\[gateways\]\[bogus\]\[select\]\"><option value=\"a\">a<\/option>(.*)/, ActiveProcessor::FormHelper.input(@engine.query, 'select', @engine.query.fields['config']['select'])
    end

    should "render a card select" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<select(.*)name=\"gateways\[gateways\]\[bogus\]\[card_select\]\"><option value=\"Bogus\">Bogus<\/option>(.*)/, ActiveProcessor::FormHelper.input(@engine.query, 'card_select', @engine.query.fields['config']['card_select'])
    end

    should "render a text field" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<textarea(.*)name=\"gateways\[gateways\]\[bogus\]\[text\]\"(.*)>abc<\/textarea>/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['text'])
    end

    should "render a hidden field" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<input(.*)type=\"hidden\"(.*)>/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['hidden'])
    end

    should "render a separator" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /br/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['separator'])
    end

    should "render plain text" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /some plain text/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['plain_text'])
    end

    should "render payment confirmation select " do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<select(.*)name=\"gateways\[gateways\]\[bogus\]\[payment_confirmation\]\">(.*)/, ActiveProcessor::FormHelper.input(@engine.query, 'payment_confirmation', @engine.query.fields['config']['payment_confirmation'])
    end

    should "render payment confirmation lite select " do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<select(.*)name=\"gateways\[gateways\]\[bogus\]\[payment_confirmation_lite\]\">(.*)/, ActiveProcessor::FormHelper.input(@engine.query, 'payment_confirmation_lite', @engine.query.fields['config']['payment_confirmation_lite'])
    end

    should "render year select " do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<select(.*)name=\"gateways\[gateways\]\[bogus\]\[year_select\]\">(.*)/, ActiveProcessor::FormHelper.input(@engine.query, 'year_select', @engine.query.fields['config']['year_select'])
    end

    should "render month select " do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /<select(.*)name=\"gateways\[gateways\]\[bogus\]\[month_select\]\">(.*)/, ActiveProcessor::FormHelper.input(@engine.query, 'month_select', @engine.query.fields['config']['month_select'])
    end

    should "accept after argument as proc" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /value=\"abc\"/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['after_proc'])
      assert_match /def/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['after_proc'])
    end

    should "accept after argument as string" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /value=\"abc\"/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['after_str'])
      assert_match /def/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['after_str'])
    end

    should "accept before argument as proc" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /value=\"abc\"/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['before_proc'])
      assert_match /def/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['before_proc'])
    end

    should "accept before argument as string" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /value=\"abc\"/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['before_str'])
      assert_match /def/, ActiveProcessor::FormHelper.input(@engine.query, 'text', @engine.query.fields['config']['before_str'])
    end

    should "warn if field was not recognized" do
      @engine = GatewayEngine.new(:first, {:engine => :gateways, :gateway => :bogus})
      assert_match /unrecognized/, ActiveProcessor::FormHelper.input(@engine.query, 'abc', @engine.query.fields['abc'])
    end

  end

end
