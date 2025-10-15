'use client';

import { useState, useMemo } from 'react';
import { format, addHours, startOfDay, parseISO, isWithinInterval } from 'date-fns';
import { ru } from 'date-fns/locale';
import { CalendarEvent } from '@/types';
import { cn } from '@/lib/utils';
import { ChevronLeft, ChevronRight, Calendar, Plus } from 'lucide-react';

interface DayViewProps {
  date: Date;
  events: CalendarEvent[];
  onEventClick?: (event: CalendarEvent) => void;
  onTimeSlotClick?: (date: Date, hour: number) => void;
  className?: string;
}

export function DayView({ 
  date, 
  events = [], 
  onEventClick, 
  onTimeSlotClick,
  className 
}: DayViewProps) {
  const [selectedDate, setSelectedDate] = useState(date);

  // Time slots configuration - create a comprehensive time grid
  const TIME_SLOTS = useMemo(() => {
    const slots = [];
    const earliestEvent = events.reduce((earliest, event) => {
      const eventHour = parseISO(event.start_time).getHours();
      return eventHour < earliest ? eventHour : earliest;
    }, 9); // Default to 9 AM

    const latestEvent = events.reduce((latest, event) => {
      const endTime = event.end_time ? parseISO(event.end_time) : parseISO(event.start_time);
      const eventHour = endTime.getHours();
      return eventHour > latest ? eventHour : latest;
    }, 18); // Default to 6 PM

    // If there are no events, show 3-hour intervals from 6 AM to 10 PM
    if (events.length === 0) {
      for (let hour = 6; hour <= 22; hour += 3) {
        slots.push(hour);
      }
    } else {
      // Show all hours from earliest to latest event, with padding
      const startHour = Math.max(6, earliestEvent - 1);
      const endHour = Math.min(23, latestEvent + 2);
      
      for (let hour = startHour; hour <= endHour; hour++) {
        slots.push(hour);
      }
    }

    return slots;
  }, [events]);

  // Group events by hour
  const eventsByHour = useMemo(() => {
    const grouped: { [key: number]: CalendarEvent[] } = {};
    
    events.forEach(event => {
      const eventDate = parseISO(event.start_time);
      const hour = eventDate.getHours();
      
      if (!grouped[hour]) {
        grouped[hour] = [];
      }
      grouped[hour].push(event);
    });
    
    return grouped;
  }, [events]);

  // Get events for a specific hour
  const getEventsForHour = (hour: number) => {
    return eventsByHour[hour] || [];
  };

  const navigateDay = (direction: 'prev' | 'next') => {
    const newDate = new Date(selectedDate);
    newDate.setDate(selectedDate.getDate() + (direction === 'next' ? 1 : -1));
    setSelectedDate(newDate);
  };

  const goToToday = () => {
    setSelectedDate(new Date());
  };

  const formatTime = (hour: number) => {
    return format(addHours(startOfDay(new Date()), hour), 'HH:mm');
  };

  const getEventTypeColor = (eventType: string) => {
    switch (eventType?.toLowerCase()) {
      case 'встреча':
      case 'meeting':
        return 'bg-red-100 border-l-red-500 text-red-800';
      case 'план':
      case 'plan':
        return 'bg-purple-100 border-l-purple-500 text-purple-800';
      case 'задача':
      case 'task':
        return 'bg-blue-100 border-l-blue-500 text-blue-800';
      case 'отдых':
      case 'rest':
        return 'bg-green-100 border-l-green-500 text-green-800';
      default:
        return 'bg-gray-100 border-l-gray-500 text-gray-800';
    }
  };

  const getEventDuration = (event: CalendarEvent) => {
    if (!event.end_time) return '';
    
    const start = parseISO(event.start_time);
    const end = parseISO(event.end_time);
    const duration = (end.getTime() - start.getTime()) / (1000 * 60); // minutes
    
    if (duration < 60) {
      return `${duration} мин`;
    } else {
      const hours = Math.floor(duration / 60);
      const mins = duration % 60;
      return mins > 0 ? `${hours}ч ${mins}м` : `${hours}ч`;
    }
  };

  return (
    <div className={cn("bg-white rounded-lg shadow-sm border overflow-hidden", className)}>
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b bg-gray-50">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <Calendar className="h-5 w-5 text-orange-600" />
            <h2 className="text-xl font-semibold text-gray-900">
              {format(selectedDate, 'EEEE, d MMMM yyyy', { locale: ru })}
            </h2>
          </div>
          
          <div className="flex items-center gap-2">
            <button
              onClick={() => navigateDay('prev')}
              className="p-2 hover:bg-gray-200 rounded-md transition-colors"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            
            <button
              onClick={() => navigateDay('next')}
              className="p-2 hover:bg-gray-200 rounded-md transition-colors"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
        
        <div className="flex items-center gap-2">
          <button
            onClick={goToToday}
            className="px-3 py-2 text-sm bg-orange-100 text-orange-700 hover:bg-orange-200 rounded-md transition-colors"
          >
            Сегодня
          </button>
        </div>
      </div>

      {/* Time Grid */}
      <div className="relative">
        {/* All-day events section (if any) */}
        <div className="border-b bg-gray-50/50 p-3">
          <div className="text-xs text-gray-500 mb-2">Весь день</div>
          {events.filter(e => !e.end_time || (parseISO(e.end_time).getTime() - parseISO(e.start_time).getTime()) >= 24 * 60 * 60 * 1000).length === 0 ? (
            <div className="text-xs text-gray-400 italic">Нет событий</div>
          ) : (
            // All-day events would go here
            <div className="text-xs text-gray-400">All-day events</div>
          )}
        </div>

        {/* Time slots */}
        <div className="relative">
          {TIME_SLOTS.map((hour, index) => {
            const hourEvents = getEventsForHour(hour);
            const isEvenHour = hour % 2 === 0;
            
            return (
              <div 
                key={hour} 
                className={cn(
                  "grid grid-cols-[80px_1fr] border-b",
                  isEvenHour ? "bg-white" : "bg-gray-50/30"
                )}
              >
                {/* Time label */}
                <div className="p-4 border-r bg-gray-50 text-right">
                  <div className="text-sm font-medium text-gray-600">
                    {formatTime(hour)}
                  </div>
                </div>

                {/* Event area */}
                <div 
                  className="min-h-[80px] p-3 relative cursor-pointer hover:bg-blue-50/30 transition-colors"
                  onClick={() => onTimeSlotClick?.(selectedDate, hour)}
                >
                  {/* Events for this hour */}
                  {hourEvents.map((event, eventIndex) => (
                    <div
                      key={event.id}
                      className={cn(
                        "mb-2 p-3 rounded-lg border-l-4 cursor-pointer",
                        "transition-all hover:shadow-md hover:scale-[1.01]",
                        getEventTypeColor(event.event_type)
                      )}
                      onClick={(e) => {
                        e.stopPropagation();
                        onEventClick?.(event);
                      }}
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <div className="font-semibold text-sm mb-1">
                            {event.title}
                          </div>
                          <div className="text-xs opacity-75 mb-1">
                            {format(parseISO(event.start_time), 'HH:mm')}
                            {event.end_time && (
                              <>
                                {' - '}
                                {format(parseISO(event.end_time), 'HH:mm')}
                              </>
                            )}
                          </div>
                          {event.description && (
                            <div className="text-xs opacity-60 truncate">
                              {event.description}
                            </div>
                          )}
                        </div>
                        <div className="ml-2 flex flex-col items-end">
                          <div className="text-xs opacity-60">
                            {getEventDuration(event)}
                          </div>
                          <div className="text-xs px-2 py-1 rounded-full bg-white/50 mt-1">
                            {event.event_type === 'встреча' ? 'Встреча' : 'План'}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}

                  {/* Empty slot indicator */}
                  {hourEvents.length === 0 && (
                    <div className="h-full flex items-center justify-center text-gray-400">
                      <div className="text-center opacity-0 hover:opacity-60 transition-opacity">
                        <Plus className="h-4 w-4 mx-auto mb-1" />
                        <div className="text-xs">Добавить событие</div>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Empty State */}
        {events.length === 0 && (
          <div className="p-12 text-center text-gray-500">
            <Calendar className="h-12 w-12 mx-auto mb-4 text-gray-400" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              Нет событий на {format(selectedDate, 'd MMMM', { locale: ru })}
            </h3>
            <p className="text-sm text-gray-500 mb-4">
              Нажмите на любой временной слот, чтобы добавить событие
            </p>
            <button className="px-4 py-2 bg-orange-100 text-orange-700 hover:bg-orange-200 rounded-md transition-colors text-sm">
              + Добавить событие
            </button>
          </div>
        )}
      </div>

      {/* Footer with event summary */}
      {events.length > 0 && (
        <div className="p-4 border-t bg-gray-50">
          <div className="flex items-center justify-between text-sm text-gray-600">
            <div>
              Всего событий: <span className="font-medium text-gray-900">{events.length}</span>
            </div>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-1">
                <div className="w-3 h-3 rounded border-l-4 border-l-red-500 bg-red-100"></div>
                <span>Встречи ({events.filter(e => e.event_type === 'встреча').length})</span>
              </div>
              <div className="flex items-center gap-1">
                <div className="w-3 h-3 rounded border-l-4 border-l-purple-500 bg-purple-100"></div>
                <span>Планы ({events.filter(e => e.event_type === 'план').length})</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}