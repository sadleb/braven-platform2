class AddNewIndexToCapstoneEvaluationSubmissions < ActiveRecord::Migration[6.1]
  def change
    add_index :capstone_evaluation_submissions, :new
  end
end