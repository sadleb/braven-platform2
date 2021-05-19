# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendSignupEmailMailer, type: :mailer do
  describe '#signup_email' do
    let(:recipient) { 'example.fellow@example.com' }
    let(:sign_up_url) { 'https://platformweb/users/sign_up?signup_token=fake_token' }
    let(:mail) { SendSignupEmailMailer.with(email: recipient, sign_up_url: sign_up_url).signup_email}

    it 'has the right subject' do
      expect(mail.subject).to eql('Get ready for Braven')
    end

    it 'has the right recipient' do
      expect(mail.to).to eql([recipient])
    end

    it 'renders the right body' do
      expect(mail.body.encoded).to match('to access the program you must create a Braven Canvas account')
      expect(mail.body.encoded).to match(/#{Regexp.escape('https://platformweb/users/sign_up?signup_token=3Dfake_token=0D')}/)
    end
  end
end
