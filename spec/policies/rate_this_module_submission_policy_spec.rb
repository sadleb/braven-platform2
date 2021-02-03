require 'rails_helper'

RSpec.describe RateThisModuleSubmissionPolicy, type: :policy do
  subject { described_class }

  let(:course) { create :course }
  let(:section) { create :section, course: course }

  let(:course_rise360_module_version) { create :course_rise360_module_version, course: course }
  let(:fellow_user) { create :fellow_user, section: section }

  let(:rate_this_module_submission) { create(
    :rate_this_module_submission,
    course_rise360_module_version: course_rise360_module_version,
    user: fellow_user,
  ) }

  let(:user) { create :registered_user }

  # Examples.
  shared_examples 'admin gets special access' do
    scenario 'allows admin users even when submission is not their own' do
      user.add_role :admin
      expect(subject).to permit(user, rate_this_module_submission)
    end
  end

  shared_examples 'admin does not get special access' do
    scenario 'disallows admin users who do not match other criteria' do
      user.add_role :admin
      expect(subject).not_to permit(user, rate_this_module_submission)
    end
  end

  shared_examples 'requires own-submission and enrolled' do
    scenario 'disallows non-enrolled when own-submission' do
      rate_this_module_submission.user = user
      expect(subject).not_to permit(user, rate_this_module_submission)
    end

    scenario 'disallows other users submissions when enrolled' do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit(user, rate_this_module_submission)
    end

    scenario 'allows own-submission when enrolled' do
      rate_this_module_submission.user = user
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, rate_this_module_submission)
    end
  end


  # Tests.
  permissions :launch? do
    it_behaves_like 'admin gets special access'
    it_behaves_like 'requires own-submission and enrolled'
  end

  permissions :edit? do
    it_behaves_like 'admin gets special access'
    it_behaves_like 'requires own-submission and enrolled'
  end

  permissions :update? do
    it_behaves_like 'admin does not get special access'
    it_behaves_like 'requires own-submission and enrolled'
  end
end
