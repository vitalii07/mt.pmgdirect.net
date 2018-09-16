ActionController::Routing::Routes.draw do |map|

  map.resources :searches
  map.destroyall '/seeds/:id/destroyall/', :controller => 'seeds', :action => 'destroyall'
  map.login '/login/:id', :controller => 'users', :action => 'login'
  map.logout '/logout', :controller => 'users', :action => 'logout'
  
  #For the delivery exception & DSR report
  map.delivery_excpetion '/der', :controller => 'reports', :action => 'delivery_exception'
  map.dsr 'reports/dsr/:id', :controller => 'reports', :action => 'dsr'
  
#  map.report '/jobs/:id/report', :controller => 'jobs', :action => 'report'
	map.fetch_data 'seeds/fetch_data', :controller => 'seeds', :action => 'fetch_data'
  map.resources :mailshops
  map.resources :versions, :member => {:delivery_bargraph => :get}
  map.resources :jobs, :collection => { :search => :get, :select => :get, :admin_report => :get, :search => :get}, :member => {:delivery_bargraph => :get}
  map.resources :clients, :collection => {:manager_list => :get}
  map.resources :scfs, :collection => {:all_scfs => :get, :search => :get}
  map.resources :users, :collection => {:client_list => :get, :manager_list => :get}
  map.resources :seeds, :member => { :destroyall => :delete}
  map.resources :reports, 
    :collection => {
      :scfperformancerpt => :get,:delivery_by_state_rpt => :get, :returns_by_state_rpt => :get, 
      :delivery_by_scf_rpt => :get, :returns_by_scf_rpt => :get, :delivery_by_seed_rpt => :get, 
      :returns_by_seed_rpt => :get, :new_delivery_exception => :get
    },
    :member => {:new_delivery_summary => :get}
  map.connect '', :controller => "jobs", :action => "index", :c => 'created_at', :d => "down"

  map.resources :csheaders, :shallow => true do |csheaders|
    csheaders.resources :confirmstats
  end
  map.resources :messages, :only => [:destroy]
  map.connect '/reload_usps', :controller => "confirmstats", :action => "reload"

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
