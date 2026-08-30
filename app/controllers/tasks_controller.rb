require "did_you_mean"

class TasksController < ApplicationController
  UPCOMING_DAYS = 7

  before_action :set_task, only: %i[edit update destroy complete]
  helper_method :task_list_path, :safe_return_to

  def index
    @project = Project.find(params[:project_id]) if params[:project_id]
    @tasks = Task.where(project: @project).ordered.includes(:labels)
  end

  def completed
    @occurrences = CompletedOccurrence.order(completed_at: :desc)
  end

  def today
    @tasks = Task.due_today_or_undated.ordered.includes(:labels)
  end

  def overdue
    @tasks = Task.overdue.ordered.includes(:labels)
  end

  def upcoming
    range = 1.day.from_now.beginning_of_day..UPCOMING_DAYS.days.from_now.end_of_day
    @groups = Task.due_between(range).ordered.includes(:labels)
                  .group_by { |t| t.due_at.to_date }
  end

  # Client-side toast poll (slice 6): timed tasks due in (since, now]. The
  # client advances its anchor to response.now each poll, so server time wins.
  def due_since
    since = Time.iso8601(params[:since])
    now = Time.current
    tasks = Task.where(all_day: false)
                .where("due_at > ? AND due_at <= ?", since, now)
                .order(:due_at)
    render json: {
      now: now.utc.iso8601(6),
      tasks: tasks.pluck(:id, :title, :due_at).map { |id, title, due| { id: id, title: title, due_at: due&.utc.iso8601(6) } }
    }
  rescue ArgumentError, TypeError
    render json: { error: "since must be ISO8601" }, status: :bad_request
  end

  def new
    @task = Task.new
  end

  def create
    qp = quick_add_params
    parsed = QuickAdd.parse(qp[:title].to_s)
    attrs = {
      title: parsed[:title],
      priority: parsed[:priority] || 0,
      due_date: parsed[:due_date],
      due_time: parsed[:due_time],
      recurrence: parsed[:recurrence],
      label_ids: qp[:label_ids] || []
    }
    if parsed[:recurrence].present?
      apply_recurrence_anchors!(attrs, parsed[:recurrence], nil)
    end
    project_name = params[:project_name].presence || parsed[:project_name]
    if project_name.present?
      project = Project.find_by(name: project_name)
      if project.nil? && !params[:force_create_project].present? && (suggestion = project_suggestion(project_name))
        @project_candidate = project_name
        @project_suggestion = suggestion
        @task = Task.new(quick_add_params)
        render :new, status: :unprocessable_content
        return
      end
      project ||= Project.create!(name: project_name)
      attrs[:project_id] = project.id
    end
    @task = Task.new(attrs)
    if @task.save
      redirect_to safe_return_to || task_list_path(@task)
    else
      # On recurrence-validation failure the parsed title has already lost the
      # recurrence span; rebuild from the raw quick-add string so the edit
      # control shows the exact phrase the user must correct.
      preserve_quick_add_input!(@task) if parsed[:recurrence].present?
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    attrs = task_params.to_h.with_indifferent_access
    @reschedule_to = params[:reschedule_to].to_s
    if @reschedule_to.present? && !apply_reschedule!(attrs, @reschedule_to)
      render :edit, status: :unprocessable_content
      return
    end
    if attrs[:recurrence].present?
      apply_recurrence_anchors!(attrs, attrs[:recurrence], @task)
    end
    if @task.update(attrs)
      redirect_to safe_return_to || task_list_path(@task)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy
    redirect_back_or_to task_list_path(@task)
  end

  def complete
    path = task_list_path(@task)
    @task.complete!
    redirect_back_or_to path, notice: "Task completed."
  end

  def search
    @query = params[:q].to_s.strip
    @include_completed = ActiveModel::Type::Boolean.new.cast(params[:include_completed])

    if @query.present?
      pattern = "%#{escape_like(@query)}%"
      @tasks = Task.where("title LIKE ? ESCAPE '\\'", pattern).ordered.includes(:labels)
      @completed_occurrences = @include_completed ?
        CompletedOccurrence.where("task_title LIKE ? ESCAPE '\\'", pattern).order(completed_at: :desc) :
        CompletedOccurrence.none
    else
      @tasks = Task.none
      @completed_occurrences = CompletedOccurrence.none
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  # Return to the task's own list: its project, or Inbox.
  def task_list_path(task)
    task.project ? project_tasks_path(task.project) : tasks_path
  end

  # First near-miss project name, or nil. Case-insensitive exact matches are
  # handled by Project.find_by (NOCASE column); this only catches typos.
  def project_suggestion(name)
    DidYouMean::SpellChecker.new(dictionary: Project.pluck(:name)).correct(name).first
  end

  def task_params
    params.require(:task).permit(:title, :notes, :due_date, :due_time, :project_id, :priority, :recurrence, label_ids: [])
  end

  # % and _ are LIKE wildcards; escape them (and the escape char itself)
  # so a literal % or _ in the search box doesn't act as a wildcard.
  def escape_like(text)
    text.gsub("\\") { "\\\\" }.gsub("%") { "\\%" }.gsub("_") { "\\_" }
  end

  # True for hour/minute recurrences, which need a real time-of-day anchor so
  # the task is not all_day (else due_tag hides the time and the slice-6
  # notifier would skip it). Based on the parsed unit, not the raw string, so
  # invalid recurrence text (e.g. "every 0 minutes") is never treated as
  # sub-day and cannot seed a timed anchor before validation rejects it.
  def recurrence_is_sub_day?(recurrence)
    rule = Recurrence.parse(recurrence)
    rule && rule.unit.in?(%i[hour minute])
  rescue Recurrence::InvalidError
    false
  end

  # A recurring task defaults its anchor date to today when it has no date at
  # all (fixed stepping needs a starting point; rolling ignores it anyway) —
  # but only for the initial bootstrap, never overriding an explicit blank
  # post from the edit form. A sub-day recurrence always needs a real time
  # anchor so the task is not all_day (the slice-6 notifier skips all_day
  # tasks and due_tag hides the time on them).
  def apply_recurrence_anchors!(attrs, recurrence, existing_task)
    # Skip anchoring entirely for malformed recurrence text: the loose-prefix
    # checks below would otherwise seed due_date/due_time that persist on the
    # in-memory task once validation rightly rejects the recurrence.
    Recurrence.parse(recurrence)
  rescue Recurrence::InvalidError
    nil
  else
    if recurrence_is_sub_day?(recurrence) && attrs[:due_time].blank?
      attrs[:due_time] = Time.current.strftime("%H:%M")
    end

    # Bootstrap today's date only when this edit assigns a recurrence to a
    # task that had none (or creates one without a date). A repeated edit of a
    # task the user already cleared must not silently re-add today.
    bootstrapping = existing_task.nil? ||
      (existing_task.recurrence.blank? && existing_task.due_at.blank?)
    attrs[:due_date] = Date.current.iso8601 if attrs[:due_date].blank? && bootstrapping
  end

  # Move a free-text point-in-time phrase from the edit form's "Reschedule
  # to" field into the due_date/due_time attrs, via the shared QuickAdd
  # grammar. Returns true (attrs mutated) or false (guard failed, error on
  # @task for the :edit re-render). Guard order matters: a recurring task
  # has no single "next" date to set; a changed picker means the user gave
  # two conflicting instructions. QuickAdd never raises, so a nil due_date
  # is its parse-failure signal. Priority/project/recurrence in the phrase
  # are ignored -- this field sets a date only.
  def apply_reschedule!(attrs, phrase)
    if @task.recurrence.present? || attrs[:recurrence].present?
      @task.errors.add(:base, "Can't reschedule a recurring task; clear the recurrence first.")
      return false
    end

    if picker_changed?(attrs)
      @task.errors.add(:base, "Use the date pickers or Reschedule to, not both.")
      return false
    end

    parsed = QuickAdd.parse(phrase)
    if parsed[:due_date].blank?
      @task.errors.add(:base, "Couldn't read a date from that phrase.")
      return false
    end

    attrs[:due_date] = parsed[:due_date]
    attrs[:due_time] = parsed[:due_time]
    true
  end

  # True when the submitted date/time picker values differ from what the
  # form rendered (the task's current values). The pickers post pre-filled,
  # so only a real change counts as "using" them against reschedule_to.
  def picker_changed?(attrs)
    (attrs.key?(:due_date) && attrs[:due_date].to_s != @task.due_date.to_s) ||
      (attrs.key?(:due_time) && attrs[:due_time].to_s != @task.due_time.to_s)
  end

  # Copy the raw quick-add string (which the parsed title already lost the
  # recurrence span from) plus the failures onto a fresh task for the error
  # render.
  def preserve_quick_add_input!(failed_task)
    raw = Task.new(quick_add_params)
    # The parsed title errors (e.g. "can't be blank" when the phrase was only
    # a recurrence) describe the stripped title, not the restored raw string.
    # Drop them when a recurrence error is the real problem; keep them when
    # title presence is the only thing that failed, so the page shows the
    # user a reason for the 422.
    other_errors = failed_task.errors.any? { |error| error.attribute != :title }
    failed_task.errors.each do |error|
      next if error.attribute == :title && other_errors
      raw.errors.add(error.attribute, error.message)
    end
    @task = raw
  end

  # Create accepts only the quick-add field and labels; priority, due date,
  # and project come from the parsed text (slice 4d).
  def quick_add_params
    params.require(:task).permit(:title, label_ids: [])
  end

  # Only accept internal, non-protocol-relative paths (blocks "//evil.com" open redirects).
  def safe_return_to
    path = params[:return_to]
    path if path.present? && path.start_with?("/") && !path.start_with?("//")
  end
end
