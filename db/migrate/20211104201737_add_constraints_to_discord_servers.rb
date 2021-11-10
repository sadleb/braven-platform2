class AddConstraintsToDiscordServers < ActiveRecord::Migration[6.1]
  def change
    # Remove existing servers with invalid info.
    DiscordServer.where('webhook_id IS NULL OR webhook_token IS NULL OR name IS NULL').destroy_all

    # Modify constraints.
    change_column_null :discord_servers, :discord_server_id, false
    change_column_null :discord_servers, :name, false
    change_column_null :discord_servers, :webhook_id, false
    change_column_null :discord_servers, :webhook_token, false
    add_index :discord_servers, :name, :unique => true
    add_index :discord_servers, :discord_server_id, :unique => true
    add_index :discord_servers, :webhook_id, :unique => true
  end
end
