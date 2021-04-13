# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RegisterUserAccount do
  describe '#run' do
    let(:enrollment_status) { SalesforceAPI::ENROLLED }
    let(:salesforce_participant) { 
      sp = SalesforceAPI::SFParticipant.new('firstName', 'lastName', 'email@email.com')
      sp.status = enrollment_status
      sp
    }
    let(:canvas_user) { create :canvas_user }
    let(:sign_up_params) { {password: 'some_password', password_confirmation: 'some_password', salesforce_id: 'someId'} }
    let(:sf_client) { instance_double(SalesforceAPI, find_participant: salesforce_participant, find_program: SalesforceAPI::SFProgram.new, set_canvas_user_id: nil) }
    let(:canvas_client) { instance_double(CanvasAPI, create_user: canvas_user, disable_user_grading_emails: nil) }
    let(:enrollment_process) { instance_double(SyncPortalEnrollmentForAccount, run: nil) }

    before do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(SyncPortalEnrollmentForAccount).to receive(:new).and_return(enrollment_process)
    end

    it 'creates a canvas user if enrolled status' do
      RegisterUserAccount.new(sign_up_params).run
      expect(canvas_client).to have_received(:create_user).once
    end

    it 'creates local user' do
      expect {
        RegisterUserAccount.new(sign_up_params).run
      }.to change(User, :count).by(1)
    end

    it 'updates local user if already created' do
      user = create(:registered_user, salesforce_id: sign_up_params[:salesforce_id])
      expect {
        RegisterUserAccount.new(sign_up_params).run
      }.to change(User, :count).by(0)
      expect(user.canvas_user_id).to be(canvas_user[:id])
    end

    context 'when not enrolled status' do
      let(:enrollment_status) { SalesforceAPI::DROPPED }
      it 'raises an error' do
        enrollment_status = SalesforceAPI::DROPPED
        expect { RegisterUserAccount.new(sign_up_params).run }.to raise_error(RegisterUserAccount::RegisterUserAccountError)
      end
    end

    it 'updates Salesforce' do
      RegisterUserAccount.new(sign_up_params).run
      expect(sf_client).to have_received(:set_canvas_user_id).once
    end

    it 'enrolls the user in Canvas' do
      RegisterUserAccount.new(sign_up_params).run
      expect(enrollment_process).to have_received(:run).once
    end

    it 'create a local User' do
      expect{ RegisterUserAccount.new(sign_up_params).run }.to change(User, :count).by(1)
    end

    it 'sends confirmation instructions to user' do
      Devise.mailer.deliveries.clear()
      RegisterUserAccount.new(sign_up_params).run
      expect(Devise.mailer.deliveries.count).to eq 1
      user = User.find_by_canvas_user_id!(canvas_user['id'])
      expect(user.confirmation_sent_at).not_to be(nil)
    end
  end
end
