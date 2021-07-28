# frozen_string_literal: true

class GenerateZoomLinksMailer < ApplicationMailer
  def success_email
    attachments['meeting_participants.csv'] = { mime_type: 'text/csv', content: attachment }
    mail(to: recipient, subject: 'Here are the Zoom links you generated')
  end

  def failure_email
    @exception = params[:exception]
    @participants = params[:participants]
    @failed_participants = params[:failed_participants]
    mail(to: recipient, subject: 'Zoom links generation failed')
  end

  private

  def recipient
    params[:email]
  end

  def attachment
    params[:csv]
  end
end
