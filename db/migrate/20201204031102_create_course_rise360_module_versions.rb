class CreateCourseRise360ModuleVersions < ActiveRecord::Migration[6.0]
  def change
    create_table :course_rise360_module_versions do |t|
      t.references :course, null: false, foreign_key: true
      t.references :rise360_module_version, null: false, foreign_key: true, index: { name: 'index_course_module_versions_on_module_version_id '}
      t.integer :canvas_assignment_id
    end
  end
end
