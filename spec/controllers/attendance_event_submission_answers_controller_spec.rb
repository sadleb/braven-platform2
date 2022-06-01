require 'rails_helper'

RSpec.describe AttendanceEventSubmissionAnswersController, type: :controller do
  render_views

  describe 'GET #launch' do

    let(:course) { create :course, salesforce_program_id: participant.program_id }
    let(:section) { create :section, course: course }
    let(:course_attendance_event) { create(
      :course_attendance_event,
      course: course,
      attendance_event: attendance_event,
    ) }
    let(:lti_launch) { create(:lti_launch_assignment,
        canvas_user_id: user.canvas_user_id,
        canvas_course_id: course_attendance_event.course.id,
        canvas_assignment_id: course_attendance_event.canvas_assignment_id,
      )
    }

    # Defaults. Must be overriden in tests
    let(:user) { nil }
    let(:participant) { nil }
    let(:attendance_event) { nil }

    before(:each) do
      allow(HerokuConnect::Participant).to receive(:find_participant).and_return(participant)
    end

    subject { get :launch, params: { state: lti_launch.state } }

    shared_examples 'an LTI assignment launch' do
      it 'returns a success response' do
        subject
        expect(response).to be_successful
      end

      context 'non-enrolled user' do
        let(:course) { create :course }
        let(:user) { create :registered_user }

        it 'does not authorize access' do
          expect { subject }.to raise_error Pundit::NotAuthorizedError
        end
      end
    end

    shared_examples 'attendance event without Zoom link' do
      let(:participant) { build :heroku_connect_participant, webinar_access_1__c: nil, webinar_access_2__c: nil, webinar_access_3__c: nil }
      let(:user) { create :fellow_user, section: section }

      it_behaves_like 'an LTI assignment launch'
      it 'does not show the Zoom link' do
        subject
        expect(response.body).to include('This assignment is a reminder to attend your')
        expect(response.body).not_to include('Zoom')
      end
    end

    shared_examples 'attendance event with Zoom link' do
      context 'when Participant has link' do
        let(:zoom_meeting_link1) { 'https://meeting_link.example.fake1' }
        let(:zoom_meeting_link2) { 'https://meeting_link.example.fake2' }
        let(:zoom_meeting_link3) { 'https://meeting_link.example.fake3' }

        # You must set an expected_meeting_link variable before calling this.
        shared_examples 'shows the Zoom link' do
          it 'shows the HTML' do
            subject
            expect(response.body).to match(
              /<a href="#{expected_meeting_link}" target="_blank">Click here to join the Zoom #{attendance_event.event_type_display} \(opens in new tab\)!<\/a>/
            )
          end
        end

        context 'Fellow' do
          let(:participant) { build :heroku_connect_fellow_participant, webinar_access_1__c: zoom_meeting_link1, webinar_access_2__c: zoom_meeting_link2, webinar_access_3__c: zoom_meeting_link3 }
          let(:user) { create :fellow_user, section: section }
          it_behaves_like 'an LTI assignment launch'
          it_behaves_like 'shows the Zoom link'
        end

        context 'TA' do
          let(:participant) { build :heroku_connect_ta_participant, webinar_access_1__c: zoom_meeting_link1, webinar_access_2__c: zoom_meeting_link2, webinar_access_3__c: zoom_meeting_link3 }
          let(:user) { create :ta_user, accelerator_section: section }
          it_behaves_like 'an LTI assignment launch'
          it_behaves_like 'shows the Zoom link'
        end
      end # 'when Participant has link'

      context 'when Participant has no link' do
        it_behaves_like 'attendance event without Zoom link'
      end

    end # 'attendance event with Zoom link'

    context 'when Learning Lab event' do
      let(:attendance_event) { create :learning_lab_attendance_event }
      let(:expected_meeting_link) { zoom_meeting_link1 }
      it_behaves_like 'attendance event with Zoom link'
    end

    context 'when Orientation event' do
      let(:attendance_event) { create :orientation_attendance_event }
      let(:expected_meeting_link) { zoom_meeting_link2 }
      it_behaves_like 'attendance event with Zoom link'
    end

    context 'when Mock Interviews event' do
      let(:attendance_event) { create :mock_interviews_attendance_event }
      let(:expected_meeting_link) { zoom_meeting_link3 }
      it_behaves_like 'attendance event with Zoom link'
    end

    context 'when Leadership Coach 1:1 event' do
      let(:attendance_event) { create :one_on_one_attendance_event }
      it_behaves_like 'attendance event without Zoom link'
    end

  end # 'GET #launch'

end
