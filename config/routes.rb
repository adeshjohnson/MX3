# -*- encoding : utf-8 -*-
Mor::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => 'callc#main'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.

  match 'test/load_delta_sql(/*path)' => 'test#load_delta_sql'
  match 'callc/pay_subscriptions_test/:year/:month' => 'callc#pay_subscriptions_test'
  match 'billing/callc/pay_subscriptions_test/:year/:month' => 'callc#pay_subscriptions_test'

  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/gateways', :constraints => {:engine=>/gateways/}
  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/integrations', :constraints => {:engine => /integrations/}
  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/google_checkout', :constraints => {:engine => /google_checkout/}
  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/osmp', :constraints => {:engine => /osmp/}
  match '/payment_gateways/:engine/:gateway(/:action/:id)' => 'active_processor/ideal', :constraints => {:engine => /ideal/}
  match '/payment_gateways/:engine/:gateway/pay(/:id)' => 'active_processor/ideal#pay', :constraints => {:engine => /ideal/}

  match '/ccshop' => 'ccpanel#index'
  match '/webphone' => 'callc#webphone'
  match '/active_processor/callc/main' => 'callc#main'
  match '/images/callc/login' => 'callc#login'
  match ':controller/:action.:format'

  # turi buti paskutinis !
  match ':controller(/:action(/:id(.:format)))'


end
