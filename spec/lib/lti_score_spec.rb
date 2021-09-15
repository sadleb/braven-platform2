require 'rails_helper'
require 'lti_score'

RSpec.describe LtiScore do

  describe '#new_project_submission' do
    context 'when it''s the first submission' do
      let(:user_id) { 1234 }
      let(:submission_url) { 'https://platformweb/the/url/to/view/submission' }
      it 'generates a new_submission message for the Canvas score API ' do
        allow(Time).to receive(:now).and_return(Time.now)
        expect(JSON.parse(LtiScore.new_project_submission(user_id, submission_url))).to eq(
          {
            'userId' => user_id.to_s,
            'timestamp' => Time.now.utc.iso8601(3), # 3 decimal precision of milliseconds
            'activityProgress' => LtiScore::ActivityProgress::SUBMITTED,
            'gradingProgress' => LtiScore::GradingProgress::PENDING_MANUAL,
            'https://canvas.instructure.com/lti/submission' => {
              'new_submission' => true,
              'submission_type' => 'basic_lti_launch',
              'submission_data' => submission_url,
              'submitted_at' => Time.now.utc.iso8601(3)
            }
          }
        )
      end
    end
  end

  describe '#new_full_credit_submission' do
    context 'gives full credit''s the first submission' do
      let(:user_id) { 1235 }
      let(:submission_url) { 'https://platformweb/the/url/to/view/submission' }
      it 'generates a new_submission message for the Canvas score API ' do
        allow(Time).to receive(:now).and_return(Time.now)
        expect(JSON.parse(LtiScore.new_full_credit_submission(user_id, submission_url))).to eq(
          {
            'userId' => user_id.to_s,
            'timestamp' => Time.now.utc.iso8601(3), # 3 decimal precision of milliseconds
            'activityProgress' => LtiScore::ActivityProgress::SUBMITTED,
            'gradingProgress' => LtiScore::GradingProgress::FULLY_GRADED,
            'scoreGiven' => 100,
            'scoreMaximum' => 100,
            'https://canvas.instructure.com/lti/submission' => {
              'new_submission' => true,
              'submission_type' => 'basic_lti_launch',
              'submission_data' => submission_url,
              'submitted_at' => Time.now.utc.iso8601(3)
            }
          }
        )
      end
    end
  end

  describe '#new_module submission' do
    context 'when it''s the first submission' do
      let(:user_id) { 1236 }
      let(:submission_url) { 'https://platformweb/the/url/to/view/submission' }
      it 'generates a new_submission message for the Canvas score API ' do
        allow(Time).to receive(:now).and_return(Time.now)
        expect(JSON.parse(LtiScore.new_module_submission(user_id, submission_url))).to eq(
          {
            'userId' => user_id.to_s,
            'timestamp' => Time.now.utc.iso8601(3), # 3 decimal precision of milliseconds
            'activityProgress' => LtiScore::ActivityProgress::IN_PROGRESS,
            'gradingProgress' => LtiScore::GradingProgress::PENDING_MANUAL,
            'https://canvas.instructure.com/lti/submission' => {
              'new_submission' => true,
              'submission_type' => 'basic_lti_launch',
              'submission_data' => submission_url,
              'submitted_at' => LtiScore::NON_SENSICAL_SUBMITTED_AT
            }
          }
        )
      end
    end
  end

end

