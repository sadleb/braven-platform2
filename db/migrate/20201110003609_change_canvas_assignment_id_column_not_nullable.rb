class ChangeCanvasAssignmentIdColumnNotNullable < ActiveRecord::Migration[6.0]
  def change
    change_column_null :base_course_custom_content_versions, :canvas_assignment_id, false, 0
  end
end
