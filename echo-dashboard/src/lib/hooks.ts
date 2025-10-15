import { useState, useEffect, useCallback, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import apiClient from './api';
import { debounce } from './utils';
import type {
  Entry,
  DashboardOverview,
  EntryFilters,
  SearchResponse,
  AnalyticsData,
  Insight,
  CalendarEvent,
  Reminder,
  UpdateEntryData,
  BulkUpdateData
} from '@/types';

// Dashboard hooks
export function useDashboardOverview() {
  return useQuery({
    queryKey: ['dashboard', 'overview'],
    queryFn: () => apiClient.getDashboardOverview(),
    staleTime: 5 * 60 * 1000, // 5 minutes
    refetchInterval: 10 * 60 * 1000, // 10 minutes
  });
}

export function useInbox(page = 1, perPage = 20) {
  return useQuery({
    queryKey: ['dashboard', 'inbox', page, perPage],
    queryFn: () => apiClient.getInbox(page, perPage),
    keepPreviousData: true,
  });
}

export function useNeedsAttention(page = 1, perPage = 20) {
  return useQuery({
    queryKey: ['dashboard', 'needs-attention', page, perPage],
    queryFn: () => apiClient.getNeedsAttention(page, perPage),
    keepPreviousData: true,
  });
}

// Entry hooks
export function useEntries(filters: EntryFilters = {}) {
  return useQuery({
    queryKey: ['entries', filters],
    queryFn: () => apiClient.getEntries(filters),
    keepPreviousData: true,
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

export function useEntry(id: number) {
  return useQuery({
    queryKey: ['entries', id],
    queryFn: () => apiClient.getEntry(id),
    enabled: !!id,
  });
}

export function useUpdateEntry() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: UpdateEntryData }) =>
      apiClient.updateEntry(id, data),
    onSuccess: (updatedEntry) => {
      // Update the entry in cache
      queryClient.setQueryData(['entries', updatedEntry.id], updatedEntry);
      
      // Invalidate related queries
      queryClient.invalidateQueries({ queryKey: ['entries'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useCategorizeEntry() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, category }: { id: number; category: string }) =>
      apiClient.categorizeEntry(id, category),
    onSuccess: (updatedEntry) => {
      queryClient.setQueryData(['entries', updatedEntry.id], updatedEntry);
      queryClient.invalidateQueries({ queryKey: ['entries'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useAddTags() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, tags }: { id: number; tags: string[] }) =>
      apiClient.addTagsToEntry(id, tags),
    onSuccess: (updatedEntry) => {
      queryClient.setQueryData(['entries', updatedEntry.id], updatedEntry);
      queryClient.invalidateQueries({ queryKey: ['entries'] });
    },
  });
}

export function useBulkUpdateEntries() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: BulkUpdateData) => apiClient.bulkUpdateEntries(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['entries'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useSimilarEntries(entryId: number) {
  return useQuery({
    queryKey: ['entries', entryId, 'similar'],
    queryFn: () => apiClient.getSimilarEntries(entryId),
    enabled: !!entryId,
    staleTime: 10 * 60 * 1000, // 10 minutes
  });
}

export function useEntriesStats() {
  return useQuery({
    queryKey: ['entries', 'stats'],
    queryFn: () => apiClient.getEntriesStats(),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Search hooks
export function useSearch(query: string, page = 1) {
  return useQuery({
    queryKey: ['search', query, page],
    queryFn: () => apiClient.search(query, page),
    enabled: query.length > 0,
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

export function useSearchSuggestions(query: string) {
  return useQuery({
    queryKey: ['search', 'suggestions', query],
    queryFn: () => apiClient.getSearchSuggestions(query),
    enabled: query.length > 0,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Debounced search hook
export function useDebouncedSearch(initialQuery = '') {
  const [query, setQuery] = useState(initialQuery);
  const [debouncedQuery, setDebouncedQuery] = useState(initialQuery);

  const debouncedSetQuery = useCallback(
    debounce((searchQuery: string) => {
      setDebouncedQuery(searchQuery);
    }, 500),
    []
  );

  useEffect(() => {
    debouncedSetQuery(query);
  }, [query, debouncedSetQuery]);

  const searchResults = useSearch(debouncedQuery);

  return {
    query,
    setQuery,
    debouncedQuery,
    searchResults,
  };
}

// Insights hooks
export function useInsights(type?: string, page = 1) {
  return useQuery({
    queryKey: ['insights', type, page],
    queryFn: () => apiClient.getInsights(type, page),
    keepPreviousData: true,
  });
}

export function useInsight(id: number) {
  return useQuery({
    queryKey: ['insights', id],
    queryFn: () => apiClient.getInsight(id),
    enabled: !!id,
  });
}

export function useGenerateInsight() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (type: string) => apiClient.generateInsight(type),
    onSuccess: () => {
      // Invalidate insights queries after generation
      queryClient.invalidateQueries({ queryKey: ['insights'] });
    },
  });
}

export function useAnalytics() {
  return useQuery({
    queryKey: ['insights', 'analytics'],
    queryFn: () => apiClient.getAnalytics(),
    staleTime: 10 * 60 * 1000, // 10 minutes
  });
}

// Calendar hooks
export function useCalendarEvents(page = 1) {
  return useQuery({
    queryKey: ['calendar-events', page],
    queryFn: () => apiClient.getCalendarEvents(page),
    keepPreviousData: true,
  });
}

export function useCalendarEvent(id: number) {
  return useQuery({
    queryKey: ['calendar-events', id],
    queryFn: () => apiClient.getCalendarEvent(id),
    enabled: !!id,
  });
}

export function useCreateCalendarEvent() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: Partial<CalendarEvent>) =>
      apiClient.createCalendarEvent(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['calendar-events'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useUpdateCalendarEvent() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: Partial<CalendarEvent> }) =>
      apiClient.updateCalendarEvent(id, data),
    onSuccess: (updatedEvent) => {
      queryClient.setQueryData(['calendar-events', updatedEvent.id], updatedEvent);
      queryClient.invalidateQueries({ queryKey: ['calendar-events'] });
    },
  });
}

export function useDeleteCalendarEvent() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => apiClient.deleteCalendarEvent(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['calendar-events'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

// Reminder hooks
export function useReminders(page = 1) {
  return useQuery({
    queryKey: ['reminders', page],
    queryFn: () => apiClient.getReminders(page),
    keepPreviousData: true,
  });
}

export function useCreateReminder() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: Partial<Reminder>) => apiClient.createReminder(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useUpdateReminder() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: Partial<Reminder> }) =>
      apiClient.updateReminder(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
    },
  });
}

export function useDeleteReminder() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => apiClient.deleteReminder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

// UI hooks
export function useLocalStorage<T>(key: string, initialValue: T) {
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (typeof window === 'undefined') return initialValue;
    
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(`Error reading localStorage key "${key}":`, error);
      return initialValue;
    }
  });

  const setValue = useCallback((value: T | ((val: T) => T)) => {
    try {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      
      if (typeof window !== 'undefined') {
        window.localStorage.setItem(key, JSON.stringify(valueToStore));
      }
    } catch (error) {
      console.error(`Error setting localStorage key "${key}":`, error);
    }
  }, [key, storedValue]);

  return [storedValue, setValue] as const;
}

export function useDebounce<T>(value: T, delay: number) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}

export function useClickOutside(
  ref: React.RefObject<HTMLElement>,
  handler: (event: MouseEvent | TouchEvent) => void
) {
  useEffect(() => {
    const listener = (event: MouseEvent | TouchEvent) => {
      if (!ref.current || ref.current.contains(event.target as Node)) {
        return;
      }
      handler(event);
    };

    document.addEventListener('mousedown', listener);
    document.addEventListener('touchstart', listener);

    return () => {
      document.removeEventListener('mousedown', listener);
      document.removeEventListener('touchstart', listener);
    };
  }, [ref, handler]);
}

export function useKeyboard(key: string, callback: () => void) {
  useEffect(() => {
    const handleKeyPress = (event: KeyboardEvent) => {
      if (event.key === key) {
        callback();
      }
    };

    document.addEventListener('keydown', handleKeyPress);
    return () => document.removeEventListener('keydown', handleKeyPress);
  }, [key, callback]);
}

// Intersection Observer hook for lazy loading
export function useIntersectionObserver(
  ref: React.RefObject<Element>,
  options: IntersectionObserverInit = {}
) {
  const [isIntersecting, setIsIntersecting] = useState(false);

  useEffect(() => {
    if (!ref.current) return;

    const observer = new IntersectionObserver(([entry]) => {
      setIsIntersecting(entry.isIntersecting);
    }, options);

    observer.observe(ref.current);

    return () => observer.disconnect();
  }, [ref, options]);

  return isIntersecting;
}