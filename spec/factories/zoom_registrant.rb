FactoryBot.define do

  # Represents the response to add a meeting regisrant with the Zoom API
  # See: https://marketplace.zoom.us/docs/api-reference/zoom-api/meetings/meetingregistrantcreate

  factory :zoom_registrant, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id)
    sequence(:join_url) { |i| "https://us02web.zoom.us/w/1234567890?tk=abunchofchars&pwd=abunchofchars#{i}" }
    sequence(:registrant_id)
    start_time { DateTime.now.utc.to_i }
    topic { 'Test Meeting' }

    initialize_with { attributes.stringify_keys }
  end

end
