# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InitializeNewCourse do
  let(:cohort_schedules) { build_list(:heroku_connect_cohort_schedule, 2) }
  let(:destination_course_program) { build :heroku_connect_program_launched, cohort_schedules: cohort_schedules }
  let(:source_course) { create :course_launched }
  let(:canvas_client) { instance_double(CanvasAPI) }
  let(:create_section_service) { instance_double(CreateSection) }
  let(:sections) { [] }

  let(:assignment_ids) { [912874, 983745] }
  let(:assignment1) { build(:canvas_assignment, id: assignment_ids[0], course_id: new_course.canvas_course_id) }
  let(:assignment2) { build(:canvas_assignment, id: assignment_ids[1], course_id: new_course.canvas_course_id) }
  let(:assignments) { [assignment1, assignment2] }

  # Be sure to set this in the tests below
  let(:new_course) { nil }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:get_assignments).and_return(assignments)
    allow(canvas_client).to receive(:update_assignment_lti_launch_url)
    allow(CreateSection).to receive(:new).and_return(create_section_service)
    allow(create_section_service).to receive(:run) do
      local_section = create :section
      sections << local_section
      local_section
    end
  end

  describe '#run' do
    subject(:run_initialize_service) do
      InitializeNewCourse.new(new_course, destination_course_program).run
    end

    shared_examples 'initializes the course' do
      it "creates the Cohort Schedule sections" do
        expect(destination_course_program.cohort_schedules.pluck(:sfid).count).to be > 0 # sanity check
        destination_course_program.cohort_schedules.each do |cs|
          expect(CreateSection).to receive(:new)
            .with(new_course, cs.canvas_section_name, Section::Type::COHORT_SCHEDULE, cs.sfid)
        end
        run_initialize_service
      end

      it "creates the Teaching Assistant sections" do
        expect(CreateSection).to receive(:new)
          .with(new_course, SectionConstants::TA_SECTION, Section::Type::TEACHING_ASSISTANTS).once
        run_initialize_service
      end

      # Note: When we switch over to static endpoints for LTI launch URLs this will go away.
      # See TODO: # https://app.asana.com/0/1174274412967132/1199352155608256

      # Make sure and set this in the tests that use this shared_example
      let(:source_course_custom_content_version) { nil }

      shared_examples 'source course assignment is copied to destination course assignment' do
        let(:source_assignment_url) { source_course_custom_content_version.new_submission_url }
        # This mimics an assignment that was cloned to the new course with the old launch URL for the source course
        let(:canvas_course_assignment) {
          build(:canvas_assignment,
            id: source_course_custom_content_version.canvas_assignment_id + 1,
            course_id: new_course.canvas_course_id,
            lti_launch_url: source_assignment_url,
          )
        }

        before(:each) do
          allow(canvas_client).to receive(:get_assignments).and_return([canvas_course_assignment])
        end

        it 'creates the new local database models' do
          expect{run_initialize_service}.to change(CourseCustomContentVersion, :count).by(1)
          new_course_custom_content_version = CourseCustomContentVersion
            .find_by(canvas_assignment_id: canvas_course_assignment['id'])
          expect(new_course_custom_content_version.id).not_to eq(source_course_custom_content_version.id)
          expect(new_course_custom_content_version.custom_content_version_id).to eq(source_course_custom_content_version.custom_content_version_id)
        end

        it 'updates the LTI launch/submission URL' do
          run_initialize_service
          course_custom_content_version = CourseCustomContentVersion.find_by(
            canvas_assignment_id: canvas_course_assignment['id'],
          )
          destination_course_url = course_custom_content_version.new_submission_url

          expect(canvas_client)
            .to have_received(:update_assignment_lti_launch_url)
            .with(
              new_course.canvas_course_id,
              canvas_course_assignment['id'],
              destination_course_url,
            ).once

          expect(source_assignment_url).not_to eq(destination_course_url)
        end
      end

      context 'impact surveys' do
        let(:source_course_custom_content_version) { create(
          :course_survey_version,
          course: source_course,
        ) }

        it_behaves_like 'source course assignment is copied to destination course assignment'
      end

      context 'projects' do
        let(:source_course_custom_content_version) { create(
          :course_project_version,
          course: source_course,
        ) }

        it_behaves_like 'source course assignment is copied to destination course assignment'
      end
    end # 'initializes the course'

    context 'for Accelerator Course' do
      let(:new_course) { destination_course_program.accelerator_course }
      it_behaves_like 'initializes the course'
    end

    context 'for LC Playbook Course' do
      let(:new_course) { destination_course_program.lc_playbook_course }
      it_behaves_like 'initializes the course'
    end

  end # '#run'
end
