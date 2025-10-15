user = User.first
entry = Entry.where(user: user).last
puts "Создаю событие для: #{entry.content}"

event = user.calendar_events.create!(
  entry: entry,
  title: "Плавание дочки",
  description: entry.content,
  start_time: Time.current.in_time_zone(user.timezone).change(hour: 17, min: 30),
  event_type: "plan"
)

puts "Создано событие: #{event.title} в #{event.start_time.strftime('%H:%M')}"