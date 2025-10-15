'use client';

import { useState } from 'react';
import { WeekView } from './WeekView';
import { DayView } from './DayView';
import { CompactWeekView } from './CompactWeekView';
import { CalendarEvent } from '@/types';
import { cn } from '@/lib/utils';
import { CalendarDays, Calendar, List, Grid } from 'lucide-react';

type ViewType = 'compact' | 'week' | 'month' | 'day';

interface CalendarContainerProps {
  events: CalendarEvent[];
  initialView?: ViewType;
  selectedDate?: Date;
  onEventClick?: (event: CalendarEvent) => void;
  onTimeSlotClick?: (date: Date, hour: number) => void;
  className?: string;
}

export function CalendarContainer({ 
  events = [], 
  initialView = 'compact',
  selectedDate = new Date(),
  onEventClick, 
  onTimeSlotClick,
  className 
}: CalendarContainerProps) {
  const [currentView, setCurrentView] = useState<ViewType>(initialView);
  const [currentDate, setCurrentDate] = useState(selectedDate);

  const viewOptions = [
    {
      type: 'compact' as ViewType,
      label: 'Неделя',
      icon: CalendarDays,
    },
    {
      type: 'month' as ViewType,
      label: 'Месяц',
      icon: Grid,
    },
    {
      type: 'day' as ViewType,
      label: 'День',
      icon: Calendar,
    },
  ];

  const handleTimeSlotClick = (date: Date, hour: number) => {
    setCurrentDate(date);
    onTimeSlotClick?.(date, hour);
  };

  const handleEventClick = (event: CalendarEvent) => {
    onEventClick?.(event);
  };

  const handleDateClick = (date: Date) => {
    setCurrentDate(date);
    // Не переключаем вид - оставляем в компактном виде
  };

  return (
    <div className={cn("space-y-4", className)}>

      {/* Calendar Views */}
      <div className="calendar-container">
        {currentView === 'compact' && (
          <CompactWeekView
            events={events}
            selectedDate={currentDate}
            onEventClick={handleEventClick}
            onDateClick={handleDateClick}
            maxEventsPerDay={5}
            viewOptions={viewOptions}
            currentView={currentView}
            onViewChange={setCurrentView}
          />
        )}
        
        {currentView === 'month' && (
          <CompactWeekView
            events={events}
            selectedDate={currentDate}
            onEventClick={handleEventClick}
            onDateClick={handleDateClick}
            maxEventsPerDay={2}
            viewOptions={viewOptions}
            currentView={currentView}
            onViewChange={setCurrentView}
          />
        )}
        
        {currentView === 'day' && (
          <DayView
            date={currentDate}
            events={events.filter(event => {
              const eventDate = new Date(event.start_time);
              return eventDate.toDateString() === currentDate.toDateString();
            })}
            onEventClick={handleEventClick}
            onTimeSlotClick={handleTimeSlotClick}
          />
        )}
      </div>
    </div>
  );
}