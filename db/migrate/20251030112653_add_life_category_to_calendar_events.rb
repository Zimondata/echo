class AddLifeCategoryToCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_events, :life_category, :string, default: 'work'
    add_index :calendar_events, :life_category

    # Sync existing calendar events with their entry's category
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE calendar_events
          SET life_category = COALESCE(
            (SELECT category FROM entries WHERE entries.id = calendar_events.entry_id),
            'work'
          )
        SQL
      end
    end
  end
end
