class Task < ApplicationRecord
  belongs_to :project, optional: true
  has_many :task_labels, dependent: :destroy
  has_many :labels, through: :task_labels

  validates :title, presence: true
  validates :priority, inclusion: { in: 0..3 }

  scope :active, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :ordered, -> { order(Arel.sql("due_at ASC NULLS LAST, created_at DESC")) }
  scope :due_today_or_undated, -> { where("due_at <= ? OR due_at IS NULL", Time.current.end_of_day) }
  scope :due_between, ->(range) { where(due_at: range) }

  def completed?
    completed_at.present?
  end

  def complete!
    with_lock do
      return if completed?
      update!(completed_at: Time.current)
    end
  end
end
