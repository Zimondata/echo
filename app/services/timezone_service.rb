class TimezoneService
  # Карта городов к timezone
  CITY_TIMEZONES = {
    # Испания
    'madrid' => 'Europe/Madrid',
    'barcelona' => 'Europe/Madrid', 
    'valencia' => 'Europe/Madrid',
    'sevilla' => 'Europe/Madrid',
    'zaragoza' => 'Europe/Madrid',
    'malaga' => 'Europe/Madrid',
    'murcia' => 'Europe/Madrid',
    'palma' => 'Europe/Madrid',
    'bilbao' => 'Europe/Madrid',
    'granada' => 'Europe/Madrid',
    
    # Россия
    'moscow' => 'Europe/Moscow',
    'москва' => 'Europe/Moscow',
    'spb' => 'Europe/Moscow',
    'petersburg' => 'Europe/Moscow',
    'питер' => 'Europe/Moscow',
    'санкт-петербург' => 'Europe/Moscow',
    'новосибирск' => 'Asia/Novosibirsk',
    'екатеринбург' => 'Asia/Yekaterinburg',
    
    # Другие популярные города
    'london' => 'Europe/London',
    'лондон' => 'Europe/London',
    'paris' => 'Europe/Paris',
    'париж' => 'Europe/Paris',
    'berlin' => 'Europe/Berlin',
    'берлин' => 'Europe/Berlin',
    'rome' => 'Europe/Rome',
    'рим' => 'Europe/Rome',
    'amsterdam' => 'Europe/Amsterdam',
    'амстердам' => 'Europe/Amsterdam',
    'vienna' => 'Europe/Vienna',
    'вена' => 'Europe/Vienna',
    'zurich' => 'Europe/Zurich',
    'цюрих' => 'Europe/Zurich',
    
    # США
    'new york' => 'America/New_York',
    'нью-йорк' => 'America/New_York',
    'los angeles' => 'America/Los_Angeles',
    'лос-анджелес' => 'America/Los_Angeles',
    'chicago' => 'America/Chicago',
    'чикаго' => 'America/Chicago',
    
    # Азия
    'tokyo' => 'Asia/Tokyo',
    'токио' => 'Asia/Tokyo',
    'beijing' => 'Asia/Shanghai',
    'пекин' => 'Asia/Shanghai',
    'dubai' => 'Asia/Dubai',
    'дубай' => 'Asia/Dubai',
    'singapore' => 'Asia/Singapore',
    'сингапур' => 'Asia/Singapore'
  }.freeze
  
  # Определение timezone по геолокации (упрощенная версия)
  def self.detect_timezone(latitude, longitude)
    # Простая логика на основе долготы для основных зон
    # В продакшене лучше использовать API вроде TimeZoneDB или Google Maps
    
    case longitude
    when -15..0  # Великобритания
      'Europe/London'
    when 0..15   # Центральная Европа  
      case latitude
      when 35..45  # Испания, юг Европы
        'Europe/Madrid'
      when 45..55  # Центральная Европа
        'Europe/Berlin'
      else
        'Europe/Paris'
      end
    when 15..45  # Восточная Европа
      case latitude
      when 50..70
        'Europe/Moscow'
      else
        'Europe/Kiev'
      end
    when 45..180 # Азия
      case longitude
      when 45..90
        'Asia/Yekaterinburg'
      when 90..120
        'Asia/Shanghai'
      else
        'Asia/Tokyo'
      end
    when -180..-90 # Западное побережье США
      'America/Los_Angeles'
    when -90..-60  # Центральные штаты США
      'America/Chicago'
    when -60..0    # Восточное побережье США
      'America/New_York'
    else
      'UTC'
    end
  rescue StandardError => e
    Rails.logger.error "Timezone detection error: #{e.message}"
    nil
  end
  
  # Парсинг пользовательского ввода
  def self.parse_timezone_input(input)
    normalized_input = input.strip.downcase
    
    # Проверяем прямое соответствие timezone
    if valid_timezone?(input)
      return input
    end
    
    # Ищем в карте городов
    city_timezone = CITY_TIMEZONES[normalized_input]
    return city_timezone if city_timezone
    
    # Ищем частичное соответствие
    CITY_TIMEZONES.each do |city, timezone|
      if city.include?(normalized_input) || normalized_input.include?(city)
        return timezone
      end
    end
    
    # Пытаемся найти в списке доступных timezone
    available_zones = ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:name)
    
    # Ищем точное соответствие (case insensitive)
    exact_match = available_zones.find { |zone| zone.downcase == normalized_input }
    return exact_match if exact_match
    
    # Ищем частичное соответствие
    partial_match = available_zones.find { |zone| zone.downcase.include?(normalized_input) }
    return partial_match if partial_match
    
    nil
  end
  
  # Проверка валидности timezone
  def self.valid_timezone?(timezone_name)
    TZInfo::Timezone.get(timezone_name)
    true
  rescue TZInfo::InvalidTimezoneIdentifier
    false
  end
  
  # Получение списка популярных timezone для Испании
  def self.spain_timezones
    [
      'Europe/Madrid',    # Материковая Испания
      'Atlantic/Canary'   # Канарские острова
    ]
  end
  
  # Получение информации о timezone
  def self.timezone_info(timezone_name)
    return nil unless valid_timezone?(timezone_name)
    
    tz = TZInfo::Timezone.get(timezone_name)
    current_time = Time.current.in_time_zone(timezone_name)
    
    {
      name: timezone_name,
      current_time: current_time,
      offset: current_time.formatted_offset,
      abbreviation: current_time.zone,
      dst: tz.current_period.dst?
    }
  rescue StandardError => e
    Rails.logger.error "Timezone info error: #{e.message}"
    nil
  end
end