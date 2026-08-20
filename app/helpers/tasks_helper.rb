module TasksHelper
  PRIORITY_TAG = { 1 => "is-info", 2 => "is-warning", 3 => "is-danger" }.freeze
  # Stored integer -> p1..p4 display number (inverse of the input mapping).
  PRIORITY_LABELS = QuickAdd::PRIORITY_TOKENS.invert.freeze
  # Edit-form options in the p1..p4 convention, urgent first, each mapped to its
  # stored integer. One source of truth: QuickAdd::PRIORITY_TOKENS.
  PRIORITY_SELECT_OPTIONS = QuickAdd::PRIORITY_TOKENS.map { |p, stored| [ "P#{p}", stored ] }.freeze

  def format_time(time)
    time&.strftime("%b %-d, %-l:%M %p")
  end

  def due_tag(task)
    return unless task.due_at
    task.all_day? ? task.due_at.strftime("%b %-d") : format_time(task.due_at)
  end

  # p1..p4 display number for a stored priority integer (p1 is most urgent).
  # Single source for the display convention, shared by every priority view.
  def priority_label(priority)
    PRIORITY_LABELS[priority]
  end

  # p4 (stored 0) is baseline and renders no badge; p1..p3 get a colored tag.
  def priority_badge(task)
    cls = PRIORITY_TAG[task.priority]
    cls && tag.span("P#{priority_label(task.priority)}", class: "tag #{cls}")
  end

  def priority_select_options
    PRIORITY_SELECT_OPTIONS
  end
end
