# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceProgramMailer, type: :mailer do
  describe '#success_email' do
    let(:recipient) { 'example@example.com' }
    let(:mail) { SyncSalesforceProgramMailer.with(email: recipient).success_email }

    # before(:each) { mail.deliver_now }

    it 'has the right subject' do
      expect(mail.subject).to eql('Sync Successful')
    end

    it 'has the right recipient' do
      expect(mail.to).to eql([recipient])
    end

    it 'renders the right body' do
      expect(mail.body.encoded).to match('successful')
    end
  end

  describe '#failure_email' do
    let(:recipient) { 'example@example.com' }
    let(:exception) { StandardError.new "fake exception" }
    let(:mail) { SyncSalesforceProgramMailer.with(email: recipient, exception: exception).failure_email }

    # before(:each) { mail.deliver_now }

    it 'has the right subject' do
      expect(mail.subject).to eql('Sync Failed')
    end

    it 'has the right recipient' do
      expect(mail.to).to eql([recipient])
    end

    it 'renders the right body' do
      expect(mail.body.encoded).to match('failed')
      expect(mail.body.encoded).to match('fake exception')
    end
  end

end
