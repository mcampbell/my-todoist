class AddCompletionNotesToCompletedOccurrences < ActiveRecord::Migration[8.1]
  def change
    add_column :completed_occurrences, :completion_notes, :text
  end
end
