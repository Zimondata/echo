// API Types
export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    current_page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
}

// User Types
export interface User {
  id: number;
  telegram_id: number;
  username?: string;
  first_name?: string;
  last_name?: string;
  timezone: string;
  language: string;
  google_connected: boolean;
  settings: Record<string, any>;
  created_at: string;
  updated_at: string;
}

// Entry Types
export type EntryType = 'diary' | 'idea' | 'plan' | 'plan_update';
export type EntryStatus = 'active' | 'archived' | 'deleted';
export type DashboardStatus = 'new' | 'triaged' | 'processed' | 'archived';
export type Category = 'inbox' | 'work' | 'life' | 'health' | 'ideas' | 'projects';

export interface Entry {
  id: number;
  entry_type: EntryType;
  content: string;
  transcript?: string;
  audio_url?: string;
  category: Category;
  dashboard_status: DashboardStatus;
  priority: number;
  tags: string[];
  insights: Record<string, any>;
  metadata: Record<string, any>;
  status: EntryStatus;
  occurred_at: string;
  processed_at?: string;
  created_at: string;
  updated_at: string;
  has_audio: boolean;
  has_transcript: boolean;
  has_calendar_event: boolean;
  has_reminders: boolean;
  calendar_event?: CalendarEvent;
  reminders?: Reminder[];
}

// Calendar Event Types
export interface CalendarEvent {
  id: number;
  title: string;
  description?: string;
  start_time: string;
  end_time?: string;
  event_type: string;
  google_event_id?: string;
  google_synced: boolean;
  created_at: string;
  updated_at: string;
}

// Reminder Types
export type ReminderType = 'one_time' | 'recurring';
export type ReminderStatus = 'pending' | 'sent' | 'cancelled';

export interface Reminder {
  id: number;
  message?: string;
  remind_at: string;
  reminder_type: ReminderType;
  status: ReminderStatus;
  sent_at?: string;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

// Insight Types
export type InsightType = 
  | 'daily_summary' 
  | 'weekly_digest' 
  | 'trend_analysis' 
  | 'mood_tracker' 
  | 'productivity_insight' 
  | 'goal_progress';

export interface Insight {
  id: number;
  insight_type: InsightType;
  title: string;
  content?: string;
  data: Record<string, any>;
  generated_at: string;
  expires_at?: string;
  created_at: string;
  is_expired: boolean;
}

// Dashboard Types
export interface DashboardStats {
  entries: {
    total: number;
    new: number;
    needs_attention: number;
    by_type: {
      diary: number;
      ideas: number;
      plans: number;
    };
    by_category: Record<Category, number>;
  };
  calendar: {
    upcoming_events: number;
    today_events: number;
    this_week_events: number;
  };
  reminders: {
    pending: number;
    today: number;
    overdue: number;
  };
}

export interface RecentActivity {
  recent_entries: Entry[];
  upcoming_events: CalendarEvent[];
  pending_reminders: Reminder[];
  insights: Insight[];
}

export interface DashboardOverview {
  stats: DashboardStats;
  recent_activity: RecentActivity;
}

// Search Types
export interface SearchResult {
  id: number;
  entry_type: EntryType;
  content: string;
  category: Category;
  tags: string[];
  match_type: 'text' | 'tag' | 'semantic';
  occurred_at: string;
  created_at: string;
  relevance_score: number;
  highlights: {
    field: string;
    text: string;
  }[];
}

export interface SearchResponse {
  query: string;
  total_results: number;
  results: {
    text_matches: SearchResult[];
    tag_matches: SearchResult[];
    similar_content: SearchResult[];
  };
  filters: {
    categories: Category[];
    entry_types: EntryType[];
    date_ranges: {
      key: string;
      label: string;
      count: number;
    }[];
  };
  suggestions: string[];
}

export interface SearchSuggestion {
  type: 'category' | 'entry_type' | 'tag';
  text: string;
  display: string;
}

// Analytics Types
export interface AnalyticsData {
  mood_trends: {
    date: string;
    mood_score?: number;
    entries_count: number;
  }[];
  productivity_trends: Record<string, {
    total_entries: number;
    plans_count: number;
    ideas_count: number;
    diary_count: number;
  }>;
  category_distribution: Record<Category, number>;
  weekly_activity: {
    week: string;
    total_entries: number;
    by_type: Record<EntryType, number>;
    avg_per_day: number;
  }[];
  entry_types_over_time: {
    month: string;
    diary: number;
    ideas: number;
    plans: number;
  }[];
}

// API Error Types
export interface ApiError {
  error: string;
  message?: string;
  details?: string[];
}

// Filter Types
export interface EntryFilters {
  type?: EntryType;
  category?: Category;
  status?: DashboardStatus;
  search?: string;
  sort?: 'priority' | 'created_at' | 'occurred_at';
  page?: number;
  per_page?: number;
}

// Form Types
export interface UpdateEntryData {
  category?: Category;
  dashboard_status?: DashboardStatus;
  priority?: number;
  tags?: string[];
  status?: EntryStatus;
}

export interface BulkUpdateData {
  entry_ids: number[];
  category?: Category;
  dashboard_status?: DashboardStatus;
  priority?: number;
}

// Theme & UI Types
export type Theme = 'light' | 'dark' | 'system';

export interface UIState {
  sidebarCollapsed: boolean;
  theme: Theme;
  notifications: Notification[];
}

export interface Notification {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message?: string;
  timestamp: string;
  read: boolean;
}

// WebSocket Types
export interface WebSocketMessage {
  type: 'entry_created' | 'entry_updated' | 'calendar_event_created' | 'reminder_triggered' | 'insight_generated';
  data: any;
  timestamp: string;
}

// Chart Data Types
export interface ChartDataPoint {
  name: string;
  value: number;
  date?: string;
}

export interface TimeSeriesData {
  date: string;
  value: number;
  category?: string;
}

// Export all types
export type {
  ApiResponse,
  PaginatedResponse,
  User,
  Entry,
  CalendarEvent,
  Reminder,
  Insight,
  DashboardStats,
  RecentActivity,
  DashboardOverview,
  SearchResult,
  SearchResponse,
  AnalyticsData,
  ApiError,
  EntryFilters,
  UpdateEntryData,
  BulkUpdateData,
  UIState,
  Notification,
  WebSocketMessage,
  ChartDataPoint,
  TimeSeriesData
};