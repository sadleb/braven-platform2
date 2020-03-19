class AddUserToCourseContentHistories < ActiveRecord::Migration[6.0]
  def change
    add_reference :course_content_histories, :user, foreign_key: true
  end
end
