# frozen_string_literal: true

class GenerateTestUsersMailer < ApplicationMailer
  def success_email
    @success_users = params[:success_users]
    mail(to: recipient, subject: 'Test User Generation Successful')
  end

  def failure_email
    @exception = params[:exception]
    @failed_users = params[:failed_users]
    @success_users = params[:success_users]
    @sync_error = params[:sync_error]
    mail(to: recipient, subject: 'Test User Generation Failed - Uh Oh')
  end

  private

  def recipient
    params[:email]
  end
end
