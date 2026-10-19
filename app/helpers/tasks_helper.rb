module TasksHelper
  PRIORITY_TAG = { 1 => "is-info", 2 => "is-warning", 3 => "is-danger" }.freeze
  # Stored integer -> p1..p4 display number (inverse of the input mapping).
  PRIORITY_LABELS = QuickAdd::PRIORITY_TOKENS.invert.freeze
  # Edit-form options in the p1..p4 convention, urgent first, each mapped to its
  # stored integer. One source of truth: QuickAdd::PRIORITY_TOKENS.
  PRIORITY_SELECT_OPTIONS = QuickAdd::PRIORITY_TOKENS.map { |p, stored| [ "P#{p}", stored ] }.freeze
  # http(s) only, so text never yields a javascript: link. The last character
  # excludes sentence punctuation: "see https://x.example." links x.example.
  # shortcut: a URL that really ends in ")" loses it; balance parens if that bites.
  URL_SPLIT = %r{\b(https?://[^\s<>"]*[^\s<>".,;:!?)\]'])}i

  def format_time(time)
    return unless time
    "#{time.strftime("%b %-d#{year_suffix(time)}")}, #{time_of_day(time)}"
  end

  # Clock time only, no date -- shared by format_time and the creation flash's
  # today/tomorrow phrasing.
  def time_of_day(time)
    time.strftime("%-l:%M %p")
  end

  def due_tag(task)
    return unless task.due_at
    return format_time(task.due_at) unless task.all_day?
    task.due_at.strftime("%b %-d#{year_suffix(task.due_at)}")
  end

  # The recurrence limit for the task row's ↻ tag: " · N left" or " · ends <date>".
  def recurrence_limit_text(task)
    if task.recurrence_remaining
      " · #{task.recurrence_remaining} left"
    elsif task.recurrence_ends_at
      ends = task.recurrence_ends_at
      " · ends #{task.ends_all_day? ? ends.strftime("%b %-d#{year_suffix(ends)}") : format_time(ends)}"
    end
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

  # Overdue rows redden with age so the oldest stand out. Nil when not overdue.
  def overdue_class(task)
    return unless task.overdue?
    if task.due_at > 1.week.ago then "has-background-danger-light"
    elsif task.due_at > 1.month.ago then "has-background-danger-85"
    else "has-background-danger-80"
    end
  end

  # First line of notes for list rows, with "..." when more text follows.
  # Blank notes render nothing.
  def notes_preview(text)
    notes = text.to_s.strip
    return if notes.empty?
    first, rest = notes.split("\n", 2)
    "#{first.rstrip}#{'...' if rest.present?}"
  end

  # Text with each http(s) URL as a new-tab link. The block renders the text
  # between URLs (default: escaped as-is). Split on a capture group, so odd
  # parts are URLs and even parts are the text around them.
  def linkify(text)
    safe_join(text.to_s.split(URL_SPLIT).each_with_index.filter_map do |part, i|
      if i.odd?
        link_to(part, part, target: "_blank", rel: "noopener noreferrer")
      elsif !part.empty?
        block_given? ? yield(part) : part
      end
    end)
  end

  def priority_select_options
    PRIORITY_SELECT_OPTIONS
  end

  private

  # Single source for the "only show the year when it's not the current
  # year" rule, shared by format_time and due_tag's all-day branch.
  def year_suffix(time)
    time.year == Time.current.year ? "" : ", %Y"
  end
end
