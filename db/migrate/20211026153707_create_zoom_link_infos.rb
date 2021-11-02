class CreateZoomLinkInfos < ActiveRecord::Migration[6.1]
  def change
    create_table :zoom_link_infos do |t|
      #####
      # Columns used to lookup / uniquely identify which "link" this info is for
      ####
      t.string :salesforce_participant_id, null: false
      t.check_constraint "char_length(salesforce_participant_id) = 18",
        name: 'chk_zoom_link_infos_salesforce_participant_id_length'
      # This is the attribute on the SalesforceAPI::SFParticipant struct that we
      # used to generate this link / registrant. E.g. zoom_meeting_id_1
      t.string :salesforce_meeting_id_attribute, null: false
      t.check_constraint "salesforce_meeting_id_attribute IN ('zoom_meeting_id_1', 'zoom_meeting_id_2')",
        name: 'chk_zoom_link_infos_sf_meeting_id_attribute'
      t.index [:salesforce_participant_id, :salesforce_meeting_id_attribute], name: "index_zoom_link_infos_uniqueness", unique: true

      #####
      # The information used to generate the registrant for a meeting. If any
      # of this changes, we need to update the registration / link to match the
      # new info
      #####
      t.string :meeting_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :prefix

      #####
      # The resulting information to use in future API calls to update the registration
      # Note: we're purposefully not storing the actual join_url here b/c Salesforce is the
      # source of truth and we don't want to start using a different link internally in
      # the Platform from what is in Salesforce.
      #####
      t.string :registrant_id, null: false, index: { unique: true }

      # Set a timestamp default so we can upsert easier.
      t.timestamps(default: -> { "CURRENT_TIMESTAMP" })
    end
  end
end
