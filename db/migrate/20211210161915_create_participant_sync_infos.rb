class CreateParticipantSyncInfos < ActiveRecord::Migration[6.1]
  def change
    create_table :participant_sync_infos do |t|
      # Note that this is called sfid to match the HerokuConnect naming b/c
      # we use those models to create this one.
      t.string :sfid, null: false, limit: 18, index: { unique: true }

      # IMPORTANT: these columns MUST exactly match the ParticipantSyncInfo::SyncScope
      # It's tempting to abstract away the underlying Salesforce fields (e.g.
      # lc1_first_name, lc1_last_name, etc into a zoom_prefix field) but if we
      # do that, we can't directly create these models from the HerokuConnect::Participant
      # results (and it prevents us from using a hashed value of the attributes to detect
      # changes in the future). The abstraction will happen in the ruby code instead of DB level.
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :contact_id, null: false, limit: 18
      t.string :status, null: false
      t.string :role, null: false
      t.string :candidate_role_select
      t.string :canvas_accelerator_course_id, null: false
      t.string :canvas_lc_playbook_course_id, null: false
      t.string :cohort_schedule_weekday, null: false
      t.string :cohort_schedule_time
      t.string :cohort_section_name
      t.string :zoom_meeting_id_1
      t.string :zoom_meeting_id_2
      t.string :lc1_first_name
      t.string :lc1_last_name
      t.string :lc2_first_name
      t.string :lc2_last_name
      t.string :lc_count
      t.string :ta_names, array: true
      t.string :ta_caseload_name

      t.check_constraint "char_length(sfid) = 18",
        name: 'chk_participant_sync_infos_sfid_length'
      t.check_constraint "char_length(contact_id) = 18",
        name: 'chk_participant_sync_infos_contact_id_length'

      # Set a timestamp default so we can upsert easier.
      t.timestamps(default: -> { "CURRENT_TIMESTAMP" })
    end
  end
end
