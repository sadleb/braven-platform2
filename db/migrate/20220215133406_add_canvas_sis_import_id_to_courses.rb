class AddCanvasSisImportIdToCourses < ActiveRecord::Migration[6.1]
  def change
    add_column :courses, :last_canvas_sis_import_id, :bigint
  end
end
