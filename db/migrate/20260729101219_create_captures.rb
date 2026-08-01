class CreateCaptures < ActiveRecord::Migration[8.0]
  def change
    create_table :captures do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source_type, null: false
      t.string :source_ref, null: false
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: 'received'
      t.text :raw_text
      t.text :transcript
      t.json :transcript_versions, null: false, default: []
      t.json :segment_timestamps, null: false, default: []
      t.json :attachments, null: false, default: []
      t.json :provider_ledger, null: false, default: []
      t.string :audio_retention_policy, null: false, default: 'delete_after_verified_transcript'
      t.string :parser_version
      t.json :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :captures, [:user_id, :idempotency_key], unique: true
    add_index :captures, [:user_id, :status]
    add_index :captures, [:user_id, :occurred_at]
    add_index :captures, [:user_id, :source_type, :source_ref], unique: true
  end
end
