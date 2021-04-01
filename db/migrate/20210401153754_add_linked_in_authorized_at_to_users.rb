class AddLinkedInAuthorizedAtToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :linked_in_authorized_at, :datetime, default: nil
  end
end
