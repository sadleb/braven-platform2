class AddTypeToBaseCourseCustomContentVersions < ActiveRecord::Migration[6.0]
  def change
    add_column :base_course_custom_content_versions, :type, :string
  end
end
