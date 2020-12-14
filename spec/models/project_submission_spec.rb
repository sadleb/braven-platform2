require 'rails_helper'

RSpec.describe ProjectSubmission, type: :model do

  it { should validate_presence_of :user }
  it { should validate_presence_of :course_project_version }

  describe '#valid?' do
    let(:user) { create(:fellow_user) }
    let(:course_project_version) { create(:course_project_version) }
    let(:project_submission) {
      build(:project_submission, user: user, course_project_version: course_project_version)
    }

    context 'when valid' do
      it 'allows saving' do
        expect { project_submission.save! }.to_not raise_error
      end
    end

    context 'uniqueness constraint violated' do
      it 'disallows saving' do
        create(
          :project_submission,
          user: user,
          course_project_version: course_project_version,
        )

        expect { project_submission.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when multiple submitted submissions for same user/project' do
      it 'allows saving' do
        create(
          :project_submission_submitted,
          user: user,
          course_project_version: course_project_version,
        )
        create(
          :project_submission_submitted,
          user: user,
          course_project_version: course_project_version,
        )

        expect { project_submission.save! }.not_to raise_error
      end
    end

    context 'when submisssion is_submitted' do
      it 'disallows updating' do
        project_submission.save_answers!

        expect { project_submission.update(user: User.first) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end

  end

end
