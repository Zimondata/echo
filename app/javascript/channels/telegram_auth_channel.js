import consumer from "channels/consumer"

const TelegramAuthChannel = {
  subscribe(sessionToken) {
    this.subscription = consumer.subscriptions.create(
      { channel: "TelegramAuthChannel", session_token: sessionToken },
      {
        connected() {
          console.log("✅ Connected to TelegramAuthChannel")
        },

        disconnected() {
          console.log("❌ Disconnected from TelegramAuthChannel")
        },

        received(data) {
          console.log("📨 Received data:", data)

          if (data.type === 'auth_confirmed') {
            console.log("✅ Auth confirmed! Redirecting to:", data.redirect_url)
            window.completeTelegramAuth(sessionToken)
          }
        }
      }
    )

    return this.subscription
  },

  unsubscribe() {
    if (this.subscription) {
      consumer.subscriptions.remove(this.subscription)
      this.subscription = null
    }
  }
}

// Export globally for use in views
window.TelegramAuthChannel = TelegramAuthChannel

export default TelegramAuthChannel
