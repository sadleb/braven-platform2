class RemoveEmailSentDatesFromChampionContacts < ActiveRecord::Migration[6.1]
  def change
    remove_column :champion_contacts, :first_email_from_fellow_sent, :datetime
    remove_column :champion_contacts, :latest_email_from_fellow_sent, :datetime
    remove_column :champion_contacts, :first_email_from_champion_sent, :datetime
    remove_column :champion_contacts, :latest_email_from_champion_sent, :datetime
  end
end
