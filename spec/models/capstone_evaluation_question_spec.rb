require 'rails_helper'

RSpec.describe CapstoneEvaluationQuestion, type: :model do

  # Validations
  it { should validate_presence_of :text }

  let(:capstone_evaluation_question) { build(:capstone_evaluation_question) } 

  describe "#save" do
    it 'allows saving' do
      expect { capstone_evaluation_question.save! }.to_not raise_error
    end
  end
end
