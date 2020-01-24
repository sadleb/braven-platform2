class CreateCourseContentAnswers < ActiveRecord::Migration[6.0]
  def change
    create_table :course_content_answers do |t|
      t.string :uuid
      t.references :course_content, null: false, foreign_key: true
      t.boolean :correctness
      t.boolean :mastery
      t.boolean :instant_feedback

      t.timestamps

      t.index [:course_content_id, :uuid], unique: true
    end
  end
end
