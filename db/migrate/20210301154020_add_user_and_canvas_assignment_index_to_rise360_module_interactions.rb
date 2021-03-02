class AddUserAndCanvasAssignmentIndexToRise360ModuleInteractions < ActiveRecord::Migration[6.0]
  def change
    add_index :rise360_module_interactions, [:user_id, :canvas_assignment_id], name: 'index_rise360_module_interactions_on_user_id_and_assignment_id'
  end
end
