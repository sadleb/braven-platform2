class RenameLessonInteractionsToModuleInteractions < ActiveRecord::Migration[6.0]
  def change
    rename_table :lesson_interactions, :module_interactions
  end
end
