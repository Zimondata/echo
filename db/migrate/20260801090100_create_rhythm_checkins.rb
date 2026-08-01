class CreateRhythmCheckins < ActiveRecord::Migration[8.0]
  def change
    create_table :rhythm_checkins do |t|
      t.references :rhythm, null: false, foreign_key: true
      t.date :local_date, null: false
      t.string :state, null: false
      t.string :previous_state
      t.datetime :returned_at
      t.text :note

      t.timestamps
    end

    add_index :rhythm_checkins, [ :rhythm_id, :local_date ], unique: true
    add_check_constraint :rhythm_checkins,
      "state IN ('full', 'minimum', 'skipped', 'returned')",
      name: "rhythm_checkins_state_allowed"
  end
end
