class AddLogistics < ActiveRecord::Migration[6.0]
  def up
    create_table :logistics do |t|
      t.string :day_of_week, null: false
      t.string :time_of_day, null: false
      t.integer :program_id, null: false

      t.timestamps
    end

    add_index :logistics, [:day_of_week, :time_of_day, :program_id], unique: true
    add_foreign_key :logistics, :programs
  end

  def down
    drop_table :logistics
  end
end
