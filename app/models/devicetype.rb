class Devicetype < ActiveRecord::Base

  def self.load_types(options = {})
    Devicetype.find(:all).map{|type|
      (options.has_key?(type.name) and  options[type.name] == false) ? nil : type
    }.compact
  end
end
