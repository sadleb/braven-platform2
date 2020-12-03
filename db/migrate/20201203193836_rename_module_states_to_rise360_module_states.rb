class RenameModuleStatesToRise360ModuleStates < ActiveRecord::Migration[6.0]
  def change
    rename_table :module_states, :rise360_module_states
  end
end
