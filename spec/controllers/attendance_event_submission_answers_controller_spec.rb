require 'rails_helper'

RSpec.describe AttendanceEventSubmissionAnswersController, type: :controller do
  render_views

  describe 'GET #launch' do
    subject { get :launch, params: { state: @lti_launch.state } }

    let(:course) { create :course }
    let(:attendance_event) { create :attendance_event }
    let(:course_attendance_event) { create(
      :course_attendance_event,
      course: course,
      attendance_event: attendance_event,
    ) }

    before(:each) do
      @lti_launch = create(
        :lti_launch_assignment,
        canvas_user_id: user.canvas_user_id,
        course_id: course_attendance_event.course.id,
        assignment_id: course_attendance_event.canvas_assignment_id,
      )
    end

    shared_examples 'an LTI assignment launch' do
      scenario 'returns a success response' do
        subject
        expect(response).to be_successful
      end
    end

    context 'enrolled user' do
      let(:section) { create :section, course: course }

      context 'Fellow' do
        let(:user) { create :fellow_user, section: section }
        it_behaves_like 'an LTI assignment launch'
      end

      context 'TA' do
        let(:user) { create :ta_user, section: section }
        it_behaves_like 'an LTI assignment launch'
      end
    end

    context 'non-enrolled user (admin)' do
      let(:user) { create :admin_user }
      it_behaves_like 'an LTI assignment launch'
    end

    context 'non-enrolled user' do
      let(:user) { create :registered_user }
      it 'does not authorize access' do
        expect { subject }.to raise_error Pundit::NotAuthorizedError
      end
    end
  end
end
