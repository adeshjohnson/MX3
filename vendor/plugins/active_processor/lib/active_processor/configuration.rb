# -*- encoding : utf-8 -*-
module ActiveProcessor
  class Configuration
    # Configuration file location
    # Default location: plugin root directory
    attr_accessor :config_file

    # Configuration data (hash)
    attr_accessor :data

    # Identification wether we're using Rails <2.0
    attr_accessor :legacy_rails

    # Translate fuction, specify a block
    attr_accessor :translate_func

    # currency exchange function, specify a block
    attr_accessor :currency_exchange

    # currency converter url
    attr_accessor :currency_calc_url

    # tax calculation proc
    attr_accessor :calculate_tax

    # tax calculation proc
    attr_accessor :substract_tax

    # currently active site language
    attr_accessor :language

    # layout to use for payments (maybe customized per engine / per gateway throught controller)
    attr_accessor :layout

    # host to sent notifications to
    attr_accessor :host

    # logging (enabled?)
    attr_accessor :logging

    # logging facility (default: ActiveRecord base logger)
    attr_accessor :logger

    def initialize
      # standard configuration
      @config_file = File.dirname(__FILE__)+"/../../gateway_config.yml"
      @legacy_rails = (Rails.respond_to?(:env)) ? false : true
      @data = YAML::load(File.open(@config_file))[((@legacy_rails) ? RAILS_ENV : Rails.env)]
      @translate_func = lambda { |phrase| t(phrase) }
      @currency_exchange = lambda { |curr1, curr2| 1.0 }
      @currency_calc_url = "/currencies/calculate"
      @calculate_tax = lambda { |u, a| a }
      @substract_tax = lambda { |u, a| a }
      @layout = "callc"
      @language = "en"
      @config = "http://localhost:3000"
      @logging = true
      @logger = ActiveRecord::Base.logger
    end

  end

  class << self
    attr_accessor :configuration
  end

  # ActiveProcessor should be configured in appropriate environment configuration file or initializer (with newer rails)
  #
  # @example
  #   ActiveProcessor.configure do |config|
  #     config.config_file = Rails.root +"/config/gateway_config.yml"
  #     config.legacy_rails = false
  #   end
  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Log something
  def self.log(msg)
    self.configuration.logger.info("[ActiveProcessor] #{msg}") if self.configuration.logging
  end

  def self.debug(msg)
    self.configuration.logger.debug("[ActiveProcessor] #{msg}")
  end

  # In case of payment error
  class GatewayError < StandardError
  end

  # In case of payment engine errror
  class GatewayEngineError < StandardError
  end

  # In case of payment engine errror
  class PaymentEngineError < StandardError
  end

end
