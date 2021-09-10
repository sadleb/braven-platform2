class AddOnTimeCreditReceivedToRise360ModuleGrades < ActiveRecord::Migration[6.1]
  def change
    add_column :rise360_module_grades, :on_time_credit_received, :boolean, null: false, default: false
  end
end
