class AddUniqueIndexOnUserSalesforceId < ActiveRecord::Migration[6.1]
  def change
    User.where(salesforce_id: '').update_all(salesforce_id: nil)
    remove_index :users, :salesforce_id
    add_index :users, :salesforce_id, unique: true
  end
end
