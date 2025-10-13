class TelegramWebhookJob < ApplicationJob
  queue_as :default

  def perform(update_data)
    update = Telegram::Bot::Types::Update.new(update_data)

    return unless update.message

    message = update.message

    # Get or create user
    user = find_or_create_user(message.from)

    # Process message through handler
    Telegram::MessageHandler.new(user, message).process

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

  def find_or_create_user(from)
    User.find_or_create_by!(telegram_id: from.id) do |user|
      user.username = from.username
      user.first_name = from.first_name
      user.last_name = from.last_name
      user.language = from.language_code || "ru"
    end
  end
end
