class CreateSurveySubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :survey_submissions do |t|
      t.belongs_to :user, foreign_key: true, null: false
      # This index name is over the 63 character limit, specify one manually
      t.belongs_to :base_course_custom_content_version, foreign_key: true, null: false, index: { name: 'index_survey_submissions_on_course_survey_version_id' }
      t.timestamps
    end
  end
end
