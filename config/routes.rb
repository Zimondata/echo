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

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Telegram Bot webhook
  post "/telegram/webhook", to: "telegram#webhook"
end
