# This file will create dummy data for the application, if not already present.
# This SHOULD NOT be used in production, which is why it's separate from the
# seeds file.

# Add the admin users
u1 = User.find_or_create_by email: 'admin@beyondz.org' do |u|
  u.first_name = 'Dev'
  u.last_name = 'Admin(BZ)'
  u.password = "#{ENV['DEV_ENV_USER_PASSWORD']}"
  u.add_role :admin
end
u1.update!(
  confirmed_at:  DateTime.now,
  registered_at: DateTime.now
)

u2 = User.find_or_create_by email: 'admin@bebraven.org' do |u|
  u.first_name = 'Dev'
  u.last_name = 'Admin(BV)'
  u.password = "#{ENV['DEV_ENV_USER_PASSWORD']}"
  u.confirmed_at = DateTime.now
  u.registered_at = DateTime.now
  u.add_role :admin
end
u2.update!(
  confirmed_at:  DateTime.now,
  registered_at: DateTime.now
)

u3 = User.find_or_create_by email: 'booster.admin@bebraven.org' do |u|
  u.first_name = 'Dev'
  u.last_name = 'Admin(Booster)'
  u.password = "#{ENV['DEV_ENV_USER_PASSWORD']}"
  u.confirmed_at = DateTime.now
  u.registered_at = DateTime.now
  u.add_role :admin
end
u3.update!(
  confirmed_at:  DateTime.now,
  registered_at: DateTime.now
)

user_count = User.count
FactoryBot.create_list(:registered_user, 5) unless user_count > 3
puts "Created #{User.count - user_count} users"

course = Course.find_or_create_by! name: 'Launched Accelerator Course', is_launched: true
unlaunched_course = Course.find_or_create_by! name: 'Accelerator Template', is_launched: false
