require 'rails_helper'

RSpec.describe AttendanceEventSubmissionsController, type: :controller do
  render_views

  let(:lc_playbook_course) { create :course, canvas_course_id: 1 }
  let(:lc_playbook_section) { create :section, course: lc_playbook_course }

  let(:accelerator_course) { create :course, canvas_course_id: 2 }
  let(:accelerator_section) { create :section, course: accelerator_course }

  let(:salesforce_client) { double(SalesforceAPI) }

  before(:each) do
    @lti_launch = create(
      :lti_launch_resource_link_request,
      course_id: lc_playbook_course.canvas_course_id,
      canvas_user_id: user.canvas_user_id,
    )
    allow(SalesforceAPI).to receive(:client).and_return(salesforce_client)
    allow(salesforce_client)
      .to receive(:get_accelerator_course_id_from_lc_playbook_course_id)
      .with(lc_playbook_course.canvas_course_id)
      .and_return(accelerator_course.canvas_course_id)
  end

  shared_examples 'valid request' do
    scenario 'returns a success response' do
      subject
      expect(response).to be_successful
    end
  end

  shared_examples 'not permitted' do
    scenario 'throws a pundit error' do
      expect { subject }.to raise_error Pundit::NotAuthorizedError
    end
  end

  describe 'GET #launch' do
    subject { get(:launch, params: { state: @lti_launch.state } ) }

    shared_examples 'valid launch' do
      scenario 'creates a submission' do
        expect { subject }.to change(AttendanceEventSubmission, :count).by(1)
      end

      scenario 'uses the same submission on the second launch request' do
        subject
        expect { subject }.not_to change(AttendanceEventSubmissionAnswer, :count)
      end

      scenario 'redirects to #edit' do
        expect(subject).to redirect_to edit_attendance_event_submission_path(
          AttendanceEventSubmission.last,
          state: @lti_launch.state,
        )
      end
    end

    shared_examples 'no attendance events' do
      scenario 'renders message' do
        subject
        expect(response.body).to include("There are no events")
      end

      scenario 'does not have a form' do
        subject
        expect(response.body).not_to include("</form>")
      end

      scenario 'does not create a submission' do
        expect { subject }.not_to change(AttendanceEventSubmission, :count)
      end
    end

    context 'as non-enrolled user' do
      let(:user) { create :registered_user }
      it_behaves_like 'not permitted'
    end

    context 'as enrolled (Fellow) user' do
      let(:user) { create :fellow_user, section: accelerator_section }
      it_behaves_like 'not permitted'
    end

    context 'as non-enrolled (admin) user' do
      let!(:user) { create :admin_user }
      let!(:fellow_user) { create :fellow_user, section: accelerator_section }

      context 'with attendance events' do
        let!(:course_attendance_event) { create(
          :course_attendance_event,
          course: accelerator_course,
        ) }
        it_behaves_like 'valid launch'
      end

      context 'no attendance events' do
        it_behaves_like 'no attendance events'
      end
    end

    context 'as enrolled (LC) user' do
      let!(:user) { create :ta_user, section: accelerator_section }
      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, lc_playbook_section
      end

      context 'no attendance events' do
        it_behaves_like 'no attendance events'
      end

      context 'with attendance events' do
        let!(:course_attendance_event) { create(
          :course_attendance_event,
          course: accelerator_course,
        ) }

        context 'without fellows' do
          it_behaves_like 'valid launch'
        end

        context 'with fellows' do
          let!(:fellow_user) { create :fellow_user, section: accelerator_section }
          it_behaves_like 'valid launch'
        end
      end
    end
  end

  describe 'GET #edit' do
    let(:course_attendance_event) { create(
      :course_attendance_event,
      course: accelerator_course,
    ) }

    before(:each) do
      @attendance_event_submission = AttendanceEventSubmission.create!(
        course_attendance_event: course_attendance_event,
        user: user,
      )
    end

    subject { get(:edit, params: {
      id: @attendance_event_submission.id,
      state: @lti_launch.state,
    } ) }

    shared_examples 'no fellows' do
      scenario 'shows a message' do
        subject
        expect(response.body).to include("no fellows to take attendance for")
      end
    end

    context 'as non-enrolled user' do
      let(:user) { create :registered_user }
      it_behaves_like 'not permitted'
    end

    context 'as enrolled (Fellow) user' do
      let(:user) { create :fellow_user, section: accelerator_section }
      it_behaves_like 'not permitted'
    end

    context 'as non-enrolled (admin) user' do
      let(:user) { create :admin_user }
      it_behaves_like 'valid request'
      it_behaves_like 'no fellows'
    end

    context 'as enrolled (LC) user' do
      let(:user) { create :ta_user, section: accelerator_section }
      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, lc_playbook_section
      end

      it_behaves_like 'valid request'

      context 'without fellows' do
        it_behaves_like 'no fellows'
      end

      context 'with fellows' do
        let!(:fellow_user) { create :fellow_user, section: accelerator_section }

        it "shows the Fellow's name in attendance form" do
          subject
          expect(response.body).to include("</form>")
          expect(response.body).to include(fellow_user.full_name)
          expect(response.body).not_to include (user.full_name)
        end
      end
    end
  end

  describe 'PUT #update' do
    let(:canvas_client) { double(CanvasAPI) }

    let(:fellow_user){ create :fellow_user, section: accelerator_section }
    let(:course_attendance_event) { create(
      :course_attendance_event,
      course: accelerator_course,
    ) }
    let!(:attendance_event_submission) { create(
      :attendance_event_submission,
      course_attendance_event: course_attendance_event,
      user: user,
    ) }

    subject {
      put(
        :update,
        params: {
          id: attendance_event_submission.id,
          attendance_event_submission: {
            fellow_user.id.to_s => {
              'in_attendance' => true,
            },
          },
          state: @lti_launch.state,
        },
      )
    }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:update_module_grades)
    end

    shared_examples 'a successful update' do
      scenario 'uses existing submission' do
        expect { subject }.not_to change(AttendanceEventSubmission, :count)
      end

      scenario 'redirects to #edit' do
        subject
        expect(response).to redirect_to edit_attendance_event_submission_path(
          attendance_event_submission,
          state: @lti_launch.state,
        )
      end

      scenario 'renders a success notification' do
        subject
        expect(flash[:notice]).to match /saved/
      end

      scenario 'updates grades in Canvas' do
        subject
        grades = AttendanceGradeCalculator.compute_grades(attendance_event_submission)
        expect(canvas_client).to have_received(:update_module_grades)
          .with(accelerator_course.canvas_course_id, course_attendance_event.canvas_assignment_id, grades)
          .once
      end
    end

    context 'as the LC' do
      let(:user) { create :ta_user, section: accelerator_section }
      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, lc_playbook_section
      end

      it_behaves_like 'a successful update'

      it 'creates a new answer for the fellow' do
        expect{ subject }.to change(AttendanceEventSubmissionAnswer, :count).by(1)
        expect(AttendanceEventSubmissionAnswer.last.for_user).to eq(fellow_user)
      end

      it 'uses existing record for fellow' do
        subject
        expect { subject }.not_to change(AttendanceEventSubmissionAnswer, :count)
      end
    end

    context 'as admin' do
      let(:user) { create :admin_user }
      it_behaves_like 'a successful update'
    end

    context 'as Fellow' do
      let(:user) { create :fellow_user, section: accelerator_section, canvas_user_id: 4321 }
      it_behaves_like 'not permitted'
    end

    context 'as not-enrolled' do
      let(:user) { create :registered_user }
      it_behaves_like 'not permitted'
    end
  end
end
