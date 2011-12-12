%w{ models controllers helpers }.each do |dir|
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path
  if Rails.respond_to?(:env)
    ActiveSupport::Dependencies.load_paths << path
    ActiveSupport::Dependencies.load_once_paths.delete(path)
    # <hack>
    HOST = IO.readlines(File.dirname(__FILE__) + '/../../../config/environment.rb').reject { |l| l =~ /^#/ }.join.match(/[^#]Web_URL = "(\S+)"/)[1]
    HOST = $1
    # </hack>
  else
    # <hack>
    HOST = IO.readlines(File.dirname(__FILE__) + '/../../../config/environment.rb').reject { |l| l =~ /^#/ }.join.match(/[^#]Web_URL = "(\S+)"/)[1]
    HOST = $1
    # </hack>
    Dependencies.load_paths << path
    Dependencies.load_once_paths.delete(path)
  end
end

def initialize_production(config)

  config.after_initialize do
    ActiveProcessor.configure do |config|
      config.host = HOST
      config.translate_func = lambda {|s| Localization::_t(s, ActiveProcessor.configuration.language )}
      config.calculate_tax = lambda{ |u,a| User.find(:first, :conditions => { :id => u }).get_tax.apply_tax(a) }
      config.substract_tax = lambda{ |u,a| User.find(:first, :conditions => { :id => u }).get_tax.count_amount_without_tax(a) }
      config.currency_exchange = lambda {|c1, c2| Currency.count_exchange_rate(c1, c2)}
    end
  end
end

def initialize_development(config)
  config.after_initialize do
    ActiveMerchant::Billing::Base.mode = :test

    ActiveProcessor.configure do |config|
      config.host = HOST
      config.translate_func = lambda {|s| Localization::_t(s, ActiveProcessor.configuration.language )}
      config.currency_exchange = lambda {|c1, c2| Currency.count_exchange_rate(c1, c2)}
      config.calculate_tax = lambda{ |u,a| User.find(:first, :conditions => { :id => u }).get_tax.apply_tax(a) }
      config.substract_tax = lambda{ |u,a| User.find(:first, :conditions => { :id => u }).get_tax.count_amount_without_tax(a) }
    end
  end
end

if Rails.respond_to?(:env) # jei Rails > 2.0
  if Rails.env.eql?("production")
    initialize_production(config)
  else
    initialize_development(config)
  end
else # Rails < 2.0
  if RAILS_ENV.eql?("production")
    initialize_production(config)
  else
    initialize_development(config)
  end
end

require "active_processor"
