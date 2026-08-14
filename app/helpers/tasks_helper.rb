module TasksHelper
  def format_time(time)
    time&.strftime("%b %-d, %-l:%M %p")
  end
end
