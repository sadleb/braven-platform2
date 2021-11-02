FactoryBot.define do

  factory :zoom_link_info do

    sequence(:salesforce_participant_id) { |i| "a2Xz%011dEBB" % i }
    salesforce_meeting_id_attribute { 'zoom_meeting_id_1' }
    sequence(:meeting_id)
    sequence(:email) { |i| "zoomemail#{i}@fake.com" }
    sequence(:first_name) { |i| "TestZoomFirstName#{i}" }
    sequence(:last_name) { |i| "TestZoomLastName#{i}" }
    sequence(:registrant_id)

    factory :zoom_link_info_with_prefix do
      sequence(:prefix) { |i| "TestZoomPrefix#{i}"}
    end
  end

end
