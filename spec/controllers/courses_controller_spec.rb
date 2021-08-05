require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.
#
# Also compared to earlier versions of this generator, there are no longer any
# expectations of assigns and templates rendered. These features have been
# removed from Rails core in Rails 5, but can be added back in via the
# `rails-controller-testing` gem.

RSpec.describe CoursesController, type: :controller do
  render_views

  let(:user) { create :admin_user }
  let(:valid_attributes) { attributes_for(:course) }
  let(:invalid_attributes) { { name: '' } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # CoursesController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  let(:sf_client) { double(SalesforceAPI) }
  let(:canvas_client) { double(CanvasAPI) }

  describe 'when logged in' do
    before do
      allow(sf_client).to receive(:get_current_and_future_canvas_course_ids)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      sign_in user
    end

    describe "GET #index" do
      it "returns a success response" do
        get :index, params: {}, session: valid_session
        expect(response).to be_successful
      end
    end

    describe "GET #new" do
      it "returns a success response" do
        get :new, params: { create_from_course_id: 1 }, session: valid_session
        expect(response).to be_successful
      end
    end

    describe "POST #create" do

      shared_examples 'clones as a new Course Template' do
        let(:new_course_name) { 'Template From Cloned Course' }

        scenario 'starts the clone job' do
          expect(CloneCourseJob).to receive(:perform_later).with(user.email, source_course, new_course_name).once
          post(:create,
            params: {
              course: { name: new_course_name },
              create_from_course_id: source_course.id
            },
            session: valid_session
          )
        end

        scenario 'redirects to the courses list' do
          allow(CloneCourseJob).to receive(:perform_later).and_return(nil)
          post(:create,
            params: {
              course: { name: new_course_name },
              create_from_course_id: source_course.id
            },
            session: valid_session
          )
          expect(response).to redirect_to(courses_path)
          expect(flash[:notice]).to match /Template initialization started/
        end
      end

      context 'from unlaunched course' do
        let(:source_course) { create :course_unlaunched }

        it_behaves_like 'clones as a new Course Template'
      end

      context 'from a launched course' do
        let(:source_course) { create :course_launched }

        it_behaves_like 'clones as a new Course Template'
      end

    end

    describe "PUT #update" do
      let(:course) { create(:course) }

      subject(:put_update) do
        put(
          :update,
          params: {
            id: course.to_param,
            course: put_attributes,
            session: valid_session
          }
        )
      end

      context "with valid params" do
        let(:put_attributes) {
          { name: 'turtles' }
        }
        before(:each) { put_update }

        it "updates the requested course" do
          course.reload
          expect(course.name).to eq('turtles')
        end

        it "redirects to the course" do
          expect(response).to redirect_to(courses_path)
        end
      end

      context "with invalid params" do
        let(:put_attributes) { invalid_attributes }
        before(:each) { put_update }

        it "returns a success response (i.e. to display the 'edit' course)" do
          expect(response).to redirect_to(edit_course_path(course))
        end
      end
    end

    context "when Course is launched" do

      let(:valid_course_launched_attributes) { attributes_for(:course_launched) }
      let(:course_launched) { create(:course_launched, valid_course_launched_attributes) }

      describe "GET #edit" do
        it "returns a success response with a warning message" do
          allow(canvas_client).to receive(:get_assignments).and_return([])
          get :edit, params: {id: course_launched.to_param }, session: valid_session
          expect(response).to be_successful
          expect(response.body).to match(/Caution! You are editing a launched course/)
        end
      end

      describe "DELETE #destroy" do
        # In the future would could implement the ability to delete a launched course by only allowing it
        # if students hadn't done any work or providing a list of what would be blown away. Not important
        # at the moment b/c A) the only valid use-case I know of would be to delete test launched courses
        # B) delete doesn't currently really even work since it needs to cascade delete all foreign key
        # references which it doesn't do.
        it "raises an error" do
          expect { delete :destroy, params: {id: course_launched.to_param }, session: valid_session }
            .to raise_error(CoursesController::CourseAdminError)
        end
      end

    end

    context "when Course is not launched" do

      let(:valid_course_unlaunched_attributes) { attributes_for(:course_unlaunched) }
      let(:course_unlaunched) { create(:course_unlaunched, valid_course_unlaunched_attributes) }

      describe "GET #edit" do
        it "returns a success response" do
          allow(canvas_client).to receive(:get_assignments).and_return([])
          get :edit, params: {id: course_unlaunched.to_param }, session: valid_session
          expect(response).to be_successful
        end
      end

      describe "DELETE #destroy" do
        it "destroys the requested unlaunched course" do
          course_unlaunched
          expect {
            delete :destroy, params: {id: course_unlaunched.to_param}, session: valid_session
          }.to change(Course, :count).by(-1)
        end

        it "redirects to the courses list" do
          delete :destroy, params: {id: course_unlaunched.to_param}, session: valid_session
          expect(response).to redirect_to(courses_url)
        end
      end

    end

    describe "GET #launch_new" do
      it "returns a success response" do
        get :launch_new, session: valid_session
        expect(response).to be_successful
      end
    end

    describe "POST #launch_create" do

      context "with valid params" do
        let(:sf_program_id) { 'TestSalesforceProgramID' }
        let(:email) { 'test@email.com' }
        let(:fellow_source_course_id) { '24' }
        let(:fellow_course_name) { 'Test Fellow Course Name' }
        let(:lc_source_course_id) { '25' }
        let(:lc_course_name) { 'Test LC Course Name' }

        subject(:post_launch_create) do
          post(
            :launch_create,
            params: {
              salesforce_program_id: sf_program_id,
              notification_email: email,
              fellow_source_course_id: fellow_source_course_id,
              fellow_course_name: fellow_course_name,
              lc_source_course_id: lc_source_course_id,
              lc_course_name: lc_course_name,
              session: valid_session
            }
          )
        end

        it "starts the launch job" do
          expect(LaunchProgramJob).to receive(:perform_later).with(sf_program_id, email, fellow_source_course_id, fellow_course_name, lc_source_course_id, lc_course_name).once
          post_launch_create
        end

        it "redirects to the course management page" do
          allow(LaunchProgramJob).to receive(:perform_later).and_return(nil)
          post_launch_create
          expect(response).to redirect_to(courses_path)
          expect(flash[:notice]).to match /Program launch started/
        end
      end

      context "with invalid params" do
        it "redirects to launch_new with error message, before calling launch job" do
          post(
            :launch_create,
            params: {
              salesforce_program_id: 'TestSalesforceProgramID',
              # missing params!
              session: valid_session
            }
          )
          expect(LaunchProgramJob).not_to receive(:perform_later)
          expect(response).to redirect_to(launch_courses_path)
          expect(flash[:alert]).to match /Error:/
        end
      end

    end

    describe 'JSON requests' do
      let(:access_token) { create :access_token }

      context 'when admin' do

        before(:each) do
          access_token.user.add_role RoleConstants::ADMIN
        end

        describe "GET #index" do
          it "allows access token via params" do
            get :index, params: {access_key: access_token.key, type: 'Course'}, format: :json
            expect(response).to be_successful
          end

          it "allows access token via headers" do
            request.headers.merge!('Access-Key' => access_token.key)

            get :index, params: {type: 'Course'}, format: :json
            expect(response).to be_successful
          end
        end

      end

      context 'when not admin' do

        before(:each) do
          access_token.user.remove_role RoleConstants::ADMIN # Just to be safe
        end

        describe "GET #index" do
          it "does not allow access token via params" do
            expect{ get :index, params: {access_key: access_token.key, type: 'Course'}, format: :json }.to raise_error(Pundit::NotAuthorizedError)
          end

          it "does not allow access token via headers" do
            request.headers.merge!('Access-Key' => access_token.key)

            expect{ get :index, params: {type: 'Course'}, format: :json }.to raise_error(Pundit::NotAuthorizedError)
          end
        end

      end

    end

  end
end
