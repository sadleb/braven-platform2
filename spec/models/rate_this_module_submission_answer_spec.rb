require 'rails_helper'

RSpec.describe RateThisModuleSubmissionAnswer, type: :model do
  subject { create(:rate_this_module_submission_answer) }

  # Associations
  it { should belong_to :rate_this_module_submission }
  it { should have_one :user }

  # Validations
  it { should validate_presence_of :input_name }
  it { should validate_uniqueness_of(:input_name).scoped_to(:rate_this_module_submission_id) }
end
