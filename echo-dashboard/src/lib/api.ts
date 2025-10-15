import axios, { AxiosInstance, AxiosResponse } from 'axios';
import type {
  ApiResponse,
  PaginatedResponse,
  Entry,
  CalendarEvent,
  Reminder,
  Insight,
  DashboardOverview,
  SearchResponse,
  AnalyticsData,
  EntryFilters,
  UpdateEntryData,
  BulkUpdateData,
} from '@/types';

class ApiClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1',
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    });

    // Request interceptor for auth
    this.client.interceptors.request.use(
      (config) => {
        // Add auth token if available
        const token = this.getAuthToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          this.handleAuthError();
        }
        return Promise.reject(error);
      }
    );
  }

  private getAuthToken(): string | null {
    // For now, return null as we're using the temporary auth system
    return null;
  }

  private handleAuthError(): void {
    // Handle authentication errors
    console.warn('Authentication required');
  }

  // Dashboard API
  async getDashboardOverview(): Promise<DashboardOverview> {
    const response: AxiosResponse<ApiResponse<DashboardOverview>> = 
      await this.client.get('/dashboard/overview');
    return response.data.data;
  }

  async getInbox(page = 1, perPage = 20): Promise<PaginatedResponse<Entry>> {
    const response: AxiosResponse<ApiResponse<PaginatedResponse<Entry>>> = 
      await this.client.get(`/dashboard/inbox?page=${page}&per_page=${perPage}`);
    return response.data.data;
  }

  async getNeedsAttention(page = 1, perPage = 20): Promise<PaginatedResponse<Entry>> {
    const response: AxiosResponse<ApiResponse<PaginatedResponse<Entry>>> = 
      await this.client.get(`/dashboard/needs_attention?page=${page}&per_page=${perPage}`);
    return response.data.data;
  }

  // Entries API
  async getEntries(filters: EntryFilters = {}): Promise<PaginatedResponse<Entry>> {
    const params = new URLSearchParams();
    
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        params.append(key, String(value));
      }
    });

    const response: AxiosResponse<ApiResponse<PaginatedResponse<Entry>>> = 
      await this.client.get(`/entries?${params.toString()}`);
    return response.data.data;
  }

  async getEntry(id: number): Promise<Entry> {
    const response: AxiosResponse<ApiResponse<Entry>> = 
      await this.client.get(`/entries/${id}`);
    return response.data.data;
  }

  async updateEntry(id: number, data: UpdateEntryData): Promise<Entry> {
    const response: AxiosResponse<ApiResponse<Entry>> = 
      await this.client.patch(`/entries/${id}`, { entry: data });
    return response.data.data;
  }

  async categorizeEntry(id: number, category: string): Promise<Entry> {
    const response: AxiosResponse<ApiResponse<Entry>> = 
      await this.client.patch(`/entries/${id}/categorize`, { category });
    return response.data.data;
  }

  async addTagsToEntry(id: number, tags: string[]): Promise<Entry> {
    const response: AxiosResponse<ApiResponse<Entry>> = 
      await this.client.patch(`/entries/${id}/add_tags`, { tags });
    return response.data.data;
  }

  async bulkUpdateEntries(data: BulkUpdateData): Promise<{ updated_count: number }> {
    const response: AxiosResponse<ApiResponse<{ updated_count: number }>> = 
      await this.client.patch('/entries/bulk_update', data);
    return response.data.data;
  }

  async getSimilarEntries(id: number): Promise<{ similar_entries: Entry[] }> {
    const response: AxiosResponse<ApiResponse<{ similar_entries: Entry[] }>> = 
      await this.client.get(`/entries/${id}/similar`);
    return response.data.data;
  }

  async getEntriesStats(): Promise<Record<string, any>> {
    const response: AxiosResponse<ApiResponse<Record<string, any>>> = 
      await this.client.get('/entries/stats');
    return response.data.data;
  }

  // Search API
  async search(query: string, page = 1): Promise<SearchResponse> {
    const response: AxiosResponse<ApiResponse<SearchResponse>> = 
      await this.client.get(`/search?q=${encodeURIComponent(query)}&page=${page}`);
    return response.data.data;
  }

  async getSearchSuggestions(query: string): Promise<{ suggestions: any[] }> {
    const response: AxiosResponse<ApiResponse<{ suggestions: any[] }>> = 
      await this.client.get(`/search/suggestions?q=${encodeURIComponent(query)}`);
    return response.data.data;
  }

  // Insights API
  async getInsights(type?: string, page = 1): Promise<PaginatedResponse<Insight>> {
    const params = new URLSearchParams({ page: String(page) });
    if (type) params.append('type', type);

    const response: AxiosResponse<ApiResponse<PaginatedResponse<Insight>>> = 
      await this.client.get(`/insights?${params.toString()}`);
    return response.data.data;
  }

  async getInsight(id: number): Promise<Insight> {
    const response: AxiosResponse<ApiResponse<Insight>> = 
      await this.client.get(`/insights/${id}`);
    return response.data.data;
  }

  async generateInsight(type: string): Promise<{ message: string }> {
    const response: AxiosResponse<ApiResponse<{ message: string }>> = 
      await this.client.post('/insights/generate', { insight_type: type });
    return response.data.data;
  }

  async getAnalytics(): Promise<AnalyticsData> {
    const response: AxiosResponse<ApiResponse<AnalyticsData>> = 
      await this.client.get('/insights/analytics');
    return response.data.data;
  }

  // Calendar API
  async getCalendarEvents(page = 1): Promise<PaginatedResponse<CalendarEvent>> {
    const response: AxiosResponse<ApiResponse<PaginatedResponse<CalendarEvent>>> = 
      await this.client.get(`/calendar_events?page=${page}`);
    return response.data.data;
  }

  async getCalendarEvent(id: number): Promise<CalendarEvent> {
    const response: AxiosResponse<ApiResponse<CalendarEvent>> = 
      await this.client.get(`/calendar_events/${id}`);
    return response.data.data;
  }

  async createCalendarEvent(data: Partial<CalendarEvent>): Promise<CalendarEvent> {
    const response: AxiosResponse<ApiResponse<CalendarEvent>> = 
      await this.client.post('/calendar_events', { calendar_event: data });
    return response.data.data;
  }

  async updateCalendarEvent(id: number, data: Partial<CalendarEvent>): Promise<CalendarEvent> {
    const response: AxiosResponse<ApiResponse<CalendarEvent>> = 
      await this.client.patch(`/calendar_events/${id}`, { calendar_event: data });
    return response.data.data;
  }

  async deleteCalendarEvent(id: number): Promise<void> {
    await this.client.delete(`/calendar_events/${id}`);
  }

  async syncGoogleCalendar(): Promise<{ message: string }> {
    const response: AxiosResponse<ApiResponse<{ message: string }>> = 
      await this.client.post('/calendar_events/sync_google');
    return response.data.data;
  }

  // Reminders API
  async getReminders(page = 1): Promise<PaginatedResponse<Reminder>> {
    const response: AxiosResponse<ApiResponse<PaginatedResponse<Reminder>>> = 
      await this.client.get(`/reminders?page=${page}`);
    return response.data.data;
  }

  async getReminder(id: number): Promise<Reminder> {
    const response: AxiosResponse<ApiResponse<Reminder>> = 
      await this.client.get(`/reminders/${id}`);
    return response.data.data;
  }

  async createReminder(data: Partial<Reminder>): Promise<Reminder> {
    const response: AxiosResponse<ApiResponse<Reminder>> = 
      await this.client.post('/reminders', { reminder: data });
    return response.data.data;
  }

  async updateReminder(id: number, data: Partial<Reminder>): Promise<Reminder> {
    const response: AxiosResponse<ApiResponse<Reminder>> = 
      await this.client.patch(`/reminders/${id}`, { reminder: data });
    return response.data.data;
  }

  async deleteReminder(id: number): Promise<void> {
    await this.client.delete(`/reminders/${id}`);
  }

  // Utility methods
  async healthCheck(): Promise<{ status: string }> {
    const response = await this.client.get('/health');
    return response.data;
  }
}

// Create singleton instance
const apiClient = new ApiClient();

export default apiClient;

// Export individual methods for easier use
export const {
  getDashboardOverview,
  getInbox,
  getNeedsAttention,
  getEntries,
  getEntry,
  updateEntry,
  categorizeEntry,
  addTagsToEntry,
  bulkUpdateEntries,
  getSimilarEntries,
  getEntriesStats,
  search,
  getSearchSuggestions,
  getInsights,
  getInsight,
  generateInsight,
  getAnalytics,
  getCalendarEvents,
  getCalendarEvent,
  createCalendarEvent,
  updateCalendarEvent,
  deleteCalendarEvent,
  syncGoogleCalendar,
  getReminders,
  getReminder,
  createReminder,
  updateReminder,
  deleteReminder,
  healthCheck
} = apiClient;