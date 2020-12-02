class RenameBaseCourseCustomContentVersionsToCourseCustomContentVersions < ActiveRecord::Migration[6.0]
  def change
    rename_table :base_course_custom_content_versions, :course_custom_content_versions

    # Update foreign keys
    rename_column :project_submissions, :base_course_custom_content_version_id, :course_custom_content_version_id
    rename_column :survey_submissions, :base_course_custom_content_version_id, :course_custom_content_version_id

    rename_index :project_submissions, :index_submissions_on_base_course_custom_content_version_id, :index_project_submissions_on_course_project_version_id
    rename_index :course_custom_content_versions, :index_bcccv_unique_version_ids, :index_course_custom_content_version_unique_version_ids
    rename_index :course_custom_content_versions, :index_base_course_custom_content_versions_on_version_id, :index_course_custom_content_versions_on_version_id
  end
end
