class AddMetadataToRise360ModuleVersions < ActiveRecord::Migration[6.0]
  def change
    add_column :rise360_module_versions, :activity_id, :string
    add_column :rise360_module_versions, :quiz_questions, :integer
    add_index :rise360_module_versions, [:activity_id]
  end
end
