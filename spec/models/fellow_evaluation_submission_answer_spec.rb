require 'rails_helper'

RSpec.describe FellowEvaluationSubmissionAnswer, type: :model do

  # Associations
  it { should belong_to :fellow_evaluation_submission }
  it { should belong_to :for_user }

  # Validations
  it { should validate_presence_of :fellow_evaluation_submission_id }
  it { should validate_presence_of :for_user_id }
  it { should validate_presence_of :input_name }
  it { should validate_presence_of :input_value }

  let(:user) { create :lc_playbook_user }
  let(:submission) { create :fellow_evaluation_submission, user: user }
  let(:fellow_evaluation_submission_answer) { create(
    :fellow_evaluation_submission_answer,
    fellow_evaluation_submission: submission,
  ) }

  describe "#save" do
    it 'allows saving' do
      expect { fellow_evaluation_submission_answer.save! }.to_not raise_error
    end
  end
end
