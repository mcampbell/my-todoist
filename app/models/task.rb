class Task < ApplicationRecord
  belongs_to :project, optional: true
  has_many :task_labels, dependent: :destroy
  has_many :labels, through: :task_labels

  validates :title, presence: true
  validates :priority, inclusion: { in: 0..3 }
  validate :recurrence_must_be_parseable

  scope :ordered, -> { order(Arel.sql("due_at ASC NULLS LAST, created_at DESC")) }
  scope :due_today_or_undated, -> { where("due_at <= ? OR due_at IS NULL", Time.current.end_of_day) }
  scope :due_between, ->(range) { where(due_at: range) }
  scope :overdue, -> { where("due_at < ?", Time.current.beginning_of_day) }

  def overdue?
    due_at.present? && due_at < Time.current.beginning_of_day
  end

  def recurrence=(value)
    super(value.presence)
  end

  def complete!
    with_lock do
      reload
      snapshot = CompletedOccurrence.create!(
        task_title: title,
        project_name: project&.name,
        priority: priority,
        label_names: labels.pluck(:name).sort_by { |n| n.downcase }.join(", "),
        due_at: due_at,
        all_day: all_day,
        completed_at: Time.current
      )
      if recurrence.blank?
        destroy!
      else
        rule = Recurrence.parse(recurrence)
        next_due = rule.next_from(due_at: due_at || Time.current, now: Time.current)
        # A rolling recurrence reschedules from the completion clock time, so
        # an all-day task's next occurrence would otherwise pick up whatever
        # time it happened to be completed at. all_day tasks have no time to
        # preserve, so floor to the date only and keep all_day as it was --
        # unless the recurrence is sub-day (hour/minute): flooring that would
        # stall the task at the same midnight forever, so let it become timed
        # instead (an all-day task recurring every N minutes makes no sense
        # as all-day in the first place).
        sub_day = rule.unit.in?(%i[hour minute])
        next_due = next_due.beginning_of_day if all_day && !sub_day
        update!(due_at: next_due, all_day: all_day && !sub_day)
      end
      snapshot
    end
  end

  def due_date=(value)
    @due_date_assigned = true
    @due_date = value
  end

  def due_date
    @due_date || due_at&.to_date&.iso8601
  end

  attr_writer :due_time

  def due_time
    @due_time || (due_at.present? && !all_day? ? due_at.strftime("%H:%M") : nil)
  end

  before_validation :compose_due_at, if: -> { @due_date_assigned }

  private

  def recurrence_must_be_parseable
    return if recurrence.blank?
    Recurrence.parse(recurrence)
  rescue Recurrence::InvalidError
    errors.add(:recurrence, "is invalid")
  end

  def compose_due_at
    if @due_date.blank?
      self.due_at = nil
      self.all_day = false
      return
    end

    date = Date.parse(@due_date)
    if @due_time.present?
      time = Time.zone.parse(@due_time)
      self.due_at = date.in_time_zone.change(hour: time.hour, min: time.min)
      self.all_day = false
    else
      self.due_at = date.in_time_zone.beginning_of_day
      self.all_day = true
    end
  rescue ArgumentError, TypeError
    errors.add(:due_at, "is invalid")
  end
end
