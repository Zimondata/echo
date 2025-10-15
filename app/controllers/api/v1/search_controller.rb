class Api::V1::SearchController < Api::BaseController
  def index
    query = params[:q]&.strip
    
    return error_response("Search query is required") if query.blank?

    results = perform_search(query)
    success_response(results)
  end

  def suggestions
    query = params[:q]&.strip
    return success_response({ suggestions: [] }) if query.blank?

    suggestions = generate_suggestions(query)
    success_response({ suggestions: suggestions })
  end

  private

  def perform_search(query)
    # Полнотекстовый поиск по записям
    entries = search_entries(query)
    
    # Поиск по тегам
    tag_matches = search_by_tags(query)
    
    # Векторный поиск (если есть embeddings)
    similar_entries = vector_search(query) if can_perform_vector_search?
    
    {
      query: query,
      total_results: entries.count + tag_matches.count + (similar_entries&.count || 0),
      results: {
        text_matches: entries.limit(20).map { |e| serialize_search_entry(e, 'text') },
        tag_matches: tag_matches.limit(10).map { |e| serialize_search_entry(e, 'tag') },
        similar_content: similar_entries&.limit(10)&.map { |e| serialize_search_entry(e, 'semantic') } || []
      },
      filters: available_filters(query),
      suggestions: generate_search_suggestions(query)
    }
  end

  def search_entries(query)
    search_term = "%#{query}%"
    current_user.entries.active.where(
      "content ILIKE ? OR transcript ILIKE ?", 
      search_term, search_term
    ).recent
  end

  def search_by_tags(query)
    current_user.entries.active
      .where("tags ILIKE ?", "%#{query}%")
      .recent
  end

  def vector_search(query)
    # Пока заглушка - в реальности нужно сгенерировать embedding для запроса
    # и найти похожие записи через pgvector
    return nil unless can_perform_vector_search?
    
    # Для демо найдем записи, которые уже имеют embeddings
    sample_entry = current_user.entries.active.where.not(embedding: nil).first
    return nil unless sample_entry
    
    sample_entry.nearest_neighbors(:embedding, distance: "cosine")
               .where.not(id: sample_entry.id)
               .limit(5)
  end

  def can_perform_vector_search?
    # Проверяем, есть ли записи с embeddings
    current_user.entries.active.where.not(embedding: nil).exists?
  end

  def generate_suggestions(query)
    suggestions = []
    
    # Предложения на основе категорий
    categories = %w[work life health ideas projects]
    matching_categories = categories.select { |c| c.include?(query.downcase) }
    suggestions += matching_categories.map { |c| { type: 'category', text: c, display: "Category: #{c.capitalize}" } }
    
    # Предложения на основе типов записей
    types = %w[diary idea plan]
    matching_types = types.select { |t| t.include?(query.downcase) }
    suggestions += matching_types.map { |t| { type: 'entry_type', text: t, display: "Type: #{t.capitalize}" } }
    
    # Предложения на основе тегов
    tag_suggestions = find_similar_tags(query)
    suggestions += tag_suggestions.map { |tag| { type: 'tag', text: tag, display: "Tag: ##{tag}" } }
    
    suggestions.uniq.first(10)
  end

  def find_similar_tags(query)
    # Собираем все теги пользователя
    all_tags = []
    current_user.entries.active.where.not(tags: [nil, '']).find_each do |entry|
      all_tags += entry.tag_list
    end
    
    # Ищем похожие теги
    query_downcase = query.downcase
    all_tags.uniq.select { |tag| tag.downcase.include?(query_downcase) }.first(5)
  end

  def available_filters(query)
    # Возвращаем доступные фильтры для текущего поиска
    {
      categories: current_user.entries.active.distinct.pluck(:category).compact,
      entry_types: current_user.entries.active.distinct.pluck(:entry_type).compact,
      date_ranges: [
        { key: 'today', label: 'Today', count: entries_count_for_period(1.day.ago) },
        { key: 'week', label: 'This Week', count: entries_count_for_period(1.week.ago) },
        { key: 'month', label: 'This Month', count: entries_count_for_period(1.month.ago) }
      ]
    }
  end

  def generate_search_suggestions(query)
    [
      "Search in category: work",
      "Filter by type: ideas", 
      "Show entries from last week",
      "Find similar content"
    ]
  end

  def entries_count_for_period(since)
    current_user.entries.active.where('created_at >= ?', since).count
  end

  def serialize_search_entry(entry, match_type)
    {
      id: entry.id,
      entry_type: entry.entry_type,
      content: entry.content.truncate(150),
      category: entry.category,
      tags: entry.tag_list,
      match_type: match_type,
      occurred_at: entry.occurred_at,
      created_at: entry.created_at,
      relevance_score: calculate_relevance_score(entry, match_type),
      highlights: generate_highlights(entry, params[:q])
    }
  end

  def calculate_relevance_score(entry, match_type)
    # Простой алгоритм расчета релевантности
    base_score = case match_type
    when 'text' then 1.0
    when 'tag' then 0.8
    when 'semantic' then 0.9
    else 0.5
    end
    
    # Бонусы за приоритет и недавность
    priority_bonus = entry.priority * 0.1
    recency_bonus = [1.0 - (Time.current - entry.created_at) / 1.month.to_f, 0.0].max * 0.2
    
    [base_score + priority_bonus + recency_bonus, 1.0].min.round(2)
  end

  def generate_highlights(entry, query)
    return [] if query.blank?
    
    highlights = []
    query_regex = Regexp.new(Regexp.escape(query), Regexp::IGNORECASE)
    
    # Highlights в контенте
    if entry.content.match?(query_regex)
      matched_text = entry.content.scan(/.{0,20}#{query_regex}.{0,20}/i).first
      highlights << { field: 'content', text: matched_text } if matched_text
    end
    
    # Highlights в транскрипте
    if entry.transcript.present? && entry.transcript.match?(query_regex)
      matched_text = entry.transcript.scan(/.{0,20}#{query_regex}.{0,20}/i).first
      highlights << { field: 'transcript', text: matched_text } if matched_text
    end
    
    highlights
  end
end