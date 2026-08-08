class TaskStepsController < ApplicationController
  InvalidLockVersion = Class.new(StandardError)
  TaskRevisionConflict = Class.new(StandardError)

  before_action :set_task
  before_action :ensure_mutable_task!
  before_action :set_step, only: %i[toggle destroy]

  def create
    mutate_parent! do
      @task.task_steps.create!(
        text: step_params[:text],
        position: (@task.task_steps.maximum(:position) || -1) + 1
      )
    end
    redirect_to tasks_path(status: @task.status), notice: "Шаг добавлен"
  rescue ActiveRecord::RecordInvalid => error
    render plain: error.record.errors.full_messages.to_sentence, status: :unprocessable_entity
  rescue InvalidLockVersion, TaskRevisionConflict
    redirect_task_conflict
  end

  def toggle
    mutate_parent! do
      @step.update!(completed_at: @step.completed? ? nil : Time.current)
    end
    redirect_to tasks_path(status: @task.status), notice: "Шаг обновлён"
  rescue InvalidLockVersion, TaskRevisionConflict
    redirect_task_conflict
  end

  def destroy
    mutate_parent! { @step.destroy! }
    redirect_to tasks_path(status: @task.status), notice: "Шаг удалён"
  rescue InvalidLockVersion, TaskRevisionConflict
    redirect_task_conflict
  end

  private

  def set_task
    @task = current_user.tasks.active.find(params[:task_id])
  end

  def ensure_mutable_task!
    raise ActiveRecord::RecordNotFound if %w[completed dropped].include?(@task.status)
  end

  def set_step
    @step = @task.task_steps.find(params[:id])
  end

  def mutate_parent!
    expected = strict_lock_version(lock_params[:lock_version])
    @task.with_lock do
      raise TaskRevisionConflict unless @task.lock_version == expected

      yield
      @task.touch
    end
  end

  def step_params
    params.require(:task_step).permit(:text)
  end

  def lock_params
    raw = params[:task]
    raw.is_a?(ActionController::Parameters) ? raw.permit(:lock_version) : {}
  end

  def redirect_task_conflict
    redirect_to tasks_path(status: @task.status),
      alert: "Задача уже изменилась. Показана свежая версия.",
      status: :see_other
  end

  def strict_lock_version(value)
    string = value.to_s
    raise InvalidLockVersion unless string.match?(/\A\d+\z/)

    Integer(string, 10)
  end
end
