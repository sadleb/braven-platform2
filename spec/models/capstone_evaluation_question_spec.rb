require 'rails_helper'

RSpec.describe CapstoneEvaluationQuestion, type: :model do

  # Validations
  it { should validate_presence_of :text }

  let(:capstone_evaluation_question) { build(:capstone_evaluation_question) } 

  describe '#save' do
    it 'allows saving' do
      expect { capstone_evaluation_question.save! }.to_not raise_error
    end
  end

  describe '#four_question_warning' do
    before(:each) do
      allow(Rails.logger).to receive(:warn)
    end

    context 'when a new CapstoneEvaluationQuestion is created' do
      it 'should log a warning that there should only be four questions after_create' do
        CapstoneEvaluationQuestion.create!(text: 'test question')

        expect(Rails.logger)
          .to have_received(:warn)
          .with('There should always be exactly four Capstone Evaluation Questions. Do not add or remove any questions as it will affect grade calculations')
      end
    end

    context 'when a new CapstoneEvaluationQuestion is deleted' do
      let(:question) { CapstoneEvaluationQuestion.create!(text: 'test question') }

      it 'should log a warning that there should only be four questions before_destroy' do
        CapstoneEvaluationQuestion.destroy(question.id)

        # Expect the warning twice because the questions needs to be created so that we have a question to destroy
        # and it warns after_create and before_destroy
        expect(Rails.logger)
          .to have_received(:warn)
          .with('There should always be exactly four Capstone Evaluation Questions. Do not add or remove any questions as it will affect grade calculations')
          .twice
      end
    end
  end
end
