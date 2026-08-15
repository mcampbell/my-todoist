class AddRecurrenceToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :recurrence, :string
  end
end
