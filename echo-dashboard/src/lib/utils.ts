import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import { format, formatDistanceToNow, isToday, isYesterday, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// Date utilities
export function formatDate(date: string | Date, formatStr = 'dd.MM.yyyy'): string {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return format(dateObj, formatStr, { locale: ru });
}

export function formatDateTime(date: string | Date): string {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return format(dateObj, 'dd.MM.yyyy HH:mm', { locale: ru });
}

export function formatRelativeTime(date: string | Date): string {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  
  if (isToday(dateObj)) {
    return `Сегодня в ${format(dateObj, 'HH:mm')}`;
  }
  
  if (isYesterday(dateObj)) {
    return `Вчера в ${format(dateObj, 'HH:mm')}`;
  }
  
  return formatDistanceToNow(dateObj, { addSuffix: true, locale: ru });
}

// Text utilities
export function truncateText(text: string, maxLength = 100): string {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength).trim() + '...';
}

export function highlightText(text: string, query: string): string {
  if (!query || !text) return text;
  
  const regex = new RegExp(`(${query})`, 'gi');
  return text.replace(regex, '<mark>$1</mark>');
}

export function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// Color utilities
export function getEntryTypeColor(type: string): string {
  const colors = {
    diary: 'bg-blue-100 text-blue-800',
    idea: 'bg-yellow-100 text-yellow-800',
    plan: 'bg-green-100 text-green-800',
    plan_update: 'bg-purple-100 text-purple-800'
  };
  
  return colors[type as keyof typeof colors] || 'bg-gray-100 text-gray-800';
}

export function getCategoryColor(category: string): string {
  const colors = {
    inbox: 'bg-gray-100 text-gray-800',
    work: 'bg-blue-100 text-blue-800',
    life: 'bg-green-100 text-green-800',
    health: 'bg-red-100 text-red-800',
    ideas: 'bg-yellow-100 text-yellow-800',
    projects: 'bg-purple-100 text-purple-800'
  };
  
  return colors[category as keyof typeof colors] || 'bg-gray-100 text-gray-800';
}

export function getStatusColor(status: string): string {
  const colors = {
    new: 'bg-red-100 text-red-800',
    triaged: 'bg-yellow-100 text-yellow-800',
    processed: 'bg-green-100 text-green-800',
    archived: 'bg-gray-100 text-gray-800'
  };
  
  return colors[status as keyof typeof colors] || 'bg-gray-100 text-gray-800';
}

export function getPriorityColor(priority: number): string {
  if (priority >= 8) return 'bg-red-100 text-red-800';
  if (priority >= 5) return 'bg-yellow-100 text-yellow-800';
  if (priority >= 3) return 'bg-blue-100 text-blue-800';
  return 'bg-gray-100 text-gray-800';
}

// Data processing utilities
export function groupByDate<T extends { created_at: string }>(items: T[]): Record<string, T[]> {
  return items.reduce((groups, item) => {
    const date = format(parseISO(item.created_at), 'yyyy-MM-dd');
    if (!groups[date]) {
      groups[date] = [];
    }
    groups[date].push(item);
    return groups;
  }, {} as Record<string, T[]>);
}

export function sortByDate<T extends { created_at: string }>(items: T[], order: 'asc' | 'desc' = 'desc'): T[] {
  return [...items].sort((a, b) => {
    const dateA = new Date(a.created_at).getTime();
    const dateB = new Date(b.created_at).getTime();
    return order === 'desc' ? dateB - dateA : dateA - dateB;
  });
}

export function filterByDateRange<T extends { created_at: string }>(
  items: T[], 
  startDate: Date, 
  endDate: Date
): T[] {
  return items.filter(item => {
    const itemDate = parseISO(item.created_at);
    return itemDate >= startDate && itemDate <= endDate;
  });
}

// Search utilities
export function fuzzySearch<T>(items: T[], query: string, keys: (keyof T)[]): T[] {
  if (!query) return items;
  
  const searchQuery = query.toLowerCase();
  
  return items.filter(item =>
    keys.some(key => {
      const value = item[key];
      if (typeof value === 'string') {
        return value.toLowerCase().includes(searchQuery);
      }
      if (Array.isArray(value)) {
        return value.some(v => 
          typeof v === 'string' && v.toLowerCase().includes(searchQuery)
        );
      }
      return false;
    })
  );
}

// Validation utilities
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export function isValidUrl(url: string): boolean {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

// Local storage utilities
export function getFromStorage<T>(key: string, defaultValue: T): T {
  if (typeof window === 'undefined') return defaultValue;
  
  try {
    const item = localStorage.getItem(key);
    return item ? JSON.parse(item) : defaultValue;
  } catch {
    return defaultValue;
  }
}

export function saveToStorage<T>(key: string, value: T): void {
  if (typeof window === 'undefined') return;
  
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (error) {
    console.error('Failed to save to localStorage:', error);
  }
}

export function removeFromStorage(key: string): void {
  if (typeof window === 'undefined') return;
  
  try {
    localStorage.removeItem(key);
  } catch (error) {
    console.error('Failed to remove from localStorage:', error);
  }
}

// Number utilities
export function formatNumber(num: number): string {
  return new Intl.NumberFormat('ru-RU').format(num);
}

export function formatPercentage(value: number, total: number): string {
  if (total === 0) return '0%';
  const percentage = (value / total) * 100;
  return `${percentage.toFixed(1)}%`;
}

// Array utilities
export function unique<T>(array: T[]): T[] {
  return [...new Set(array)];
}

export function groupBy<T, K extends keyof T>(array: T[], key: K): Record<string, T[]> {
  return array.reduce((groups, item) => {
    const groupKey = String(item[key]);
    if (!groups[groupKey]) {
      groups[groupKey] = [];
    }
    groups[groupKey].push(item);
    return groups;
  }, {} as Record<string, T[]>);
}

export function chunk<T>(array: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

// Debounce utility
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout;
  
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(null, args), wait);
  };
}

// Theme utilities
export function getThemePreference(): 'light' | 'dark' | 'system' {
  return getFromStorage('theme', 'system');
}

export function setThemePreference(theme: 'light' | 'dark' | 'system'): void {
  saveToStorage('theme', theme);
}

// Error utilities
export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'Произошла неизвестная ошибка';
}

export function isApiError(error: unknown): error is { response: { data: { error: string } } } {
  return (
    typeof error === 'object' &&
    error !== null &&
    'response' in error &&
    typeof (error as any).response === 'object' &&
    'data' in (error as any).response &&
    typeof (error as any).response.data === 'object' &&
    'error' in (error as any).response.data
  );
}