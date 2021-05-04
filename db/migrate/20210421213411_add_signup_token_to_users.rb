class AddSignupTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :signup_token, :string
    add_column :users, :signup_token_sent_at, :datetime
    add_index :users, :signup_token
  end
end
