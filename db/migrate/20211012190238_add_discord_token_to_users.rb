class AddDiscordTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :discord_token, :string
  end
end
