class AddNotesToCompletedOccurrences < ActiveRecord::Migration[8.1]
  def change
    add_column :completed_occurrences, :notes, :text
  end
end
