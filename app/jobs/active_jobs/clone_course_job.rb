# frozen_string_literal: true

# Responsible for running app/services/clone_course.rb as
# a background job and sending an email notification when complete
# since it takes time and could time-out in the UI.
class CloneCourseJob < ApplicationJob
  queue_as :default

  def perform(notification_email, source_course, destination_course_name, salesforce_program)
    Honeycomb.add_field(ApplicationJob::HONEYCOMB_RUNNING_USER_EMAIL_FIELD, notification_email)
    CloneCourse.new(source_course, destination_course_name, salesforce_program).run.wait_and_initialize
    CloneCourseMailer.with(email: notification_email).success_email.deliver_now
  rescue => exception
    Rails.logger.error(exception)
    CloneCourseMailer.with(email: notification_email, exception: exception).failure_email.deliver_now
    raise
  end

end
