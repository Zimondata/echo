class TelegramWebhookJob < ApplicationJob
  queue_as :default

  def perform(update_data)
    update = Telegram::Bot::Types::Update.new(update_data)

    if update.message
      # Handle regular message
      message = update.message
      user = find_or_create_user(message.from)
      Telegram::MessageHandler.new(user, message).process
    elsif update.callback_query
      # Handle callback query (inline button press)
      handle_callback_query(update.callback_query)
    end

  rescue StandardError => e
    Rails.logger.error "TelegramWebhookJob error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Notify user about error
    Telegram::BotService.send_message(
      chat_id: message&.chat&.id,
      text: "Извините, произошла ошибка. Попробуйте позже."
    ) if message&.chat&.id
  end

  private

  def handle_callback_query(callback_query)
    # Get user
    user = find_or_create_user(callback_query.from)
    
    # Parse callback data
    data = callback_query.data
    chat_id = callback_query.message.chat.id
    
    if data.start_with?('fix_type_')
      # Format: "fix_type_123_idea"
      parts = data.split('_')
      entry_id = parts[2]
      new_type = parts[3]
      
      # Find entry
      entry = user.entries.find_by(id: entry_id)
      if entry && entry.update(entry_type: new_type)
        # Send confirmation
        type_name = case new_type
                   when 'idea' then 'Идеи'
                   when 'plan' then 'Планы'
                   when 'diary' then 'Дневник'
                   else new_type
                   end
        
        Telegram::BotService.send_message(
          chat_id: chat_id,
          text: "✅ Запись перемещена в «#{type_name}»"
        )
      else
        Telegram::BotService.send_message(
          chat_id: chat_id,
          text: "❌ Ошибка при изменении типа записи"
        )
      end
    elsif data.start_with?('fix_ok_')
      # User confirmed classification is correct
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "👍 Отлично!"
      )
    end
    
    # Answer callback query to remove loading state
    Telegram::BotService.client.api.answer_callback_query(
      callback_query_id: callback_query.id
    )
  rescue StandardError => e
    Rails.logger.error "Callback query error: #{e.message}"
    # Always answer callback query
    Telegram::BotService.client.api.answer_callback_query(
      callback_query_id: callback_query.id,
      text: "Ошибка обработки"
    ) rescue nil
  end

  def find_or_create_user(from)
    User.find_or_create_by!(telegram_id: from.id) do |user|
      user.username = from.username
      user.first_name = from.first_name
      user.last_name = from.last_name
      user.language = from.language_code || "ru"
    end
  end
end
