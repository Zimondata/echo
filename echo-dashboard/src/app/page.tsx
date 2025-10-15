'use client';

import { CalendarContainer } from '@/components/calendar';
import { CalendarEvent } from '@/types';

// Mock data for demonstration
const mockEvents: CalendarEvent[] = [
  // Sunday (13th) - Multiple events to test expansion
  {
    id: 1,
    title: 'Тренировка по плаванию с инструктором',
    description: 'Занятие в бассейне',
    start_time: '2024-10-13T15:30:00',
    end_time: '2024-10-13T17:30:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-13T10:00:00',
    updated_at: '2024-10-13T10:00:00'
  },
  {
    id: 2,
    title: 'Запланировано событие на завтра',
    description: 'Важная встреча',
    start_time: '2024-10-13T17:30:00',
    end_time: '2024-10-13T18:30:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-13T10:00:00',
    updated_at: '2024-10-13T10:00:00'
  },
  {
    id: 3,
    title: 'Важная встреча с клиентом по проекту',
    description: 'Обсуждение технических деталей',
    start_time: '2024-10-13T14:00:00',
    end_time: '2024-10-13T15:30:00',
    event_type: 'встреча',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-13T09:00:00',
    updated_at: '2024-10-13T09:00:00'
  },
  {
    id: 4,
    title: 'Утренняя пробежка',
    description: 'Спорт на свежем воздухе',
    start_time: '2024-10-13T07:00:00',
    end_time: '2024-10-13T08:00:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-13T06:00:00',
    updated_at: '2024-10-13T06:00:00'
  },
  // Monday (14th) - Multiple events
  {
    id: 5,
    title: 'Подъем',
    description: 'Начало дня',
    start_time: '2024-10-14T06:00:00',
    end_time: '2024-10-14T07:00:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-14T05:00:00',
    updated_at: '2024-10-14T05:00:00'
  },
  {
    id: 6,
    title: 'Медитация',
    description: 'Утренняя практика',
    start_time: '2024-10-14T06:30:00',
    end_time: '2024-10-14T07:30:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-14T05:30:00',
    updated_at: '2024-10-14T05:30:00'
  },
  {
    id: 7,
    title: 'Тренировка по плаванию',
    description: 'Бассейн с тренером',
    start_time: '2024-10-14T08:00:00',
    end_time: '2024-10-14T09:00:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-14T07:00:00',
    updated_at: '2024-10-14T07:00:00'
  },
  // Tuesday (15th) - Multiple events
  {
    id: 9,
    title: 'Утренняя планерка',
    description: 'Команда разработки',
    start_time: '2024-10-15T09:00:00',
    end_time: '2024-10-15T10:00:00',
    event_type: 'встреча',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-15T08:00:00',
    updated_at: '2024-10-15T08:00:00'
  },
  {
    id: 10,
    title: 'Работа над проектом Echo',
    description: 'Доработка календаря',
    start_time: '2024-10-15T11:00:00',
    end_time: '2024-10-15T15:00:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-15T09:00:00',
    updated_at: '2024-10-15T09:00:00'
  },
  {
    id: 11,
    title: 'Обед с коллегами',
    description: 'Кафе рядом с офисом',
    start_time: '2024-10-15T13:00:00',
    end_time: '2024-10-15T14:00:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-15T12:00:00',
    updated_at: '2024-10-15T12:00:00'
  },
  {
    id: 12,
    title: 'Звонок с клиентом',
    description: 'Обсуждение требований',
    start_time: '2024-10-15T16:00:00',
    end_time: '2024-10-15T17:00:00',
    event_type: 'встреча',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-15T15:00:00',
    updated_at: '2024-10-15T15:00:00'
  },
  // Wednesday (16th) - One event
  {
    id: 8,
    title: 'Совзон по вайб коду',
    description: 'Техническое обсуждение',
    start_time: '2024-10-16T14:00:00',
    end_time: '2024-10-16T16:00:00',
    event_type: 'план',
    google_event_id: undefined,
    google_synced: false,
    created_at: '2024-10-16T10:00:00',
    updated_at: '2024-10-16T10:00:00'
  },
  // Thursday (17th) - No events
  // Friday (18th) - No events  
  // Saturday (19th) - No events
];

export default function Home() {
  const handleEventClick = (event: CalendarEvent) => {
    console.log('Event clicked:', event);
    // Здесь можно открыть модальное окно с деталями события
  };

  const handleTimeSlotClick = (date: Date, hour: number) => {
    console.log('Time slot clicked:', date, hour);
    // Здесь можно открыть форму создания нового события
  };

  return (
    <div className="min-h-screen bg-gray-50 p-4">
      <div className="max-w-7xl mx-auto">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            Echo Dashboard
          </h1>
          <p className="text-gray-600">
            AI-powered personal assistant with smart calendar
          </p>
        </div>
        
        {/* Большой календарь на всю ширину */}
        <CalendarContainer 
          events={mockEvents}
          initialView="compact"
          selectedDate={new Date('2024-10-14')}
          onEventClick={handleEventClick}
          onTimeSlotClick={handleTimeSlotClick}
          className="mb-6"
        />
        
        {/* Только статистика внизу */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Quick stats */}
          <div className="bg-white p-6 rounded-lg shadow-sm border">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">
              📊 Статистика за сегодня
            </h3>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-gray-600">События</span>
                <span className="font-medium">8</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Записи</span>
                <span className="font-medium">12</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Идеи</span>
                <span className="font-medium">4</span>
              </div>
            </div>
          </div>
          
          {/* Recent activity */}
          <div className="bg-white p-6 rounded-lg shadow-sm border">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">
              ⏰ Недавняя активность
            </h3>
            <div className="space-y-3">
              <div className="text-sm">
                <div className="font-medium text-gray-900">
                  Новая тренировка добавлена
                </div>
                <div className="text-gray-500">5 минут назад</div>
              </div>
              <div className="text-sm">
                <div className="font-medium text-gray-900">
                  Встреча с клиентом завершена
                </div>
                <div className="text-gray-500">2 часа назад</div>
              </div>
              <div className="text-sm">
                <div className="font-medium text-gray-900">
                  План "Медитация" выполнен
                </div>
                <div className="text-gray-500">3 часа назад</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
