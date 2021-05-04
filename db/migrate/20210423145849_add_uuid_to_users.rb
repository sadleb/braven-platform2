class AddUuidToUsers < ActiveRecord::Migration[6.1]
  def change
    # Note: gen_random_uuid() is from pgcypto in Postgres >= 9.4.
    enable_extension 'pgcrypto'
    add_column :users, :uuid, :string, null: false, default: -> { "gen_random_uuid()" }
    add_index :users, [:uuid], :unique => true
  end
end
