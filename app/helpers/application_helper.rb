module ApplicationHelper
  # Whole seconds from +now+ to the next midnight in the app's zone (the same
  # clock that decides "today" for the task views). The layout hands this to a
  # client timer that reloads the page so date-based views roll over on their
  # own. Ceil so the timer never fires a hair before the day boundary.
  def seconds_until_midnight(now = Time.current)
    (now.tomorrow.beginning_of_day - now).ceil
  end
end
