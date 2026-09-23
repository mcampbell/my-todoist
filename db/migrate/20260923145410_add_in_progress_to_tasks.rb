class AddInProgressToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :in_progress, :boolean, default: false, null: false
  end
end
