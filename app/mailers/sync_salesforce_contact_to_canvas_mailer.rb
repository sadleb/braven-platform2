# frozen_string_literal: true

class SyncSalesforceContactToCanvasMailer < ApplicationMailer

  def failure_email
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @new_email = params[:new_email]
    @user_id = params[:user_id]
    @canvas_user_id = params[:canvas_user_id]
    @salesforce_contact_id = params[:salesforce_contact_id]
    @exception = params[:exception]
    mail(to: recipient, subject: "Uh Oh! Email update failed for: #{@new_email}")
  end

  private

  def recipient
    params[:staff_email]
  end
end
