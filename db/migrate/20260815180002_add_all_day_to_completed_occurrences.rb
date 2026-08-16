class AddAllDayToCompletedOccurrences < ActiveRecord::Migration[8.0]
  def up
    add_column :completed_occurrences, :all_day, :boolean, null: false, default: false

    # Historical rows (from the CompletedOccurrences backfill, whose source
    # `tasks` rows are already deleted) can't be reclassified faithfully: the
    # app allows a genuinely `00:00`-timed task distinct from an all-day one,
    # and midnight due_at alone can't distinguish them. Leave them at the
    # default false rather than corrupt data. Live completions snapshot
    # all_day from the task, so only pre-existing history shows a phantom
    # midnight time.
  end

  def down
    remove_column :completed_occurrences, :all_day
  end
end
