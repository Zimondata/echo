'use client';

import { useState, useEffect, useMemo } from 'react';
import { format, startOfWeek, endOfWeek, addDays, addHours, startOfDay, isSameDay, parseISO, isWithinInterval } from 'date-fns';
import { ru } from 'date-fns/locale';
import { CalendarEvent } from '@/types';
import { cn } from '@/lib/utils';
import { ChevronLeft, ChevronRight, Calendar } from 'lucide-react';

interface WeekViewProps {
  events: CalendarEvent[];
  selectedDate?: Date;
  onEventClick?: (event: CalendarEvent) => void;
  onTimeSlotClick?: (date: Date, hour: number) => void;
  className?: string;
}

export function WeekView({ 
  events = [], 
  selectedDate = new Date(), 
  onEventClick, 
  onTimeSlotClick,
  className 
}: WeekViewProps) {
  const [currentWeek, setCurrentWeek] = useState(selectedDate);

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

  // Time slots configuration
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

    // If there are no events, show 3-hour intervals from 9 AM to 6 PM
    if (events.length === 0) {
      for (let hour = 9; hour <= 18; hour += 3) {
        slots.push(hour);
      }
    } else {
      // Show hourly slots from earliest to latest event, with some padding
      const startHour = Math.max(6, earliestEvent - 1);
      const endHour = Math.min(22, latestEvent + 2);
      
      for (let hour = startHour; hour <= endHour; hour++) {
        slots.push(hour);
      }
    }

    return slots;
  }, [events]);

  // Group events by date and time
  const eventsByDateTime = useMemo(() => {
    const grouped: { [key: string]: CalendarEvent[] } = {};
    
    events.forEach(event => {
      const eventDate = parseISO(event.start_time);
      const dayKey = format(eventDate, 'yyyy-MM-dd');
      const hourKey = eventDate.getHours();
      const key = `${dayKey}-${hourKey}`;
      
      if (!grouped[key]) {
        grouped[key] = [];
      }
      grouped[key].push(event);
    });
    
    return grouped;
  }, [events]);

  // Get events for a specific day and hour
  const getEventsForTimeSlot = (day: Date, hour: number) => {
    const dayKey = format(day, 'yyyy-MM-dd');
    const key = `${dayKey}-${hour}`;
    return eventsByDateTime[key] || [];
  };

  // Check if a time slot overlaps with any event
  const hasEventsInTimeSlot = (day: Date, hour: number) => {
    return events.some(event => {
      const eventStart = parseISO(event.start_time);
      const eventEnd = event.end_time ? parseISO(event.end_time) : addHours(eventStart, 1);
      const slotStart = addHours(startOfDay(day), hour);
      const slotEnd = addHours(slotStart, 1);
      
      return isWithinInterval(eventStart, { start: slotStart, end: slotEnd }) ||
             isWithinInterval(slotStart, { start: eventStart, end: eventEnd });
    });
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

  const formatTime = (hour: number) => {
    return format(addHours(startOfDay(new Date()), hour), 'HH:mm');
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
      <div className="overflow-x-auto">
        <div className="min-w-full">
          {/* Days Header */}
          <div className="grid grid-cols-8 border-b bg-gray-50">
            <div className="p-3 border-r text-xs font-medium text-gray-500">
              Время
            </div>
            {weekDays.map((day, index) => (
              <div
                key={index}
                className={cn(
                  "p-3 border-r last:border-r-0 text-center",
                  isToday(day) && "bg-orange-50"
                )}
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
                <div className="text-xs text-gray-500 mt-1">
                  {isToday(day) ? 'Сегодня' : format(day, 'MMM', { locale: ru })}
                </div>
              </div>
            ))}
          </div>

          {/* Time Slots */}
          {TIME_SLOTS.map((hour) => (
            <div key={hour} className="grid grid-cols-8 border-b hover:bg-gray-50/50">
              {/* Time Column */}
              <div className="p-3 border-r bg-gray-50/50 text-right">
                <span className="text-sm font-medium text-gray-600">
                  {formatTime(hour)}
                </span>
              </div>

              {/* Day Columns */}
              {weekDays.map((day, dayIndex) => {
                const timeSlotEvents = getEventsForTimeSlot(day, hour);
                const hasEvents = timeSlotEvents.length > 0;
                
                return (
                  <div
                    key={`${dayIndex}-${hour}`}
                    className={cn(
                      "p-2 border-r last:border-r-0 min-h-[80px] relative",
                      "cursor-pointer hover:bg-blue-50/30 transition-colors",
                      isToday(day) && "bg-orange-50/20"
                    )}
                    onClick={() => onTimeSlotClick?.(day, hour)}
                  >
                    {/* Events in this time slot */}
                    {timeSlotEvents.map((event, eventIndex) => (
                      <div
                        key={event.id}
                        className={cn(
                          "mb-1 p-2 rounded-md border text-xs cursor-pointer",
                          "transition-all hover:shadow-sm",
                          getEventTypeColor(event.event_type),
                          eventIndex > 0 && "mt-1"
                        )}
                        onClick={(e) => {
                          e.stopPropagation();
                          onEventClick?.(event);
                        }}
                      >
                        <div className="font-medium truncate">
                          {event.title}
                        </div>
                        <div className="text-xs opacity-75 mt-1">
                          {format(parseISO(event.start_time), 'HH:mm')}
                          {event.end_time && (
                            <> - {format(parseISO(event.end_time), 'HH:mm')}</>
                          )}
                        </div>
                      </div>
                    ))}

                    {/* Empty state indicator */}
                    {!hasEvents && (
                      <div className="text-center text-gray-400 text-xs py-4">
                        <div className="opacity-0 hover:opacity-60 transition-opacity">
                          + Добавить событие
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          ))}

          {/* Empty State */}
          {events.length === 0 && (
            <div className="p-8 text-center text-gray-500">
              <Calendar className="h-8 w-8 mx-auto mb-3 text-gray-400" />
              <p className="text-sm">Нет событий на эту неделю</p>
              <p className="text-xs text-gray-400 mt-1">
                Нажмите на временной слот, чтобы добавить событие
              </p>
            </div>
          )}
        </div>
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