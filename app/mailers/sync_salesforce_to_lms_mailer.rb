# frozen_string_literal: true

# Salesforce sync response mailer
class SyncSalesforceToLmsMailer < ApplicationMailer
  def success_email
    mail(to: recipient, subject: 'Sync Successful')
  end

  def failure_email
    @exception = params[:exception]
    @failed_participants = params[:failed_participants]
    @total_participants_count = params[:total_participants_count]
    mail(to: recipient, subject: 'Sync Failed')
  end

  private

  def recipient
    params[:email]
  end
end
