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

    # This is irreversible. Trying to rollback this migration with throw
    # an exception. This is the desired behavior b/c really we're just getting
    # core data model infrastructure in place and haven't started using these
    # yet in production. We want a clear point in the migration chain where
    # before that it's clear the related data models weren't used and after
    # they are future migrations have to plan for how to preserve data on rollbacks
    # if they are altering actively used data.
    drop_table :people 
  end
end
