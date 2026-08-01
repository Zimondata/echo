class CreateIntentProposals < ActiveRecord::Migration[8.0]
  def change
    create_table :intent_proposals do |t|
      t.references :capture, null: false, foreign_key: true
      t.string :intent_type, null: false
      t.string :title, null: false
      t.text :description
      t.string :owner_type, null: false, default: 'user'
      t.string :risk_level, null: false, default: 'reversible'
      t.decimal :confidence, precision: 5, scale: 4
      t.json :source_span, null: false, default: {}
      t.json :payload, null: false, default: {}
      t.json :entities, null: false, default: {}
      t.string :status, null: false, default: 'proposed'
      t.datetime :due_at
      t.datetime :accepted_at
      t.datetime :rejected_at
      t.text :review_note
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :intent_proposals, [:capture_id, :status]
    add_index :intent_proposals, [:intent_type, :status]
    add_index :intent_proposals, [:owner_type, :status]
  end
end
