class CreateCompletedOccurrences < ActiveRecord::Migration[8.0]
  def up
    create_table :completed_occurrences do |t|
      t.string :task_title, null: false
      t.string :project_name
      t.integer :priority, null: false
      t.string :label_names
      t.datetime :due_at
      t.datetime :completed_at, null: false

      t.timestamps
    end

    rows = select_all(<<~SQL)
      SELECT
        tasks.title AS task_title,
        projects.name AS project_name,
        tasks.priority AS priority,
        (
          SELECT GROUP_CONCAT(name, ', ')
          FROM (
            SELECT labels.name AS name
            FROM labels
            INNER JOIN task_labels ON task_labels.label_id = labels.id
            WHERE task_labels.task_id = tasks.id
            ORDER BY labels.name
          )
        ) AS label_names,
        tasks.due_at AS due_at,
        tasks.completed_at AS completed_at
      FROM tasks
      LEFT JOIN projects ON projects.id = tasks.project_id
      WHERE tasks.completed_at IS NOT NULL
    SQL

    now = Time.current
    rows.each do |row|
      execute(sanitize_sql_array([
        "INSERT INTO completed_occurrences (task_title, project_name, priority, label_names, due_at, completed_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        row["task_title"], row["project_name"], row["priority"], row["label_names"],
        row["due_at"], row["completed_at"], now, now
      ]))
    end

    execute("DELETE FROM tasks WHERE completed_at IS NOT NULL")
    remove_column :tasks, :completed_at
  end

  def down
    add_column :tasks, :completed_at, :datetime
    drop_table :completed_occurrences
  end
end
