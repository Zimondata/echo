module Telegram
  class MessageHandler
    attr_reader :user, :message, :chat_id

    def initialize(user, message)
      @user = user
      @message = message
      @chat_id = message.chat.id
    end

    def process
      # Send typing indicator
      BotService.send_typing(chat_id)

      # Handle different message types
      if message.text&.start_with?("/")
        handle_command
      elsif message.location
        handle_location_message
      elsif message.voice
        handle_voice_message
      elsif message.photo
        handle_photo_message
      elsif message.text
        handle_text_message
      else
        send_reply("Извините, я пока поддерживаю только текстовые, голосовые сообщения, фото и геолокацию.")
      end
    end

    private

    def handle_command
      command = message.text.split.first.downcase

      case command
      when "/start"
        handle_start_command
      when "/help"
        handle_help_command
      when "/settings"
        handle_settings_command
      when "/status"
        handle_status_command
      when "/calendar"
        handle_calendar_command
      when "/today"
        handle_today_command
      when "/week"
        handle_week_command
      when "/add_event"
        handle_add_event_command
      when "/insights"
        handle_insights_command
      when "/digest"
        handle_digest_command
      when "/daily"
        handle_daily_summary_command
      when "/stats"
        handle_detailed_stats_command
      when "/plan"
        handle_plan_command
      when "/optimize"
        handle_optimize_command
      when "/suggest"
        handle_suggest_command
      when "/autoplan"
        handle_autoplan_command
      when "/timezone"
        handle_timezone_command
      when "/nutrition"
        handle_nutrition_command
      else
        send_reply("Неизвестная команда. Используй /help для списка команд.")
      end
    end

    def handle_start_command
      welcome_text = <<~TEXT
        Привет, #{user.full_name}! 👋

        Я *Echo* — твой AI-ассистент для управления дневником, идеями и планами.

        Я умею:
        📔 Вести дневник твоих мыслей
        💡 Сохранять идеи и инсайты
        📅 Планировать задачи и события
        🔔 Напоминать о важном
        🍽️ Отслеживать питание и калории

        Просто отправь мне голосовое или текстовое сообщение, и я всё сохраню!

        🕐 *Важно:* Для корректной работы напоминаний настрой свой часовой пояс:
        • Отправь геолокацию 📍 (самый простой способ)
        • Или используй `/timezone Madrid` (для Испании)

        Используй /help для подробной информации.
      TEXT

      send_reply(welcome_text)
    end

    def handle_help_command
      help_text = <<~TEXT
        *Команды:*

        /start — Начать работу
        /help — Показать это сообщение
        /settings — Настройки
        /timezone — Настроить часовой пояс
        /status — Статистика твоих записей
        
        *Календарь:*
        /calendar — Просмотр календаря
        /today — События на сегодня
        /week — События на неделю
        /add_event — Быстрое создание события
        
        *Аналитика и инсайты:*
        /insights — Последние инсайты
        /digest — Недельный дайджест
        /daily — Резюме за сегодня
        /stats — Подробная статистика
        
        *Автоматическое планирование:*
        /plan — Создать план на день/неделю
        /optimize — Оптимизировать расписание
        /suggest — Умные предложения задач
        /autoplan — Полное автопланирование
        
        *Питание:*
        /nutrition — Статистика питания за день

        *Как использовать:*

        1️⃣ *Отправь сообщение* (текст или голос)
        Я автоматически определю, что это: дневник, идея или план.

        2️⃣ *Если это план с датой*, я создам событие в календаре

        3️⃣ *Настрой напоминания*, и я буду присылать уведомления

        *Примеры:*

        💬 "Сегодня был продуктивный день, закончил проект"
        → Сохраню как запись в дневнике

        💬 "У меня идея создать AI-бота для планирования"
        → Сохраню как идею

        💬 "Завтра в 15:00 встреча с клиентом"
        → Создам событие в календаре и напоминание
        
        💬 "Съел овсянку с бананом на завтрак, примерно 300 ккал"
        → Сохраню как запись о питании с подсчётом БЖУ
      TEXT

      send_reply(help_text)
    end

    def handle_settings_command
      settings_text = <<~TEXT
        ⚙️ *Настройки*

        Текущие настройки:
        🌍 Язык: #{user.language}
        🕐 Часовой пояс: #{user.timezone}

        Для изменения настроек напиши мне, что хочешь изменить.
      TEXT

      send_reply(settings_text)
    end

    def handle_status_command
      entries_count = user.entries.active.count
      ideas_count = user.entries.ideas.count
      plans_count = user.entries.plans.count
      reminders_count = user.reminders.pending.count

      status_text = <<~TEXT
        📊 *Твоя статистика*

        📝 Всего записей: #{entries_count}
        💡 Идей: #{ideas_count}
        📅 Планов: #{plans_count}
        🔔 Активных напоминаний: #{reminders_count}

        Продолжай в том же духе! 🚀
      TEXT

      send_reply(status_text)
    end

    def handle_voice_message
      send_reply("🎤 Обрабатываю голосовое сообщение...")

      # Download audio file
      audio_data = BotService.download_file(message.voice.file_id)

      unless audio_data
        send_reply("Не удалось скачать аудио. Попробуй еще раз.")
        return
      end

      # Transcribe with Whisper
      transcript = Ai::WhisperService.transcribe(audio_data)

      unless transcript
        send_reply("Не удалось распознать речь. Попробуй еще раз.")
        return
      end

      # Process transcribed text
      process_content(transcript, audio_file_id: message.voice.file_id)
    end

    def handle_text_message
      process_content(message.text)
    end

    def handle_photo_message
      send_reply("📸 Анализирую фото...")

      # Get the highest resolution photo
      photo = message.photo.last
      photo_data = BotService.download_file(photo.file_id)

      unless photo_data
        send_reply("Не удалось скачать фото. Попробуй еще раз.")
        return
      end

      # First, try to analyze as Garmin screenshot
      garmin_analysis = Ai::GarminAnalyzer.analyze_screenshot(photo_data)
      
      if garmin_analysis[:is_garmin_screenshot] && garmin_analysis[:confidence_score] > 60
        # Process as activity/training data
        process_garmin_screenshot(garmin_analysis, photo.file_id)
        return
      end

      # If not Garmin, analyze as food photo
      food_analysis = Ai::VisionService.analyze_food_photo(photo_data)

      unless food_analysis
        send_reply("Не удалось распознать еду на фото. Попробуй другое фото или опиши еду текстом.")
        return
      end

      # Add caption if provided
      caption_text = message.caption.present? ? " #{message.caption}" : ""
      combined_text = "#{food_analysis[:description]}#{caption_text}"

      # Process as nutrition content
      process_nutrition_photo(combined_text, food_analysis, photo.file_id)
    end

    def process_nutrition_photo(text, vision_analysis, photo_file_id)
      # Create nutrition entry directly from vision analysis
      nutrition_data = {
        calories: vision_analysis[:nutrition][:calories] || 0,
        protein: vision_analysis[:nutrition][:protein] || 0,
        fat: vision_analysis[:nutrition][:fat] || 0,
        carbs: vision_analysis[:nutrition][:carbs] || 0,
        meal_type: vision_analysis[:meal_type] || determine_meal_type_by_time,
        food_items: vision_analysis[:food_items].is_a?(Array) ? vision_analysis[:food_items].join(', ') : vision_analysis[:food_items],
        meal_description: vision_analysis[:description] || text.truncate(200)
      }

      # Create Entry record
      entry = user.entries.create!(
        entry_type: 'nutrition',
        content: text,
        metadata: {
          photo_file_id: photo_file_id,
          vision_analysis: vision_analysis,
          auto_detected: true
        }
      )

      # Create NutritionEntry
      nutrition_entry = user.nutrition_entries.create!(
        entry: entry,
        calories: nutrition_data[:calories],
        protein: nutrition_data[:protein],
        fat: nutrition_data[:fat],
        carbs: nutrition_data[:carbs],
        meal_type: nutrition_data[:meal_type],
        food_items: nutrition_data[:food_items],
        meal_description: nutrition_data[:meal_description],
        recorded_at: Time.current,
        photo_url: photo_file_id, # Store Telegram file_id
        analysis_data: vision_analysis
      )

      # Send enhanced confirmation with confidence
      send_photo_nutrition_confirmation(nutrition_entry, vision_analysis)

      # Update user's last entry context for corrections
      user.update_last_entry_context([entry.id])

    rescue StandardError => e
      Rails.logger.error "Error processing nutrition photo: #{e.message}"
      send_reply("Произошла ошибка при анализе фото. Попробуй еще раз или опиши еду текстом.")
    end

    def send_photo_nutrition_confirmation(nutrition_entry, vision_analysis)
      meal_emoji = case nutrition_entry.meal_type
      when 'breakfast' then '🌅'
      when 'lunch' then '☀️'
      when 'dinner' then '🌙'
      when 'snack' then '🍎'
      else '🍽️'
      end

      confidence_emoji = case vision_analysis[:confidence_score] || 70
      when 90..100 then '🎯'
      when 80..89 then '✅'
      when 70..79 then '👍'
      else '⚠️'
      end

      # Build enhanced reply with cultural context and component breakdown
      confirmation_text = <<~TEXT
        #{meal_emoji} *Распознал еду на фото!*

        #{confidence_emoji} *Уверенность: #{vision_analysis[:confidence_score] || 70}%*

        🍽️ *Что вижу:*
        #{vision_analysis[:description] || nutrition_entry.meal_description}
      TEXT
      
      # Add cultural context if available
      if vision_analysis[:cultural_context].present?
        confirmation_text += "\n🌍 *Кухня:* #{vision_analysis[:cultural_context]}"
      end
      
      # Add component breakdown if available
      if vision_analysis[:components]&.any?
        confirmation_text += "\n\n📋 *Анализ по компонентам:*"
        vision_analysis[:components].each do |component|
          weight = component[:estimated_weight] || component["estimated_weight"]
          name = component[:name] || component["name"]
          calories = component[:calories] || component["calories"]
          confirmation_text += "\n• #{name} (#{weight}): #{calories} ккал"
        end
      end
      
      # Add total nutrition
      confirmation_text += <<~TEXT


        📊 *Общая пищевая ценность:*
        • Калории: #{nutrition_entry.calories.to_i} ккал
        • Белки: #{nutrition_entry.protein.to_f.round(1)} г
        • Жиры: #{nutrition_entry.fat.to_f.round(1)} г  
        • Углеводы: #{nutrition_entry.carbs.to_f.round(1)} г
      TEXT
      
      # Add total weight if available
      if vision_analysis[:portion_analysis]&.[](:total_weight)
        confirmation_text += "\n⚖️ *Общий вес:* #{vision_analysis[:portion_analysis][:total_weight]}"
      end
      
      # Add food items
      if nutrition_entry.food_items.present?
        confirmation_text += "\n\n🥘 *Продукты:* #{nutrition_entry.food_items}"
      end
      
      # Add preparation notes if available
      if vision_analysis[:preparation_notes].present?
        confirmation_text += "\n\n👨‍🍳 *Особенности:* #{vision_analysis[:preparation_notes]}"
      end
      
      confirmation_text += "\n\n💡 Если данные неточные, исправь через /nutrition или добавь текстом"

      send_reply(confirmation_text)
    end

    def process_content(text, audio_file_id: nil)
      # First, check if this might be a correction to recent entries
      if user.can_correct_recent_entries?
        recent_entries = user.get_recent_entries_for_correction
        
        if recent_entries.any?
          correction_result = Ai::CorrectionDetector.analyze(text, recent_entries, user: user)
          
          if correction_result[:is_correction]
            correction_response = Ai::CorrectionApplier.apply(correction_result, user)
            
            if correction_response
              send_correction_confirmation(correction_response)
              return
            else
              Rails.logger.error "Failed to apply correction: #{correction_result}"
              # Fall through to normal processing
            end
          end
        end
      end

      # Use multi-plan analyzer to extract multiple plans from one message
      analyses = Ai::MultiPlanAnalyzer.analyze(text, user: user)
      
      # Check if any analysis is a command - if so, handle it and don't save
      if analyses.any? { |a| a[:type] == 'command' }
        handle_user_command(text)
        return
      end
      
      Rails.logger.info "PROCESS_CONTENT: Received #{analyses.count} analyses from MultiPlanAnalyzer"
      analyses.each_with_index do |a, i|
        Rails.logger.info "  Analysis #{i+1}: create_calendar_event=#{a[:create_calendar_event]}, event_title='#{a[:event_title]}'"
      end
      
      # Track created events to avoid duplicates within same message
      created_events_titles = []
      created_entries = []
      
      # Check if we should group related ideas
      should_group_ideas = analyses.count > 1 && 
                          analyses.all? { |a| a[:type] == 'idea' } &&
                          audio_file_id.present?
      
      parent_entry = nil
      group_id = should_group_ideas ? SecureRandom.uuid : nil
      
      analyses.each_with_index do |analysis, index|
        current_entry = nil
        
        # For grouped ideas, create first as parent, rest as children
        if should_group_ideas && index == 0
          # Create main parent entry with combined content
          combined_content = "#{analysis[:content] || analysis[:summary]}\n\nСвязанные размышления:\n" + 
                            analyses[1..-1].map { |a| "• #{a[:content] || a[:summary]}" }.join("\n")
          
          parent_entry = user.entries.create!(
            entry_type: analysis[:type],
            content: combined_content,
            transcript: text,
            audio_file_id: audio_file_id,
            priority: analysis[:priority] || 0,
            group_id: group_id,
            metadata: {
              multi_plan_source: true,
              plan_index: 1,
              total_plans: analyses.count,
              is_grouped_idea: true,
              grouped_content_count: analyses.count
            }.merge(analysis[:metadata] || {})
          )
          
          current_entry = parent_entry
          created_entries << parent_entry
          
        elsif should_group_ideas && index > 0
          # Create child entries for additional ideas
          child_entry = user.entries.create!(
            entry_type: analysis[:type],
            content: analysis[:content] || analysis[:summary] || text,
            transcript: text,
            audio_file_id: audio_file_id,
            priority: analysis[:priority] || 0,
            group_id: group_id,
            parent_entry: parent_entry,
            metadata: {
              multi_plan_source: true,
              plan_index: index + 1,
              total_plans: analyses.count,
              is_grouped_idea_child: true
            }.merge(analysis[:metadata] || {})
          )
          
          current_entry = child_entry
          created_entries << child_entry
          
        else
          # Create regular standalone entry
          entry = user.entries.create!(
            entry_type: analysis[:type],
            content: analysis[:content] || analysis[:summary] || text,
            transcript: text,
            audio_file_id: audio_file_id,
            priority: analysis[:priority] || 0,
            metadata: {
              multi_plan_source: analyses.count > 1,
              plan_index: index + 1,
              total_plans: analyses.count,
              create_calendar_event: analysis[:create_calendar_event],
              event_title: analysis[:event_title],
              event_time: analysis[:event_time]&.iso8601
            }.merge(analysis[:metadata] || {})
          )
          
          current_entry = entry
          created_entries << entry
        end

        # Handle calendar events with proper deduplication
        Rails.logger.info "DEBUG: Checking calendar event creation for entry #{index + 1}"
        Rails.logger.info "  entry_type: #{analysis[:type]}"
        Rails.logger.info "  create_calendar_event: #{analysis[:create_calendar_event]}"
        Rails.logger.info "  event_title: #{analysis[:event_title]}"
        Rails.logger.info "  event_time: #{analysis[:event_time]}"
        
        # Create calendar event for plans (even without explicit create_calendar_event flag)
        should_create_event = (analysis[:type] == 'plan' && analysis[:event_title].present?) || 
                             (analysis[:create_calendar_event] && analysis[:event_title].present?)
        
        if should_create_event
          # Check if we already created this event in this batch
          normalized_title = analysis[:event_title].strip.downcase
          
          Rails.logger.info "  normalized_title: #{normalized_title}"
          Rails.logger.info "  already created: #{created_events_titles}"
          
          if created_events_titles.include?(normalized_title)
            Rails.logger.info "Skipping duplicate event in same batch: #{analysis[:event_title]}"
          elsif should_update_existing_event?(analysis)
            Rails.logger.info "Event already exists, handling as update: #{analysis[:event_title]}"
            handle_plan_update(current_entry, analysis)
          else
            Rails.logger.info "Creating new calendar event: #{analysis[:event_title]}"
            # Create new calendar event
            create_calendar_event(current_entry, analysis)
            created_events_titles << normalized_title
          end
        else
          Rails.logger.info "  Skipping calendar creation - not a plan or missing title"
        end

        # Create reminder if needed
        if analysis[:create_reminder] && analysis[:reminder_time]
          create_reminder(current_entry, analysis)
        end

        # Create nutrition entry if needed
        if analysis[:type] == 'nutrition' && analysis[:nutrition]
          create_nutrition_entry(current_entry, analysis)
        end
      end

      # Send comprehensive confirmation
      send_multi_entry_confirmation(created_entries, analyses, text)

      # Update user's last entry context for corrections
      if created_entries.any?
        user.update_last_entry_context(created_entries.map(&:id))
      end

    rescue StandardError => e
      Rails.logger.error "Error processing content: #{e.message}"
      send_reply("Произошла ошибка при обработке. Попробуй еще раз.")
    end

    def send_entry_confirmation(entry, analysis)
      type_emoji = case entry.entry_type
      when "diary" then "📔"
      when "idea" then "💡"
      when "plan" then "📅"
      else "📝"
      end

      confirmation_text = <<~TEXT
        #{type_emoji} *Записал!*

        *Тип:* #{entry_type_name(entry.entry_type)}
        *Дата:* #{entry.occurred_at.in_time_zone(user.timezone).strftime('%d %B %Y, %H:%M')}

        *Резюме:*
        #{entry.content}
      TEXT

      # Create inline keyboard for fixing classification
      keyboard = []
      
      # Add buttons for other types (excluding current type)
      if entry.entry_type != 'idea'
        keyboard << [{ text: "💡 Это идея", callback_data: "fix_type_#{entry.id}_idea" }]
      end
      
      if entry.entry_type != 'plan'
        keyboard << [{ text: "📅 Это план", callback_data: "fix_type_#{entry.id}_plan" }]
      end
      
      if entry.entry_type != 'diary'
        keyboard << [{ text: "📔 Это дневник", callback_data: "fix_type_#{entry.id}_diary" }]
      end

      # Only add correction buttons if there are alternatives
      if keyboard.any?
        keyboard << [{ text: "✅ Все правильно", callback_data: "fix_ok_#{entry.id}" }]
        
        send_reply_with_keyboard(confirmation_text, keyboard)
      else
        send_reply(confirmation_text)
      end
    end

    def send_multi_entry_confirmation(entries, analyses, original_text)
      if entries.count == 1
        # Single entry - use standard confirmation
        send_entry_confirmation(entries.first, analyses.first)
        return
      end

      # Multiple entries - send comprehensive confirmation
      confirmation_text = <<~TEXT
        🎯 *Отлично! Обработал твое сообщение*

        Из твоего сообщения я извлек *#{entries.count} записей*:
      TEXT

      entries.each_with_index do |entry, index|
        type_emoji = case entry.entry_type
        when "diary" then "📔"
        when "idea" then "💡" 
        when "plan" then "📅"
        else "📝"
        end

        confirmation_text += "\n#{index + 1}. #{type_emoji} *#{entry_type_name(entry.entry_type)}*\n"
        confirmation_text += "   └ #{entry.content.truncate(100)}\n"
        
        # Add timing info if it's a plan with time
        if entry.entry_type == 'plan' && entry.calendar_event
          if entry.calendar_event.all_day?
            event_date = entry.calendar_event.start_time.in_time_zone(user.timezone).strftime('%d.%m')
            confirmation_text += "   📅 #{event_date} (план без времени)\n"
          else
            event_time = entry.calendar_event.start_time.in_time_zone(user.timezone).strftime('%d.%m в %H:%M')
            confirmation_text += "   📅 #{event_time}\n"
          end
        end
      end

      confirmation_text += "\n💡 *Статистика:*\n"
      
      type_counts = entries.group_by(&:entry_type).transform_values(&:count)
      type_counts.each do |type, count|
        type_emoji = case type
        when "diary" then "📔"
        when "idea" then "💡"
        when "plan" then "📅"
        else "📝"
        end
        confirmation_text += "#{type_emoji} #{entry_type_name(type)}: #{count}\n"
      end

      calendar_events_count = entries.count { |e| e.calendar_event.present? }
      if calendar_events_count > 0
        confirmation_text += "\n📅 Создано событий в календаре: #{calendar_events_count}"
      end

      reminders_count = entries.sum { |e| e.reminders.count }
      if reminders_count > 0
        confirmation_text += "\n🔔 Создано напоминаний: #{reminders_count}"
      end

      send_reply(confirmation_text)
    end

    def entry_type_name(type)
      {
        "diary" => "Дневник",
        "idea" => "Идея",
        "plan" => "План",
        "plan_update" => "Обновление плана",
        "nutrition" => "Питание"
      }[type] || type
    end

    def create_calendar_event(entry, analysis)
      # Проверяем metadata для all_day события  
      is_all_day = analysis[:metadata]&.dig(:all_day) || analysis[:metadata]&.dig("all_day") || false
      Rails.logger.info "Creating event with all_day: #{is_all_day}, event_time: #{analysis[:event_time]}" # Debug
      
      # Определяем время события
      if analysis[:event_time]
        # Если есть event_time, используем его
        start_time = analysis[:event_time]
        end_time = analysis[:event_end_time]
        # Если время 00:00 и есть флаг all_day, это план без конкретного времени
        if is_all_day && start_time.hour == 0 && start_time.min == 0
          is_all_day = true
        end
      elsif is_all_day || analysis[:type] == 'plan'
        # Для планов без указанного времени используем сегодня в часовом поясе пользователя
        user_today = Time.current.in_time_zone(user.timezone).beginning_of_day
        start_time = user_today
        end_time = user_today.end_of_day
        is_all_day = true
      else
        # Fallback на сегодня
        start_time = Time.current
        end_time = nil
      end
      
      event = user.calendar_events.create!(
        entry: entry,
        title: analysis[:event_title] || entry.content.truncate(100),
        description: entry.content,
        start_time: start_time,
        end_time: end_time,
        event_type: "plan",
        all_day: is_all_day
      )

      if is_all_day
        formatted_date = event.start_time.in_time_zone(user.timezone).strftime('%d.%m')
        send_reply("📅 Добавил план в календарь на #{formatted_date}: #{event.title}")
      else
        send_reply("📅 Создал событие в календаре на #{event.start_time.in_time_zone(user.timezone).strftime('%d.%m в %H:%M')}: #{event.title}")
      end
    rescue StandardError => e
      Rails.logger.error "Error creating calendar event: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end

    def create_reminder(entry, analysis)
      # Check if it's a recurring reminder request
      if analysis[:recurring_pattern]
        create_recurring_reminder(entry, analysis)
      else
        reminder = user.reminders.create!(
          entry: entry,
          reminder_type: "one_time",
          remind_at: analysis[:reminder_time],
          message: analysis[:reminder_message] || entry.content.truncate(200)
        )

        send_reply("🔔 Напомню тебе #{reminder.remind_at.in_time_zone(user.timezone).strftime('%d.%m в %H:%M')}")
      end
    rescue StandardError => e
      Rails.logger.error "Error creating reminder: #{e.message}"
    end

    def create_nutrition_entry(entry, analysis)
      nutrition_data = analysis[:nutrition]
      return unless nutrition_data

      # Determine meal type based on time if not provided
      meal_type = nutrition_data[:meal_type] || determine_meal_type_by_time

      nutrition_entry = user.nutrition_entries.create!(
        entry: entry,
        calories: nutrition_data[:calories] || 0,
        protein: nutrition_data[:protein] || 0,
        fat: nutrition_data[:fat] || 0,
        carbs: nutrition_data[:carbs] || 0,
        meal_type: meal_type,
        food_items: nutrition_data[:food_items],
        meal_description: nutrition_data[:meal_description] || entry.content.truncate(200),
        recorded_at: Time.current,
        analysis_data: analysis.except(:nutrition)
      )

      # Send nutrition confirmation
      send_nutrition_confirmation(nutrition_entry)

    rescue StandardError => e
      Rails.logger.error "Error creating nutrition entry: #{e.message}"
    end

    def determine_meal_type_by_time
      hour = Time.current.in_time_zone(user.timezone).hour
      
      case hour
      when 5..10
        'breakfast'
      when 11..15
        'lunch'
      when 16..18
        'snack'
      when 19..23
        'dinner'
      else
        'snack'
      end
    end

    def send_nutrition_confirmation(nutrition_entry)
      meal_emoji = case nutrition_entry.meal_type
      when 'breakfast' then '🌅'
      when 'lunch' then '☀️'
      when 'dinner' then '🌙'
      when 'snack' then '🍎'
      else '🍽️'
      end

      confirmation_text = <<~TEXT
        #{meal_emoji} *Записал приём пищи!*

        *#{nutrition_entry.meal_type_display}* в #{nutrition_entry.recorded_at.in_time_zone(user.timezone).strftime('%H:%M')}

        🍽️ *Пищевая ценность:*
        • Калории: #{nutrition_entry.calories.to_i} ккал
        • Белки: #{nutrition_entry.protein.to_f.round(1)} г
        • Жиры: #{nutrition_entry.fat.to_f.round(1)} г  
        • Углеводы: #{nutrition_entry.carbs.to_f.round(1)} г

        #{nutrition_entry.food_items.present? ? "🥘 *Продукты:* #{nutrition_entry.food_items}" : ""}

        💡 Посмотреть статистику питания: /nutrition
      TEXT

      send_reply(confirmation_text)
    end

    def should_update_existing_event?(analysis)
      return false unless analysis[:create_calendar_event] && analysis[:event_title]
      
      # Check for exact title match AND same date
      normalized_title = analysis[:event_title].strip.downcase
      
      # Determine the event date
      event_date = if analysis[:event_time]
        analysis[:event_time].to_date
      elsif analysis[:metadata]&.dig(:all_day)
        # For all-day events, check today and tomorrow
        Date.current
      else
        Date.current
      end
      
      # Check for similar events on the same day
      similar_events = user.calendar_events
                          .where('DATE(start_time) = ?', event_date)
                          .where('LOWER(title) = LOWER(?)', analysis[:event_title].strip)
      
      similar_events.any?
    end

    def handle_plan_update(entry, analysis)
      Rails.logger.info "DEBUG: handle_plan_update STARTED for entry: #{entry.content}"
      Rails.logger.info "DEBUG: analysis keys: #{analysis.keys}"
      Rails.logger.info "DEBUG: event_title=#{analysis[:event_title]}, create_calendar_event=#{analysis[:create_calendar_event]}"
      
      return unless analysis[:event_title] && analysis[:create_calendar_event]
      Rails.logger.info "DEBUG: Passed initial checks, proceeding with plan update"
      
      # Найти недавние события ТОЧНО похожие по названию в последние 24 часа
      search_title = analysis[:event_title].strip
      recent_events = user.calendar_events
                         .where('created_at >= ?', 24.hours.ago)
                         .where('LOWER(title) = LOWER(?)', search_title)
                         .order(created_at: :desc)
                         .limit(3)
      
      if recent_events.any?
        # Обновляем самое недавнее похожее событие
        event_to_update = recent_events.first
        
        # Если это исправление времени
        if analysis[:event_time] && !event_to_update.all_day? && analysis[:metadata]&.dig(:correction)
          old_time = event_to_update.start_time.in_time_zone(user.timezone).strftime('%H:%M')
          corrected_time = analysis[:metadata][:corrected_time] || analysis[:event_time].in_time_zone(user.timezone).strftime('%H:%M')
          
          event_to_update.update!(
            start_time: analysis[:event_time],
            end_time: analysis[:event_end_time]
          )
          
          send_reply("✏️ Исправил время с #{old_time} на #{corrected_time}: #{event_to_update.title}")
        else
          # Если это дубль - просто не создаем новое событие
          send_reply("📋 Событие \"#{search_title}\" уже существует")
        end
      else
        # Если похожих событий нет, создаем новое
        Rails.logger.info "DEBUG: No similar events found for '#{search_title}', creating new event"
        Rails.logger.info "DEBUG: create_calendar_event=#{analysis[:create_calendar_event]}, event_time=#{analysis[:event_time]}"
        if analysis[:create_calendar_event]
          create_calendar_event(entry, analysis)
          Rails.logger.info "DEBUG: Calendar event created successfully"
          
          # Отправляем сообщение о создании нового события вместо обновления
          if analysis[:event_time]
            time_str = analysis[:event_time].in_time_zone(user.timezone).strftime('%H:%M')
            date_str = analysis[:event_time].in_time_zone(user.timezone).strftime('%d.%m')
            send_reply("📅 Создал новое событие: #{search_title} на #{date_str} в #{time_str}")
          else
            date_str = analysis[:event_date] ? Date.parse(analysis[:event_date]).strftime('%d.%m') : 'завтра'
            send_reply("📅 Создал новое событие: #{search_title} на #{date_str}")
          end
        else
          Rails.logger.info "DEBUG: Calendar event NOT created - missing conditions"
          send_reply("⚠️ Не смог обновить план \"#{search_title}\" - событие не найдено. Попробуйте создать новый план.")
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error handling plan update: #{e.message}"
    end

    def create_recurring_reminder(entry, analysis)
      pattern = analysis[:recurring_pattern]
      
      # Parse recurring pattern like "каждые 3 часа до 22:00"
      interval_hours = pattern[:interval_hours] || 3
      end_time = pattern[:end_time] || "22:00"
      start_time = analysis[:reminder_time] || Time.current + 1.hour
      
      # Create first reminder
      reminder = user.reminders.create!(
        entry: entry,
        reminder_type: "recurring",
        remind_at: start_time,
        message: analysis[:reminder_message] || entry.content.truncate(200),
        metadata: {
          interval_hours: interval_hours,
          end_time: end_time,
          created_from: "telegram_message"
        }
      )

      send_reply(<<~TEXT)
        🔔 *Создал повторяющееся напоминание!*
        
        ⏰ Первое: #{reminder.remind_at.in_time_zone(user.timezone).strftime('%d.%m в %H:%M')}
        🔄 Интервал: каждые #{interval_hours} ч.
        🛑 До: #{end_time}
        
        💡 Напоминания будут приходить автоматически до указанного времени каждый день
      TEXT
    rescue StandardError => e
      Rails.logger.error "Error creating recurring reminder: #{e.message}"
      send_reply("Ошибка создания повторяющегося напоминания: #{e.message}")
    end

    def handle_calendar_command
      events = user.calendar_events.for_week.active.order(:start_time)
      
      if events.empty?
        send_reply("📅 У тебя нет событий на эту неделю. Создай новое событие командой /add_event")
        return
      end

      calendar_text = "📅 *Календарь на неделю*\n\n"
      
      events.group_by(&:start_date).each do |date, day_events|
        calendar_text += "*#{date.strftime('%d %B %Y')}*\n"
        
        day_events.each do |event|
          status_emoji = event.done? ? "✅" : "⏰"
          time_str = event.all_day? ? "весь день" : event.start_time.in_time_zone(user.timezone).strftime("%H:%M")
          
          calendar_text += "#{status_emoji} #{time_str} - #{event.title}\n"
        end
        
        calendar_text += "\n"
      end

      send_reply(calendar_text)
    end

    def handle_today_command
      today = Date.current
      events = user.calendar_events.for_date_range(today.beginning_of_day, today.end_of_day).active.order(:start_time)
      
      if events.empty?
        send_reply("📅 На сегодня событий нет. Отличный день для отдыха! 😊")
        return
      end

      today_text = "📅 *События на сегодня (#{today.strftime('%d %B %Y')})*\n\n"
      
      events.each do |event|
        status_emoji = event.done? ? "✅" : "⏰"
        time_str = event.all_day? ? "весь день" : event.start_time.in_time_zone(user.timezone).strftime("%H:%M")
        priority_emoji = case event.priority
        when 'urgent' then '🔴'
        when 'high' then '🟡'
        when 'medium' then '🟢'
        else '⚪'
        end
        
        today_text += "#{status_emoji} #{priority_emoji} #{time_str} - #{event.title}\n"
        today_text += "   #{event.description}\n\n" if event.description.present?
      end

      send_reply(today_text)
    end

    def handle_week_command
      handle_calendar_command
    end

    def handle_add_event_command
      send_reply(<<~TEXT)
        📅 *Быстрое создание события*
        
        Отправь мне сообщение в формате:
        
        *Заголовок события*
        Дата и время
        Описание (опционально)
        
        *Примеры:*
        
        💬 "Встреча с клиентом завтра в 15:00"
        💬 "Поездка к родителям в субботу весь день"
        💬 "Звонок врачу 25 октября в 10:30"
        
        Или просто отправь описание события с датой/временем, и я сам создам событие! ✨
      TEXT
    end

    def handle_insights_command
      recent_insights = user.insights.active.recent.limit(3)
      
      if recent_insights.empty?
        send_reply("🧠 У тебя пока нет инсайтов. Продолжай добавлять записи, и я создам для тебя полезные аналитические отчеты!")
        return
      end

      insights_text = "🧠 *Последние инсайты*\n\n"
      
      recent_insights.each do |insight|
        icon = case insight.insight_type
        when 'daily_summary' then '📊'
        when 'weekly_digest' then '📈'
        when 'trend_analysis' then '📉'
        when 'productivity_insight' then '⚡'
        else '💡'
        end
        
        insights_text += "#{icon} *#{insight.title}*\n"
        insights_text += "#{insight.content.truncate(150)}\n"
        insights_text += "_#{insight.generated_at.in_time_zone(user.timezone).strftime('%d.%m в %H:%M')}_\n\n"
      end
      
      insights_text += "💡 Хочешь получить свежий анализ? Используй /digest или /daily"

      send_reply(insights_text)
    end

    def handle_digest_command
      send_reply("📈 Генерирую недельный дайджест... Это займет немного времени.")
      
      # Запускаем генерацию недельного дайджеста
      GenerateInsightJob.perform_later(user.id, 'weekly_digest')
      
      send_reply(<<~TEXT)
        ✨ Твой недельный дайджест будет готов через несколько минут!
        
        В нем ты увидишь:
        📊 Статистику активности за неделю
        🎯 Твои главные достижения  
        💡 Инсайты и паттерны поведения
        🚀 Цели на следующую неделю
        
        Используй /insights чтобы посмотреть результат.
      TEXT
    end

    def handle_daily_summary_command
      send_reply("📊 Анализирую твой день...")
      
      # Запускаем генерацию дневного резюме
      GenerateInsightJob.perform_later(user.id, 'daily_summary', { date: Date.current })
      
      send_reply(<<~TEXT)
        🌟 Создаю резюме твоего дня!
        
        Скоро увидишь:
        📝 Краткий обзор всех записей
        🎯 Ключевые моменты дня
        😊 Анализ настроения
        🏷 Главные темы и идеи
        
        Проверь /insights через минутку!
      TEXT
    end

    def handle_detailed_stats_command
      stats = Analytics::UserStatsCollector.weekly_stats(user)
      
      stats_text = <<~TEXT
        📊 *Подробная статистика*
        
        *За эту неделю:*
        📝 Записей: #{stats[:total_entries]}
        ⚡ Продуктивность: #{stats[:productivity_score]}%
        ✅ Выполнено событий: #{stats[:completion_rate]}%
        
        *Динамика роста:*
        📈 Рост записей: #{stats.dig(:growth_metrics, :entries_growth) || 0}%
        🎯 Консистентность: #{stats.dig(:growth_metrics, :consistency_score) || 0}%
        
        *Настроение:*
        😊 Общий балл: #{stats.dig(:mood_trends, :mood_score) || 50}/100
        ➕ Позитивные индикаторы: #{stats.dig(:mood_trends, :positive_indicators) || 0}
        ➖ Негативные индикаторы: #{stats.dig(:mood_trends, :negative_indicators) || 0}
        
        *Топ категории:*
      TEXT
      
      if stats[:top_categories] && !stats[:top_categories].empty?
        stats[:top_categories].each do |category, count|
          stats_text += "• #{category}: #{count}\n"
        end
      else
        stats_text += "• Пока недостаточно данных\n"
      end
      
      stats_text += "\n💡 Используй /digest для получения персональных рекомендаций!"

      send_reply(stats_text)
    rescue StandardError => e
      Rails.logger.error "Error generating detailed stats: #{e.message}"
      send_reply("Произошла ошибка при генерации статистики. Попробуй позже.")
    end

    def handle_plan_command
      command_parts = message.text.split
      plan_type = command_parts[1] || 'daily' # daily или weekly
      
      case plan_type.downcase
      when 'weekly', 'неделя', 'неделю'
        handle_weekly_plan_command
      else
        handle_daily_plan_command
      end
    end

    def handle_daily_plan_command
      send_reply("🧠 Создаю умный план на сегодня...")
      
      begin
        plan_data = Ai::AutoPlanner.generate_daily_plan(
          user: user,
          options: { include_context: true }
        )
        
        if plan_data[:scheduled_tasks].empty?
          send_reply(<<~TEXT)
            📋 *План на сегодня*
            
            У тебя пока нет активных задач для планирования.
            
            💡 *Что можно сделать:*
            • Добавь идеи или планы через обычные сообщения
            • Используй /suggest для получения предложений
            • Попробуй /autoplan для полного планирования
          TEXT
          return
        end
        
        plan_text = format_daily_plan(plan_data)
        send_reply(plan_text)
        
        # Если есть рекомендации, отправляем их отдельно
        if plan_data[:recommendations]&.any?
          recs_text = format_recommendations(plan_data[:recommendations])
          send_reply(recs_text)
        end
        
      rescue StandardError => e
        Rails.logger.error "Error generating daily plan: #{e.message}"
        send_reply("Произошла ошибка при создании плана. Попробуй позже или добавь задачи вручную.")
      end
    end

    def handle_weekly_plan_command
      send_reply("📅 Создаю план на неделю... Это может занять немного времени.")
      
      begin
        plan_data = Ai::AutoPlanner.generate_weekly_plan(
          user: user,
          options: { detailed_analysis: true }
        )
        
        if plan_data[:daily_plans].empty?
          send_reply("📋 Недостаточно данных для создания недельного плана. Попробуй сначала /plan для дневного планирования.")
          return
        end
        
        weekly_text = format_weekly_plan(plan_data)
        send_reply(weekly_text)
        
      rescue StandardError => e
        Rails.logger.error "Error generating weekly plan: #{e.message}"
        send_reply("Произошла ошибка при создании недельного плана. Попробуй позже.")
      end
    end

    def handle_optimize_command
      send_reply("⚡ Оптимизирую твое расписание...")
      
      begin
        # Получаем текущие незавершенные задачи
        pending_plans = user.entries.plans
                           .where(dashboard_status: ['new', 'triaged'])
                           .recent
                           .limit(10)
        
        if pending_plans.empty?
          send_reply(<<~TEXT)
            🤔 Нет задач для оптимизации!
            
            💡 *Что можно сделать:*
            • Добавь планы через сообщения
            • Используй /autoplan для создания задач из идей
            • Попробуй /suggest для получения предложений
          TEXT
          return
        end
        
        # Конвертируем в формат для оптимизатора
        tasks_for_optimization = pending_plans.map do |entry|
          {
            id: entry.id,
            title: entry.content.truncate(50),
            estimated_time: 60, # Default 1 hour
            priority: entry.priority > 0 ? 'high' : 'medium',
            category: entry.category || 'work'
          }
        end
        
        optimization_result = Ai::ScheduleOptimizer.call(
          user: user,
          tasks: tasks_for_optimization
        )
        
        optimization_text = format_optimization_result(optimization_result)
        send_reply(optimization_text)
        
      rescue StandardError => e
        Rails.logger.error "Error optimizing schedule: #{e.message}"
        send_reply("Произошла ошибка при оптимизации. Попробуй позже.")
      end
    end

    def handle_suggest_command
      send_reply("💡 Анализирую контекст и генерирую предложения...")
      
      begin
        suggestions = Ai::AutoPlanner.suggest_next_actions(
          user: user,
          options: { include_context: true }
        )
        
        suggestions_text = format_suggestions(suggestions)
        send_reply(suggestions_text)
        
      rescue StandardError => e
        Rails.logger.error "Error generating suggestions: #{e.message}"
        send_reply("Произошла ошибка при генерации предложений. Попробуй позже.")
      end
    end

    def handle_autoplan_command
      send_reply("🤖 Запускаю полное автоматическое планирование...")
      
      begin
        # Анализируем идеи и создаем из них планы
        recent_ideas = user.entries.ideas
                          .where(dashboard_status: ['new', 'triaged'])
                          .where(created_at: 7.days.ago..Time.current)
                          .recent
                          .limit(5)
        
        created_plans = 0
        
        recent_ideas.each do |idea|
          plan_data = Ai::PlanGenerator.call(
            user: user,
            idea_content: idea.content,
            context: "Автоматическое планирование"
          )
          
          # Создаем записи для каждой задачи из плана
          plan_data[:tasks].each do |task|
            user.entries.create!(
              entry_type: 'plan',
              content: "#{task[:title]}: #{task[:description]}",
              category: task[:category] || 'projects',
              priority: task[:priority] == 'high' ? 10 : (task[:priority] == 'medium' ? 5 : 1),
              dashboard_status: 'new',
              metadata: {
                estimated_time: task[:estimated_time],
                source: 'ai_generated',
                source_idea_id: idea.id,
                auto_generated: true
              }
            )
            created_plans += 1
          end
          
          # Помечаем идею как обработанную
          idea.update!(dashboard_status: 'processed')
        end
        
        if created_plans > 0
          send_reply(<<~TEXT)
            ✨ *Автопланирование завершено!*
            
            📋 Создано #{created_plans} новых задач из ваших идей
            🧠 AI проанализировал #{recent_ideas.count} идей
            
            💡 *Что дальше:*
            • Используй /plan для создания расписания
            • Попробуй /optimize для оптимизации времени
            • Команда /today покажет события на сегодня
            
            Все новые задачи появятся в твоем планировщике!
          TEXT
          
          # Автоматически создаем дневной план
          handle_daily_plan_command
        else
          send_reply(<<~TEXT)
            🤔 *Автопланирование завершено*
            
            К сожалению, не нашел подходящих идей для превращения в планы.
            
            💡 *Рекомендации:*
            • Добавь больше идей через голосовые или текстовые сообщения
            • Попробуй /suggest для получения предложений
            • Используй /plan для работы с существующими задачами
          TEXT
        end
        
      rescue StandardError => e
        Rails.logger.error "Error in autoplan: #{e.message}"
        send_reply("Произошла ошибка при автоматическом планировании. Попробуй позже.")
      end
    end

    def handle_nutrition_command
      today = Date.current
      daily_totals = NutritionEntry.daily_totals(user, today)
      recent_entries = user.nutrition_entries.active.for_date(today).recent.limit(5)

      if recent_entries.empty?
        send_reply(<<~TEXT)
          🍽️ *Питание за сегодня*
          
          📊 Пока нет записей о питании на сегодня.
          
          💡 *Как добавить:*
          • Отправь фото еды 📸
          • Опиши что ел: "Съел овсянку с бананом"
          • Укажи калории: "Обед 450 ккал"
          
          Я автоматически подсчитаю БЖУ!
        TEXT
        return
      end

      nutrition_text = <<~TEXT
        🍽️ *Питание за #{today.strftime('%d %B')}*

        📊 *Итого за день:*
        • Калории: #{daily_totals[:calories].to_i} ккал
        • Белки: #{daily_totals[:protein].to_f.round(1)} г
        • Жиры: #{daily_totals[:fat].to_f.round(1)} г
        • Углеводы: #{daily_totals[:carbs].to_f.round(1)} г
        • Приёмов пищи: #{daily_totals[:meals_count]}

        🥘 *Последние приёмы:*
      TEXT

      recent_entries.each do |entry|
        meal_emoji = case entry.meal_type
        when 'breakfast' then '🌅'
        when 'lunch' then '☀️'
        when 'dinner' then '🌙'
        when 'snack' then '🍎'
        else '🍽️'
        end

        time_str = entry.recorded_at.in_time_zone(user.timezone).strftime('%H:%M')
        nutrition_text += "\n#{meal_emoji} #{time_str} - #{entry.meal_type_display}\n"
        nutrition_text += "   └ #{entry.calories.to_i} ккал"
        
        if entry.food_items.present?
          food_preview = entry.food_items_list.first(2).join(', ')
          nutrition_text += " • #{food_preview}"
          if entry.food_items_list.count > 2
            nutrition_text += " и др."
          end
        end
        nutrition_text += "\n"
      end

      # Calculate macro percentages
      total_macros = daily_totals[:protein] + daily_totals[:fat] + daily_totals[:carbs]
      if total_macros > 0
        protein_pct = ((daily_totals[:protein] / total_macros) * 100).round(1)
        fat_pct = ((daily_totals[:fat] / total_macros) * 100).round(1)
        carbs_pct = ((daily_totals[:carbs] / total_macros) * 100).round(1)
        
        nutrition_text += <<~TEXT

          📈 *Соотношение БЖУ:*
          🔵 Белки: #{protein_pct}%
          🟠 Жиры: #{fat_pct}%
          🟣 Углеводы: #{carbs_pct}%

          💡 Открыть полную статистику: #{ENV['APP_URL'] || 'echo.app'}/nutrition
        TEXT
      end

      send_reply(nutrition_text)

    rescue StandardError => e
      Rails.logger.error "Error handling nutrition command: #{e.message}"
      send_reply("Произошла ошибка при получении данных о питании. Попробуй позже.")
    end

    private

    def send_correction_confirmation(correction_response)
      entry = correction_response[:updated_entry]
      success_message = correction_response[:success_message]
      correction_type = correction_response[:correction_type]
      
      confirmation_text = "✏️ *Исправление применено!*\n\n#{success_message}"
      
      # Add updated data based on correction type
      case correction_type
      when "nutrition_correction"
        if entry.nutrition_entry
          nutrition = entry.nutrition_entry
          confirmation_text += <<~TEXT
            
            
            📊 *Обновленная пищевая ценность:*
            • Калории: #{nutrition.calories.to_i} ккал
            • Белки: #{nutrition.protein.to_f.round(1)} г
            • Жиры: #{nutrition.fat.to_f.round(1)} г  
            • Углеводы: #{nutrition.carbs.to_f.round(1)} г
            
            #{nutrition.food_items.present? ? "🥘 *Продукты:* #{nutrition.food_items}" : ""}
          TEXT
        end
        
      when "time_correction"
        if entry.calendar_event
          event_time = entry.calendar_event.start_time.in_time_zone(user.timezone)
          if entry.calendar_event.all_day?
            confirmation_text += "\n\n📅 *Обновленное время:* #{event_time.strftime('%d.%m')} (весь день)"
          else
            confirmation_text += "\n\n📅 *Обновленное время:* #{event_time.strftime('%d.%m в %H:%M')}"
          end
        end
        
      when "content_correction"
        confirmation_text += "\n\n📝 *Обновленное содержание:*\n#{entry.content}"
        
        # If it's a nutrition entry, also show updated nutrition data
        if entry.nutrition_entry
          nutrition = entry.nutrition_entry
          confirmation_text += <<~TEXT
            
            
            📊 *Пищевая ценность:*
            • Калории: #{nutrition.calories.to_i} ккал
            • Белки: #{nutrition.protein.to_f.round(1)} г
            • Жиры: #{nutrition.fat.to_f.round(1)} г  
            • Углеводы: #{nutrition.carbs.to_f.round(1)} г
            
            #{nutrition.food_items.present? ? "🥘 *Продукты:* #{nutrition.food_items}" : ""}
          TEXT
        end
        
      when "type_correction"
        type_names = {
          'diary' => 'дневник',
          'idea' => 'идея',
          'plan' => 'план',
          'nutrition' => 'питание'
        }
        confirmation_text += "\n\n📝 *Новый тип:* #{type_names[entry.entry_type] || entry.entry_type}"
        
        if entry.calendar_event
          confirmation_text += "\n📅 Создано календарное событие"
        end
      end
      
      send_reply(confirmation_text)
    end

    private

    def format_daily_plan(plan_data)
      text = "📋 *#{plan_data[:summary]}*\n\n"
      
      if plan_data[:context_insights]&.any?
        text += "🔍 *Контекст:*\n"
        plan_data[:context_insights].each do |insight|
          text += "• #{insight[:message]}\n"
        end
        text += "\n"
      end
      
      if plan_data[:priorities]&.any?
        text += "🎯 *Приоритеты:*\n"
        plan_data[:priorities].first(3).each do |priority|
          text += "• #{priority[:title]} (важность: #{(priority[:weight] * 100).round}%)\n"
        end
        text += "\n"
      end
      
      if plan_data[:scheduled_tasks]&.any?
        text += "⏰ *Расписание задач:*\n"
        plan_data[:scheduled_tasks].each do |task|
          time_str = ""
          if task[:suggested_start_time]
            time_str = " в #{task[:suggested_start_time].in_time_zone(user.timezone).strftime('%H:%M')}"
          end
          
          confidence_emoji = case task[:confidence_score]
                           when 80..100 then "🎯"
                           when 60..79 then "✅"
                           else "⚠️"
                           end
          
          text += "#{confidence_emoji} *#{task[:title]}*#{time_str}\n"
          text += "   └ #{task[:estimated_time] || 30} мин, #{task[:priority]} приоритет\n"
          
          if task[:reasoning]
            text += "   💡 #{task[:reasoning]}\n"
          end
          text += "\n"
        end
      end
      
      text += "🎯 *Вероятность успеха:* #{plan_data[:success_probability] || 70}%\n"
      text += "⏱ *Общее время:* ~#{plan_data[:estimated_total_time] || 0} ч.\n\n"
      text += "💡 Используй /optimize для улучшения расписания"
      
      text
    end

    def format_weekly_plan(plan_data)
      text = "📅 *#{plan_data[:summary]}*\n\n"
      
      if plan_data[:focus_themes]&.any?
        text += "🎯 *Основные темы недели:*\n"
        plan_data[:focus_themes].each do |theme|
          text += "• #{theme}\n"
        end
        text += "\n"
      end
      
      if plan_data[:weekly_goals]&.any?
        text += "🏆 *Цели на неделю:*\n"
        plan_data[:weekly_goals].each do |goal|
          text += "• #{goal[:title]} (#{goal[:category]})\n"
        end
        text += "\n"
      end
      
      text += "📊 *Распределение нагрузки:*\n"
      if plan_data[:workload_balance]
        wb = plan_data[:workload_balance]
        text += "• Всего: #{wb[:total_hours]} ч.\n"
        text += "• В среднем в день: #{wb[:average_daily]} ч.\n"
        text += "• Пиковый день: #{wb[:peak_day]}\n"
        text += "• Легкий день: #{wb[:lightest_day]}\n"
        text += "• Баланс: #{wb[:balance_score]}/100\n"
      end
      
      text += "\n💡 Используй /plan для детального планирования отдельных дней"
      
      text
    end

    def format_optimization_result(result)
      text = "⚡ *Оптимизация расписания*\n\n"
      
      if result[:optimized_tasks]&.any?
        text += "📋 *Оптимизированные задачи:*\n"
        result[:optimized_tasks].each do |task|
          start_time = task[:suggested_start_time]&.in_time_zone(user.timezone)&.strftime('%H:%M') || "время не определено"
          confidence_emoji = case task[:confidence_score]
                           when 80..100 then "🎯"
                           when 60..79 then "✅" 
                           else "⚠️"
                           end
          
          text += "#{confidence_emoji} *#{task[:title]}*\n"
          text += "   ⏰ Рекомендуемое время: #{start_time}\n"
          text += "   🎚 Уверенность: #{task[:confidence_score] || 50}%\n"
          
          if task[:reasoning]
            text += "   💡 #{task[:reasoning]}\n"
          end
          text += "\n"
        end
      end
      
      if result[:workload_analysis]
        wa = result[:workload_analysis]
        text += "📊 *Анализ нагрузки:*\n"
        text += "• Общее время: #{wa[:total_hours]} ч.\n"
        text += "• Категории: #{wa[:category_distribution].keys.join(', ')}\n\n"
      end
      
      if result[:user_patterns]
        up = result[:user_patterns]
        text += "📈 *Ваши паттерны:*\n"
        text += "• Пиковые часы: #{up[:peak_hours]&.map { |h| h[:hour] }&.join(', ')}\n"
        text += "• Продуктивные дни: #{up[:productive_days]&.map { |d| d[:day] }&.join(', ')}\n\n"
      end
      
      text += "💡 Планы автоматически адаптированы под ваш стиль работы!"
      
      text
    end

    def format_suggestions(suggestions)
      text = "💡 *Умные предложения*\n\n"
      
      text += "📍 *Текущий контекст:*\n"
      text += "#{suggestions[:context_summary]}\n\n"
      
      if suggestions[:immediate_suggestions]&.any?
        text += "⚡ *Рекомендации сейчас:*\n"
        suggestions[:immediate_suggestions].each do |suggestion|
          priority_emoji = case suggestion[:priority]
                          when 'high' then "🔥"
                          when 'medium' then "📝"
                          else "💭"
                          end
          
          text += "#{priority_emoji} #{suggestion[:message]}\n"
        end
        text += "\n"
      end
      
      if suggestions[:optimal_actions]&.any?
        text += "🎯 *Оптимальные действия:*\n"
        suggestions[:optimal_actions].first(3).each do |action|
          confidence_bar = "█" * (action[:confidence] * 5).to_i + "░" * (5 - (action[:confidence] * 5).to_i)
          text += "• #{action[:action].humanize}\n"
          text += "  #{confidence_bar} #{(action[:confidence] * 100).round}%\n"
        end
        text += "\n"
      end
      
      if suggestions[:recommended_next_steps]&.any?
        text += "👉 *Следующие шаги:*\n"
        suggestions[:recommended_next_steps].first(3).each do |step|
          text += "• #{step[:description]}\n"
        end
      end
      
      text
    end

    def format_recommendations(recommendations)
      return "" if recommendations.empty?
      
      text = "🔍 *Рекомендации:*\n\n"
      
      recommendations.each do |rec|
        priority_emoji = case rec[:priority]
                        when 'high' then "🔥"
                        when 'medium' then "💡"
                        else "ℹ️"
                        end
        
        text += "#{priority_emoji} #{rec[:message]}\n"
      end
      
      text
    end

    def handle_location_message
      location = message.location
      latitude = location.latitude
      longitude = location.longitude
      
      send_reply("🌍 Определяю ваш часовой пояс...")
      
      begin
        # Определяем timezone по координатам
        timezone = TimezoneService.detect_timezone(latitude, longitude)
        
        if timezone
          old_timezone = user.timezone
          user.update!(timezone: timezone)
          
          send_reply(<<~TEXT)
            ✅ *Часовой пояс обновлен!*
            
            📍 Ваше местоположение: #{latitude.round(4)}, #{longitude.round(4)}
            🕐 Был: #{old_timezone}
            🕐 Стал: #{timezone}
            
            Теперь все напоминания и события будут отображаться в вашем местном времени!
          TEXT
        else
          send_reply("❌ Не удалось определить часовой пояс по координатам. Попробуйте команду /timezone для ручной настройки.")
        end
        
      rescue StandardError => e
        Rails.logger.error "Location processing error: #{e.message}"
        send_reply("❌ Ошибка обработки геолокации. Попробуйте команду /timezone для ручной настройки.")
      end
    end

    def handle_timezone_command
      command_parts = message.text.split
      
      if command_parts.length == 1
        # Показываем текущий timezone и инструкции
        send_reply(<<~TEXT)
          🕐 *Настройка часового пояса*
          
          Ваш текущий часовой пояс: *#{user.timezone}*
          
          *Способы настройки:*
          
          1️⃣ **Отправьте геолокацию** 📍
             Нажмите 📎 → Местоположение → Отправить
             Я автоматически определю ваш часовой пояс
          
          2️⃣ **Введите город:**
             `/timezone Madrid`
             `/timezone Barcelona` 
             `/timezone Moscow`
             `/timezone London`
          
          3️⃣ **Введите timezone:**
             `/timezone Europe/Madrid`
             `/timezone Europe/Moscow`
             `/timezone UTC`
          
          💡 Правильный часовой пояс важен для корректной работы напоминаний и утренних сводок!
        TEXT
        return
      end
      
      # Пытаемся установить timezone
      timezone_input = command_parts[1..-1].join(" ")
      
      begin
        new_timezone = TimezoneService.parse_timezone_input(timezone_input)
        
        if new_timezone
          old_timezone = user.timezone
          user.update!(timezone: new_timezone)
          
          # Получаем текущее время в новом timezone
          current_time = Time.current.in_time_zone(new_timezone)
          
          send_reply(<<~TEXT)
            ✅ *Часовой пояс обновлен!*
            
            🕐 Был: #{old_timezone}
            🕐 Стал: #{new_timezone}
            🕐 Ваше время сейчас: #{current_time.strftime('%H:%M, %d %B %Y')}
            
            Все напоминания и события теперь будут отображаться в вашем местном времени!
          TEXT
        else
          send_reply(<<~TEXT)
            ❌ Не удалось распознать часовой пояс: "#{timezone_input}"
            
            Попробуйте:
            • Название города: Madrid, Barcelona, Moscow
            • Название timezone: Europe/Madrid, Europe/Moscow
            • Или отправьте геолокацию 📍
          TEXT
        end
        
      rescue StandardError => e
        Rails.logger.error "Timezone setting error: #{e.message}"
        send_reply("❌ Ошибка установки часового пояса. Проверьте формат и попробуйте снова.")
      end
    end

    def send_reply(text)
      BotService.send_message(
        chat_id: chat_id,
        text: text
      )
    end

    def send_reply_with_keyboard(text, keyboard)
      BotService.send_message_with_keyboard(
        chat_id: chat_id,
        text: text,
        keyboard: keyboard
      )
    end

    def handle_user_command(text)
      # Handle user questions and commands that shouldn't be saved as entries
      command_response = generate_command_response(text)
      send_reply(command_response)
    end

    def generate_command_response(text)
      text_lower = text.downcase
      
      if text_lower.include?("какие") && text_lower.include?("идеи")
        # Handle "какие есть у меня идеи" type questions
        ideas = user.entries.active.where(entry_type: 'idea').recent.limit(5)
        if ideas.any?
          ideas_list = ideas.map.with_index(1) do |idea, i|
            "#{i}. #{idea.content.truncate(100)}"
          end.join("\n")
          
          "💡 *Ваши последние идеи:*\n\n#{ideas_list}\n\n📝 Всего идей: #{user.entries.active.where(entry_type: 'idea').count}"
        else
          "💡 У вас пока нет сохранённых идей. Расскажите что-нибудь интересное!"
        end
      elsif text_lower.include?("план") && (text_lower.include?("какие") || text_lower.include?("что"))
        # Handle "какие планы" type questions
        plans = user.entries.active.where(entry_type: 'plan').recent.limit(5)
        if plans.any?
          plans_list = plans.map.with_index(1) do |plan, i|
            "#{i}. #{plan.content.truncate(100)}"
          end.join("\n")
          
          "📅 *Ваши планы:*\n\n#{plans_list}\n\n📋 Всего планов: #{user.entries.active.where(entry_type: 'plan').count}"
        else
          "📅 У вас пока нет планов. Создайте новый план!"
        end
      elsif text_lower.include?("калори") || text_lower.include?("бжу") || text_lower.include?("питан")
        # Handle nutrition stats questions
        today = Date.current
        nutrition_entries = user.nutrition_entries.where(recorded_at: today.beginning_of_day..today.end_of_day)
        
        if nutrition_entries.any?
          total_calories = nutrition_entries.sum(:calories)
          total_protein = nutrition_entries.sum(:protein)
          total_fat = nutrition_entries.sum(:fat)
          total_carbs = nutrition_entries.sum(:carbs)
          
          "🍽️ *Питание за сегодня:*\n\n📊 Калории: #{total_calories.to_i} ккал\n🥩 Белки: #{total_protein.round(1)} г\n🥑 Жиры: #{total_fat.round(1)} г\n🍞 Углеводы: #{total_carbs.round(1)} г\n\n🍽️ Приёмов пищи: #{nutrition_entries.count}"
        else
          "🍽️ Сегодня ещё нет записей о питании. Отправьте фото еды или опишите что съели!"
        end
      elsif text_lower.include?("записи") || text_lower.include?("что у меня")
        # Handle general entries questions
        total_entries = user.entries.active.count
        total_ideas = user.entries.active.where(entry_type: 'idea').count
        total_plans = user.entries.active.where(entry_type: 'plan').count
        total_diary = user.entries.active.where(entry_type: 'diary').count
        
        "📊 *Ваша статистика:*\n\n📝 Всего записей: #{total_entries}\n💡 Идеи: #{total_ideas}\n📅 Планы: #{total_plans}\n📔 Дневник: #{total_diary}\n🍽️ Питание: #{user.nutrition_entries.count}"
      else
        # Default response for unrecognized commands
        "🤖 Я понял, что это команда, но пока не знаю как на неё ответить.\n\nПопробуйте:\n• \"какие у меня идеи\"\n• \"покажи планы\"\n• \"статистика калорий\"\n• \"что у меня записей\"\n\nИли используйте /help для полного списка команд."
      end
    end

    def process_garmin_screenshot(garmin_analysis, photo_file_id)
      begin
        # Create ActivityEntry from Garmin data
        activity_entry = user.activity_entries.create!(
          activity_type: garmin_analysis[:activity_type],
          duration_minutes: garmin_analysis[:duration_minutes],
          distance_km: garmin_analysis[:distance_km],
          calories_burned: garmin_analysis[:calories_burned],
          average_heart_rate: garmin_analysis[:average_heart_rate],
          max_heart_rate: garmin_analysis[:max_heart_rate],
          average_pace: garmin_analysis[:average_pace],
          activity_date: garmin_analysis[:activity_date] || Time.current,
          notes: garmin_analysis[:notes],
          garmin_data: garmin_analysis[:garmin_data],
          screenshot_url: photo_file_id,
          ai_analysis: "Автоматически извлечено из Garmin (уверенность: #{garmin_analysis[:confidence_score]}%)"
        )

        # Send confirmation with extracted data
        send_garmin_confirmation(activity_entry, garmin_analysis)

        # Update user's last entry context for corrections (if there's an associated entry)
        # Note: ActivityEntry might not have an associated Entry, so we need to handle this case

      rescue StandardError => e
        Rails.logger.error "Error processing Garmin screenshot: #{e.message}"
        send_reply("Произошла ошибка при сохранении данных тренировки. Попробуй еще раз.")
      end
    end

    def send_garmin_confirmation(activity_entry, garmin_analysis)
      activity_emoji = activity_entry.activity_emoji
      confidence_emoji = case garmin_analysis[:confidence_score]
      when 80..100 then '🎯'
      when 60..79 then '✅'
      else '⚠️'
      end

      confirmation_text = <<~TEXT
        #{activity_emoji} *Обнаружил тренировку Garmin!*

        #{confidence_emoji} *Уверенность: #{garmin_analysis[:confidence_score]}%*

        🏃‍♂️ *Тип:* #{activity_entry.activity_name}
        ⏱️ *Время:* #{activity_entry.formatted_duration}
        #{activity_entry.distance_km ? "📏 *Дистанция:* #{activity_entry.formatted_distance}" : ""}
        #{activity_entry.calories_burned ? "🔥 *Калории:* #{activity_entry.calories_burned} ккал" : ""}
        #{activity_entry.average_heart_rate ? "💓 *Средний пульс:* #{activity_entry.average_heart_rate} bpm" : ""}
        #{activity_entry.average_pace ? "⚡ *Темп:* #{activity_entry.average_pace}" : ""}

        📊 Данные сохранены в разделе "Здоровье → Активность"
      TEXT

      send_reply(confirmation_text.strip)
    end
  end
end
