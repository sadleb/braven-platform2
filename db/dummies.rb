# This file will create dummy data for the application, if not already present.
# This SHOULD NOT be used in production, which is why it's separate from the
# seeds file.

user_count = User.count
FactoryBot.create_list(:user, 5) unless user_count > 0
puts "Created #{User.count - user_count} users"

program = Program.find_or_create_by name: 'SJSU'
role = Role.find_or_create_by name: 'Participant'

User.all.each{|p| p.start_membership(program.id, role.id) if p.program_memberships.empty?}
