import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { 
  Entry,
  EntryFilters,
  Theme,
  Notification,
  UIState
} from '@/types';

// UI Store
interface UIStore extends UIState {
  setSidebarCollapsed: (collapsed: boolean) => void;
  setTheme: (theme: Theme) => void;
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp' | 'read'>) => void;
  markNotificationAsRead: (id: string) => void;
  removeNotification: (id: string) => void;
  clearNotifications: () => void;
}

export const useUIStore = create<UIStore>()(
  persist(
    (set, get) => ({
      sidebarCollapsed: false,
      theme: 'system',
      notifications: [],

      setSidebarCollapsed: (collapsed) =>
        set({ sidebarCollapsed: collapsed }),

      setTheme: (theme) =>
        set({ theme }),

      addNotification: (notification) => {
        const newNotification: Notification = {
          ...notification,
          id: crypto.randomUUID(),
          timestamp: new Date().toISOString(),
          read: false,
        };

        set((state) => ({
          notifications: [newNotification, ...state.notifications].slice(0, 50), // Keep only 50 notifications
        }));
      },

      markNotificationAsRead: (id) =>
        set((state) => ({
          notifications: state.notifications.map((notification) =>
            notification.id === id ? { ...notification, read: true } : notification
          ),
        })),

      removeNotification: (id) =>
        set((state) => ({
          notifications: state.notifications.filter(
            (notification) => notification.id !== id
          ),
        })),

      clearNotifications: () => set({ notifications: [] }),
    }),
    {
      name: 'echo-ui-store',
      storage: createJSONStorage(() => localStorage),
    }
  )
);

// Entries Store
interface EntriesStore {
  selectedEntries: number[];
  filters: EntryFilters;
  searchQuery: string;
  viewMode: 'list' | 'grid' | 'kanban';
  
  setSelectedEntries: (entries: number[]) => void;
  toggleEntrySelection: (entryId: number) => void;
  clearSelection: () => void;
  setFilters: (filters: Partial<EntryFilters>) => void;
  clearFilters: () => void;
  setSearchQuery: (query: string) => void;
  setViewMode: (mode: 'list' | 'grid' | 'kanban') => void;
}

export const useEntriesStore = create<EntriesStore>()(
  persist(
    (set, get) => ({
      selectedEntries: [],
      filters: {},
      searchQuery: '',
      viewMode: 'list',

      setSelectedEntries: (entries) =>
        set({ selectedEntries: entries }),

      toggleEntrySelection: (entryId) =>
        set((state) => ({
          selectedEntries: state.selectedEntries.includes(entryId)
            ? state.selectedEntries.filter((id) => id !== entryId)
            : [...state.selectedEntries, entryId],
        })),

      clearSelection: () => set({ selectedEntries: [] }),

      setFilters: (newFilters) =>
        set((state) => ({
          filters: { ...state.filters, ...newFilters },
        })),

      clearFilters: () => set({ filters: {} }),

      setSearchQuery: (query) => set({ searchQuery: query }),

      setViewMode: (mode) => set({ viewMode: mode }),
    }),
    {
      name: 'echo-entries-store',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        filters: state.filters,
        viewMode: state.viewMode,
      }),
    }
  )
);

// Dashboard Store
interface DashboardStore {
  refreshInterval: number;
  autoRefresh: boolean;
  compactView: boolean;
  pinnedInsights: string[];
  
  setRefreshInterval: (interval: number) => void;
  setAutoRefresh: (enabled: boolean) => void;
  setCompactView: (compact: boolean) => void;
  togglePinnedInsight: (insightId: string) => void;
}

export const useDashboardStore = create<DashboardStore>()(
  persist(
    (set, get) => ({
      refreshInterval: 300000, // 5 minutes
      autoRefresh: true,
      compactView: false,
      pinnedInsights: [],

      setRefreshInterval: (interval) => set({ refreshInterval: interval }),

      setAutoRefresh: (enabled) => set({ autoRefresh: enabled }),

      setCompactView: (compact) => set({ compactView: compact }),

      togglePinnedInsight: (insightId) =>
        set((state) => ({
          pinnedInsights: state.pinnedInsights.includes(insightId)
            ? state.pinnedInsights.filter((id) => id !== insightId)
            : [...state.pinnedInsights, insightId],
        })),
    }),
    {
      name: 'echo-dashboard-store',
      storage: createJSONStorage(() => localStorage),
    }
  )
);

// Calendar Store
interface CalendarStore {
  view: 'month' | 'week' | 'day';
  selectedDate: string;
  showGoogleEvents: boolean;
  showReminders: boolean;
  
  setView: (view: 'month' | 'week' | 'day') => void;
  setSelectedDate: (date: string) => void;
  setShowGoogleEvents: (show: boolean) => void;
  setShowReminders: (show: boolean) => void;
}

export const useCalendarStore = create<CalendarStore>()(
  persist(
    (set) => ({
      view: 'month',
      selectedDate: new Date().toISOString(),
      showGoogleEvents: true,
      showReminders: true,

      setView: (view) => set({ view }),
      setSelectedDate: (date) => set({ selectedDate: date }),
      setShowGoogleEvents: (show) => set({ showGoogleEvents: show }),
      setShowReminders: (show) => set({ showReminders: show }),
    }),
    {
      name: 'echo-calendar-store',
      storage: createJSONStorage(() => localStorage),
    }
  )
);

// Analytics Store
interface AnalyticsStore {
  timeRange: '7d' | '30d' | '90d' | '1y';
  selectedMetrics: string[];
  compareMode: boolean;
  
  setTimeRange: (range: '7d' | '30d' | '90d' | '1y') => void;
  toggleMetric: (metric: string) => void;
  setCompareMode: (enabled: boolean) => void;
}

export const useAnalyticsStore = create<AnalyticsStore>()(
  persist(
    (set, get) => ({
      timeRange: '30d',
      selectedMetrics: ['entries', 'mood', 'productivity'],
      compareMode: false,

      setTimeRange: (range) => set({ timeRange: range }),

      toggleMetric: (metric) =>
        set((state) => ({
          selectedMetrics: state.selectedMetrics.includes(metric)
            ? state.selectedMetrics.filter((m) => m !== metric)
            : [...state.selectedMetrics, metric],
        })),

      setCompareMode: (enabled) => set({ compareMode: enabled }),
    }),
    {
      name: 'echo-analytics-store',
      storage: createJSONStorage(() => localStorage),
    }
  )
);

// WebSocket Store
interface WebSocketStore {
  connected: boolean;
  lastMessage: any;
  connectionAttempts: number;
  
  setConnected: (connected: boolean) => void;
  setLastMessage: (message: any) => void;
  incrementConnectionAttempts: () => void;
  resetConnectionAttempts: () => void;
}

export const useWebSocketStore = create<WebSocketStore>((set) => ({
  connected: false,
  lastMessage: null,
  connectionAttempts: 0,

  setConnected: (connected) => set({ connected }),
  setLastMessage: (message) => set({ lastMessage: message }),
  incrementConnectionAttempts: () =>
    set((state) => ({ connectionAttempts: state.connectionAttempts + 1 })),
  resetConnectionAttempts: () => set({ connectionAttempts: 0 }),
}));

// Export all stores
export {
  useUIStore,
  useEntriesStore,
  useDashboardStore,
  useCalendarStore,
  useAnalyticsStore,
  useWebSocketStore,
};