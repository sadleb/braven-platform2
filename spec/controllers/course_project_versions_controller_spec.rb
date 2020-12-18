require 'rails_helper'
require 'canvas_api'

RSpec.describe CourseProjectVersionsController, type: :controller do
  render_views

  let(:canvas_client) { double(CanvasAPI) }
  let!(:admin_user) { create :admin_user }
  let(:course) { create :course }

  before do
    sign_in admin_user
  end

  describe 'GET #new' do
    let(:project_version) { create :project_version }
    let!(:course_project_version) { create(
      :course_project_version,
      course: course,
      project_version: project_version,
    ) }

    subject { get :new, params: { course_id: course.id } }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:get_rubrics)
    end

    it 'returns a success response' do
      subject
      expect(response).to be_successful
    end

    it 'excludes modules that have already been added to the course' do
      unpublished_project = Project.create!(title: 'New Project')
      subject
      expect(response.body).to match /<option value="#{unpublished_project.id}">#{unpublished_project.title}<\/option>/
      expect(response.body).not_to match /<option.*>#{course_project_version.project_version.title}<\/option>/
    end

    it 'fetches list of unattached rubrics' do
      subject
      expect(canvas_client)
        .to have_received(:get_rubrics)
        .with(course.canvas_course_id, true)
        .once
    end
  end

  describe 'POST #publish' do
    let(:canvas_assignment_id) { 1234 }
    let(:project) { create :project }

    subject {
      post :publish, params: {
        course_id: course.id,
        custom_content_id: project.id,
      }
    }

    context 'Canvas assignment creation succeeds' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:create_lti_assignment)
          .and_return({ 'id' => canvas_assignment_id })
        allow(canvas_client).to receive(:update_assignment_lti_launch_url)
        allow(canvas_client).to receive(:add_rubric_to_assignment)
      end

      it 'adds a new join table entry' do
        expect { subject }.to change(CourseProjectVersion, :count).by(1)
        course_project_version = CourseProjectVersion.last
        expect(course_project_version.canvas_assignment_id).to eq(canvas_assignment_id)
        expect(course_project_version.course).to eq(course)
        expect(course_project_version.project_version).to eq(ProjectVersion.last)
      end

      it 'creates a new version' do
        expect { subject }.to change(ProjectVersion, :count).by(1)
      end

      it 'adds the project to the course' do
        subject
        expect(course.projects).to include(CourseProjectVersion.last.project_version.project)
      end

      it 'creates a new Canvas assignment' do
        subject
        expect(canvas_client)
          .to have_received(:create_lti_assignment)
          .with(course.canvas_course_id, project.title)
          .once
        expect(canvas_client)
          .to have_received(:update_assignment_lti_launch_url)
          .with(
            course.canvas_course_id,
            canvas_assignment_id,
            CourseProjectVersion.last.new_submission_url,
          )
          .once
      end

      it 'redirects to course edit page' do
        subject
        expect(response).to redirect_to edit_course_path(course)
      end

      context 'without rubric' do
        it 'does not add a rubric' do
          subject
          expect(canvas_client).not_to have_received(:add_rubric_to_assignment)
        end
      end

      context 'with rubric' do
        let(:rubric_id) { '777777' }
        subject {
          post :publish, params: {
            course_id: course.id,
            custom_content_id: project.id,
            rubric_id: rubric_id,
          }
        }
        it 'adds the rubric to the assignment' do
          subject
          expect(canvas_client)
            .to have_received(:add_rubric_to_assignment)
            .with(
              course.canvas_course_id,
              canvas_assignment_id,
              rubric_id,
            )
            .once
        end
      end
    end

    context 'Canvas assignment creation fails' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:create_lti_assignment)
          .and_raise(RestClient::BadRequest)
      end

      it 'does not create the join table entry' do
        expect {
          subject rescue nil
        }.not_to change(CourseProjectVersion, :count)
      end
    end
  end

  describe 'DELETE #unpublish' do
    let(:project_version) { create :project_version }
    let!(:course_project_version) { create(
      :course_project_version,
      course: course,
      project_version: project_version,
    )}

    subject {
      delete :unpublish, params: {
        course_id: course.id,
        id: course_project_version.id,
      }
    }

    context 'Canvas assignment not found' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:delete_assignment)
          .and_raise(RestClient::NotFound)
      end

      it 'deletes the join table entry' do
        expect { subject rescue nil }.to change(CourseProjectVersion, :count).by(-1)
      end
    end

    context 'Unhandled Canvas error' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:delete_assignment)
          .and_raise(RestClient::BadRequest)
      end

      it 'does not delete the join table entry' do
        expect { subject rescue nil }.not_to change(CourseProjectVersion, :count)
      end
    end

    context 'Canvas assignment found' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:delete_assignment)
      end

      it 'deletes the join table entry' do
        expect { subject }.to change(CourseProjectVersion, :count).by(-1)
      end

      it 'deletes the Canvas assignment' do
        subject
        expect(canvas_client)
          .to have_received(:delete_assignment)
          .with(course.canvas_course_id, course_project_version.canvas_assignment_id)
          .once
      end

      it 'does not delete the version' do
        expect { subject }.not_to change { ProjectVersion.count }
      end

      it 'does not delete the course' do
        expect { subject }.not_to change { Course.count }
      end

      it 'redirects to course edit page' do
        subject
        expect(response).to redirect_to edit_course_path(course)
      end
    end
  end

  describe 'PUT #publish_latest' do
    let(:project_version) { create :project_version }
    let!(:course_project_version) { create(
      :course_project_version,
      course: course,
      project_version: project_version,
    )}

    subject {
      put :publish_latest, params: {
        course_id: course.id,
        id: course_project_version.id,
      }
    }

    context 'Canvas API exception' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:update_assignment_name)
          .and_raise(RestClient::BadRequest)
        allow(canvas_client)
          .to receive(:update_assignment_lti_launch_url)
          .and_raise(RestClient::BadRequest)
      end

      it 'does not change the join table entry' do
        existing_course_project_version = course_project_version
        expect { subject rescue nil }.not_to change(CourseProjectVersion, :count)
        expect(CourseProjectVersion.last).to eq(existing_course_project_version)
      end
    end

    context 'Canvas assignment found' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client).to receive(:update_assignment_name)
        allow(canvas_client).to receive(:update_assignment_lti_launch_url)
      end

      it 'updates the assignment name' do
        subject
        expect(canvas_client)
          .to have_received(:update_assignment_name)
          .with(
            course.canvas_course_id,
            course_project_version.canvas_assignment_id,
            course_project_version.reload.project_version.title,
          )
          .once
      end

      it 'updates the LTI launch URL' do
        subject
        expect(canvas_client)
          .to have_received(:update_assignment_lti_launch_url)
          .with(
            course.canvas_course_id,
            course_project_version.canvas_assignment_id,
            course_project_version.reload.new_submission_url,
          )
          .once
      end

      it 'redirects to course edit page' do
        subject
        expect(response).to redirect_to edit_course_path(course)
      end

      it 'creates a new version' do
        prev_version = course_project_version.project_version
        expect { subject }.to change(ProjectVersion, :count).by(1)
        expect(course_project_version.reload.project_version).not_to eq(prev_version)
        expect(course_project_version.reload.project_version).to eq(ProjectVersion.last)
      end

      it 'updates the existing join table entry' do
        expect { subject }.not_to change { CourseProjectVersion.count }
      end
    end
  end
end
