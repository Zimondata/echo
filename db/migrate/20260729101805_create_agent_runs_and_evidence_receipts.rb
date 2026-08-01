class CreateAgentRunsAndEvidenceReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :intent_proposal, null: false, foreign_key: true
      t.string :executor, null: false, default: 'gary'
      t.text :objective, null: false
      t.text :definition_of_done, null: false
      t.string :status, null: false, default: 'queued'
      t.boolean :approval_required, null: false, default: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.json :metadata, null: false, default: {}
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :agent_runs, [:user_id, :status]
    add_index :agent_runs, [:intent_proposal_id, :status]

    create_table :evidence_receipts do |t|
      t.references :agent_run, null: false, foreign_key: true
      t.string :receipt_type, null: false
      t.text :summary, null: false
      t.string :tool_name
      t.string :target_ref
      t.string :result_ref
      t.text :verification, null: false
      t.boolean :verified, null: false, default: false
      t.json :redacted_inputs, null: false, default: {}
      t.json :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :evidence_receipts, [:agent_run_id, :verified]
    add_index :evidence_receipts, :occurred_at
  end
end
