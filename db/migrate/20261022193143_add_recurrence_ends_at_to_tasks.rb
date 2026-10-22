class AddRecurrenceEndsAtToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :recurrence_ends_at, :datetime
  end
end
