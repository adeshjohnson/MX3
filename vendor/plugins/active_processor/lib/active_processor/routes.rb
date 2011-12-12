module ActiveProcessor
  class Routes
    def self.draw(map)
      map.connect '/payment_gateways/configuration', { :controller => 'payment_gateways', :action => 'configuration'}
      map.connect '/payment_gateways/update', { :controller => 'payment_gateways', :action => 'update', :requirements => { :mode => /(integration|gateway)/ } }

      map.connect '/payment_gateways/:engine/:gateway/:action', { :controller => 'active_processor/gateways', :requirements => { :engine => /gateways/ } }
      map.connect '/payment_gateways/:engine/:gateway/:action', { :controller => 'active_processor/integrations', :requirements => { :engine => /integrations/ } }
      map.connect '/payment_gateways/:engine/:gateway/:action', { :controller => 'active_processor/google_checkout', :requirements => { :engine => /google_checkout/ } }
      map.connect '/payment_gateways/:engine/:gateway/:action', { :controller => 'active_processor/osmp', :requirements => { :engine => /osmp/ } }
      map.connect '/payment_gateways/:engine/:gateway/:action/:id', { :controller => 'active_processor/ideal', :requirements => { :engine => /ideal/ } }
    end
  end
end
