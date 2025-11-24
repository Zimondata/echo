class CreateInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :insights do |t|
      t.references :user, null: false, foreign_key: true
      t.string :insight_type, null: false
      t.string :title, null: false
      t.text :content
      t.json :data, default: {}
      t.datetime :generated_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :insights, :insight_type
    add_index :insights, :generated_at
    add_index :insights, :expires_at
  end
end
