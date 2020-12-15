# frozen_string_literal: true

# Responsible for running app/services/clone_course.rb as
# a background job and sending an email notification when complete
# since it takes time and could time-out in the UI.
class CloneCourseJob < ApplicationJob
  queue_as :default

  def perform(notification_email, source_course, destination_course_name)
    CloneCourse.new(source_course, destination_course_name).run.wait_and_initialize
    CloneCourseMailer.with(email: notification_email).success_email.deliver_now
  end

  rescue_from(StandardError) do |exception|
    CloneCourseMailer.with(email: arguments.first, exception: exception).failure_email.deliver_now
    raise
  end
end
