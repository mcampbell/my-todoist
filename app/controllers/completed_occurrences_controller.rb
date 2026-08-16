class CompletedOccurrencesController < ApplicationController
  def show
    @occurrence = CompletedOccurrence.find(params[:id])
  end
end
