Rails.application.routes.draw do
  # Root path - Dashboard
  root "dashboard#index"

  # Dashboard
  get "dashboard", to: "dashboard#index"

  # Entries (Diary, Ideas, Plans)
  resources :entries, only: [:index, :show] do
    collection do
      get :diary
      get :ideas
      get :plans
    end
  end

  # Calendar Events
  resources :calendar_events, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # Reminders
  resources :reminders, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # API routes
  namespace :api do
    # Custom Calendar API (new standalone)
    get 'calendar/events', to: 'calendar#index'
    post 'calendar/events', to: 'calendar#create'
    get 'calendar/events/:id', to: 'calendar#show'
    put 'calendar/events/:id', to: 'calendar#update'
    delete 'calendar/events/:id', to: 'calendar#destroy'
    patch 'calendar/events/:id/toggle_done', to: 'calendar#toggle_done'
    patch 'calendar/events/:id/move', to: 'calendar#move'
    get 'calendar/categories', to: 'calendar#categories'
    get 'calendar/upcoming', to: 'calendar#upcoming'
    get 'calendar/stats', to: 'calendar#stats'

    # Reminders API (manual send)
    post 'reminders/:id/send_now', to: 'reminders#send_now'

    namespace :v1 do
      # Dashboard
      get 'dashboard/overview', to: 'dashboard#overview'
      get 'dashboard/inbox', to: 'dashboard#inbox'
      get 'dashboard/needs_attention', to: 'dashboard#needs_attention'

      # Entries
      resources :entries, only: [:index, :show, :update] do
        member do
          patch :categorize
          patch :add_tags
          get :similar
        end
        collection do
          patch :bulk_update
          get :stats
        end
      end

      # Insights & Analytics
      resources :insights, only: [:index, :show] do
        collection do
          post :generate
          get :analytics
        end
      end

      # Calendar Events API  
      resources :calendar_events, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :toggle_done
        end
        collection do
          get :stats
        end
      end

      # Reminders API
      resources :reminders, only: [:index, :show, :create, :update, :destroy]

      # Search
      get 'search', to: 'search#index'
      get 'search/suggestions', to: 'search#suggestions'
    end
  end


  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Telegram Bot webhook
  post "/telegram/webhook", to: "telegram#webhook"
end
