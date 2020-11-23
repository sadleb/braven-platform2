require 'rails_helper'

RSpec.describe PeerReviewQuestion, type: :model do

  # Validations
  it { should validate_presence_of :text }

  let(:peer_review_question) { build(:peer_review_question) } 

  describe "#save" do
    it 'allows saving' do
      expect { peer_review_question.save! }.to_not raise_error
    end
  end
end
