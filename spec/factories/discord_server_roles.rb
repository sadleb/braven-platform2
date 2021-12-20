FactoryBot.define do
  factory :discord_server_role do
    association(:discord_server)
    sequence(:discord_role_id)
    sequence(:name) {|i| "Role #{i}"}
  end
end
