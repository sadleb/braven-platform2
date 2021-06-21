FactoryBot.define do

  # Represents a participant hash used to create registered participants with the Zoom API
  # See: https://marketplace.zoom.us/docs/api-reference/zoom-api/meetings/meetingregistrantcreate

  factory :zoom_participant, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:email) { |i| "zoomemail#{i}@fake.com" }
    sequence(:first_name) { |i| "TestZoomFirstName#{i}" }
    sequence(:last_name) { |i| "TestZoomLastName#{i}" }

    initialize_with { attributes.stringify_keys }
  end

end
