# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GradeUnsubmittedAssignments do
  let(:grade_unsubmitted_assignments) { GradeUnsubmittedAssignments.new }
  let(:sf_client) { double(SalesforceAPI) }
  # Default: no courses. Override in context below where appropriate.
  let(:accelerator_course_ids) { [] }
  let(:canvas_client) { double(CanvasAPI) }
  let(:course1) { create(:course) }
  let(:course2) { create(:course) }

  describe "#run" do
    subject { grade_unsubmitted_assignments.run }

    before :each do
      allow(grade_unsubmitted_assignments).to receive(:grade_unsubmitted_assignments).and_return(nil)

      allow(sf_client)
        .to receive(:get_current_and_future_accelerator_canvas_course_ids)
        .and_return(accelerator_course_ids)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)

      # Stub Course.where so we can check if it was called.
      allow(Course).to receive(:where).and_return([course1, course2])
    end

    # https://app.asana.com/0/1201131148207877/1200788567441198
    it 'gets current__and_future_accelerator_canvas_course_ids and gets programs that ended in the past 45 days' do
      # Need to freeze now so that it matches
      allow(Time).to receive(:now).and_return(Time.now)

      expect(sf_client)
        .to receive(:get_current_and_future_accelerator_canvas_course_ids)
        .with(ended_less_than: 45.days.ago)
        .and_return(accelerator_course_ids)
      subject
    end

    context 'with no running programs' do
      it 'exits early' do
        subject
        # We should exit before Course.where gets called.
        expect(Course).not_to have_received(:where)
      end
    end

    context 'with some running programs' do
      let(:accelerator_course_ids) { [course1.canvas_course_id, course2.canvas_course_id] }

      it 'should not exit early' do
        subject
        # We should not exit before Course.where gets called because there are courses
        expect(Course).to have_received(:where)
      end

      it 'calls grade_unsubmitted_assignments once for each course with interactions' do
        subject

        expect(grade_unsubmitted_assignments)
          .to have_received(:grade_unsubmitted_assignments)
          .exactly(accelerator_course_ids.count)
          .times
      end
    end
  end # end describe run

  let(:course) { create(:course) }
  let(:valid_assignment) { create(:canvas_assignment,
    submission_types: ['external_tool'],
    published: true,
    post_manually: false
    ) }
  let(:unpublished_assignment) { create(:canvas_assignment,
    submission_types: ['external_tool'],
    published: false,
    post_manually: false
    ) }
  let(:online_entry_assignment) { create(:canvas_assignment,
    submission_types: ['online_text_entry'],
    published: true,
    post_manually: false
    ) }
  let(:post_manually_assignment) { create(:canvas_assignment,
    submission_types: ['external_tool'],
    published: true,
    post_manually: true
  ) }
  let(:assignments) { [
    valid_assignment,
    unpublished_assignment,
    online_entry_assignment,
    post_manually_assignment
  ] }
  let(:submissions_obj) { {} }
  let(:submission_due_tomorrow) { create :canvas_submission,
    cached_due_date: (Time.now + 1.day).utc.iso8601,
    assignment_id: valid_assignment['id']
  }
  let(:submission_due_yesterday) { create :canvas_submission,
    cached_due_date: (Time.now - 1.day).utc.iso8601,
    assignment_id: valid_assignment['id']
  }

  describe '#grade_unsubmitted_assignments' do
    subject {
      grade_unsubmitted_assignments.grade_unsubmitted_assignments(course)
    }

    before :each do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:get_assignments).and_return(assignments)
      allow(canvas_client)
        .to receive(:get_unsubmitted_assignment_data)
        .and_return(submissions_obj)
      allow(canvas_client).to receive(:update_grades).and_return(nil)
    end

    it 'calls get_assignments from the Canvas API to get all course assignments' do
      expect(canvas_client)
        .to receive(:get_assignments)
        .with(course.canvas_course_id)
        .and_return(assignments)
      subject
    end

    context 'with no assignments that pass the assignment filter' do
      let(:assignments) { [unpublished_assignment, online_entry_assignment] }

      it 'filters out all assignments and exits early' do
        expect(canvas_client).not_to receive(:get_unsubmitted_assignment_data)
        subject
      end
    end

    context 'with assignments that pass the assignment filter' do
      let(:submissions_obj) { {valid_assignment['id'] => [submission_due_yesterday]} }

      it 'calls get_unsubmitted_assignment_data' do
        expect(canvas_client).to receive(:get_unsubmitted_assignment_data)
        subject
      end

      context 'with submissions returned' do
        it 'calls zero_out_grades' do
          expect(grade_unsubmitted_assignments).to receive(:zero_out_grades)
          subject
        end
      end

      context 'with no submissions returned' do
        let(:submissions_obj) { {} }

        it 'does not call zero_out_grades' do
          expect(grade_unsubmitted_assignments).not_to receive(:zero_out_grades)
          subject
        end
      end
    end

    context 'with no assignment filter' do
      let(:grade_unsubmitted_assignments) { GradeUnsubmittedAssignments.new(nil, false) }
      let(:assignments) { [unpublished_assignment, online_entry_assignment] }
      let(:submissions_obj) { {online_entry_assignment['id'] => [submission_due_yesterday]} }

      it 'calls get_unsubmitted_assignment_data' do
        expect(canvas_client).to receive(:get_unsubmitted_assignment_data)
        subject
      end

      context 'with submissions returned' do
        it 'calls zero_out_grades' do
          expect(grade_unsubmitted_assignments).to receive(:zero_out_grades)
          subject
        end
      end
    end
  end # end describe grade_unsubmitted_assignments

  describe '#zero_out_grades' do
    let(:submissions) { [] }

    subject { grade_unsubmitted_assignments.zero_out_grades(
      course.canvas_course_id,
      valid_assignment['id'],
      submissions
    )}

    before :each do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:update_grades)
    end

    context 'with submissions due in past' do
      let(:submissions) { [submission_due_tomorrow, submission_due_yesterday] }

      it 'calls update_grades and sets submission scores to zero' do
        expect(canvas_client).to receive(:update_grades)
        subject
      end
    end

    context 'with no submissions due in past' do
      let(:submissions) { [submission_due_tomorrow] }
      it 'does not call update_grades' do
        expect(canvas_client).not_to receive(:update_grades)
        subject
      end
    end
  end # end describe zero_out_grades

  describe '#assignment_filter' do
    subject { grade_unsubmitted_assignments.assignment_filter(assignment) }

    context 'with a published assignment that has an external_tool submission type, is not an attendance event and is not set to post manually' do
      let(:assignment) { valid_assignment }

      it 'passes the assignment filter and returns the assignment id' do
        expect(subject).to eq(valid_assignment['id'])
      end
    end

    context 'with an unpublished assignment' do
      let(:assignment) { unpublished_assignment }
      it 'does not pass the assignment filter and returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'with an assignment that has online_text_entry submission type' do
      let(:assignment) { online_entry_assignment }
      it 'does not pass the assignment filter and returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'with a published assignment that is an attendance event' do
      let(:assignment) { create(:canvas_assignment, published: true) }
      let!(:attendance_event) { create(:course_attendance_event, canvas_assignment_id: assignment['id']) }

      it 'does not pass the assignment filter and returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'with an assignment that is set to post manually' do
      let(:assignment) { post_manually_assignment }
      it 'does not pass the assignment filter and returns false' do
        expect(subject).to eq(false)
      end
    end
  end # end describe assignment_filter
end
