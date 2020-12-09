class DropUserSections < ActiveRecord::Migration[6.0]
  def change
    drop_table :user_sections
  end
end
