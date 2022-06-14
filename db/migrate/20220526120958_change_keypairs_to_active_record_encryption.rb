class ChangeKeypairsToActiveRecordEncryption < ActiveRecord::Migration[7.0]
  # Migrates from using attr_encrypted gem to using Rails 7 ActiveRecord encrypted
  # attributes: https://edgeguides.rubyonrails.org/active_record_encryption.html
  def change
    # We could write a migration like the articule below describes, but these are only used
    # during the LtiLaunch handshake and are regenerated monthly. So we can just blow them
    # away and the next time it's used a new one will be generated with the new encryption.
    # https://pagertree.com/2021/04/13/rails-7-attr-encrypted-migration/
    Keypair.destroy_all

    # Old columns used by attr_encrypted gem
    remove_column :keypairs, :encrypted__keypair, :string, null: false
    remove_column :keypairs, :encrypted__keypair_iv, :string, null: false

    # New column to hold encrypted value. See:
    # https://edgeguides.rubyonrails.org/active_record_encryption.html#declaration-of-encrypted-attributes
    add_column :keypairs, :keypair, :text, null: false
  end
end
