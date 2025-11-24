class CreateNutritionEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :nutrition_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, null: true, foreign_key: true
      t.decimal :calories, precision: 8, scale: 2
      t.decimal :protein, precision: 6, scale: 2
      t.decimal :fat, precision: 6, scale: 2
      t.decimal :carbs, precision: 6, scale: 2
      t.string :meal_type, null: false
      t.text :food_items
      t.datetime :recorded_at, null: false
      t.text :meal_description
      t.string :photo_url
      t.json :analysis_data, default: {}
      t.string :status, default: 'active'

      t.timestamps
    end

    add_index :nutrition_entries, :recorded_at
    add_index :nutrition_entries, :meal_type
    add_index :nutrition_entries, :status
    add_index :nutrition_entries, [:user_id, :recorded_at]
  end
end
