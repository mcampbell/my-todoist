class TasksController < ApplicationController
  before_action :set_task, only: %i[edit update destroy complete]

  def index
    @tasks = Task.active.order(Arel.sql("due_at ASC NULLS LAST, created_at DESC"))
  end

  def completed
    @tasks = Task.completed.order(completed_at: :desc)
  end

  def new
    @task = Task.new
  end

  def create
    @task = Task.new(task_params)
    if @task.save
      redirect_to tasks_path
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @task.update(task_params)
      redirect_to tasks_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy
    redirect_to tasks_path
  end

  def complete
    @task.complete!
    redirect_to tasks_path, notice: "Task completed."
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :notes, :due_at)
  end
end
