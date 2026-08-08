class TasksController < ApplicationController
  InvalidLockVersion = Class.new(StandardError)
  TaskStateConflict = Class.new(StandardError)

  def index
    load_tasks_index
  end

  def create
    @task = current_user.tasks.new(task_params)
    assign_active_project!(@task, task_project_id)
    @task.owner_type = Task::DEFAULT_OWNER_TYPE
    @task.status = Task::DEFAULT_STATUS
    @task.deleted_at = nil

    if @task.save
      redirect_to task_return_path, flash: { task_notice: "Задача добавлена" }
    else
      if params[:return_to] == "tasks"
        load_tasks_index(status: "inbox", new_task: @task)
        render :index, status: :unprocessable_entity
      elsif params[:return_to] == "project"
        load_project_workspace(new_task: @task)
        render "projects/show", status: :unprocessable_entity
      else
        @unscheduled_tasks = current_user.tasks.unscheduled.order(:created_at)
        @active_projects = current_user.projects.active.ordered
        @calendar_view = safe_view
        @calendar_date = safe_date
        render :create, status: :unprocessable_entity
      end
    end
  end

  def update
    task = current_user.tasks.active.find(params[:id])
    submitted = update_task_params
    task.assign_attributes(submitted.except(:lock_version, :project_id))
    assign_active_project!(task, submitted[:project_id]) if submitted.key?(:project_id)
    ensure_editable_state!(task)
    task.lock_version = strict_lock_version(submitted[:lock_version])
    task.save!

    if params[:return_to] == "tasks"
      redirect_to tasks_path(status: safe_task_status), flash: { task_notice: "Задача обновлена" }
    else
      redirect_to calendar_events_path(calendar_return_params), flash: { task_notice: "Задача обновлена" }
    end
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion, TaskStateConflict
    if params[:return_to] == "tasks"
      load_tasks_index(status: safe_task_status)
      flash.now[:alert] = "Задача изменена в другой вкладке. Проверь свежую версию и повтори."
      render :index, status: :conflict
      return
    end

    @submitted_task = task
    @server_task = current_user.tasks.active.find(params[:id])
    @conflict = true
    @open_action = :edit
    set_calendar_context
    render :update, status: :conflict
  rescue ActiveRecord::RecordInvalid
    if params[:return_to] == "tasks"
      load_tasks_index(status: safe_task_status)
      flash.now[:alert] = task.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
      return
    end

    @submitted_task = task
    @server_task = current_user.tasks.active.find(params[:id])
    @open_action = :edit
    set_calendar_context
    render :update, status: :unprocessable_entity
  end

  def complete
    task = lifecycle_task_for("completed")
    expected_lock_version = strict_lock_version(lifecycle_params[:lock_version])
    raise InvalidLockVersion unless task.lock_version == expected_lock_version

    unless task.status == "completed"
      task.assign_attributes(status: "completed", completed_at: Time.current)
      task.lock_version = expected_lock_version
      task.save!
    end

    respond_lifecycle_success("Задача завершена")
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion, TaskStateConflict
    render_lifecycle_conflict(task || current_user.tasks.active.find(params[:id]))
  end

  def drop
    task = lifecycle_task_for("dropped")
    expected_lock_version = strict_lock_version(drop_params[:lock_version])
    raise InvalidLockVersion unless task.lock_version == expected_lock_version

    unless task.status == "dropped"
      task.assign_attributes(
        status: "dropped",
        dropped_at: Time.current,
        drop_reason: drop_params[:drop_reason]
      )
      task.lock_version = expected_lock_version
      task.save!
    end

    respond_lifecycle_success("Задача убрана")
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion, TaskStateConflict
    conflicted_task = task || current_user.tasks.active.find(params[:id])
    render_lifecycle_conflict(conflicted_task, drop_reason: drop_params[:drop_reason], open_action: :drop)
  rescue ActiveRecord::RecordInvalid
    @submitted_task = task
    @server_task = current_user.tasks.active.find(params[:id])
    @drop_reason = drop_params[:drop_reason]
    @open_action = :drop
    set_calendar_context
    render :update, status: :unprocessable_entity
  end

  def move_to_next
    transition_someday!(status: "next")
    redirect_to tasks_path(status: "someday"), flash: { task_notice: "Задача перенесена в следующие" }
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion, TaskStateConflict
    render_lifecycle_conflict(@transition_task || current_user.tasks.active.find(params[:id]))
  end

  def drop_from_someday
    transition_someday!(status: "dropped", dropped_at: Time.current, drop_reason: drop_params[:drop_reason])
    redirect_to tasks_path(status: "someday"), flash: { task_notice: "Задача убрана" }
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion, TaskStateConflict
    render_lifecycle_conflict(@transition_task || current_user.tasks.active.find(params[:id]))
  end

  private

  def task_params
    raw_task = params[:task]
    return {} unless raw_task.is_a?(ActionController::Parameters)

    raw_task.permit(:title, :description, :next_action, :estimate_minutes, :due_on)
  end

  def update_task_params
    raw_task = params[:task]
    return {} unless raw_task.is_a?(ActionController::Parameters)

    raw_task.permit(:title, :description, :next_action, :estimate_minutes, :due_on, :project_id, :lock_version)
  end

  def lifecycle_params
    raw_task = params[:task]
    return {} unless raw_task.is_a?(ActionController::Parameters)

    raw_task.permit(:lock_version)
  end

  def drop_params
    raw_task = params[:task]
    return {} unless raw_task.is_a?(ActionController::Parameters)

    raw_task.permit(:lock_version, :drop_reason)
  end

  def respond_lifecycle_success(message)
    if turbo_frame_request?
      tasks = current_user.tasks.unscheduled.order(:created_at)
      render turbo_stream: [
        turbo_stream.replace(
          "task_lane_items",
          partial: "tasks/task_items",
          locals: { tasks: tasks, calendar_view: safe_view, calendar_date: safe_date }
        ),
        turbo_stream.update("task_lane_count", tasks.size),
        turbo_stream.replace(
          "task_lane_feedback",
          partial: "tasks/task_feedback",
          locals: { message: message }
        )
      ]
    else
      if params[:return_to] == "tasks"
        redirect_to tasks_path(status: safe_task_status), flash: { task_notice: message }
      else
        redirect_to calendar_events_path(calendar_return_params), flash: { task_notice: message }
      end
    end
  end

  def lifecycle_task_for(target_status)
    task = current_user.tasks.active.find(params[:id])
    return task if task.status == target_status || Task::UNSCHEDULED_STATUSES.include?(task.status)

    raise TaskStateConflict if %w[completed dropped].include?(task.status)

    raise ActiveRecord::RecordNotFound
  end

  def transition_someday!(attributes)
    @transition_task = current_user.tasks.active.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @transition_task.status == "someday"

    expected = strict_lock_version(lifecycle_params[:lock_version])
    raise InvalidLockVersion unless @transition_task.lock_version == expected

    @transition_task.assign_attributes(attributes)
    @transition_task.lock_version = expected
    @transition_task.save!
  end

  def ensure_editable_state!(task)
    raise TaskStateConflict if %w[completed dropped].include?(task.status)
  end

  def render_lifecycle_conflict(task, drop_reason: nil, open_action: nil)
    if params[:return_to] == "tasks"
      load_tasks_index(status: safe_task_status)
      flash.now[:alert] = "Задача изменена в другой вкладке. Проверь свежую версию и повтори."
      render :index, status: :conflict
      return
    end

    @submitted_task = task
    @server_task = current_user.tasks.active.find(params[:id])
    @conflict = true
    @drop_reason = drop_reason
    @open_action = open_action
    set_calendar_context
    render :update, status: :conflict
  end

  def set_calendar_context
    @calendar_view = safe_view
    @calendar_date = safe_date
  end

  def strict_lock_version(value)
    string_value = value.to_s
    raise InvalidLockVersion unless string_value.match?(/\A\d+\z/)

    number = Integer(string_value, 10)
    # Active Record increments lock_version on every persisted task mutation.
    raise InvalidLockVersion unless number.between?(0, (2**63) - 2)

    number
  end

  def load_tasks_index(status: nil, new_task: nil)
    @status = status.presence_in(Task::STATUSES) || params[:status].presence_in(Task::STATUSES) || "next"
    @tasks = current_user.tasks.active
      .where(status: @status)
      .includes(:time_blocks, :project, :task_steps)
      .order(:due_on, :created_at)
    @task_groups = @tasks.group_by(&:project) if @status == "someday"
    @task_counts = current_user.tasks.active.group(:status).count
    @new_task = new_task || current_user.tasks.new
    @active_projects = current_user.projects.active.ordered
  end

  def load_project_workspace(new_task:)
    @project = current_user.projects.active.find(task_project_id)
    @tasks = @project.tasks.active
      .includes(:time_blocks, :project, :task_steps)
      .order(:due_on, :created_at, :id)
    @task_groups = @tasks.group_by(&:status)
    @active_projects = current_user.projects.active.ordered
    @new_task = new_task
  end

  def task_project_id
    raw = params[:task]
    raw[:project_id] if raw.is_a?(ActionController::Parameters)
  end

  def assign_active_project!(task, project_id)
    if project_id.blank?
      task.project = nil
    elsif task.project_id.to_s != project_id.to_s
      task.project = current_user.projects.active.find(project_id)
    end
  end

  def safe_task_status
    params[:status].presence_in(Task::STATUSES) || "next"
  end

  def task_return_path
    return tasks_path(status: @task&.status || "inbox") if params[:return_to] == "tasks"
    return project_path(@task.project) if params[:return_to] == "project" && @task&.project
    return dashboard_path if params[:return_to] == "dashboard"

    calendar_events_path(calendar_return_params)
  end

  def calendar_return_params
    { view: safe_view, date: safe_date }.compact
  end

  def safe_view
    params[:view] if CalendarEventsController::VIEWS.include?(params[:view])
  end

  def safe_date
    return if params[:date].blank?

    Date.iso8601(params[:date]).iso8601
  rescue Date::Error, TypeError
    nil
  end
end
