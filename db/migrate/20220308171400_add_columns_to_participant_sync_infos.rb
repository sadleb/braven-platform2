class AddColumnsToParticipantSyncInfos < ActiveRecord::Migration[6.1]
  def change
    add_column :participant_sync_infos, :canvas_user_id, :bigint
    add_column :participant_sync_infos, :user_id, :bigint
    add_column :participant_sync_infos, :program_id, :string, limit: 18
    add_column :participant_sync_infos, :cohort_id, :string, limit: 18
    add_column :participant_sync_infos, :cohort_schedule_id, :string, limit: 18

    add_column :participant_sync_infos, :ta_caseload_enrollments, :json
    remove_column :participant_sync_infos, :ta_names
    remove_column :participant_sync_infos, :ta_caseload_name

    # Prevent duplicate Participants for the same Contact in a Program
    add_index :participant_sync_infos, [:contact_id, :program_id], unique: true

    add_check_constraint :participant_sync_infos, "char_length(program_id) = 18",
        name: 'chk_participant_sync_infos_program_id_length'
    add_check_constraint :participant_sync_infos, "char_length(cohort_id) = 18",
        name: 'chk_participant_sync_infos_cohort_id_length'
    add_check_constraint :participant_sync_infos, "char_length(cohort_schedule_id) = 18",
        name: 'chk_participant_sync_infos_cohort_schedule_id_length'
  end
end
