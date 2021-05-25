class AddUsersRolesFkeyRefs < ActiveRecord::Migration[6.1]
  def change
    add_foreign_key :users_roles, :users
    add_foreign_key :users_roles, :roles
  end
end
