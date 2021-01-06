require 'rails_helper'

# Not that we use build() instead of create() here because there model is not
# backed by the DB and we can't do create/save on it, only new.
RSpec.describe AcceleratorSurveySubmission, type: :model do
  let(:user) { create :fellow_user }
  let(:course) { create :course }

  describe '#new' do
    subject { AcceleratorSurveySubmission.new(user: user, course: course) }

    it { should be_instance_of(AcceleratorSurveySubmission) }
  end

  describe '#save_answers!' do
    let(:accelerator_survey_submission) { build(
      :accelerator_survey_submission,
      user: user,
      course: course,
    ) }
    let(:answers) { {} } # Dummy, empty list of answers

    it 'allows saving answers' do
      expect {
        accelerator_survey_submission.save_answers!(answers)
      }.to_not raise_error
    end
  end

  describe '#course' do
    let(:accelerator_survey_submission) { build(
      :accelerator_survey_submission,
      user: user,
      course: course,
    ) }
    subject { accelerator_survey_submission.course }

    it { should eq(course) }
  end

  describe '#user' do
    let(:accelerator_survey_submission) { build(
      :accelerator_survey_submission,
      user: user,
      course: course,
    ) }
    subject { accelerator_survey_submission.user }
    
    it { should eq(user) }
  end
end
