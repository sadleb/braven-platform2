# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CloneCourse do
  let(:source_course) { create(:course, attributes_for(:course_with_resource)) }
  let(:destination_course_name) { 'Test New Course Name' }
  let(:destination_canvas_course_id) { 93487 }
  let(:section_names) { [] }
  let(:canvas_create_course) { build(:canvas_course, id: destination_canvas_course_id) }
  let(:canvas_copy_course) { build(:canvas_content_migration, source_course_id: source_course.canvas_course_id) }
  let(:canvas_client) { double(CanvasAPI) }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:create_course).with(destination_course_name, time_zone: nil).and_return(canvas_create_course)
    allow(canvas_client).to receive(:copy_course).with(source_course.canvas_course_id, destination_canvas_course_id).and_return(canvas_copy_course)
  end

  subject(:clone_course_service) do
    CloneCourse.new(source_course, destination_course_name, section_names)
  end

  describe '#run' do
    let(:copy_progress_running) { build(:canvas_progress, workflow_state: 'running') }
    let(:copy_progress_complete) { build(:canvas_progress, workflow_state: 'completed') }
    before(:each) do
      allow(clone_course_service).to receive(:sleep).and_return(nil)
      allow(canvas_client).to receive(:get_copy_course_status)
        .and_return(copy_progress_running, copy_progress_complete)
    end

    context "with Canvas API success" do
      it "calls canvas API to copy the course" do
        expect(canvas_client).to receive(:create_course).with(destination_course_name, time_zone: nil).once
        expect(canvas_client).to receive(:copy_course).with(source_course.canvas_course_id, canvas_create_course['id']).once
        clone_course_service.run
      end

      it "creates new Course in local database" do
        expect { clone_course_service.run }.to change(Course, :count).by(1)
        new_course = Course.find_by(name: destination_course_name)
        expect(new_course.canvas_course_id).to eq canvas_create_course['id']
        expect(new_course.course_resource_id).to eq source_course.course_resource_id
        expect(new_course.is_launched).to eq(false)
      end

      describe "#wait_and_initialize" do
        let(:assignment1) { build(:canvas_assignment, course_id: destination_canvas_course_id) }
        let(:assignment2) { build(:canvas_assignment, course_id: destination_canvas_course_id) }
        let(:assignments) { [assignment1, assignment2] }

        before(:each) do
          allow(canvas_client).to receive(:get_assignments).and_return(assignments) 
          allow(canvas_client).to receive(:update_assignment_lti_launch_url)
        end

        shared_examples 'source course assignment is copied to destination course assignment' do
          scenario 'it updates the LTI launch/submission URL' do
            source_assignment_url = source_course_custom_content_version.new_submission_url
      
            # This mimics an assignment that was cloned to the new course with the old launch URL for the source course 
            canvas_course_assignment = build(
              :canvas_assignment,
              course_id: destination_canvas_course_id,
              lti_launch_url: source_assignment_url,
            )
      
            allow(canvas_client)
              .to receive(:get_assignments)
              .and_return([canvas_course_assignment])
      
            clone_course_service.run.wait_and_initialize
      
            course_custom_content_version = CourseCustomContentVersion.find_by(
              canvas_assignment_id: canvas_course_assignment['id'],
            )
            destination_course_url = course_custom_content_version.new_submission_url
      
            expect(canvas_client)
              .to have_received(:update_assignment_lti_launch_url)
              .with(
                destination_canvas_course_id,
                canvas_course_assignment['id'],
                destination_course_url,
              )
              .once
      
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

        it "waits for the Canvas course copy to finish before getting assignments" do
          expect(canvas_client).to receive(:get_copy_course_status).with(canvas_copy_course['progress_url']).twice
          clone_course_service.run.wait_and_initialize
        end
 
        context "with sections" do 
          let(:section_names) { ['Section1', 'Section2'] }
          let(:canvas_sections) { [] }
          before(:each) do
            allow(canvas_client).to receive(:create_lms_section) { |course_id:, name:| 
              new_section = build(:canvas_section)
              canvas_sections << new_section
              CanvasAPI::LMSSection.new(new_section['id'], name)
            }
            allow(canvas_client).to receive(:create_assignment_override_placeholders)
          end
 
          it "creates the Canvas sections" do
            expect(canvas_client).to receive(:create_lms_section).with(course_id: destination_canvas_course_id, name: section_names[0]).once
            expect(canvas_client).to receive(:create_lms_section).with(course_id: destination_canvas_course_id, name: section_names[1]).once
            clone_course_service.run.wait_and_initialize
          end
  
          it "sets the AssignmentOverrides" do
            clone_course_service.run.wait_and_initialize
            expect(canvas_client).to have_received(:create_assignment_override_placeholders)
              .with(destination_canvas_course_id, [assignment1['id'], assignment2['id']], [canvas_sections[0]['id'], canvas_sections[1]['id']]).once
          end
        end

        context "without sections" do 
          let(:section_names) { [] }
          it "does not create Canvas sections or AssignmentOverrides" do
            expect(canvas_client).not_to receive(:create_lms_section)
            expect(canvas_client).not_to receive(:create_assignment_override_placeholders)
            clone_course_service.run.wait_and_initialize
          end
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
