class AddCreatorTokenToEvidenceReceipts < ActiveRecord::Migration[8.0]
  def change
    add_reference :evidence_receipts,
      :creator_service_token,
      foreign_key: { to_table: :echo_service_tokens },
      index: true
  end
end
