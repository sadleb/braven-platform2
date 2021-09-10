class RemoveManuallyOverriddenFromRise360ModuleGrades < ActiveRecord::Migration[6.1]
  def change
    remove_column :rise360_module_grades, :grade_manually_overridden, :boolean
  end
end
