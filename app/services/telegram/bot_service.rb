module Telegram
  class BotService
    class << self
      def client
        @client ||= ::Telegram::Bot::Client.new(
          Rails.application.credentials.dig(:telegram, :bot_token)
        )
      end

      def send_message(chat_id:, text:, **options)
        return unless chat_id && text

        client.api.send_message(
          chat_id: chat_id,
          text: text,
          parse_mode: "Markdown",
          **options
        )
      rescue StandardError => e
        Rails.logger.error "Failed to send Telegram message: #{e.message}"
        nil
      end

      def send_message_with_keyboard(chat_id:, text:, keyboard:, **options)
        return unless chat_id && text && keyboard

        reply_markup = {
          inline_keyboard: keyboard
        }

        client.api.send_message(
          chat_id: chat_id,
          text: text,
          parse_mode: "Markdown",
          reply_markup: reply_markup,
          **options
        )
      rescue StandardError => e
        Rails.logger.error "Failed to send Telegram message with keyboard: #{e.message}"
        nil
      end

      def send_typing(chat_id)
        client.api.send_chat_action(
          chat_id: chat_id,
          action: "typing"
        )
      rescue StandardError => e
        Rails.logger.error "Failed to send typing action: #{e.message}"
      end

      def download_file(file_id)
        file = client.api.get_file(file_id: file_id)
        file_path = file.file_path

        return nil unless file_path

        url = "https://api.telegram.org/file/bot#{Rails.application.credentials.dig(:telegram, :bot_token)}/#{file_path}"

        # Download file
        response = HTTParty.get(url)
        return nil unless response.success?

        response.body
      rescue StandardError => e
        Rails.logger.error "Failed to download file: #{e.message}"
        nil
      end
    end
  end
end
