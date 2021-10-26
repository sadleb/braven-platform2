class AddSalesforceProgramIdToCourses < ActiveRecord::Migration[6.1]
  def change
    add_column :courses, :salesforce_program_id, :string, limit: 18
  end
end
