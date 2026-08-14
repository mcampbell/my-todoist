class Label < ApplicationRecord
  has_many :task_labels, dependent: :destroy
  has_many :tasks, through: :task_labels
  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
