Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :tasks, except: [ :show ] do
    member do
      patch :complete
    end
    collection do
      get :completed
    end
  end

  root "tasks#index"
end
