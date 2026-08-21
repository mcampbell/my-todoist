class OsNotificationsController < ApplicationController
  def create
    OsNotifier.notify(title: params[:title].to_s, message: params[:message].to_s)
    head :no_content
  end
end
