class TelegramWebhookJob < ApplicationJob
  queue_as :default
  self.log_arguments = false

  def perform(update_data)
    update = Telegram::Bot::Types::Update.new(update_data)
    sender = update.message&.from || update.callback_query&.from

    unless owner_sender?(sender)
      Rails.logger.warn "Telegram update rejected: non-owner sender"
      return
    end

    if update.message
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

  def owner_sender?(sender)
    owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"].to_s

    owner_id.present? && sender&.id.present? &&
      ActiveSupport::SecurityUtils.secure_compare(owner_id, sender.id.to_s)
  end

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
    elsif data.start_with?('reminder_')
      # Handle reminder button clicks
      handle_reminder_callback(user, data, chat_id)
    elsif data.start_with?('telegram_auth_')
      # Handle auth confirmation
      # Format: "telegram_auth_confirm_<session_token>"
      session_token = data.sub('telegram_auth_confirm_', '')
      handle_auth_confirmation(callback_query, session_token)
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

  def handle_reminder_callback(user, data, chat_id)
    # Parse callback data: reminder_<id>_<action>
    parts = data.split('_')
    reminder_id = parts[1].to_i
    action = parts[2..-1].join('_')

    reminder = user.reminders.find_by(id: reminder_id)

    unless reminder
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "❌ Напоминание не найдено"
      )
      return
    end

    case action
    when "snooze"
      # Snooze for 1 hour
      reminder.snooze!(60)
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "⏰ Напомню через час"
      )

    when "dismiss"
      # Mark as sent and helpful
      reminder.mark_as_sent!
      reminder.mark_helpful!
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "✅ Принято"
      )

    when /^discuss_idea_(\d+)$/
      # User wants to discuss an idea
      idea_id = $1.to_i
      idea = user.entries.find_by(id: idea_id)

      if idea
        # Create a follow-up plan
        Telegram::BotService.send_message(
          chat_id: chat_id,
          text: "💡 Отлично! Давай обсудим идею: \"#{idea.content.truncate(100)}\"\n\nЧто хочешь сделать первым делом?"
        )
        reminder.mark_as_sent!
        reminder.mark_helpful!
      end

    when /^snooze_idea_(\d+)_7d$/
      # Snooze idea reminder for 7 days
      reminder.update!(
        remind_at: 7.days.from_now,
        status: "pending"
      )
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "⏰ Напомню через неделю"
      )

    when /^archive_idea_(\d+)$/
      # Archive/cancel the idea reminder
      reminder.cancel!
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "📦 Идея отложена"
      )

    when "log_meal"
      # Prompt user to log a meal
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "🍽️ Отправь фото блюда или опиши текстом что ты ел"
      )
      reminder.mark_as_sent!

    when "skip_pattern_nutrition", "skip_pattern_activity"
      # User doesn't want to log today
      reminder.mark_as_sent!
      reminder.mark_not_helpful!
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "👌 Понятно, не буду беспокоить"
      )

    when "log_activity"
      # Prompt user to log activity
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "💪 Отправь скриншот Garmin или опиши тренировку текстом"
      )
      reminder.mark_as_sent!

    when /^plan_ready_(\d+)$/
      # User is ready for the plan
      reminder.mark_as_sent!
      reminder.mark_helpful!
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "✅ Отлично, все готово!"
      )

    when /^plan_prepare_(\d+)$/
      # User needs help preparing
      event_id = $1.to_i
      event = user.calendar_events.find_by(id: event_id)

      if event
        Telegram::BotService.send_message(
          chat_id: chat_id,
          text: "📝 Что нужно подготовить для: \"#{event.title}\"?\n\nОпиши и я сохраню как план подготовки"
        )
        reminder.mark_as_sent!
      end

    when /^plan_reschedule_(\d+)$/
      # User wants to reschedule
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "📅 На какое время перенести? Напиши в формате:\n\"Перенести на завтра в 15:00\""
      )
      reminder.mark_as_sent!

    when "plan_rest"
      # User wants to plan rest
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "🏖️ Отлично! Когда хочешь отдохнуть? Напиши:\n\"Выходной в субботу\" или \"Отпуск с 1 по 7 июня\""
      )
      reminder.mark_as_sent!
      reminder.mark_helpful!

    when "show_relaxation"
      # Show relaxation techniques
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: <<~TEXT
          🧘 *Техники релаксации:*

          1. *Дыхание 4-7-8*
          Вдох 4 сек, задержка 7 сек, выдох 8 сек

          2. *Прогрессивная мышечная релаксация*
          Напрягай и расслабляй мышцы по очереди

          3. *5-4-3-2-1*
          5 вещей которые видишь
          4 которые слышишь
          3 которые чувствуешь
          2 которые пахнут
          1 которую чувствуешь на вкус

          4. *Медитация 5 минут*
          Просто сиди и наблюдай за дыханием
        TEXT
      )
      reminder.mark_as_sent!
      reminder.mark_helpful!

    when "acknowledge_context"
      # User acknowledges the context
      reminder.mark_as_sent!
      reminder.mark_helpful!
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "👍 Береги себя!"
      )

    else
      # Unknown action
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "✅ Принято"
      )
      reminder.mark_as_sent! unless reminder.status == "sent"
    end

  rescue StandardError => e
    Rails.logger.error "Reminder callback error: #{e.message}"
    Telegram::BotService.send_message(
      chat_id: chat_id,
      text: "❌ Ошибка обработки действия"
    )
  end

  def handle_auth_confirmation(callback_query, session_token)
    result = TelegramAuthService.confirm_auth(
      session_token: session_token,
      telegram_user: callback_query.from
    )

    chat_id = callback_query.message.chat.id
    message_id = callback_query.message.message_id

    if result[:success]
      # Broadcast to WebSocket
      auth_session = result[:session]
      TelegramAuthChannel.broadcast_to(
        auth_session,
        {
          type: 'auth_confirmed',
          user_id: result[:user].id,
          redirect_url: Rails.application.routes.url_helpers.calendar_events_path(view: "month")
        }
      )

      # Get app URL - Telegram requires HTTPS for buttons
      app_url = if Rails.env.development?
                   'https://unbeset-tressier-roselyn.ngrok-free.dev'
                 else
                   Rails.application.credentials.dig(:app_url) || 'https://echo.datapine.space'
                 end

      # Edit original message to remove buttons
      Telegram::BotService.client.api.edit_message_text(
        chat_id: chat_id,
        message_id: message_id,
        text: "✅ Авторизация завершена!",
        parse_mode: "Markdown"
      )

      # Send new message with dashboard button
      Telegram::BotService.client.api.send_message(
        chat_id: chat_id,
        text: "🎉 Добро пожаловать в Echo!\n\nНажмите на кнопку ниже, чтобы перейти на дашборд:",
        parse_mode: "Markdown",
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [
              {
                text: "🚀 Перейти на дашборд",
                url: "#{app_url}/dashboard"
              }
            ]
          ]
        )
      )
    else
      # Edit original message to show error
      Telegram::BotService.client.api.edit_message_text(
        chat_id: chat_id,
        message_id: message_id,
        text: "❌ Ошибка авторизации: #{result[:error]}",
        parse_mode: "Markdown"
      )
    end
  rescue StandardError => e
    Rails.logger.error "Error editing auth message: #{e.message}"
    # Fallback: send new message with button if editing fails
    if result&.dig(:success)
      app_url = if Rails.env.development?
                   'https://unbeset-tressier-roselyn.ngrok-free.dev'
                 else
                   Rails.application.credentials.dig(:app_url) || 'https://echo.datapine.space'
                 end
      
      Telegram::BotService.client.api.send_message(
        chat_id: chat_id,
        text: "✅ Авторизация завершена!\n\n🎉 Добро пожаловать в Echo!\n\nНажмите на кнопку ниже, чтобы перейти на дашборд:",
        parse_mode: "Markdown",
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [
              {
                text: "🚀 Перейти на дашборд",
                url: "#{app_url}/dashboard"
              }
            ]
          ]
        )
      )
    else
      Telegram::BotService.send_message(
        chat_id: chat_id,
        text: "❌ Ошибка авторизации"
      )
    end
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
