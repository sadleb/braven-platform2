FactoryBot.define do
  # https://canvas.instructure.com/doc/api/logins.html
  factory :canvas_login, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id)
    sequence(:account_id)
    authentication_provider_id { nil }
    created_at { DateTime.now.utc.iso8601 }
    integration_id { nil }
    sequence(:sis_user_id) { |i| "BVSFID00311555#{i}mxTLTAA2-SISID" }
    sequence(:unique_id) { |i| "some_email#{i}@fake.email.com" }
    sequence(:user_id)

    initialize_with { attributes.stringify_keys }
  end
end

# Example
# {
#     "account_id": 1,
#     "authentication_provider_id": null,
#     "created_at": "2021-04-01T19:44:10Z",
#     "id": 324,
#     "integration_id": null,
#     "sis_user_id": "BVSFID0031155551mxTLTAA2-SISID",
#     "unique_id": "some_email@fake.email.org",
#     "user_id": 335
# }
