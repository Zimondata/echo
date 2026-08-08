class ProjectsController < ApplicationController
  InvalidLockVersion = Class.new(StandardError)

  def index
    load_projects
  end

  def create
    @project = current_user.projects.new(project_params)
    if @project.save
      redirect_to projects_path, notice: "Проект создан"
    else
      load_projects
      render :index, status: :unprocessable_entity
    end
  end

  def update
    project = current_user.projects.find(params[:id])
    project.lock_version = strict_lock_version(lock_params[:lock_version])
    project.update!(project_params)
    redirect_to projects_path, notice: "Проект переименован"
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion
    load_projects
    flash.now[:alert] = "Проект уже изменился. Показана свежая версия."
    render :index, status: :conflict
  rescue ActiveRecord::RecordInvalid => error
    load_projects
    flash.now[:alert] = error.record.errors.full_messages.join(", ")
    render :index, status: :unprocessable_entity
  end

  def archive
    project = current_user.projects.find(params[:id])
    project.archive!(strict_lock_version(lock_params[:lock_version]))
    redirect_to projects_path, notice: "Проект архивирован"
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion
    load_projects
    @project = current_user.projects.new
    flash.now[:alert] = "Проект уже изменён. Обнови страницу."
    render :index, status: :conflict
  end

  private

  def load_projects
    @projects = current_user.projects.ordered
    @project ||= current_user.projects.new(position: @projects.size)
  end

  def project_params
    params.require(:project).permit(:name)
  end

  def lock_params
    raw = params[:project]
    raw.is_a?(ActionController::Parameters) ? raw.permit(:lock_version) : {}
  end

  def strict_lock_version(value)
    string = value.to_s
    raise InvalidLockVersion unless string.match?(/\A\d+\z/)

    version = Integer(string, 10)
    # Active Record increments lock_version during update, so reserve the signed 64-bit maximum.
    raise InvalidLockVersion unless version.between?(0, (2**63) - 2)

    version
  end
end
