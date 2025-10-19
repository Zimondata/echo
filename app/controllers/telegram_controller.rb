class TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def webhook
    update = Telegram::Bot::Types::Update.new(webhook_params.to_h)

    # Process update asynchronously
    TelegramWebhookJob.perform_later(update.to_h)

    head :ok
  rescue StandardError => e
    Rails.logger.error "Telegram webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :ok # Always return 200 to Telegram
  end

  private

  def webhook_params
    params.permit!
  end
end
