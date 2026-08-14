class CreateLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :labels do |t|
      t.string :name, null: false, collation: "NOCASE"

      t.timestamps
    end
    add_index :labels, :name, unique: true
  end
end
