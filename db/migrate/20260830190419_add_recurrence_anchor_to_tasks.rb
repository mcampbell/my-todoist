class AddRecurrenceAnchorToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :recurrence_anchor_at, :datetime
    add_column :tasks, :recurrence_anchor_all_day, :boolean
  end
end
