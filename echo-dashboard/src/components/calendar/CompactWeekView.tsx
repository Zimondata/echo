'use client';

import { useState, useMemo } from 'react';
import { format, startOfWeek, endOfWeek, addDays, isSameDay, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';
import { CalendarEvent } from '@/types';
import { cn } from '@/lib/utils';
import { ChevronLeft, ChevronRight, Calendar, ChevronDown, ChevronUp } from 'lucide-react';

interface CompactWeekViewProps {
  events: CalendarEvent[];
  selectedDate?: Date;
  onEventClick?: (event: CalendarEvent) => void;
  onDateClick?: (date: Date) => void;
  className?: string;
  maxEventsPerDay?: number;
  viewOptions?: Array<{type: string, label: string, icon: any}>;
  currentView?: string;
  onViewChange?: (view: string) => void;
}

export function CompactWeekView({ 
  events = [], 
  selectedDate = new Date(), 
  onEventClick, 
  onDateClick,
  className,
  maxEventsPerDay = 5,
  viewOptions = [],
  currentView,
  onViewChange
}: CompactWeekViewProps) {
  const [currentWeek, setCurrentWeek] = useState(selectedDate);
  const [expandedDays, setExpandedDays] = useState<Record<string, boolean>>({});

  // Calculate week boundaries
  const weekStart = useMemo(() => startOfWeek(currentWeek, { weekStartsOn: 1 }), [currentWeek]);
  const weekEnd = useMemo(() => endOfWeek(currentWeek, { weekStartsOn: 1 }), [currentWeek]);
  const weekDays = useMemo(() => {
    const days = [];
    for (let i = 0; i < 7; i++) {
      days.push(addDays(weekStart, i));
    }
    return days;
  }, [weekStart]);

  // Group events by date
  const eventsByDate = useMemo(() => {
    const grouped: { [key: string]: CalendarEvent[] } = {};
    
    events.forEach(event => {
      const eventDate = parseISO(event.start_time);
      const dayKey = format(eventDate, 'yyyy-MM-dd');
      
      if (!grouped[dayKey]) {
        grouped[dayKey] = [];
      }
      grouped[dayKey].push(event);
    });
    
    // Sort events by start time for each day
    Object.keys(grouped).forEach(dayKey => {
      grouped[dayKey].sort((a, b) => 
        parseISO(a.start_time).getTime() - parseISO(b.start_time).getTime()
      );
    });
    
    return grouped;
  }, [events]);

  // Get events for a specific day
  const getEventsForDay = (day: Date) => {
    const dayKey = format(day, 'yyyy-MM-dd');
    return eventsByDate[dayKey] || [];
  };

  // Check if day is expanded
  const isDayExpanded = (day: Date) => {
    const dayKey = format(day, 'yyyy-MM-dd');
    return !!expandedDays[dayKey];
  };

  // Toggle day expansion
  const toggleDayExpansion = (day: Date) => {
    const dayKey = format(day, 'yyyy-MM-dd');
    setExpandedDays(prev => ({
      ...prev,
      [dayKey]: !prev[dayKey]
    }));
  };

  const navigateWeek = (direction: 'prev' | 'next') => {
    setCurrentWeek(prev => {
      const days = direction === 'next' ? 7 : -7;
      return addDays(prev, days);
    });
  };

  const goToToday = () => {
    setCurrentWeek(new Date());
  };

  const getEventTypeColor = (eventType: string) => {
    switch (eventType?.toLowerCase()) {
      case 'встреча':
      case 'meeting':
        return 'bg-red-100 border-red-300 text-red-800';
      case 'план':
      case 'plan':
        return 'bg-purple-100 border-purple-300 text-purple-800';
      case 'задача':
      case 'task':
        return 'bg-blue-100 border-blue-300 text-blue-800';
      case 'отдых':
      case 'rest':
        return 'bg-green-100 border-green-300 text-green-800';
      default:
        return 'bg-gray-100 border-gray-300 text-gray-800';
    }
  };

  const isToday = (date: Date) => {
    return isSameDay(date, new Date());
  };

  const isSelected = (date: Date) => {
    return isSameDay(date, selectedDate);
  };

  return (
    <div className={cn("bg-white rounded-lg shadow-sm border", className)}>
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <Calendar className="h-5 w-5 text-orange-600" />
            <h2 className="text-xl font-semibold text-gray-900">
              Календарь на неделю
            </h2>
          </div>

          {/* View Controls встроенные */}
          {viewOptions.length > 0 && onViewChange && (
            <div className="flex bg-gray-100 rounded-lg p-1">
              {viewOptions.map(({ type, label, icon: Icon }) => (
                <button
                  key={type}
                  onClick={() => onViewChange(type)}
                  className={cn(
                    "flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-all",
                    currentView === type
                      ? "bg-white text-orange-700 shadow-sm"
                      : "text-gray-600 hover:text-gray-900 hover:bg-gray-50"
                  )}
                >
                  <Icon className="h-4 w-4" />
                  {label}
                </button>
              ))}
            </div>
          )}
          
          <div className="flex items-center gap-2">
            <button
              onClick={() => navigateWeek('prev')}
              className="p-1 hover:bg-gray-100 rounded"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            
            <span className="text-sm font-medium text-gray-700">
              {format(weekStart, 'd MMM', { locale: ru })} - {format(weekEnd, 'd MMM yyyy', { locale: ru })}
            </span>
            
            <button
              onClick={() => navigateWeek('next')}
              className="p-1 hover:bg-gray-100 rounded"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
        
        <button
          onClick={goToToday}
          className="px-3 py-1 text-sm bg-orange-100 text-orange-700 hover:bg-orange-200 rounded-md transition-colors"
        >
          Сегодня
        </button>
      </div>

      {/* Calendar Grid */}
      <div className="grid grid-cols-7 divide-x">
        {weekDays.map((day, index) => {
          const dayEvents = getEventsForDay(day);
          const isExpanded = isDayExpanded(day);
          const visibleEvents = isExpanded ? dayEvents : dayEvents.slice(0, maxEventsPerDay);
          const hiddenEventsCount = dayEvents.length - maxEventsPerDay;
          const hasMoreEvents = hiddenEventsCount > 0;
          
          
          return (
            <div
              key={index}
              className={cn(
                "min-h-[400px] p-4", // Увеличили высоту с 200px до 400px и отступы
                isToday(day) && "bg-orange-50/50"
              )}
            >
              {/* Day Header */}
              <div
                className={cn(
                  "text-center pb-3 cursor-pointer hover:bg-gray-50 rounded-md p-2 -m-2 mb-1 group",
                  "select-none transition-colors duration-200 border-2 border-transparent hover:border-blue-200",
                  isToday(day) && "bg-orange-100 rounded-md",
                  "active:bg-blue-100 active:scale-95 transform"
                )}
                onClick={() => {
                  onDateClick?.(day);
                  // Автоматически раскрываем все события дня при клике на дату
                  if (dayEvents.length > maxEventsPerDay) {
                    toggleDayExpansion(day);
                  }
                }}
                title="Нажмите, чтобы показать все события дня"
              >
                <div className="text-xs text-gray-500 uppercase">
                  {format(day, 'EEE', { locale: ru })}
                </div>
                <div className={cn(
                  "text-lg font-semibold mt-1",
                  isToday(day) ? "text-orange-600" : "text-gray-900",
                  isSelected(day) && "text-blue-600"
                )}>
                  {format(day, 'd')}
                </div>
                <div className="text-xs text-gray-500">
                  {isToday(day) ? 'Сегодня' : format(day, 'MMM', { locale: ru })}
                </div>
                {dayEvents.length > maxEventsPerDay && (
                  <div className="text-xs text-blue-600 opacity-0 group-hover:opacity-100 transition-opacity mt-1">
                    📋 Показать все события
                  </div>
                )}
              </div>

              {/* Events */}
              <div className="space-y-1">
                {visibleEvents.map((event, eventIndex) => (
                  <div
                    key={event.id}
                    className={cn(
                      "p-2 rounded-md border text-xs cursor-pointer",
                      "transition-all hover:shadow-sm",
                      getEventTypeColor(event.event_type)
                    )}
                    onClick={(e) => {
                      e.stopPropagation();
                      onEventClick?.(event);
                    }}
                  >
                    <div className="font-medium truncate mb-1">
                      {event.title}
                    </div>
                    <div className="text-xs opacity-75">
                      {format(parseISO(event.start_time), 'HH:mm')}
                      {event.end_time && (
                        <> - {format(parseISO(event.end_time), 'HH:mm')}</>
                      )}
                    </div>
                    <div className="text-xs mt-1 px-1 py-0.5 bg-white/30 rounded text-center">
                      {event.event_type === 'план' ? 'План' : 
                       event.event_type === 'встреча' ? 'Встреча' : 
                       event.event_type === 'идея' ? 'Идея' : 
                       event.event_type === 'дневник' ? 'Дневник' : 
                       event.event_type}
                    </div>
                  </div>
                ))}

                {/* Show More / Show Less Button */}
                {hasMoreEvents && (
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      toggleDayExpansion(day);
                    }}
                    className="w-full py-2 text-xs text-gray-600 hover:text-gray-900 hover:bg-gray-50 rounded-md transition-colors flex items-center justify-center gap-1"
                  >
                    {isExpanded ? (
                      <>
                        <ChevronUp className="h-3 w-3" />
                        Скрыть
                      </>
                    ) : (
                      <>
                        <ChevronDown className="h-3 w-3" />
                        + еще {hiddenEventsCount}
                      </>
                    )}
                  </button>
                )}

                {/* Empty state */}
                {dayEvents.length === 0 && (
                  <div className="text-center text-gray-400 text-xs py-6">
                    <div className="opacity-60">
                      Нет событий
                    </div>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Footer */}
      <div className="p-3 border-t bg-gray-50/50 text-xs text-gray-500">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded border border-red-300 bg-red-100"></div>
            <span>Встречи</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded border border-purple-300 bg-purple-100"></div>
            <span>Планы</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded border border-blue-300 bg-blue-100"></div>
            <span>Задачи</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded border border-green-300 bg-green-100"></div>
            <span>Отдых</span>
          </div>
        </div>
      </div>
    </div>
  );
}