class ChangeCanvasIdsToBigint < ActiveRecord::Migration[6.0]
  def up
    change_column :course_custom_content_versions, :canvas_assignment_id, :bigint
    change_column :course_rise360_module_versions, :canvas_assignment_id, :bigint
    change_column :courses, :canvas_course_id, :bigint
    change_column :rise360_module_interactions, :canvas_course_id, :bigint
    change_column :rise360_module_interactions, :canvas_assignment_id, :bigint
    change_column :sections, :canvas_section_id, :bigint
    change_column :users, :canvas_user_id, :bigint
  end

  def down
    change_column :course_custom_content_versions, :canvas_assignment_id, :int
    change_column :course_rise360_module_versions, :canvas_assignment_id, :int
    change_column :courses, :canvas_course_id, :int
    change_column :rise360_module_interactions, :canvas_course_id, :int
    change_column :rise360_module_interactions, :canvas_assignment_id, :int
    change_column :sections, :canvas_section_id, :int
    change_column :users, :canvas_user_id, :int
  end
end
