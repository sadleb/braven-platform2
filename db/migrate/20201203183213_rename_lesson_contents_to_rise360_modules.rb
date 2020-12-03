class RenameLessonContentsToRise360Modules < ActiveRecord::Migration[6.0]
  def change
    rename_table :lesson_contents, :rise360_modules
  end
end
