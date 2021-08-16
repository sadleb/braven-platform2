class AddContextToCanvasRubrics < ActiveRecord::Migration[6.1]
  def change
    add_column :canvas_rubrics, :canvas_context_id, :bigint
    add_column :canvas_rubrics, :canvas_context_type, :string
  end
end
