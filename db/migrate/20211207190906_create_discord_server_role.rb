class CreateDiscordServerRole < ActiveRecord::Migration[6.1]
  def change
    create_table :discord_server_roles do |t|
      t.references :discord_server, null: false, foreign_key: true
      t.string :discord_role_id, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :discord_server_roles, :discord_role_id, unique: true
    add_index :discord_server_roles, [:discord_server_id, :name], unique: true
  end
end
