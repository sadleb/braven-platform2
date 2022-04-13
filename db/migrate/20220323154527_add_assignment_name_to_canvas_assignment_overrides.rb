class AddAssignmentNameToCanvasAssignmentOverrides < ActiveRecord::Migration[6.1]
  def change
    add_column :canvas_assignment_overrides, :assignment_name, :string
  end
end
