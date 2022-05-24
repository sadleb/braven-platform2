# frozen_string_literal: true

class GenerateTestUsersJob < ApplicationJob
  queue_as :default

  def perform(send_to_email, params)
    Honeycomb.add_field('generate_test_users.params', params)
    generate_service = GenerateTestUsers.new(params)

    begin
      generate_service.run()
      GenerateTestUsersMailer.with(
        email: send_to_email,
        success_users: generate_service.success_users,
      ).success_email.deliver_now
    rescue => e
      Rails.logger.error(e)
      GenerateTestUsersMailer.with(
        email: send_to_email,
        exception: e,
        failed_users: generate_service.failed_users,
        success_users: generate_service.success_users,
        sync_error: generate_service.sync_error_message
      ).failure_email.deliver_now

      raise
    end
  end

end
