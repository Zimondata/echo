namespace :db do
  desc "Migrate data from PostgreSQL to SQLite3"
  task :migrate_from_postgres, [:dry_run] => :environment do |_t, args|
    dry_run = args[:dry_run] == 'dry_run'
    
    puts "=" * 80
    puts "PostgreSQL to SQLite3 Data Migration"
    puts "=" * 80
    puts "Mode: #{dry_run ? 'DRY RUN (no data will be written)' : 'LIVE (data will be migrated)'}"
    puts ""
    
    # Get PostgreSQL connection URL
    postgres_url = ENV['POSTGRES_DATABASE_URL'] || 
                   ENV['DATABASE_URL'] ||
                   Rails.application.credentials.dig(:database, :url)
    
    unless postgres_url
      puts "ERROR: PostgreSQL connection URL not found!"
      puts "Please provide POSTGRES_DATABASE_URL environment variable or set it in Rails credentials"
      puts "Example: POSTGRES_DATABASE_URL=postgres://user:pass@host/dbname"
      exit 1
    end
    
    begin
      # Connect to PostgreSQL
      require 'pg'
      pg_conn = PG.connect(postgres_url)
      puts "✓ Connected to PostgreSQL database"
      
      # Get SQLite3 connection (Rails default)
      sqlite_conn = ActiveRecord::Base.connection
      puts "✓ Connected to SQLite3 database"
      puts ""
      
      # Tables to migrate in order (respecting foreign keys)
      tables_to_migrate = [
        'users',
        'entries',
        'calendar_events',
        'reminders',
        'nutrition_entries',
        'activity_entries',
        'insights',
        'quests'
      ]
      
      total_records = 0
      errors = []
      
      tables_to_migrate.each do |table_name|
        puts "Migrating #{table_name}..."
        
        begin
          # Get column names from PostgreSQL
          pg_columns_result = pg_conn.exec("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1 ORDER BY ordinal_position", [table_name])
          pg_columns = pg_columns_result.map { |row| row['column_name'] }
          
          # Skip if table doesn't exist
          if pg_columns.empty?
            puts "  ⚠ Table #{table_name} does not exist in PostgreSQL, skipping..."
            next
          end
          
          # Filter out vector column (embedding) - SQLite doesn't have it
          columns_to_migrate = pg_columns.reject { |col| col == 'embedding' }
          
          # Get all data from PostgreSQL
          pg_result = pg_conn.exec("SELECT #{columns_to_migrate.join(', ')} FROM #{table_name}")
          
          record_count = pg_result.count
          puts "  Found #{record_count} records"
          
          if record_count == 0
            puts "  ✓ No records to migrate"
            next
          end
          
          unless dry_run
            # Disable foreign key checks temporarily
            sqlite_conn.execute("PRAGMA foreign_keys = OFF") if table_name != 'users'
            
            # Clear existing data (optional - comment out if you want to append)
            # sqlite_conn.execute("DELETE FROM #{table_name}")
            
            # Prepare insert statement
            placeholders = (['?'] * columns_to_migrate.length).join(', ')
            insert_sql = "INSERT INTO #{table_name} (#{columns_to_migrate.join(', ')}) VALUES (#{placeholders})"
            
            # Migrate records
            migrated = 0
            pg_result.each do |row|
              values = columns_to_migrate.map do |col|
                value = row[col]
                
                # Handle NULL values
                next nil if value.nil?
                
                # Handle JSONB columns - convert to JSON string
                column_info = pg_columns_result.find { |c| c['column_name'] == col }
                if column_info && column_info['data_type'] == 'jsonb'
                  # PostgreSQL returns jsonb as string, but we need to ensure it's valid JSON
                  value = value.to_s
                  # If it's already a JSON string, use it; otherwise wrap it
                  begin
                    JSON.parse(value)
                    value
                  rescue JSON::ParserError
                    # If it's not valid JSON, wrap it as a JSON string
                    value.to_json
                  end
                else
                  value
                end
              end
              
              begin
                sqlite_conn.execute(insert_sql, values)
                migrated += 1
              rescue => e
                errors << { table: table_name, error: e.message, record: row }
                puts "    ⚠ Error inserting record #{migrated + 1}: #{e.message}"
              end
            end
            
            # Re-enable foreign key checks
            sqlite_conn.execute("PRAGMA foreign_keys = ON") if table_name != 'users'
            
            puts "  ✓ Migrated #{migrated}/#{record_count} records"
            total_records += migrated
          else
            puts "  [DRY RUN] Would migrate #{record_count} records"
            total_records += record_count
          end
          
        rescue => e
          error_msg = "Error migrating #{table_name}: #{e.message}"
          puts "  ✗ #{error_msg}"
          errors << { table: table_name, error: error_msg }
        end
        
        puts ""
      end
      
      # Summary
      puts "=" * 80
      puts "Migration Summary"
      puts "=" * 80
      puts "Total records: #{total_records}"
      puts "Errors: #{errors.count}"
      
      if errors.any?
        puts ""
        puts "Errors encountered:"
        errors.each do |error|
          puts "  - #{error[:table]}: #{error[:error]}"
        end
      end
      
      if dry_run
        puts ""
        puts "This was a DRY RUN. No data was actually migrated."
        puts "Run without [dry_run] argument to perform actual migration."
      else
        puts ""
        puts "Migration completed!"
      end
      
      pg_conn.close
      
    rescue PG::Error => e
      puts "ERROR: PostgreSQL connection failed: #{e.message}"
      exit 1
    rescue => e
      puts "ERROR: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
end

