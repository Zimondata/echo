Rails.application.routes.draw do
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # ActionCable endpoint for WebSocket connections
  mount ActionCable.server => '/cable'

  # Activity Entries
  resources :activity_entries, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  # The primary domain is the owner app. Public project material remains at /showcase.
  root "sessions#new"
  get "old", to: "landing#index"
  get "video", to: "landing#video"
  get "showcase", to: "landing#showcase"
  
  
  # Auth routes
  namespace :telegram_auth do
    post :initiate
    post :status
  end

  resources :sessions, only: [:new, :create, :destroy] do
    collection do
      post :complete_telegram_auth
    end
  end

  get "/login", to: "sessions#new"
  delete "/logout", to: "sessions#destroy", as: :logout

  # Dashboard (protected)
  get "dashboard", to: "dashboard#index"
  get "today", to: "dashboard#index", as: :today
  get "inbox", to: "inbox#index"
  patch "inbox/intent_proposals/:id/review", to: "inbox#review_proposal"
  patch "inbox/approval_requests/:id/resolve", to: "inbox#resolve_approval"
  get "agents", to: "agents#index"
  get "reviews", to: "reviews#index"
  resource :settings, only: %i[show update]
  get "dashboard/nutrition_stats", to: "dashboard#nutrition_stats"
  get "health", to: "health#show", as: :health
  get "health/nutrition/new", to: "health#new_nutrition", as: :new_health_nutrition
  post "health/nutrition", to: "health#create_nutrition", as: :health_nutrition
  get "health/activity/new", to: "health#new_activity", as: :new_health_activity
  post "health/activity", to: "health#create_activity", as: :health_activity


  # Entries (Diary, Ideas, Plans)
  resources :entries, only: [:index, :show, :create, :update, :destroy] do
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
  resources :calendar_events, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    patch :toggle_done, on: :member
  end

  # Tasks waiting for a slot on the calendar
  resources :tasks, only: [ :index, :create, :update ] do
    member do
      patch :complete
      patch :drop
      patch :move_to_next
      patch :drop_from_someday
    end
    resources :task_steps, only: %i[create destroy] do
      patch :toggle, on: :member
    end
    resources :time_blocks, only: %i[create edit update destroy] do
      post :undo_reschedule, on: :member
    end
  end

  resources :projects, only: %i[index show create update] do
    patch :archive, on: :member
  end

  # Rhythms are persisted depth inside Plan, not a permanent destination.
  resources :rhythms, only: %i[index create update] do
    member do
      post :checkin
      post :return_to_rhythm, path: :return, as: :return
    end
  end

  # Reminders
  resources :reminders, only: [ :index, :create, :destroy ] do
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

  # Dashboard Variant 3 Test
  get 'dashboard_v3_test', to: 'dashboard_v3_test#index'

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

    namespace :v1 do
      # Dashboard
      get 'dashboard/overview', to: 'dashboard#overview'
      get 'dashboard/inbox', to: 'dashboard#inbox'
      get 'dashboard/needs_attention', to: 'dashboard#needs_attention'

      # Trusted capture ledger
      resources :captures, only: [:index, :show, :create]
      resources :agent_runs, only: [:index, :show, :create] do
        member do
          patch :transition
        end
        resources :evidence_receipts, only: :create
      end
      patch 'evidence_receipts/:id/verify', to: 'evidence_verifications#update'
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
