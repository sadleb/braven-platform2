class CreateDiscordServers < ActiveRecord::Migration[6.1]
  def change
    create_table :discord_servers do |t|
      t.string :discord_server_id, null:false
      t.string :name
      t.string :webhook_id
      t.string :webhook_token

      t.timestamps
    end
  end
end
