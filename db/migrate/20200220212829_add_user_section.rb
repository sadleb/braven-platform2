class AddUserSection < ActiveRecord::Migration[6.0]
  def up
    create_table :user_sections do |t|
      t.integer :user_id, null: false
      t.integer :section_id, null: false
      t.string :type, null: false

      t.timestamps
    end

    add_index :user_sections, [:user_id, :section_id], unique: true
    add_index :user_sections, :user_id
    add_index :user_sections, :section_id

    add_foreign_key :user_sections, :users
    add_foreign_key :user_sections, :sections
  end

  def down
    drop_table :user_sections
  end
end
