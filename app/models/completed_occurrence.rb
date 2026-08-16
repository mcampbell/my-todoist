class CompletedOccurrence < ApplicationRecord
  validates :task_title, :priority, :completed_at, presence: true
end
