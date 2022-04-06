class ChangeParticipantSyncInfosRoleToRoleCategory < ActiveRecord::Migration[6.1]
  def change
    rename_column :participant_sync_infos, :role, :role_category
  end
end
