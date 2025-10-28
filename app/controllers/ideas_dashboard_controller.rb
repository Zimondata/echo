class IdeasDashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @stats = calculate_idea_stats
    @priority_ideas = current_user.entries.ideas.by_priority.limit(5)
    @research_ready = current_user.entries.ideas.where(idea_status: 'new').limit(10)
    @quest_candidates = current_user.entries.ideas.where(quest_generated: false).limit(10)
    @recent_quests = current_user.quests.recent.limit(5)
    @research_completed = current_user.entries.ideas.where.not(research_data: nil).limit(5)
  end

  def research_idea
    @entry = current_user.entries.find(params[:id])
    
    if @entry.entry_type != 'idea'
      redirect_to ideas_dashboard_path, alert: 'Можно анализировать только идеи'
      return
    end

    research_service = Ai::IdeaResearchService.new(@entry)
    
    if research_service.perform_research
      redirect_to ideas_dashboard_path, notice: 'Исследование идеи завершено!'
    else
      redirect_to ideas_dashboard_path, alert: 'Не удалось провести исследование идеи'
    end
  end

  def generate_quest
    @entry = current_user.entries.find(params[:id])
    
    if @entry.entry_type != 'idea'
      redirect_to ideas_dashboard_path, alert: 'Можно создавать квесты только из идей'
      return
    end

    if @entry.quest_generated?
      redirect_to ideas_dashboard_path, alert: 'Квест для этой идеи уже создан'
      return
    end

    quest_service = Ai::QuestGeneratorService.new(@entry)
    quest = quest_service.generate_quest
    
    if quest
      redirect_to quest_path(quest), notice: 'Квест успешно создан!'
    else
      redirect_to ideas_dashboard_path, alert: 'Не удалось создать квест'
    end
  end

  def show_research
    @entry = current_user.entries.find(params[:id])
    
    unless @entry.research_data.present?
      redirect_to ideas_dashboard_path, alert: 'Исследование для этой идеи не проводилось'
      return
    end

    @research = @entry.research_data
  end

  private

  def calculate_idea_stats
    ideas = current_user.entries.ideas
    
    {
      total_ideas: ideas.count,
      new_ideas: ideas.where(idea_status: 'new').count,
      in_progress: ideas.where(idea_status: 'in_progress').count,
      completed: ideas.where(idea_status: 'completed').count,
      with_research: ideas.where.not(research_data: nil).count,
      with_quests: ideas.where(quest_generated: true).count,
      high_priority: ideas.where(idea_priority: 'high').count,
      medium_priority: ideas.where(idea_priority: 'medium').count,
      low_priority: ideas.where(idea_priority: 'low').count
    }
  end
end