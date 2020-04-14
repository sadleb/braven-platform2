FactoryBot.define do
  # Represents a user returned from the canvas API
  factory :canvas_user, class: Hash do
    skip_create # This isn't stored in the DB.
    sequence(:email) {|i| "test#{i}@example.com"}
    sequence(:id) 
    integration_id { "null" }
    login_id { email }
    sequence(:short_name) { |i| "TestFirst#{i}" }
    sequence(:name) { |i| "#{short_name} TestLast#{i}" }
    sis_import_id { "null" }
    sis_login_id { email }
    sequence(:sis_user_id) { |i| "BVSFID#{i}-SISID#{i}" }
    sequence(:sortable_name) { |i| "TestLast#{i}, #{short_name}" }
    initialize_with { attributes.stringify_keys }
  end
end

# Example
#{
#    "email": "brian+testsyncfellowtolmssjsu1@bebraven.org",
#    "id": 3720,
#    "integration_id": null,
#    "login_id": "brian+testsyncfellowtolmssjsu1@bebraven.org",
#    "name": "brian+testsyncfellowtolmssjsu1@bebraven.org",
#    "short_name": "Brian",
#    "sis_import_id": null,
#    "sis_login_id": "brian+testsyncfellowtolmssjsu1@bebraven.org",
#    "sis_user_id": "BVSFID003170000124dLOAAY-SISID",
#    "sortable_name": "xTestSyncFellowToLmsSJSU1, Brian"
#}

