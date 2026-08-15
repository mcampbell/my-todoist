class AddAllDayToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :all_day, :boolean, default: false, null: false
  end
end
