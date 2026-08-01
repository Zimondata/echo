class CreateApprovalRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :approval_requests do |t|
      t.references :agent_run, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.text :risk_reason, null: false
      t.datetime :requested_at, null: false
      t.datetime :resolved_at
      t.string :decided_by
      t.text :decision_note
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :approval_requests, [:agent_run_id, :status]
    add_index :approval_requests, [:status, :requested_at]
  end
end
