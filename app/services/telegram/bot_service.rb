module Telegram
  class BotService
    class << self
      def client
        @client ||= ::Telegram::Bot::Client.new(
          ENV.fetch("TELEGRAM_BOT_TOKEN")
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

        url = "https://api.telegram.org/file/bot#{ENV.fetch('TELEGRAM_BOT_TOKEN')}/#{file_path}"

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
