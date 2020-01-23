class MovePersonColumnsToUser < ActiveRecord::Migration[6.0]
  def change

    # Note: we haven't started using this stuff in production,
    # so there is not data in the people table. It's safe to just re-create
    # it on users and drop the table

    change_table :users do |t|
      t.string :first_name, null: false, default: ''
      t.string :middle_name
      t.string :last_name, null: false, default: ''
    end

    drop_table :people do |t|
      t.string :first_name, null: false
      t.string :middle_name
      t.string :last_name, null: false
      t.timestamps null: false
    end
  end
end
