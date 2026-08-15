class Task < ApplicationRecord
  belongs_to :project, optional: true
  has_many :task_labels, dependent: :destroy
  has_many :labels, through: :task_labels

  validates :title, presence: true
  validates :priority, inclusion: { in: 0..3 }

  scope :ordered, -> { order(Arel.sql("due_at ASC NULLS LAST, created_at DESC")) }
  scope :due_today_or_undated, -> { where("due_at <= ? OR due_at IS NULL", Time.current.end_of_day) }
  scope :due_between, ->(range) { where(due_at: range) }
  scope :overdue, -> { where("due_at < ?", Time.current.beginning_of_day) }

  def overdue?
    due_at.present? && due_at < Time.current.beginning_of_day
  end

  def complete!
    with_lock do
      reload
      CompletedOccurrence.create!(
        task_title: title,
        project_name: project&.name,
        priority: priority,
        label_names: labels.pluck(:name).sort_by { |n| n.downcase }.join(", "),
        due_at: due_at,
        completed_at: Time.current
      )
      destroy!
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
