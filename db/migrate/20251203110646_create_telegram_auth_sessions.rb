class CreateTelegramAuthSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_auth_sessions do |t|
      t.string :session_token, null: false
      t.bigint :telegram_id
      t.references :user, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.string :initiated_from
      t.string :client_ip
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :telegram_auth_sessions, :session_token, unique: true
    add_index :telegram_auth_sessions, :telegram_id
    add_index :telegram_auth_sessions, :expires_at
    add_index :telegram_auth_sessions, [:status, :expires_at]
  end
end
