class AddDiscordStateToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :discord_state, :string
  end
end
