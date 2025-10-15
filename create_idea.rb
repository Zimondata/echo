user = User.first

# Создаем идею
idea = user.entries.create!(
  entry_type: "idea",
  content: "Создать мобильное приложение для быстрых заметок с голосовым вводом",
  priority: 8,
  occurred_at: Time.current
)

# Создаем дневниковую запись
diary = user.entries.create!(
  entry_type: "diary", 
  content: "Сегодня был продуктивный день. Много размышлял о новых проектах и возможностях для развития.",
  priority: 6,
  occurred_at: Time.current
)

puts "Создана идея: #{idea.content}"
puts "Создана дневниковая запись: #{diary.content}"