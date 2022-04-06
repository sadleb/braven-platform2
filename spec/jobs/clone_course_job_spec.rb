# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CloneCourseJob, type: :job do
  describe '#perform' do
    let(:clone_course) { double(CloneCourse, run: nil) }
    let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
    let(:mailer) { double('DummyMailerInstance', success_email: delivery, failure_email: delivery) }
    let(:notification_email) { 'fake_notify@email.com' }
    let(:source_course) { create :course }
    let(:new_course_name) { 'Test Clone Course Name1' }
    let(:destination_course_program) { build :heroku_connect_program_unlaunched }

    before(:each) do
      allow(clone_course).to receive(:wait_and_initialize)
      allow(clone_course).to receive(:run).and_return(clone_course)
      allow(CloneCourse).to receive(:new).and_return(clone_course)
      allow(CloneCourseMailer).to receive(:with).and_return(mailer)
    end

    subject(:clone_course_job) do
      CloneCourseJob.perform_now(notification_email, source_course, new_course_name, destination_course_program)
    end

    it 'starts the clone process' do
      clone_course_job
      expect(clone_course).to have_received(:run)
    end

    it 'waits for the clone process to complete and initializes the new course' do
      clone_course_job
      expect(clone_course).to have_received(:wait_and_initialize)
    end

    it 'sends success mail if successful' do
      clone_course_job
      expect(mailer).to have_received(:success_email)
    end

    it 'sends failure mail if something bad happens' do
      allow(clone_course).to receive(:run).and_raise('something bad')
      expect(mailer).to receive(:failure_email)
      expect{ clone_course_job }.to raise_error('something bad')
    end
  end
end
