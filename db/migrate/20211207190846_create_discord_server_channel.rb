class CreateDiscordServerChannel < ActiveRecord::Migration[6.1]
  def change
    create_table :discord_server_channels do |t|
      t.references :discord_server, null: false, foreign_key: true
      t.string :discord_channel_id, null: false
      t.string :name, null: false
      t.integer :position, null: false

      t.timestamps
    end
    add_index :discord_server_channels, :discord_channel_id, unique: true
    add_index :discord_server_channels, [:discord_server_id, :name], unique: true
  end
end
