# frozen_string_literal: true

class SendSignUpEmailMailer < ApplicationMailer

  def sign_up_email
    @first_name = params[:first_name]
    @sign_up_url = params[:sign_up_url]
    mail(to: recipient, subject: "Get ready for Braven")
  end

  private

  def recipient
    params[:email]
  end
end
