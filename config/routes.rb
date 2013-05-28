resources :invoices do
   	collection do 
      get :auto_complete
   		get :bulk_edit, :context_menu
   		post :bulk_edit, :bulk_update
   		delete :bulk_destroy 
   	end
end
resources :expenses do
    collection do 
      get :bulk_edit, :context_menu
      post :bulk_edit, :bulk_update
      delete :bulk_destroy 
    end
end

resources :invoice_imports, :only => [:new, :create]
resources :expense_imports, :only => [:new, :create]
resources :invoice_comments, :only => [:create, :destroy]

resources :projects do
	resources :invoices, :only => [:index, :new, :create]
  resources :expenses, :only => [:index, :new, :create]
end

match "invoices_time_entries/:action", :controller => "invoices_time_entries"
  
