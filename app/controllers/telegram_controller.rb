class TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  before_action :verify_telegram_webhook_secret!
  before_action :verify_owner_update!

  def webhook
    TelegramWebhookJob.perform_later(webhook_payload)

    head :ok
  rescue StandardError => e
    Rails.logger.error "Telegram webhook processing error: #{e.class}"
    head :internal_server_error
  end

  private

  def verify_telegram_webhook_secret!
    expected = ENV["TELEGRAM_WEBHOOK_SECRET"].to_s
    provided = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s

    return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided)

    head :unauthorized
  end

  def verify_owner_update!
    owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"].to_s
    sender_id = params.dig(:message, :from, :id) || params.dig(:callback_query, :from, :id)

    return if owner_id.present? && sender_id.present? &&
      ActiveSupport::SecurityUtils.secure_compare(owner_id, sender_id.to_s)

    head :forbidden
  end

  def webhook_payload
    request.request_parameters.deep_stringify_keys.slice(
      "update_id", "message", "callback_query"
    )
  end
end
