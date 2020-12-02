class RenameBaseCourseToCourse < ActiveRecord::Migration[6.0]
  def change
    rename_table :base_courses, :courses

    # Update foreign keys
    rename_column :base_course_custom_content_versions, :base_course_id, :course_id
    rename_column :grade_categories, :base_course_id, :course_id
    rename_column :peer_review_submissions, :base_course_id, :course_id
    rename_column :sections, :base_course_id, :course_id
  end
end
