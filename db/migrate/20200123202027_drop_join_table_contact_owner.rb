class DropJoinTableContactOwner < ActiveRecord::Migration[6.0]
  def change
    # Irreversible and can't be rolled back.  This isn't used yet in prod.
    # See: 20200123165835_move_person_columns_to_user.rb for more context 
    # on why this is the desired behavior.
    drop_table :contact_owners
  end
end
