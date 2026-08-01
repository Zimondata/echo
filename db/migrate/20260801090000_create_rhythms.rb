class CreateRhythms < ActiveRecord::Migration[8.0]
  def change
    create_table :rhythms do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :full_version, null: false
      t.text :minimum_version, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :rhythms, [ :user_id, :active, :position ]
  end
end
