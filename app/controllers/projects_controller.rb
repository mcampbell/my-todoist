class ProjectsController < ApplicationController
  before_action :set_project, only: %i[edit update destroy]

  def index
    @projects = Project.order(:name)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      redirect_to projects_path
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @project.update(project_params)
      redirect_to projects_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted. Its tasks moved to Inbox."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name)
  end
end
