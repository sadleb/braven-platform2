FactoryBot.define do
  # https://canvas.instructure.com/doc/api/admins.html
  factory :canvas_admin, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id)
    role { 'SomeCanvasAccountRole' }
    sequence(:role_id)
    user { build :canvas_user }
    workflow_state { 'some_state' } # e.g. deleted or active

    factory :canvas_account_admin do
      role { 'Account Admin' }
    end

    factory :canvas_staff_account do
      role { 'Staff Account' }
    end

    initialize_with { attributes.stringify_keys }
  end
end

# Example
# {
#   "id": 1,
#   "role": "Account Admin",
#   "role_id": 2,
#   "user": {
#     "id": 3,
#     "name": "Brian xTestUser",
#     "login_in": "some_email@fake.email.org",
#     ... more user attributes ...
#   }
# }
