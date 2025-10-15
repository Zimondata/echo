require "test_helper"

class TimezoneServiceTest < ActiveSupport::TestCase
  test "detects timezone for Madrid coordinates" do
    # Координаты Мадрида: 40.4168, -3.7038
    timezone = TimezoneService.detect_timezone(40.4168, -3.7038)
    assert_equal 'Europe/Madrid', timezone
  end
  
  test "detects timezone for Moscow coordinates" do
    # Координаты Москвы: 55.7558, 37.6176  
    timezone = TimezoneService.detect_timezone(55.7558, 37.6176)
    assert_equal 'Europe/Moscow', timezone
  end
  
  test "detects timezone for Barcelona coordinates" do
    # Координаты Барселоны: 41.3851, 2.1734
    timezone = TimezoneService.detect_timezone(41.3851, 2.1734)
    assert_equal 'Europe/Madrid', timezone
  end
  
  test "parses city names correctly" do
    assert_equal 'Europe/Madrid', TimezoneService.parse_timezone_input('Madrid')
    assert_equal 'Europe/Madrid', TimezoneService.parse_timezone_input('madrid')
    assert_equal 'Europe/Madrid', TimezoneService.parse_timezone_input('Barcelona')
    assert_equal 'Europe/Moscow', TimezoneService.parse_timezone_input('Moscow')
    assert_equal 'Europe/Moscow', TimezoneService.parse_timezone_input('москва')
  end
  
  test "parses timezone names correctly" do
    assert_equal 'Europe/Madrid', TimezoneService.parse_timezone_input('Europe/Madrid')
    assert_equal 'Europe/Moscow', TimezoneService.parse_timezone_input('Europe/Moscow')
    assert_equal 'UTC', TimezoneService.parse_timezone_input('UTC')
  end
  
  test "returns nil for invalid input" do
    assert_nil TimezoneService.parse_timezone_input('InvalidCity')
    assert_nil TimezoneService.parse_timezone_input('NotATimezone')
    assert_nil TimezoneService.parse_timezone_input('')
  end
  
  test "validates timezone names correctly" do
    assert TimezoneService.valid_timezone?('Europe/Madrid')
    assert TimezoneService.valid_timezone?('Europe/Moscow')
    assert TimezoneService.valid_timezone?('UTC')
    assert_not TimezoneService.valid_timezone?('Invalid/Timezone')
    assert_not TimezoneService.valid_timezone?('')
  end
  
  test "provides timezone info" do
    info = TimezoneService.timezone_info('Europe/Madrid')
    
    assert_not_nil info
    assert_equal 'Europe/Madrid', info[:name]
    assert_not_nil info[:current_time]
    assert_not_nil info[:offset]
    assert_not_nil info[:abbreviation]
    assert_includes [true, false], info[:dst]
  end
  
  test "returns spain timezones" do
    spain_timezones = TimezoneService.spain_timezones
    
    assert_includes spain_timezones, 'Europe/Madrid'
    assert_includes spain_timezones, 'Atlantic/Canary'
  end
  
  test "handles case insensitive input" do
    assert_equal 'Europe/Madrid', TimezoneService.parse_timezone_input('MADRID')
    assert_equal 'Europe/Madrid', TimezoneService.parse_timezone_input('MaDrId')
    assert_equal 'Europe/Moscow', TimezoneService.parse_timezone_input('MOSCOW')
  end
  
  test "handles multi-word city names" do
    assert_equal 'America/New_York', TimezoneService.parse_timezone_input('new york')
    assert_equal 'America/New_York', TimezoneService.parse_timezone_input('нью-йорк')
    assert_equal 'America/Los_Angeles', TimezoneService.parse_timezone_input('los angeles')
  end
  
  test "handles partial matches" do
    # Должно найти Barcelona через madrid в составе 
    assert_equal 'Europe/Madrid', TimezoneService.parse_timezone_input('barc')
    assert_equal 'Europe/Moscow', TimezoneService.parse_timezone_input('mosc')
  end
end