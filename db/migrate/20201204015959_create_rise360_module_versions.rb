class CreateRise360ModuleVersions < ActiveRecord::Migration[6.0]
  def change
    create_table :rise360_module_versions do |t|
      t.references :rise360_module, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
  end
end
