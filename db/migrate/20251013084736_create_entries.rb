class CreateEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :entry_type, null: false # diary, idea, plan, plan_update
      t.text :content, null: false
      t.text :transcript
      t.string :audio_url
      t.string :audio_file_id
      t.jsonb :metadata, default: {}
      t.vector :embedding, limit: 1536
      t.string :status, default: "active" # active, archived, deleted
      t.integer :priority, default: 0
      t.datetime :occurred_at

      t.timestamps
    end

    add_index :entries, :entry_type
    add_index :entries, :status
    add_index :entries, :occurred_at
    add_index :entries, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
