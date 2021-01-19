require 'rails_helper'

RSpec.describe AttendanceEventsController, type: :controller do
  render_views
  let(:user) { create :admin_user }

  before do
    sign_in user
  end

  describe "GET #index" do
    context 'without any attendance events' do
      it 'returns a success response' do
        get :index
        expect(response).to be_successful
      end
    end

    context 'with attendance events' do
      let!(:attendence_events) { create_list :attendance_event, 3 }
      
      it 'returns a success response' do
        get :index
        expect(response). to be_successful
      end
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
    end
  end

  shared_examples 'a successful update' do
    scenario 'renders a success notification' do
      subject
      expect(flash[:notice]).to match /successfully/
    end

    scenario 'redirects to #index' do
      subject
      expect(response).to redirect_to(attendance_events_path)
    end
  end

  describe "POST #create" do
    subject { post :create, params: params }

    context "with valid params" do
      let(:valid_attributes) { { title: 'Attendance Event Title' } }
      let(:params) { { attendance_event: valid_attributes } }

      it "creates a new AttendanceEvent" do
        expect { subject }.to change(AttendanceEvent, :count).by(1)
      end

      it "saves the title" do
        subject
        expect(AttendanceEvent.last.title).to eq(valid_attributes[:title])
      end

      it_behaves_like 'a successful update'

      context 'with custom redirect' do
        let(:course) { create :course }
        let(:custom_path) { edit_course_path(course) }
        let(:valid_attributes) { {
          title: 'Attendance Event Title',
          redirect_to: custom_path,
        } }

        it 'redirects to the specified path' do
          subject
          expect(response).to redirect_to(custom_path)
        end
      end
    end

    context "with invalid params" do
      let(:invalid_attirbutes) { { title: '' } }
      let(:params) { { attendance_event: invalid_attirbutes } }

      it 'raises an error' do
        expect { subject }.to raise_error ActiveRecord::RecordInvalid
      end

      it 'does not create an event' do
        expect {
          subject rescue ActiveRecord::RecordInvalid
        }.not_to change(AttendanceEvent, :count)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:attendance_event) { create :attendance_event }

    subject { delete :destroy, params: params }

    context 'with valid params' do
      let(:params) { { id: attendance_event.id } }

      it 'deletes the event' do
        expect { subject }.to change(AttendanceEvent, :count).by(-1)
      end

      it_behaves_like 'a successful update'
    end

    context 'with invalid params' do
      let(:params) { { id: 0 } }

      it 'raises an error' do
        expect { subject }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'does not delete any events' do
        expect {
          subject rescue ActiveRecord::RecordNotFound
        }.not_to change(AttendanceEvent, :count)
      end
    end
  end
end