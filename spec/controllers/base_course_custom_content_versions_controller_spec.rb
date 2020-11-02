require 'rails_helper'

RSpec.describe BaseCourseCustomContentVersionsController, type: :controller do
  render_views

  let!(:admin_user) { create :admin_user }
  let(:course) { create :course_with_canvas_id }
  let(:course_project_version) { create :course_project_version, base_course: course }
  let(:invalid_edit_project_params) { {base_course_id: course_project_version.base_course_id, id: course_project_version} }
  let(:course_template) { create :course_template_with_canvas_id }
  let(:project) { create :project }
  let(:project_version) { create :project_version, custom_content: project }
  let(:course_template_project_version) { create :course_template_project_version, base_course: course_template, custom_content_version: project_version }
  let(:valid_edit_project_params) { {base_course_id: course_template_project_version.base_course_id, id: course_template_project_version} }
  let(:canvas_client) { double(CanvasAPI) }


  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # BaseCourseCustomContentVersionsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
  end

  context 'when logged in as admin user' do
    before do
      sign_in admin_user
    end  

    describe 'POST #create' do

      context 'with valid params' do

        context 'for project' do
          let(:valid_projet_create_params) { {base_course_id: course_template.id, custom_content_id: project.id} }
          let(:name) { 'Test Create Project 1' }
          let(:created_canvas_assignment) { FactoryBot.json(:canvas_assignment, course_id: course_template['canvas_course_id'], name: name) }
          let(:created_bcccv) { BaseCourseCustomContentVersion.last }
  
          before(:each) do
            allow(canvas_client).to receive(:create_lti_assignment).and_return(created_canvas_assignment)
            allow(canvas_client).to receive(:update_assignment_lti_launch_url)
          end

          it 'creates the Canvas assignment' do
            expect(canvas_client).to receive(:create_lti_assignment)
              .with(course_template.canvas_course_id, project.title)
            post :create, params: valid_projet_create_params, session: valid_session
          end

          it 'saves a new version of the project' do
            expect { post :create, params: valid_projet_create_params, session: valid_session }.to change {ProjectVersion.count}.by(1)
          end

          it 'creates a new BaseCourseCustomContentVersion for the new content version' do
            expect { post :create, params: valid_projet_create_params, session: valid_session }.to change {BaseCourseCustomContentVersion.count}.by(1)
            expect(created_bcccv.custom_content_version).to eq(ProjectVersion.last)
          end

          it 'sets the LTI launch URL to the proper project submission URL' do
            post :create, params: valid_projet_create_params, session: valid_session
            expect(canvas_client).to have_received(:update_assignment_lti_launch_url)
              .with(course_template['canvas_course_id'], created_canvas_assignment['id'],
                    new_base_course_custom_content_version_project_submission_url(base_course_custom_content_version_id: created_bcccv.id) )
          end

          it 'redirects back to edit page and flashes message' do
            response = post :create, params: valid_projet_create_params, session: valid_session
            expect(response).to redirect_to(edit_course_template_path(course_template_project_version.base_course))
            expect(flash[:notice]).to match /successfully published/
          end
        end
      end

      context 'with invalid params' do
        it 'throws when not a CourseTemplate' do
          expect { post :create, params: {base_course_id: course.id, custom_content_id: project.id}, session: valid_session }
            .to raise_error(BaseCourse::BaseCourseEditError)
        end
      end
    end # 'POST #create'

    describe 'POST #update' do
      context 'with valid params' do

        context 'for project' do
          let(:new_body) { 'updated project body' }

          before(:each) do
            project = course_template_project_version.custom_content_version.custom_content
            project.body = new_body
            project.save!
          end

          it 'saves a new version of the project' do
            expect { post :update, params: valid_edit_project_params, session: valid_session }.to change {ProjectVersion.count}.by(1)
          end

          it 'associates the exsiting BaseCourseCustomContentVersion to the new content version' do
            expect(course_template_project_version.custom_content_version.body).not_to eq(new_body)
            expect { post :update, params: valid_edit_project_params, session: valid_session }.not_to change {BaseCourseCustomContentVersion.count}
            expect(BaseCourseCustomContentVersion.find(course_template_project_version.id).custom_content_version).to eq(ProjectVersion.last)
          end

          it 'redirects back to edit page and flashes message' do
            response = post :update, params: valid_edit_project_params, session: valid_session
            expect(response).to redirect_to(edit_course_template_path(course_template_project_version.base_course))
            expect(flash[:notice]).to match /successfully published/
          end
        end
      end

      context 'with invalid params' do
        it 'throws when not a CourseTemplate' do
          expect { post :update, params: invalid_edit_project_params, session: valid_session }.to raise_error(BaseCourse::BaseCourseEditError)
        end
      end
    end # 'POST #update'

    describe 'POST #delete' do
      context 'with valid params' do

        context 'for project' do

          before(:each) do
            allow(canvas_client).to receive(:delete_assignment)
            course_template_project_version # create it in the DB ahead of time
          end

          it 'doesnt delete the project version content' do
            expect { post :destroy, params: valid_edit_project_params, session: valid_session }.not_to change {ProjectVersion.count}
          end

          it 'deletes the BaseCourseCustomContentVersion join record' do
            expect { post :destroy, params: valid_edit_project_params, session: valid_session }.to change {BaseCourseCustomContentVersion.count}.by(-1)
            expect { BaseCourseCustomContentVersion.find(course_template_project_version.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end

          it 'deletes the Canvas assignment' do
            expect(canvas_client).to receive(:delete_assignment)
              .with(course_template_project_version.base_course.canvas_course_id,
                    course_template_project_version.canvas_assignment_id)
            post :destroy, params: valid_edit_project_params, session: valid_session
          end

          it 'doesnt delete the BaseCourseCustomContentVersion if Canvas assignment deletion fails' do
            allow(canvas_client).to receive(:delete_assignment).and_raise RestClient::BadRequest
            expect { post :destroy, params: valid_edit_project_params, session: valid_session }.to raise_error(RestClient::BadRequest)
            expect(BaseCourseCustomContentVersion.find(course_template_project_version.id)).to be_present
          end

          it 'redirects back to edit page and flashes message' do
            response = post :destroy, params: valid_edit_project_params, session: valid_session
            expect(response).to redirect_to(edit_course_template_path(course_template_project_version.base_course))
            expect(flash[:notice]).to match /successfully deleted/
          end
        end
      end

      context 'with invalid params' do
        it 'throws when not a CourseTemplate' do
          expect { post :destroy, params: invalid_edit_project_params, session: valid_session }.to raise_error(BaseCourse::BaseCourseEditError)
        end
      end
    end # 'POST #delete

  end # logged in as admin user
end
