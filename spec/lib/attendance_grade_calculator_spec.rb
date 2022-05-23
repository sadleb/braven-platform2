require 'rails_helper'
require 'attendance_grade_calculator'

RSpec.describe AttendanceGradeCalculator do

  let(:course) { create :course }
  let(:section) { create :section }

  let(:ta_user) { create :ta_user, accelerator_section: section }
  let(:fellow_user) { create :fellow_user, section: section }

  let(:course_attendance_event) { create :course_attendance_event, course: course }

  let(:attendance_event_submission) { create(
    :attendance_event_submission,
    course_attendance_event: course_attendance_event,
    user: ta_user,
  ) }

  describe '#compute_grade' do
    let(:attendance_submission_event_answer) { create(
      :attendance_event_submission_answer,
      attendance_event_submission: attendance_event_submission,
      for_user: fellow_user,
      in_attendance: in_attendance,
    ) }

    shared_examples 'no credit' do
      scenario 'it gives 0%' do
        grade = AttendanceGradeCalculator.compute_grade(attendance_submission_event_answer)
        expect(grade).to eq('0%')
      end
    end

    shared_examples 'full credit' do
      scenario 'it gives 100%' do
        grade = AttendanceGradeCalculator.compute_grade(attendance_submission_event_answer)
        expect(grade).to eq('100%')
      end
    end

    context 'attendance not taken' do
      let(:in_attendance) { nil }
      it_behaves_like 'no credit'
    end

    context 'attendance not taken' do
      let(:in_attendance) { '' }
      it_behaves_like 'no credit'
    end

    context 'marked absent' do
      let(:in_attendance) { false }
      it_behaves_like 'no credit'
    end

    context 'marked present' do
      let(:in_attendance) { true }
      it_behaves_like 'full credit'
    end
  end

  describe '#compute_grades' do
    context 'no answers' do
      it 'returns empty' do
        grades = AttendanceGradeCalculator.compute_grades(attendance_event_submission)
        expect(grades).to eq({})
      end
    end

    context 'with answers' do
      let!(:attendance_submission_event_answer) { create(
        :attendance_event_submission_answer,
        attendance_event_submission: attendance_event_submission,
        for_user: fellow_user,
        in_attendance: true,
      ) }
      it 'returns hash' do
        grades = AttendanceGradeCalculator.compute_grades(attendance_event_submission)
        expect(grades).to eq({fellow_user.canvas_user_id => '100%'})
      end
    end

    # TODO: write specs for it skipping folks without a Canvas account:
    # https://app.asana.com/0/1201131148207877/1201399664994348
  end

end
