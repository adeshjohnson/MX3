ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  map.connect '', :controller => "callc"

#  map.connect 'tariffs/user_rates/:currency',
#    :controller => 'tariffs',
#    :action => 'user_rates',
#    :requirements => { :currency => /\w+/}
#    #:currency => nil
  
  ActiveProcessor::Routes.draw(map) # active processor routes

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  map.connect 'test/load_delta_sql/*path',         :controller => 'test', :action => 'load_delta_sql'
  #map.connect 'test/load_delta_sql/:folder/:path', :controller => 'test', :action => 'load_delta_sql'
  
  map.connect 'callc/pay_subscriptions_test/:year/:month', :controller => 'callc', :action => 'pay_subscriptions_test'
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'

  map.connect 'billing/callc/pay_subscriptions_test/:year/:month', :controller => 'callc', :action => 'pay_subscriptions_test'
  map.connect 'billing/:controller/:action/:id.:format'
  map.connect 'billing/:controller/:action/:id'  
  
  map.connect 'stylesheets/:rcss.:format', :controller => '/stylesheets', :action => 'rcss'

  map.connect ':controller/:action.:format'
  map.connect 'billing/:controller/:action.:format'
end
