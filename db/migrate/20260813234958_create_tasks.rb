class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.text :notes
      t.datetime :due_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
