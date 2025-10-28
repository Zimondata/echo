module Ai
  class CorrectionApplier
    class << self
      def apply(correction_result, user)
        return false unless correction_result[:is_correction]
        
        target_entry = correction_result[:target_entry]
        return false unless target_entry
        
        corrections = correction_result[:corrections]
        success_messages = []
        
        case correction_result[:correction_type]
        when "time_correction"
          success_messages << apply_time_correction(target_entry, corrections[:time])
        when "nutrition_correction"
          success_messages << apply_nutrition_correction(target_entry, corrections[:nutrition])
        when "content_correction"
          success_messages << apply_content_correction(target_entry, corrections[:content])
        when "type_correction"
          success_messages << apply_type_correction(target_entry, corrections[:entry_type])
        else
          return false
        end
        
        # Log the correction
        Rails.logger.info "Applied correction: #{correction_result[:correction_type]} to entry #{target_entry.id}"
        
        # Return both success message and updated entry data
        {
          success_message: success_messages.compact.join(", "),
          updated_entry: target_entry,
          correction_type: correction_result[:correction_type]
        }
      end

      private

      def apply_time_correction(entry, new_time)
        return nil unless new_time && entry.calendar_event
        
        old_time = entry.calendar_event.start_time
        new_datetime = Time.zone.parse(new_time)
        
        entry.calendar_event.update!(
          start_time: new_datetime,
          end_time: entry.calendar_event.end_time ? new_datetime + (entry.calendar_event.end_time - old_time) : nil
        )
        
        old_time_str = old_time.strftime('%H:%M')
        new_time_str = new_datetime.strftime('%H:%M')
        
        "изменил время с #{old_time_str} на #{new_time_str}"
      end

      def apply_nutrition_correction(entry, nutrition_data)
        return nil unless nutrition_data && entry.nutrition_entry
        
        nutrition_entry = entry.nutrition_entry
        changes = []
        
        if nutrition_data[:calories] && nutrition_data[:calories] != nutrition_entry.calories
          old_calories = nutrition_entry.calories
          nutrition_entry.update!(calories: nutrition_data[:calories])
          changes << "калории: #{old_calories} → #{nutrition_data[:calories]}"
        end
        
        if nutrition_data[:protein] && nutrition_data[:protein] != nutrition_entry.protein
          old_protein = nutrition_entry.protein
          nutrition_entry.update!(protein: nutrition_data[:protein])
          changes << "белки: #{old_protein}г → #{nutrition_data[:protein]}г"
        end
        
        if nutrition_data[:fat] && nutrition_data[:fat] != nutrition_entry.fat
          old_fat = nutrition_entry.fat
          nutrition_entry.update!(fat: nutrition_data[:fat])
          changes << "жиры: #{old_fat}г → #{nutrition_data[:fat]}г"
        end
        
        if nutrition_data[:carbs] && nutrition_data[:carbs] != nutrition_entry.carbs
          old_carbs = nutrition_entry.carbs
          nutrition_entry.update!(carbs: nutrition_data[:carbs])
          changes << "углеводы: #{old_carbs}г → #{nutrition_data[:carbs]}г"
        end
        
        return nil if changes.empty?
        
        "исправил БЖУ: #{changes.join(', ')}"
      end

      def apply_content_correction(entry, new_content)
        return nil unless new_content && new_content != entry.content
        
        old_content = entry.content.truncate(50)
        entry.update!(content: new_content)
        
        # If this is a nutrition entry, try to recalculate nutrition data
        if entry.nutrition_entry && entry.entry_type == 'nutrition'
          recalculate_nutrition_for_content(entry, new_content)
        end
        
        "изменил содержание с '#{old_content}' на '#{new_content.truncate(50)}'"
      end

      def apply_type_correction(entry, new_type)
        return nil unless new_type && new_type != entry.entry_type
        
        old_type = entry.entry_type
        entry.update!(entry_type: new_type)
        
        # If changing to/from plan, handle calendar events
        if new_type == 'plan' && !entry.calendar_event
          # Create calendar event for new plan
          create_calendar_event_for_entry(entry)
        elsif old_type == 'plan' && new_type != 'plan' && entry.calendar_event
          # Remove calendar event if no longer a plan
          entry.calendar_event.destroy
        end
        
        type_names = {
          'diary' => 'дневник',
          'idea' => 'идею',
          'plan' => 'план',
          'nutrition' => 'питание'
        }
        
        "изменил тип с '#{type_names[old_type]}' на '#{type_names[new_type]}'"
      end

      def create_calendar_event_for_entry(entry)
        return unless entry.entry_type == 'plan'
        
        # Create a simple all-day event for today
        start_time = Time.current.in_time_zone(entry.user.timezone).beginning_of_day
        
        entry.user.calendar_events.create!(
          entry: entry,
          title: entry.content.truncate(100),
          description: entry.content,
          start_time: start_time,
          end_time: start_time.end_of_day,
          event_type: "plan",
          all_day: true
        )
      end

      def recalculate_nutrition_for_content(entry, new_content)
        # Use specialized nutrition correction analyzer for better accuracy
        nutrition_data = Ai::NutritionCorrectionAnalyzer.analyze(new_content, user: entry.user)
        
        if nutrition_data && nutrition_data[:confidence] > 50
          nutrition_entry = entry.nutrition_entry
          
          # Update nutrition data - only update fields that have new values
          update_data = {}
          
          if nutrition_data[:calories].present?
            update_data[:calories] = nutrition_data[:calories]
          end
          
          if nutrition_data[:protein].present?
            update_data[:protein] = nutrition_data[:protein]
          end
          
          if nutrition_data[:fat].present?
            update_data[:fat] = nutrition_data[:fat]
          end
          
          if nutrition_data[:carbs].present?
            update_data[:carbs] = nutrition_data[:carbs]
          end
          
          if nutrition_data[:food_items].present?
            update_data[:food_items] = nutrition_data[:food_items]
          end
          
          # Always update meal description
          update_data[:meal_description] = nutrition_data[:meal_description] || new_content.truncate(200)
          
          if update_data.any?
            nutrition_entry.update!(update_data)
            Rails.logger.info "Updated nutrition fields: #{update_data.keys.join(', ')}"
          end
          
          Rails.logger.info "Recalculated nutrition for entry #{entry.id}: #{nutrition_data}"
        else
          Rails.logger.info "No nutrition data found for content: #{new_content}"
        end
      rescue StandardError => e
        Rails.logger.error "Error recalculating nutrition: #{e.message}"
        # Don't fail the correction if nutrition recalculation fails
      end
    end
  end
end