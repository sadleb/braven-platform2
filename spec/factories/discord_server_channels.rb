FactoryBot.define do
  factory :discord_server_channel do
    association(:discord_server)
    sequence(:discord_channel_id)
    sequence(:name) {|i| "channel-#{i}"}
    sequence(:position)
  end
end
