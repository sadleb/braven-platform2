class ChangeProgramMembershipsFromPersonToUser < ActiveRecord::Migration[6.0]
  def change
    change_table :program_memberships do |t|
      t.rename :person_id, :user_id
    end
  end
end
