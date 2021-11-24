FactoryBot.define do
  factory :discord_server do
    sequence(:discord_server_id)
    sequence(:name) {|i| "Discord Server Name #{i}"}
    sequence(:webhook_id)
    sequence(:webhook_token) { |i| "test#{i}" }
  end
end
