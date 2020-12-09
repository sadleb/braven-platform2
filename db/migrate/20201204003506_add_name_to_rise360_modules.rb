class AddNameToRise360Modules < ActiveRecord::Migration[6.0]
  def change
    add_column :rise360_modules, :name, :string, null: false, default: ''
  end
end
