# This file will create dummy data for the application, if not already present.
# This SHOULD NOT be used in production, which is why it's separate from the
# seeds file.

if User.count == 0
  User.create [{first_name: 'Dev', last_name: 'Admin', email: 'admin@beyondz.org', admin: true}]
end

user_count = User.count
FactoryBot.create_list(:user, 5) unless user_count > 1
puts "Created #{User.count - user_count} users"

program = Program.find_or_create_by name: 'SJSU'
role = Role.find_or_create_by name: 'Participant'

User.all.each{|p| p.start_membership(program.id, role.id) if p.program_memberships.empty?}

######
# TODO: this is just quick and dirty for testing the grading related models I'm working on. Clean it up
####

# Add the admin users
User.find_or_create_by email: 'admin@beyondz.org' do |u|
  u.first_name = 'Dev'
  u.last_name = 'Admin(BZ)'
  u.admin = true
end
User.find_or_create_by email: 'admin@bebraven.org' do |u|
  u.first_name = 'Dev'
  u.last_name = 'Admin(BV)'
  u.admin = true
end

module1 = CourseModule.find_or_create_by name: 'Module 1', program: program, position: 1, percent_of_grade: 0.75
module2 = CourseModule.find_or_create_by name: 'Module 2', program: program, position: 1, percent_of_grade: 0.25

project1 = Project.find_or_create_by name: 'Test Project 1', course_module: module1, points_possible: 10
project2 = Project.find_or_create_by name: 'Test Project 2', course_module: module2, points_possible: 20, grades_published_at: DateTime.now 

project_submission1 = ProjectSubmission.find_or_create_by user: User.first, project: project1, points_received: 10, submitted_at: DateTime.now
project_submission2 = ProjectSubmission.find_or_create_by user: User.first, project: project2, points_received: 20, submitted_at: DateTime.now
project_submission3 = ProjectSubmission.find_or_create_by user: User.second, project: project1, points_received: 5, submitted_at: DateTime.now
project_submission4 = ProjectSubmission.find_or_create_by user: User.second, project: project2, points_received: 10, submitted_at: DateTime.now

lesson1 = Lesson.find_or_create_by name: 'Test Lesson 1', course_module: module1, points_possible: 50
lesson2 = Lesson.find_or_create_by name: 'Test Lesson 2', course_module: module2, points_possible: 100

lesson_submission1 = LessonSubmission.find_or_create_by user: User.first, lesson: lesson1, points_received: 50, submitted_at: DateTime.now
lesson_submission2 = LessonSubmission.find_or_create_by user: User.first, lesson: lesson2, points_received: 100, submitted_at: DateTime.now
lesson_submission3 = LessonSubmission.find_or_create_by user: User.second, lesson: lesson1, points_received: 25, submitted_at: DateTime.now
lesson_submission4 = LessonSubmission.find_or_create_by user: User.second, lesson: lesson2, points_received: 50, submitted_at: DateTime.now

