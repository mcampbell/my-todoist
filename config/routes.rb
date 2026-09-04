Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :tasks, except: [ :show ] do
    member do
      patch :complete
      patch :skip
    end
    collection do
      get :due_since
      get :completed
      get :today
      get :upcoming
      get :overdue
      get :search
    end
  end

  resource :os_notification, only: :create

  resources :projects, except: :show
  resources :labels, except: :show
  resources :completed_occurrences, only: :show

  get "projects/:project_id/tasks", to: "tasks#index", as: :project_tasks

  root "tasks#index"
end
