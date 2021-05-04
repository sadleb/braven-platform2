class AddUniqueIndexOnUserSignupToken < ActiveRecord::Migration[6.1]
  def change
    remove_index :users, :signup_token
    add_index :users, :signup_token, unique: true
  end
end
