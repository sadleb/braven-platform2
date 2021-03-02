class CreateRise360ModuleGrades < ActiveRecord::Migration[6.0]
  def change
    create_table :rise360_module_grades do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course_rise360_module_version, null: false, foreign_key: true

      # Storing the URL that the LtiAdvantageAPI.create_score() endpoint returns
      # b/c we'll eventually want to grab the value that's in Canvas and compare
      # it too our computed value to handle discrepencies, like someone manually
      # changing it in Canvas.
      t.string :canvas_results_url

      t.index [:user_id, :course_rise360_module_version_id], name: "index_rise360_module_grades_uniqueness", unique: true
    end
  end
end
