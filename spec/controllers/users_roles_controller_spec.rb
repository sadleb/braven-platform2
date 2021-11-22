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
    let(:sync_account_service) { double(SyncPortalEnrollmentForAccount, run: nil) }

    before(:each) do
      allow(SyncPortalEnrollmentForAccount).to receive(:new).and_return(sync_account_service)
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
        let(:fellow_section) { build(:section, course_id: course.id) }
        let(:enrollment_type) { RoleConstants::STUDENT_ENROLLMENT }

        let(:valid_create_params) { {
          user_id: test_user.id,
          role_name: enrollment_type,
          fellow_course_id: course.canvas_course_id,
          cohort: fellow_section.name
         } }

        before(:each) do
          post :create, params: valid_create_params, session: valid_session
        end

        it 'calls the sync service' do
          expect(sync_account_service).to have_received(:run)
        end

        it 'redirects to edit user path' do
          expect(response).to redirect_to(edit_user_path(test_user))
        end

      end

    end # POST #create

    describe 'DELETE #destroy' do

      context 'with valid params' do
        let(:test_user) { create :registered_user, canvas_user_id: canvas_user_id }
        let(:enrollment_type) { RoleConstants::STUDENT_ENROLLMENT }
        let(:role) { Section.find_roles(enrollment_type, test_user).first }
        let(:section) { create :section }

        let(:valid_delete_params) { {
          id: role.id,
          user_id: test_user.id,
         } }

        before(:each) do
          test_user.add_role enrollment_type, section
          delete :destroy, params: valid_delete_params, session: valid_session
        end

        it 'calls the sync service' do
          expect(sync_account_service).to have_received(:run)
        end

        it 'redirects to edit user path' do
          expect(response).to redirect_to(edit_user_path(test_user))
        end

      end

    end # DELETE #destroy

  end # logged in as admin user

end
