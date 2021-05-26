require 'rails_helper'

RSpec.describe CapstoneEvaluationSubmissionAnswer, type: :model do

  # Associations
  it { should belong_to :capstone_evaluation_submission }
  it { should belong_to :capstone_evaluation_question }
  it { should belong_to :for_user }

  # Validations
  it { should validate_presence_of :capstone_evaluation_submission_id }
  it { should validate_presence_of :capstone_evaluation_question_id }
  it { should validate_presence_of :for_user_id }
  it { should validate_presence_of :input_value }

  let!(:user) { create(:fellow_user) }
  let(:capstone_evaluation_submission) { create(:capstone_evaluation_submission, user: user) }
  let(:capstone_evaluation_submission_answer) { create(:capstone_evaluation_submission_answer, capstone_evaluation_submission: capstone_evaluation_submission) }

  describe "#save" do
    it 'allows saving' do
      expect { capstone_evaluation_submission_answer.save! }.to_not raise_error
    end
  end
end
