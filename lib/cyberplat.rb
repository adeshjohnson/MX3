# -*- encoding : utf-8 -*-
require 'cgi'
require 'net/http'
#require 'net/https'

begin
  require 'money' 
rescue LoadError
  require 'rubygems'
  require_gem 'money'
end
    
require File.dirname(__FILE__) + '/cyberplat/notification'
require File.dirname(__FILE__) + '/cyberplat/helper'
