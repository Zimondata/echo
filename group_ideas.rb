user = User.first

# Находим связанные идеи за последние 4 часа
ideas = Entry.where(user: user, entry_type: "idea")
             .where("created_at >= ?", 4.hours.ago)
             .order(:created_at)

puts "Группирую #{ideas.count} связанных идей..."

if ideas.count > 1
  group_id = SecureRandom.uuid
  parent = ideas.first
  
  # Объединяем содержимое всех идей
  combined_content = ideas.first.content + "\n\nСвязанные размышления:\n" + 
                    ideas[1..-1].map { |idea| "• #{idea.content}" }.join("\n")
  
  # Обновляем родительскую запись
  parent.update!(
    group_id: group_id,
    content: combined_content
  )
  
  # Делаем остальные идеи детьми
  ideas[1..-1].each_with_index do |idea, index|
    idea.update!(
      parent_entry: parent,
      group_id: group_id
    )
  end
  
  puts "Готово! Создана группа #{group_id}"
  puts "Родительская запись: #{parent.content[0..50]}..."
  puts "Дочерних записей: #{parent.child_entries.count}"
else
  puts "Нет идей для группировки"
end