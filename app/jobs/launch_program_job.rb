# frozen_string_literal: true

class LaunchProgramJob < ApplicationJob
  queue_as :default

  def perform(salesforce_program_id, notification_email, fellow_source_course_id, fellow_course_name, lc_source_course_id, lc_course_name)

    LaunchProgram.new(salesforce_program_id, fellow_source_course_id, fellow_course_name, lc_source_course_id, lc_course_name).run
    LaunchProgramMailer.with(email: notification_email).success_email.deliver_now

  rescue => exception
    Rails.logger.error(exception)
    LaunchProgramMailer.with(email: notification_email, exception: exception).failure_email.deliver_now
    raise
  end

end
