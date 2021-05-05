class AddManualGradeOverriddenToRise360ModuleGrade < ActiveRecord::Migration[6.1]
  def change
    add_column :rise360_module_grades, :grade_manually_overridden, :boolean, default: false
  end
end
