class SmartPriorityController < ApplicationController
  before_action :authenticate_user!

  # Запуск анализа приоритетов для всех идей пользователя
  def analyze_all
    begin
      # Запускаем анализ в фоне
      SmartPriorityAnalysisJob.perform_later(
        current_user.id, 
        notify: true, 
        auto_actions: params[:auto_actions] == 'true'
      )
      
      flash[:notice] = 'AI анализ приоритетов запущен! Результаты будут готовы через несколько минут.'
      
      respond_to do |format|
        format.html { redirect_to ideas_dashboard_path }
        format.json { render json: { success: true, message: 'Analysis started' } }
      end
      
    rescue => e
      Rails.logger.error "Failed to start priority analysis: #{e.message}"
      
      flash[:alert] = 'Не удалось запустить анализ приоритетов'
      
      respond_to do |format|
        format.html { redirect_to ideas_dashboard_path }
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end

  # Анализ приоритета одной конкретной идеи
  def analyze_idea
    @entry = current_user.entries.find(params[:id])
    
    unless @entry.entry_type == 'idea'
      flash[:alert] = 'Можно анализировать только идеи'
      redirect_to ideas_dashboard_path
      return
    end

    begin
      # Анализируем конкретную идею
      score_data = SmartPriorityAnalysisJob.analyze_single_idea(@entry.id)
      
      flash[:notice] = "Приоритет идеи обновлен! Оценка: #{score_data[:total_score]}/10"
      
      respond_to do |format|
        format.html { redirect_to ideas_dashboard_path }
        format.json { render json: { success: true, score_data: score_data } }
      end
      
    rescue => e
      Rails.logger.error "Failed to analyze idea #{@entry.id}: #{e.message}"
      
      flash[:alert] = 'Не удалось проанализировать идею'
      
      respond_to do |format|
        format.html { redirect_to ideas_dashboard_path }
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end

  # Показать детальный анализ приоритета идеи
  def show_analysis
    @entry = current_user.entries.find(params[:id])
    @analysis = @entry.metadata&.dig('ai_analysis')
    
    unless @analysis
      flash[:alert] = 'Анализ для этой идеи не найден. Запустите анализ приоритетов.'
      redirect_to ideas_dashboard_path
      return
    end
  end

  # Получить статистику анализа приоритетов
  def stats
    ideas_with_analysis = current_user.entries.ideas
                                      .where.not(metadata: nil)
                                      .select { |e| e.metadata&.dig('ai_analysis').present? }
    
    @stats = {
      total_analyzed: ideas_with_analysis.count,
      critical: count_by_priority(ideas_with_analysis, 'critical'),
      high: count_by_priority(ideas_with_analysis, 'high'),
      medium: count_by_priority(ideas_with_analysis, 'medium'),
      low: count_by_priority(ideas_with_analysis, 'low'),
      last_analysis: get_last_analysis_time(ideas_with_analysis)
    }

    respond_to do |format|
      format.html { render :stats }
      format.json { render json: @stats }
    end
  end

  # Настройки автоматического анализа
  def settings
    # Показываем настройки анализа
  end

  def update_settings
    # Обновляем настройки анализа (в будущем можно добавить в User модель)
    settings_params = params.require(:settings).permit(:auto_analysis, :notification_level, :auto_quest_creation)
    
    # Пока сохраняем в метаданных пользователя
    user_metadata = current_user.metadata || {}
    user_metadata['priority_analysis_settings'] = settings_params
    
    if current_user.update(metadata: user_metadata)
      flash[:notice] = 'Настройки анализа приоритетов сохранены'
    else
      flash[:alert] = 'Не удалось сохранить настройки'
    end
    
    redirect_to smart_priority_settings_path
  end

  private

  def count_by_priority(ideas, priority_level)
    ideas.count { |e| e.metadata.dig('ai_analysis', 'priority_level') == priority_level }
  end

  def get_last_analysis_time(ideas)
    analysis_times = ideas.map { |e| e.metadata.dig('ai_analysis', 'last_analyzed') }
                          .compact
                          .map { |time_str| Time.parse(time_str) rescue nil }
                          .compact

    analysis_times.max
  end
end