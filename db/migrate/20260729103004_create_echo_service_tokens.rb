class CreateEchoServiceTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :echo_service_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.json :scopes, null: false, default: []
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :echo_service_tokens, :token_digest, unique: true
    add_index :echo_service_tokens, [:user_id, :revoked_at]
  end
end
