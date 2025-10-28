module Ai
  class SmartReminderEngine
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # Main method to generate all types of smart reminders
    def generate_reminders
      return [] unless user.present?

      reminders = []

      # 1. Check for stale ideas (ideas without follow-up)
      reminders += check_stale_ideas

      # 2. Check for broken patterns (habits the user usually follows)
      reminders += check_broken_patterns

      # 3. Check goals and plans progress
      reminders += check_goals_progress

      # 4. Analyze diary context for insights
      reminders += check_diary_context

      # 5. Generate suggestions based on user interests
      reminders += generate_suggestions

      # Filter out low confidence reminders and duplicates
      reminders
        .select { |r| r[:confidence] >= 60 }
        .uniq { |r| [r[:smart_type], r[:message]] }
        .sort_by { |r| -r[:confidence] }
    end

    private

    # Check for ideas that haven't been acted upon
    def check_stale_ideas
      stale_ideas = user.entries
        .where(entry_type: "idea")
        .where("created_at < ?", 3.days.ago)
        .where("created_at > ?", 30.days.ago) # Don't go too far back
        .order(created_at: :desc)
        .limit(10)

      # Filter out ideas that have recent plan updates
      recent_plan_ids = user.entries
        .where(entry_type: "plan")
        .where("created_at > ?", 3.days.ago)
        .pluck(:id)

      stale_ideas.reject do |idea|
        # Check if this idea has been mentioned in recent plans
        idea.content.split(/\W+/).any? do |word|
          next if word.length < 4
          user.entries.where(id: recent_plan_ids).any? { |plan| plan.content.downcase.include?(word.downcase) }
        end
      end.map do |idea|
        create_idea_reminder(idea)
      end
    end

    def create_idea_reminder(idea)
      days_ago = ((Time.current - idea.created_at) / 1.day).round

      {
        smart_type: "idea",
        smart_trigger: "idea_aging",
        message: "У тебя #{days_ago} #{days_word(days_ago)} назад была идея: \"#{idea.content.truncate(100)}\". Хочешь обсудить первые шаги?",
        priority: days_ago > 7 ? "high" : "medium",
        confidence: [90 - (days_ago * 2), 60].max, # Decreases with age
        related_entry_ids: [idea.id],
        ai_context: {
          idea_content: idea.content,
          created_at: idea.created_at,
          days_stale: days_ago
        },
        action_buttons: [
          { text: "Да, давай обсудим", callback: "discuss_idea_#{idea.id}" },
          { text: "Напомнить через неделю", callback: "snooze_idea_#{idea.id}_7d" },
          { text: "Удалить идею", callback: "archive_idea_#{idea.id}" }
        ],
        remind_at: Time.current + rand(1..4).hours # Random time to avoid spam
      }
    end

    # Check for broken behavioral patterns
    def check_broken_patterns
      reminders = []

      # Check nutrition pattern (if user usually logs meals)
      nutrition_reminder = check_nutrition_pattern
      reminders << nutrition_reminder if nutrition_reminder

      # Check activity pattern (if user usually exercises)
      activity_reminder = check_activity_pattern
      reminders << activity_reminder if activity_reminder

      reminders
    end

    def check_nutrition_pattern
      # Check if user has logged nutrition in the past
      total_nutrition_entries = user.nutrition_entries.where("created_at > ?", 30.days.ago).count
      return nil if total_nutrition_entries < 10 # Not enough data

      # Check today's entries
      today_entries = user.nutrition_entries.where("created_at >= ?", Time.current.beginning_of_day).count
      return nil if today_entries > 0 # Already logged today

      # Check average entries per day
      avg_per_day = total_nutrition_entries / 30.0
      return nil if avg_per_day < 1 # User doesn't log regularly

      {
        smart_type: "pattern",
        smart_trigger: "pattern_break",
        message: "Ты обычно записываешь приемы пищи, но сегодня еще ничего не добавил. Не забыл?",
        priority: "medium",
        confidence: 75,
        related_entry_ids: [],
        ai_context: {
          pattern_type: "nutrition",
          avg_per_day: avg_per_day.round(1),
          last_entry_date: user.nutrition_entries.order(created_at: :desc).first&.created_at
        },
        action_buttons: [
          { text: "Записать прием пищи", callback: "log_meal" },
          { text: "Сегодня не нужно", callback: "skip_pattern_nutrition" }
        ],
        remind_at: Time.current + 2.hours
      }
    end

    def check_activity_pattern
      # Check if user has logged activities in the past
      total_activity_entries = user.activity_entries.where("created_at > ?", 30.days.ago).count
      return nil if total_activity_entries < 5 # Not enough data

      # Check this week's entries
      week_entries = user.activity_entries.where("created_at >= ?", Time.current.beginning_of_week).count
      return nil if week_entries >= 3 # Already active this week

      # Get day of week pattern
      current_day = Time.current.wday
      historical_entries_on_this_day = user.activity_entries
        .where("created_at > ?", 60.days.ago)
        .select { |e| e.created_at.wday == current_day }
        .count

      return nil if historical_entries_on_this_day < 2 # Not a pattern for this day

      {
        smart_type: "pattern",
        smart_trigger: "pattern_break",
        message: "Обычно ты тренируешься по #{day_name(current_day)}, но сегодня тренировки еще нет. Планируешь?",
        priority: "medium",
        confidence: 70,
        related_entry_ids: [],
        ai_context: {
          pattern_type: "activity",
          day_of_week: current_day,
          historical_count: historical_entries_on_this_day
        },
        action_buttons: [
          { text: "Записать тренировку", callback: "log_activity" },
          { text: "Сегодня выходной", callback: "skip_pattern_activity" }
        ],
        remind_at: Time.current + 3.hours
      }
    end

    # Check goals and plans that need attention
    def check_goals_progress
      reminders = []

      # Find plans with future dates that are approaching
      upcoming_plans = user.calendar_events
        .where(event_type: "plan")
        .where("start_time BETWEEN ? AND ?", Time.current, 3.days.from_now)
        .where.not(id: recent_plan_update_event_ids)
        .order(:start_time)
        .limit(3)

      upcoming_plans.each do |event|
        reminders << create_plan_reminder(event)
      end

      reminders
    end

    def create_plan_reminder(event)
      time_until = ((event.start_time - Time.current) / 1.hour).round

      {
        smart_type: "goal",
        smart_trigger: "goal_check",
        message: "Твой план \"#{event.title.truncate(80)}\" через #{time_until} #{hours_word(time_until)}. Все готово?",
        priority: time_until < 24 ? "high" : "medium",
        confidence: 85,
        related_entry_ids: [event.entry_id].compact,
        ai_context: {
          event_id: event.id,
          start_time: event.start_time,
          hours_until: time_until
        },
        action_buttons: [
          { text: "Готов", callback: "plan_ready_#{event.id}" },
          { text: "Нужна подготовка", callback: "plan_prepare_#{event.id}" },
          { text: "Перенести", callback: "plan_reschedule_#{event.id}" }
        ],
        remind_at: event.start_time - 6.hours # 6 hours before
      }
    end

    # Analyze diary for emotional context and suggestions
    def check_diary_context
      # Get recent diary entries
      recent_diary = user.entries
        .where(entry_type: "diary")
        .where("created_at > ?", 7.days.ago)
        .order(created_at: :desc)
        .limit(10)

      return [] if recent_diary.count < 3 # Not enough data

      # Look for patterns in diary (stress, fatigue, etc.)
      # This is a simple keyword-based approach; could be enhanced with AI
      stress_keywords = %w[стресс устал усталость напряжен тревога беспокой]
      stress_count = recent_diary.count do |entry|
        stress_keywords.any? { |keyword| entry.content.downcase.include?(keyword) }
      end

      return [] if stress_count < 2 # No clear pattern

      [{
        smart_type: "context",
        smart_trigger: "diary_analysis",
        message: "Заметил, что в последнее время ты часто пишешь о стрессе и усталости. Может стоит сделать перерыв?",
        priority: "high",
        confidence: 75,
        related_entry_ids: recent_diary.pluck(:id),
        ai_context: {
          pattern: "stress",
          entry_count: recent_diary.count,
          stress_mentions: stress_count
        },
        action_buttons: [
          { text: "Запланировать отдых", callback: "plan_rest" },
          { text: "Техники релаксации", callback: "show_relaxation" },
          { text: "Спасибо, учту", callback: "acknowledge_context" }
        ],
        remind_at: Time.current + 1.hour
      }]
    end

    # Generate suggestions based on user's interests and entries
    def generate_suggestions
      # Use AI to analyze user's data and generate smart suggestions
      ai_suggestions = Ai::ReminderSuggestionAnalyzer.analyze(user, limit: 15)

      # Filter suggestions to avoid duplicates with existing reminders
      existing_messages = user.reminders.pending.pluck(:message)
      ai_suggestions.reject do |suggestion|
        existing_messages.any? { |msg| msg.include?(suggestion[:message][0..50]) }
      end
    rescue StandardError => e
      Rails.logger.error "Error generating AI suggestions: #{e.message}"
      []
    end

    # Helper methods
    def recent_plan_update_event_ids
      user.entries
        .where(entry_type: "plan_update")
        .where("created_at > ?", 2.days.ago)
        .joins(:calendar_event)
        .pluck(:calendar_event_id)
    end

    def days_word(days)
      case days
      when 1 then "день"
      when 2..4 then "дня"
      else "дней"
      end
    end

    def hours_word(hours)
      case hours
      when 1 then "час"
      when 2..4 then "часа"
      else "часов"
      end
    end

    def day_name(wday)
      %w[воскресеньям понедельникам вторникам средам четвергам пятницам субботам][wday]
    end
  end
end
