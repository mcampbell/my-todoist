module TasksHelper
  PRIORITY_TAG = { 1 => "is-info", 2 => "is-warning", 3 => "is-danger" }.freeze

  def format_time(time)
    time&.strftime("%b %-d, %-l:%M %p")
  end

  def due_tag(task)
    return unless task.due_at
    task.all_day? ? task.due_at.strftime("%b %-d") : format_time(task.due_at)
  end

  # P0 (baseline) renders no badge; 1..3 get a colored tag.
  def priority_badge(task)
    cls = PRIORITY_TAG[task.priority]
    cls && tag.span("P#{task.priority}", class: "tag #{cls}")
  end
end
