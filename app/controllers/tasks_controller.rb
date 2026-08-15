require "did_you_mean"

class TasksController < ApplicationController
  UPCOMING_DAYS = 7

  before_action :set_task, only: %i[edit update destroy complete]
  helper_method :task_list_path, :safe_return_to

  def index
    @project = Project.find(params[:project_id]) if params[:project_id]
    @tasks = Task.where(project: @project).ordered.includes(:labels)
  end

  def completed
    @occurrences = CompletedOccurrence.order(completed_at: :desc)
  end

  def today
    @tasks = Task.due_today_or_undated.ordered.includes(:labels)
  end

  def overdue
    @tasks = Task.overdue.ordered.includes(:labels)
  end

  def upcoming
    range = 1.day.from_now.beginning_of_day..UPCOMING_DAYS.days.from_now.end_of_day
    @groups = Task.due_between(range).ordered.includes(:labels)
                  .group_by { |t| t.due_at.to_date }
  end

  def new
    @task = Task.new
  end

  def create
    qp = quick_add_params
    parsed = QuickAdd.parse(qp[:title].to_s)
    attrs = {
      title: parsed[:title],
      priority: parsed[:priority] || 0,
      due_date: parsed[:due_date],
      due_time: parsed[:due_time],
      label_ids: qp[:label_ids] || []
    }
    project_name = params[:project_name].presence || parsed[:project_name]
    if project_name.present?
      project = Project.find_by(name: project_name)
      if project.nil? && !params[:force_create_project].present? && (suggestion = project_suggestion(project_name))
        @project_candidate = project_name
        @project_suggestion = suggestion
        @task = Task.new(quick_add_params)
        render :new, status: :unprocessable_content
        return
      end
      project ||= Project.create!(name: project_name)
      attrs[:project_id] = project.id
    end
    @task = Task.new(attrs)
    if @task.save
      redirect_to safe_return_to || task_list_path(@task)
    else
      render :new, status: :unprocessable_content
    end
  rescue QuickAdd::RecurrenceNotSupportedError => e
    @task = Task.new(quick_add_params)
    @task.errors.add(:title, e.message)
    render :new, status: :unprocessable_content
  end

  def edit; end

  def update
    if @task.update(task_params)
      redirect_to safe_return_to || task_list_path(@task)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy
    redirect_back_or_to task_list_path(@task)
  end

  def complete
    path = task_list_path(@task)
    @task.complete!
    redirect_back_or_to path, notice: "Task completed."
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  # Return to the task's own list: its project, or Inbox.
  def task_list_path(task)
    task.project ? project_tasks_path(task.project) : tasks_path
  end

  # First near-miss project name, or nil. Case-insensitive exact matches are
  # handled by Project.find_by (NOCASE column); this only catches typos.
  def project_suggestion(name)
    DidYouMean::SpellChecker.new(dictionary: Project.pluck(:name)).correct(name).first
  end

  def task_params
    params.require(:task).permit(:title, :notes, :due_date, :due_time, :project_id, :priority, label_ids: [])
  end

  # Create accepts only the quick-add field and labels; priority, due date,
  # and project come from the parsed text (slice 4d).
  def quick_add_params
    params.require(:task).permit(:title, label_ids: [])
  end

  # Only accept internal, non-protocol-relative paths (blocks "//evil.com" open redirects).
  def safe_return_to
    path = params[:return_to]
    path if path.present? && path.start_with?("/") && !path.start_with?("//")
  end
end
