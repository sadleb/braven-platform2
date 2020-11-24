require 'rails_helper'

RSpec.describe PeerReviewPolicy, type: :policy do
  let(:user) { create :registered_user }

  subject { described_class }

  permissions :publish? do
    it "allows admins" do
      user.add_role :admin
      expect(subject).to permit user
    end

    it "disallows users that aren't logged in" do
      expect(subject).not_to permit nil
    end

    it "disallows non-admins" do
      expect(subject).not_to permit user
    end
  end

  permissions :unpublish? do
    it "allows admins" do
      user.add_role :admin
      expect(subject).to permit user
    end

    it "disallows users that aren't logged in" do
      expect(subject).not_to permit nil
    end

    it "disallows non-admins" do
      expect(subject).not_to permit user
    end
  end
end
