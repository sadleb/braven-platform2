class ChangeParticipantSyncInfoColumnsNullable < ActiveRecord::Migration[6.1]
  def change
    change_column_null :participant_sync_infos, :cohort_schedule_weekday, true
  end
end
