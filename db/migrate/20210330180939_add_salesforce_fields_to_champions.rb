class AddSalesforceFieldsToChampions < ActiveRecord::Migration[6.1]
  def change
    add_column :champions, :salesforce_id, :string
    add_column :champions, :salesforce_campaign_member_id, :string
  end
end
