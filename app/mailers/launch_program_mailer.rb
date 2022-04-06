# frozen_string_literal: true

class LaunchProgramMailer < ApplicationMailer
  def success_email
    @accelerator_course = params[:accelerator_course]
    @lc_playbook_course = params[:lc_playbook_course]
    mail(to: recipient, subject: 'New Program Launch Successful')
  end

  def failure_email
    @exception = params[:exception]
    mail(to: recipient, subject: 'New Program Launch Failed - Uh Oh')
  end

  private

  def recipient
    params[:email]
  end
end
