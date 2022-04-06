require 'rails_helper'

RSpec.describe AttendanceEventSubmissionsController, type: :controller do
  render_views

  let(:lc_playbook_course) { create :course }
  let(:lc_playbook_section) { create :cohort_section, course: lc_playbook_course }

  let(:accelerator_course) { create :course }
  let(:accelerator_section) { create :cohort_section, course: accelerator_course }
  let(:launch_section) { accelerator_section }

  let(:assignment_overrides) { [] }

  let(:canvas_client) { double(CanvasAPI) }
  let(:salesforce_client) { double(SalesforceAPI) }

  before(:each) do
    sign_in user
    @lti_launch = create(
      :lti_launch_resource_link_request,
      canvas_course_id: lc_playbook_course.canvas_course_id,
      canvas_user_id: user.canvas_user_id,
    )
    allow(SalesforceAPI).to receive(:client).and_return(salesforce_client)
    allow(salesforce_client)
      .to receive(:get_accelerator_course_id_from_lc_playbook_course_id)
      .with(lc_playbook_course.canvas_course_id)
      .and_return(accelerator_course.canvas_course_id)
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:get_assignment_overrides_for_section)
      .and_return(assignment_overrides)
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
    subject { get(:launch, params: { lti_launch_id: @lti_launch.id } ) }

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
          course_attendance_event_id: course_attendance_event,
          section_id: launch_section.id,
          lti_launch_id: @lti_launch.id,
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
      let!(:user) { create :admin_user, section: accelerator_section }
      let!(:fellow_user) { create :fellow_user, section: accelerator_section }

      context 'with attendance events' do
        let!(:course_attendance_event) { create(
          :course_attendance_event,
          course: accelerator_course,
        ) }

        context 'as TA in a section' do
          before(:each) do
            user.add_role RoleConstants::TA_ENROLLMENT, accelerator_section
          end
          it_behaves_like 'valid launch'
        end

        # Admins will just see the attendance form for the first section they are a TA in.
        context 'as TA in multiple sections' do
          let(:accelerator_section2) { create :cohort_section, course: accelerator_course  }
          let(:launch_section) { accelerator_section2 }
          before(:each) do
            user.add_role RoleConstants::TA_ENROLLMENT, accelerator_section2
          end
          it_behaves_like 'valid launch'
        end
      end

      context 'no attendance events' do
        it_behaves_like 'no attendance events'
      end
    end

    context 'as enrolled (LC) user' do
      let!(:user) { create :ta_user, section: accelerator_section }
      let(:accelerator_section2) { create :cohort_section, course: accelerator_course  }

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

          context 'when different LCs take attendance for the same event' do
            let!(:other_lc) { create :ta_user, canvas_user_id: 998877, section: accelerator_section2 }
            before(:each) do
              AttendanceEventSubmission.create(user: other_lc, course_attendance_event: course_attendance_event)
            end

            it_behaves_like 'valid launch'

            it 'creates a separate submission' do
              expect { subject }.to change(AttendanceEventSubmission, :count).by(1)
              expect(AttendanceEventSubmission.where(user: other_lc).count).to eq(1)
              expect(AttendanceEventSubmission.where(user: user).count).to eq(1)
            end
          end

        end

        context 'as TA in multiple sections' do
          it 'renders multiple sections message' do
            user.add_role RoleConstants::TA_ENROLLMENT, accelerator_section2
            subject
            expect(response.body).to include("multiple cohorts")
          end
        end

      end
    end

  end # /GET #launch

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
      lti_launch_id: @lti_launch.id,
      course_attendance_event_id: course_attendance_event
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
      before :each do
        # Set up the section.
        accelerator_section
      end

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
        let!(:fellow_user1) { create :fellow_user, last_name: 'Zebra', section: accelerator_section }
        let!(:fellow_user2) { create :fellow_user, last_name: 'BlastName', section: accelerator_section }
        let!(:fellow_user3) { create :fellow_user, last_name: 'Adams', section: accelerator_section }
        let!(:ta_section) { create :ta_section, course: accelerator_section.course }
        let!(:ta_caseload_section) { create :ta_caseload_section, course: accelerator_section.course }

        context 'when LC has special permission' do
          before :each do
            user.add_role RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL
          end

          it 'loads section dropdown' do
            subject
            expect(response.body).to include('<select id="input-attend-section"')
          end

          it 'includes accelerator section in section dropdown' do
            subject
            expect(response.body).to include(accelerator_section.name)
          end

          it 'excludes Teaching Assistants section from section dropdown' do
            subject
            expect(response.body).not_to include(ta_section.name)
          end

          it 'excludes TA Caseload sections from section dropdown' do
            subject
            expect(response.body).not_to include(ta_caseload_section.name)
          end

          it 'alphabetizes the list by last name' do
            subject
            expect(response.body).to match(/<legend>.+Adams.*<legend>.+BlastName.*<legend>.+Zebra/m)
          end
        end

        context 'when LC does not have special permission' do
          it 'does not load section dropdown' do
            subject
            expect(response.body).not_to include('<select id="input-attend-section"')
          end
        end


        it "has a required attribute on the present and absent radio buttons" do
          subject
          expect(response.body).to match(/type="radio"[^>]* required.* type="radio"[^>]* required/m)
        end

        context 'when a Fellow has previous attendance submissions for this CourseAttendanceEvent' do
          let!(:attendance_event_submission1) { create(
            :attendance_event_submission,
            course_attendance_event: course_attendance_event,
            user: user,
          ) }
          let!(:attendance_submission_event_answer1) { create(
            :absent_attendance_event_submission_answer,
            attendance_event_submission: attendance_event_submission1,
            for_user: fellow_user1,
          ) }
          let!(:attendance_event_submission2) { create(
            :attendance_event_submission,
            course_attendance_event: course_attendance_event,
            user: user,
          ) }
          let!(:attendance_event_submission_answer2) { create(
            :present_attendance_event_submission_answer,
            attendance_event_submission: attendance_event_submission2,
            for_user: fellow_user1,
          ) }

          it 'shows the attendance data from the most recent submission for this CourseAttendanceEvent for a Fellow' do
            subject
            expect(response.body).to match(/Zebra<\/legend>.*name="attendance_event_submission\[#{fellow_user1.id}\]\[in_attendance\]"\s*value="true"/m)
          end
        end

        context 'when a Fellow does not have previous attendance submissions for this CourseAttendanceEvent' do
          it 'does not show attendance data for the Fellow (neither present nor absent are checked)' do
            expect(response.body).not_to include('value="true"')
          end
        end

        context 'with learning lab event' do
          let(:course_attendance_event) { create(
            :learning_lab_course_attendance_event,
            course: accelerator_course,
          ) }

          it "shows the Fellow's name in learning lab attendance form" do
            subject
            expect(response.body).to include("</form>")
            expect(response.body).to include(fellow_user1.full_name)
            expect(response.body).to include(fellow_user2.full_name)
            expect(response.body).to include(fellow_user3.full_name)
            expect(response.body).to include('type="radio"')
            expect(response.body).not_to include(user.full_name)
          end
        end

        context 'with mock interviews event' do
          let(:course_attendance_event) { create(
            :mock_interviews_course_attendance_event,
            course: accelerator_course,
          ) }

          it "shows the Fellow's name in mock interviews attendance form" do
            subject
            expect(response.body).to include("</form>")
            expect(response.body).to include(fellow_user1.full_name)
            expect(response.body).to include(fellow_user2.full_name)
            expect(response.body).to include(fellow_user3.full_name)
            expect(response.body).to include('type="radio"')
            expect(response.body).not_to include(user.full_name)
          end
        end

        context 'with 1:1 event' do
          let(:course_attendance_event) { create(
            :one_on_one_course_attendance_event,
            course: accelerator_course,
          ) }

          it "shows the simple checkbox-only form" do
            subject
            expect(response.body).to include("</form>")
            expect(response.body).to include(fellow_user1.full_name)
            expect(response.body).to include(fellow_user2.full_name)
            expect(response.body).to include(fellow_user3.full_name)
            expect(response.body).to include('type="checkbox"')
            expect(response.body).not_to include('type="radio"')
          end
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
          lti_launch_id: @lti_launch.id,
        },
      )
    }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:update_grades)
    end

    shared_examples 'a successful update' do
      scenario 'uses existing submission' do
        expect { subject }.not_to change(AttendanceEventSubmission, :count)
      end

      scenario 'redirects to #edit' do
        subject
        expect(response).to redirect_to edit_attendance_event_submission_path(
          attendance_event_submission,
          lti_launch_id: @lti_launch.id,
        )
      end

      scenario 'renders a success notification' do
        subject
        expect(flash[:notice]).to match /saved/
      end

      scenario 'updates grades in Canvas' do
        subject
        grades = AttendanceGradeCalculator.compute_grades(attendance_event_submission)
        expect(canvas_client).to have_received(:update_grades)
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
