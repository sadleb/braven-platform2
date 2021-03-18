class DropLessons < ActiveRecord::Migration[6.1]
  def change
    drop_table :lesson_submissions
    drop_table :lessons
  end
end
