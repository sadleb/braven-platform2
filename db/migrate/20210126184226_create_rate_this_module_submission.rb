class CreateRateThisModuleSubmission < ActiveRecord::Migration[6.0]
  def change
    create_table :rate_this_module_submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course_rise360_module_version, null: false, foreign_key: true,
        index: { name: 'index_rate_this_module_submissions_fkey_2' }
      t.timestamps
    end

    add_index :rate_this_module_submissions,
      [:user_id, :course_rise360_module_version_id],
      unique: true,
      name: 'index_rate_this_module_submissions_unique_1'
  end
end
