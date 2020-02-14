class AddOrganizationToProgram < ActiveRecord::Migration[6.0]
  def change

  	# in prod, there are currently no rows in the programs table
    add_column :programs, :term, :string, null: false, default: ''
    change_column_default :programs, :term, from: '', to: nil
    add_column :programs, :organization_id, :integer, null: false, default: 0
    change_column_default :programs, :organization_id, from: 0, to: nil
    add_column :programs, :type, :string
    change_column_null :programs, :name, false

    add_index :programs, [:name, :term, :organization_id], unique: true
    add_foreign_key :programs, :organizations
  end
end
