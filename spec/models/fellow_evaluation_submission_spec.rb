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

  describe "#save" do
    let(:lc_playbook_course) { create :course_launched }
    let(:section) { create :section, course: lc_playbook_course }

    let(:user) { create :lc_playbook_user, section: section }

    let(:fellow_evaluation_submission) { create(
      :fellow_evaluation_submission,
      user: user,
      course: lc_playbook_course,
    ) }

    it 'allows saving' do
      expect { fellow_evaluation_submission.save! }.to_not raise_error
    end
  end
end
