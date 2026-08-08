module ProjectsHelper
  def task_count_label(count)
    number = count.to_i
    word = if (11..14).cover?(number % 100)
      "задач"
    else
      case number % 10
      when 1 then "задача"
      when 2..4 then "задачи"
      else "задач"
      end
    end

    "#{number} #{word}"
  end
end
