unless Rails.application.secrets.mailer_deliveray_override_address.blank?
  Rails.logger.info "Overriding all outgoing emails to be sent to: #{Rails.application.secrets.mailer_deliveray_override_address} " \
                    "instead of the specified recipient. Intended for use in staging and dev."

  class OverrideRecipientInterceptor
    def delivering_email(message)
      original_recipient = message.to
      message.to = [Rails.application.secrets.mailer_deliveray_override_address]
      message.cc = nil
      message.bcc = nil
      #message['X-Original-Recipient']=original_recipient
      message.body = "OVERRIDDEN EMAIL SENT TO Original Recipient: #{original_recipient}\n-------------------\n#{message.body}"
    end
  end

  ActionMailer::Base.register_interceptor(OverrideRecipientInterceptor.new)
end

