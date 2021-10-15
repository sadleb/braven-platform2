require 'rails_helper'

RSpec.describe Rise360ModuleInteraction, type: :model do

  # Associations
  it { should belong_to :user }

  # Validations
  it { should validate_presence_of :user }
  it { should validate_presence_of :activity_id }
  it { should validate_presence_of :verb }
  it { should validate_presence_of :canvas_course_id }
  it { should validate_presence_of :canvas_assignment_id }

  # Methods
  describe '.create_progress_interaction' do
    let(:course) { create :course }
    let(:user) { create(:registered_user) }
    let(:course_rise360_module_version) { create :course_rise360_module_version, course: course }
    let(:activity_id) { course_rise360_module_version.rise360_module_version.activity_id }

    let(:lti_launch) {
      create(
        :lti_launch_assignment,
        canvas_course_id: course.canvas_course_id,
        canvas_user_id: user.canvas_user_id,
        canvas_assignment_id: course_rise360_module_version.canvas_assignment_id,
      )
    }

    let(:expected_interaction_attributes) {
      {
        verb: Rise360ModuleInteraction::PROGRESSED,
        user: user,
        canvas_course_id: lti_launch.course_id,
        canvas_assignment_id: lti_launch.assignment_id,
        activity_id: activity_id,
        progress: progress,
      }
    }

    # Default. Change to test.
    let(:progress) { nil }

    subject { Rise360ModuleInteraction.create_progress_interaction(user, lti_launch, activity_id, progress) }

    context 'when less than 100% progress' do
      let(:progress) { 33 }

      it 'creates the interaction' do
        expect{ subject }.to change(Rise360ModuleInteraction, :count).by(1)
        expect(Rise360ModuleInteraction.find_by(expected_interaction_attributes)).to be_instance_of(Rise360ModuleInteraction)
      end

      it 'doesnt create duplicates' do
        Rise360ModuleInteraction.create_progress_interaction(user, lti_launch, activity_id, progress)
        expect{ subject }.not_to change(Rise360ModuleInteraction, :count)
        expect(Rise360ModuleInteraction.where(expected_interaction_attributes).count).to eq(1)
      end
    end

    context 'when 100% progress' do
      let(:progress) { 100 }

      before(:each) do
        allow(GradeRise360ModuleForUserJob).to receive(:perform_later).and_return(nil)
      end

      it 'creates the interaction' do
        expect{ subject }.to change(Rise360ModuleInteraction, :count).by(1)
        expect(Rise360ModuleInteraction.find_by(expected_interaction_attributes)).to be_instance_of(Rise360ModuleInteraction)
      end

      it 'doesnt create duplicates' do
        Rise360ModuleInteraction.create_progress_interaction(user, lti_launch, activity_id, progress)
        expect{ subject }.not_to change(Rise360ModuleInteraction, :count)
        expect(Rise360ModuleInteraction.where(expected_interaction_attributes).count).to eq(1)
      end

      it 'kicks off auto-grading' do
        # Call it twice to make sure it only kicks off grading once.
        subject
        Rise360ModuleInteraction.create_progress_interaction(user, lti_launch, activity_id, progress)
        expect(GradeRise360ModuleForUserJob).to have_received(:perform_later)
          .with(user, lti_launch).once
      end

    end

  end # .create_progress_interaction

end
