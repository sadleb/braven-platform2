class CreateRateThisModuleSubmissionAnswer < ActiveRecord::Migration[6.0]
  def change
    create_table :rate_this_module_submission_answers do |t|
      t.string :input_name, null: false
      t.string :input_value
      t.references :rate_this_module_submission, null: false, foreign_key: true,
        index: { name: 'index_rate_this_module_submission_answers_fkey_1' }
      t.timestamps
    end

    add_index :rate_this_module_submission_answers,
      [:rate_this_module_submission_id, :input_name],
      unique: true,
      name: 'index_rate_this_module_submission_answers_u1'
  end
end
