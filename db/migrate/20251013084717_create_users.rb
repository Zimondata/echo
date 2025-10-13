class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.bigint :telegram_id, null: false
      t.string :username
      t.string :first_name
      t.string :last_name
      t.string :timezone, default: "UTC"
      t.string :language, default: "ru"
      t.text :google_refresh_token
      t.text :google_access_token
      t.datetime :google_token_expires_at
      t.jsonb :settings, default: {}

      t.timestamps
    end
    add_index :users, :telegram_id, unique: true
  end
end
