require 'rails_helper'

RSpec.describe TestUserPolicy, type: :policy do
  let(:user) { create(:registered_user) }

  subject { described_class }

  shared_examples 'admin policy' do
    it "allows admin users" do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    it "disallows non-admin users" do
      expect(subject).not_to permit(user)
    end
  end

  permissions :post? do
    it_behaves_like 'admin policy'
  end

  permissions :cohort_schedules? do
    it_behaves_like 'admin policy'
  end

  permissions :cohort_sections? do
    it_behaves_like 'admin policy'
  end

  permissions :ta_assignments? do
    it_behaves_like 'admin policy'
  end

  permissions :get_program_tas? do
    it_behaves_like 'admin policy'
  end
end