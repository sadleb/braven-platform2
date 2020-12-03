class RenameModuleInteractionsToRise360ModuleInteractions < ActiveRecord::Migration[6.0]
  def change
    rename_table :module_interactions, :rise360_module_interactions
  end
end
