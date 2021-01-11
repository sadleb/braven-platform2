require 'rails_helper'
require 'lti_advantage_api'
require 'lti_score'

RSpec.describe FellowEvaluationSubmission, type: :model do

  # Associations
  it { should belong_to :user }
  it { should belong_to :course }

  # Validations
  it { should validate_presence_of :user_id }
  it { should validate_presence_of :course_id }

  let(:lc_playbook_course) { create :course_launched }
  let(:section) { create :section, course: lc_playbook_course }

  let(:user) { create :lc_playbook_user, section: section }

  let(:fellow_evaluation_submission) { create(
    :fellow_evaluation_submission,
    user: user,
    course: lc_playbook_course,
  ) }

  describe "#save" do
    it 'allows saving' do
      expect { fellow_evaluation_submission.save! }.to_not raise_error
    end
  end

  describe '#answers' do
    let(:fellow_evaluation_submission_answer) { create(
      :fellow_evaluation_submission_answer,
      fellow_evaluation_submission: fellow_evaluation_submission,
    ) }

    subject { fellow_evaluation_submission.answers.first }

    it { should eq(fellow_evaluation_submission_answer) }
  end

  describe '#save_answers!' do
    let(:input_name_1) { 'would-hire-entry-level-role' }
    let(:input_name_2) { 'how-ready-to-be-team' }
    let(:input_name_3) { 'other-fellow-comments-from-lc' }

    let(:fellow_user_1) { create(:fellow_user) }
    let(:fellow_user_2) { create(:fellow_user, canvas_user_id: '9999') }

    let(:answers) { {
      fellow_user_1.id.to_s => {
        input_name_1 => 'My input 1',
        input_name_2 => 'My input 2',
        input_name_3 => '',
      },
      fellow_user_2.id.to_s => {
        input_name_1 => 'My input 3',
        input_name_2 => 'My input 4',
        input_name_3 => '',
      },
    } }

    it 'creates new answers and skips blank answers' do
      expect {
        fellow_evaluation_submission.save_answers!(answers)
      }.to change(FellowEvaluationSubmissionAnswer, :count).by(4)
    end

    it 'attaches the answers to the submission' do
      fellow_evaluation_submission.save_answers!(answers)
      expect(fellow_evaluation_submission.answers.count).to eq(4)
    end
  end
end
