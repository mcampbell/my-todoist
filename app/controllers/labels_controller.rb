class LabelsController < ApplicationController
  before_action :set_label, only: %i[edit update destroy]

  def index
    @labels = Label.order(:name)
  end

  def new
    @label = Label.new
  end

  def create
    @label = Label.new(label_params)
    if @label.save
      redirect_to labels_path
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @label.update(label_params)
      redirect_to labels_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @label.destroy
    redirect_to labels_path, notice: "Label deleted."
  end

  private

  def set_label
    @label = Label.find(params[:id])
  end

  def label_params
    params.require(:label).permit(:name)
  end
end
