# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateZoomLinksJob, type: :job do
  describe '#perform' do
    let(:failed_participants) { [] }
    let(:generate_service) { double(GenerateZoomLinks, run: nil, failed_participants: failed_participants) }
    let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
    let(:mailer) { double('DummyMailerInstance', success_email: delivery, failure_email: delivery) }
    let(:meeting_id) { '1234567890' }
    let(:email) { 'example@example.com' }
    let(:participants_file_path) { 'test/file/path' }
    let(:participants) { {email: 'testzoom@example.com', first_name: 'Brian', last_name: 'xTestZoom'} }

    before(:each) do
      allow(GenerateZoomLinks).to receive(:new).and_return(generate_service)
      allow(GenerateZoomLinksMailer).to receive(:with).and_return(mailer)
    end

    it 'sends success mail if successful' do
      GenerateZoomLinksJob.perform_now(meeting_id, participants_file_path, email, participants)
      expect(mailer).to have_received(:success_email)
    end

    it 'sends failure mail if something bad happens' do
      allow(generate_service).to receive(:run).and_raise('something bad')
      expect{ GenerateZoomLinksJob.perform_now(meeting_id, participants_file_path, email, participants) }.to raise_error('something bad')
      expect(mailer).to have_received(:failure_email)
    end
  end
end