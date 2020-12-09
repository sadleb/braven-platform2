require 'rails_helper'

RSpec.describe UsersRolesController, type: :controller do
  render_views

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # WaiversController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  context 'when logged in as admin user' do
    let!(:admin_user) { create :admin_user }
    let(:course) { create :course_unlaunched}
    let(:canvas_user_id) { 92837 }
    let!(:test_user) { create :registered_user, canvas_user_id: canvas_user_id }
    let(:canvas_client) { double(CanvasAPI) }
  
    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      sign_in admin_user
    end

    describe 'GET #new' do

      context 'with valid params' do
        let(:valid_new_params) { {user_id: test_user.id} }

        before(:each) do
          get :new, params: valid_new_params, session: valid_session
        end

        it 'returns a success response' do
          expect(response).to be_successful
        end

      end

    end # GET#new

    describe 'POST #create' do

      context 'with valid params' do
        let(:canvas_api_section) { create :canvas_section }
        let(:canvas_section) { CanvasAPI::LMSSection.new(canvas_api_section['id'], canvas_api_section['name']) }
        let(:enrollment_type) { RoleConstants::STUDENT_ENROLLMENT }

        let(:valid_create_params) { {
          user_id: test_user.id,
          role_name: enrollment_type,
          fellow_course_id: course.canvas_course_id,
          cohort: canvas_section.name
         } }

        before(:each) do
          allow(canvas_client).to receive(:find_section_by)
          allow(canvas_client).to receive(:create_lms_section).and_return(canvas_section)
          allow(canvas_client).to receive(:find_enrollment)
          allow(canvas_client).to receive(:enroll_user_in_course)
          post :create, params: valid_create_params, session: valid_session
        end

        it 'redirects to edit user path' do
          expect(response).to redirect_to(edit_user_path(test_user))
        end

        it 'creates the platform Section' do
          platform_section = Section.find_by!(canvas_section_id: canvas_section.id)
          expect(platform_section.name).to eq(canvas_section.name) 
          expect(platform_section.course_id).to eq(course.id) 
          expect(platform_section.canvas_section_id).to eq(canvas_section.id) 
        end

        it 'adds the UsersRole' do
          platform_section = Section.find_by!(canvas_section_id: canvas_section.id)  
          expect(test_user.has_role?(enrollment_type, platform_section)).to be(true)
        end

        it 'calls the Canvas API to enroll the user' do
          expect(canvas_client).to have_received(:enroll_user_in_course)
            .with(canvas_user_id, course.canvas_course_id.to_s, enrollment_type, canvas_section.id).once
        end

      end

    end # POST #create

    describe 'DELETE #destroy' do

      context 'with valid params' do
        let(:test_user) { create :registered_user, canvas_user_id: canvas_user_id }
        let(:enrollment_type) { RoleConstants::STUDENT_ENROLLMENT }
        let(:role) { Section.find_roles(enrollment_type, test_user).first }
        let(:canvas_section_id) { 65768787 }
        let(:section) { create :section, canvas_section_id: canvas_section_id }
        let(:canvas_enrollment_id) { 87878979 }
        let(:canvas_enrollment) {
           CanvasAPI::LMSEnrollment.new(canvas_enrollment_id, course.canvas_course_id,
                             enrollment_type, section.canvas_section_id)
        }

        let(:valid_delete_params) { {
          id: role.id,
          user_id: test_user.id,
         } }

        before(:each) do
          allow(canvas_client).to receive(:find_enrollment).and_return(canvas_enrollment)
          allow(canvas_client).to receive(:delete_enrollment)
          test_user.add_role enrollment_type, section
          delete :destroy, params: valid_delete_params, session: valid_session
        end

        it 'redirects to edit user path' do
          expect(response).to redirect_to(edit_user_path(test_user))
        end

        it 'deletes the UsersRole' do
          expect(test_user.has_role?(enrollment_type, section)).to be(false)
        end

        it 'calls the Canvas API to unenroll the user' do
          expect(canvas_client).to have_received(:delete_enrollment)
            .with(enrollment: canvas_enrollment).once
        end

      end

    end # DELETE #destroy

  end # logged in as admin user

end
