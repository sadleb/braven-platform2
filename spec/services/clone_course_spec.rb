# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CloneCourse do
  let(:source_course_program) { build :heroku_connect_program_launched}
  let(:source_course) { source_course_program.accelerator_course }
  let(:destination_course_name) { 'Test New Course Name' }
  let(:destination_canvas_course_id) { 93487 }
  let(:destination_course_program) { build :heroku_connect_program_unlaunched }
  let(:canvas_create_course) { build(:canvas_course, id: destination_canvas_course_id) }
  let(:canvas_copy_course) { build(:canvas_content_migration, source_course_id: source_course.canvas_course_id) }
  let(:canvas_client) { instance_double(CanvasAPI) }
  let(:sf_client) { instance_double(SalesforceAPI) }

  before(:each) do
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    allow(sf_client).to receive(:update_program)
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:create_course).and_return(canvas_create_course)
    allow(canvas_client).to receive(:copy_course).and_return(canvas_copy_course)
    allow(HerokuConnect::Program).to receive(:find).with(source_course_program.sfid).and_return(source_course_program)
    allow(HerokuConnect::Program).to receive(:find).with(destination_course_program.sfid).and_return(destination_course_program)
  end

  subject(:clone_course_service) do
    CloneCourse.new(source_course, destination_course_name, destination_course_program)
  end

  describe '#run' do
    let(:copy_progress_running) { build(:canvas_progress, workflow_state: 'running') }
    let(:copy_progress_complete) { build(:canvas_progress, workflow_state: 'completed') }
    # This can only be accessed after the service is run since it creates the local Course.
    let(:destination_course) { Course.find_by(name: destination_course_name) }

    before(:each) do
      allow(clone_course_service).to receive(:sleep).and_return(nil)
      allow(canvas_client).to receive(:get_copy_course_status)
        .and_return(copy_progress_running, copy_progress_complete)
    end

    context "with Canvas API success" do
      it "calls canvas API to copy the course" do
        expect(canvas_client).to receive(:create_course)
          .with(destination_course_name, anything, destination_course_program.sis_term_id, destination_course_program.time_zone)
          .once do |course_name, course_sis_id, term_sis_id, time_zone|
          expect(course_sis_id).to eq(destination_course.sis_id)
          canvas_create_course # return the CanvasAPI course hash if we're good
        end

        expect(canvas_client).to receive(:copy_course)
          .with(source_course.canvas_course_id, destination_canvas_course_id)
          .once
        clone_course_service.run
      end

      it "creates new Course in local database" do
        expect { clone_course_service.run }.to change(Course, :count).by(1)
        expect(destination_course.canvas_course_id).to eq destination_canvas_course_id
        expect(destination_course.course_resource_id).to eq source_course.course_resource_id
        expect(destination_course.salesforce_program_id).to eq destination_course_program.sfid
        expect(destination_course.last_canvas_sis_import_id).to eq nil
        expect(destination_course.is_launched).to eq(false)
      end

      describe "#wait_and_initialize" do
        let(:initialize_course_service) { instance_double(InitializeNewCourse, run: nil) }
        before(:each) do
          allow(InitializeNewCourse).to receive(:new).and_return(initialize_course_service)
        end

        it "waits for the Canvas course copy to finish before getting assignments" do
          expect(canvas_client).to receive(:get_copy_course_status).with(canvas_copy_course['progress_url']).twice
          clone_course_service.run.wait_and_initialize
        end

        it "initializes the new course" do
          expect(initialize_course_service).to receive(:run)
          clone_course_service.run.wait_and_initialize
          expect(InitializeNewCourse).to have_received(:new).with(destination_course, destination_course_program)
        end

        it "updates Salesforce" do
          clone_course_service.run.wait_and_initialize
          expect(sf_client).to have_received(:update_program)
            .with(destination_course_program.sfid, {'Canvas_Cloud_Accelerator_Course_ID__c' => destination_course.canvas_course_id})
        end

      end # "#wait_and_initialize"
    end # "#run"

    context "with Canvas API failure" do
      it "raises an exception" do
        allow(canvas_client).to receive(:copy_course).and_raise(RestClient::NotFound)
        expect { clone_course_service.run }.to raise_error(RestClient::NotFound)
      end
    end
  end

end
