class AddOrganizationToTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :project, null: true, foreign_key: { on_delete: :nullify }
    add_column :tasks, :priority, :integer, null: false, default: 0
    add_check_constraint :tasks, "priority BETWEEN 0 AND 3", name: "priority_range"
  end
end
