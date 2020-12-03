class CreateModuleStates < ActiveRecord::Migration[6.0]
  def change
    create_table :module_states do |t|
      t.bigint :canvas_course_id, null: false
      t.bigint :canvas_assignment_id, null: false
      t.string :activity_id, null: false
      t.references :user, null: false, foreign_key: true
      t.string :state_id, null: false
      t.text :value
    end

    add_index :module_states,
      [:canvas_course_id, :canvas_assignment_id, :activity_id, :user_id, :state_id],
      unique: true,
      name: 'module_states_unique_index_1'
  end
end
