class AddCanvasResultsUrlIndexToRise360ModuleGrades < ActiveRecord::Migration[6.1]
  def change
    # Partial index on canvas_results_url since we use that to tell if they've opened
    # the module when running the grading logic. See `with_submissions` query/scope
    add_index :rise360_module_grades, :canvas_results_url, where: "canvas_results_url IS NOT NULL",
      name: "index_rise360_module_grades_on_canvas_results_url_exists"
  end
end
