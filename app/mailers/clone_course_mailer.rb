# frozen_string_literal: true

class CloneCourseMailer < ApplicationMailer
  def success_email
    mail(to: recipient, subject: 'Initialize New Course Template Successful')
  end

  def failure_email
    @exception = params[:exception]
    mail(to: recipient, subject: 'Initialize New Course Template Failed - Uh Oh')
  end

  private

  def recipient
    params[:email]
  end
end
