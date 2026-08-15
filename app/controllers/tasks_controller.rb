class TasksController < ApplicationController
  UPCOMING_DAYS = 7

  before_action :set_task, only: %i[edit update destroy complete]
  helper_method :task_list_path

  def index
    @project = Project.find(params[:project_id]) if params[:project_id]
    @tasks = Task.active.where(project: @project).ordered.includes(:labels)
  end

  def completed
    @tasks = Task.completed.order(completed_at: :desc)
  end

  def today
    @tasks = Task.active.due_today_or_undated.ordered.includes(:labels)
  end

  def upcoming
    range = 1.day.from_now.beginning_of_day..UPCOMING_DAYS.days.from_now.end_of_day
    @groups = Task.active.due_between(range).ordered.includes(:labels)
                  .group_by { |t| t.due_at.to_date }
  end

  def new
    @task = Task.new
  end

  def create
    @task = Task.new(task_params)
    if @task.save
      redirect_to task_list_path(@task)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @task.update(task_params)
      redirect_back_or_to task_list_path(@task)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy
    redirect_back_or_to task_list_path(@task)
  end

  def complete
    @task.complete!
    redirect_back_or_to task_list_path(@task), notice: "Task completed."
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  # Return to the task's own list: its project, or Inbox.
  def task_list_path(task)
    task.project ? project_tasks_path(task.project) : tasks_path
  end

  def task_params
    params.require(:task).permit(:title, :notes, :due_date, :due_time, :project_id, :priority, label_ids: [])
  end
end
