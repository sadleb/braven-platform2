FactoryBot.define do
  # Represents a CommunicationChannel returned from the canvas API
  # See: https://canvas.instructure.com/doc/api/communication_channels.html
  #
  # Important: this is meant to be built with FactoryBot.json(:canvas_communication_channel)
  factory :canvas_communication_channel, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id)
    sequence(:address) { |i| "test#{i}@example.com" }
    type { 'email' }
    position { 1 }
    sequence(:user_id)
    workflow_state { 'active' }

    initialize_with { attributes.stringify_keys }
  end
end

# Example
# {
#  // The ID of the communication channel.
#  "id": 16,
#  // The address, or path, of the communication channel.
#  "address": "sheldon@caltech.example.com",
#  // The type of communcation channel being described. Possible values are:
#  // 'email', 'push', 'sms', or 'twitter'. This field determines the type of value
#  // seen in 'address'.
#  "type": "email",
#  // The position of this communication channel relative to the user's other
#  // channels when they are ordered.
#  "position": 1,
#  // The ID of the user that owns this communication channel.
#  "user_id": 1,
#  // The current state of the communication channel. Possible values are:
#  // 'unconfirmed' or 'active'.
#  "workflow_state": "active"
#}
