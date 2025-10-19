require 'sinatra'
require 'json'

set :port, 4000
set :public_folder, 'public'

get '/' do
  erb :index
end

post '/telegram_auth' do
  content_type :json
  
  # Здесь будет валидация Telegram авторизации
  # Пока возвращаем успешный ответ
  { status: 'success', redirect: 'http://localhost:3000/dashboard' }.to_json
end