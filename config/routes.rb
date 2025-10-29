Rails.application.routes.draw do
  # Activity Entries
  resources :activity_entries, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  # Root path - Landing page
  root "landing#index"
  
  # Auth routes
  get "/auth/telegram/callback", to: "sessions#telegram_callback"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  # Dashboard (protected)
  get "dashboard", to: "dashboard#index"
  get "dashboard/nutrition_stats", to: "dashboard#nutrition_stats"
  

  # Entries (Diary, Ideas, Plans)
  resources :entries, only: [:index, :show, :update, :destroy] do
    collection do
      get :diary
      get :ideas
      get :plans
    end
  end
  
  # Convenient redirects
  get '/ideas', to: redirect('/entries/ideas')
  get '/plans', to: redirect('/entries/plans')
  get '/diary', to: redirect('/entries/diary')

  # Nutrition
  resources :nutrition_entries, path: 'nutrition', only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # Calendar Events
  resources :calendar_events, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # Reminders
  resources :reminders, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do
      post :snooze
    end
  end

  # Ideas Dashboard
  get 'ideas_dashboard', to: 'ideas_dashboard#index'
  post 'ideas_dashboard/:id/research', to: 'ideas_dashboard#research_idea', as: :research_idea
  post 'ideas_dashboard/:id/generate_quest', to: 'ideas_dashboard#generate_quest', as: :generate_quest
  get 'ideas_dashboard/:id/research', to: 'ideas_dashboard#show_research', as: :show_research

  # Quests
  resources :quests, only: [:index, :show, :edit, :update, :destroy] do
    member do
      patch :toggle_step
      patch :complete_step
      patch :uncomplete_step
      patch :update_status
    end
  end

  # Smart Priority Analysis
  post 'smart_priority/analyze_all', to: 'smart_priority#analyze_all', as: :smart_priority_analyze_all
  post 'smart_priority/:id/analyze', to: 'smart_priority#analyze_idea', as: :smart_priority_analyze_idea
  get 'smart_priority/:id/analysis', to: 'smart_priority#show_analysis', as: :smart_priority_show_analysis
  get 'smart_priority/stats', to: 'smart_priority#stats', as: :smart_priority_stats
  get 'smart_priority/settings', to: 'smart_priority#settings', as: :smart_priority_settings
  patch 'smart_priority/settings', to: 'smart_priority#update_settings'

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
      resources :entries, only: [:index, :show, :create, :update, :destroy] do
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
          patch :toggle_status
          patch :toggle
        end
        collection do
          get :stats
        end
      end

      # Reminders API
      resources :reminders, only: [:index, :show, :create, :update, :destroy]

      # Nutrition API
      resources :nutrition_entries, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :daily_stats
          get :weekly_stats
          get :monthly_stats
        end
        member do
          patch :toggle_status
        end
      end

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
