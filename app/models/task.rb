class Task < ApplicationRecord
  validates :title, presence: true

  scope :active, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }

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
