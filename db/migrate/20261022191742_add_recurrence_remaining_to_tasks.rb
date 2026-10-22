class AddRecurrenceRemainingToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :recurrence_remaining, :integer
  end
end
