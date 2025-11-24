class DashboardV3TestController < ApplicationController
  before_action :ensure_current_user

  def index
    @user = current_user
    @today = Date.current
    
    # Sample habits
    @habits = [
      { id: 1, title: 'Подъем в 7 утра', done: false, streak: 5 },
      { id: 2, title: 'Холодный душ', done: false, streak: 3 },
      { id: 3, title: 'Дыхательная практика', done: true, streak: 12 },
      { id: 4, title: 'Медитация 10 минут', done: false, streak: 7 }
    ]
    
    # Sample all-day tasks
    @all_day_tasks = [
      { id: 5, title: 'Поесть чипсы с мороженным', done: false },
      { id: 6, title: 'Посмотреть Гарри Поттера с дочкой', done: false }
    ]
    
    # Sample timed tasks (timeline)
    @timed_tasks = [
      { id: 7, title: 'Возможно телеграму', time: '09:00', done: false, category: 'work' },
      { id: 8, title: 'Подъем', time: '10:00', done: false, category: 'personal' },
      { id: 9, title: 'Отправить фактуры хисторе', time: '11:00', done: false, category: 'work' },
      { id: 10, title: 'Тренировка', time: '15:00', done: false, category: 'health' },
      { id: 11, title: 'Просмотр видео МСР', time: '18:00', done: false, category: 'learning' }
    ]
  end

  private

  def ensure_current_user
    redirect_to login_path, alert: 'Пожалуйста, войдите в систему' unless current_user
  end
end
