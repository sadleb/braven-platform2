class AddSections < ActiveRecord::Migration[6.0]
  def up
    create_table :sections do |t|
      t.string :name, null: false
      t.integer :logistic_id, null: false
      t.integer :program_id, null: false

      t.timestamps
    end

    add_index :sections, [:name, :program_id], unique: true
    add_foreign_key :sections, :programs
    add_foreign_key :sections, :logistics
  end

  def down
    drop_table :sections
  end
end
