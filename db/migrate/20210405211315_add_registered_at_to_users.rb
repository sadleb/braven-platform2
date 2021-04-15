class AddRegisteredAtToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :registered_at, :datetime, default: nil
  end
end
