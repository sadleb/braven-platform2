class AddDiscordExpiresAtToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :discord_expires_at, :datetime
  end
end
