class AddUniqueIndexToCourseRise360ModuleVersions < ActiveRecord::Migration[6.0]
  def change
    add_index :course_rise360_module_versions, :canvas_assignment_id, unique: true
  end
end
