class AddNewToCapstoneEvaluationSubmissions < ActiveRecord::Migration[6.1]
  def change
    add_column :capstone_evaluation_submissions, :new, :boolean, default: true
  end
end
