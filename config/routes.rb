Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :tasks, except: [ :show ] do
    member do
      patch :complete
    end
    collection do
      get :completed
      get :today
      get :upcoming
      get :overdue
    end
  end

  resources :projects, except: :show
  resources :labels, except: :show

  get "projects/:project_id/tasks", to: "tasks#index", as: :project_tasks

  root "tasks#index"
end
