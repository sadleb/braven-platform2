# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateJoinUsers do
  describe '#run' do
    let(:dummy_user) { instance_double('User', email: nil, first_name: nil, last_name: nil, join_user_id: 1, update!: nil) }
    let(:dummy_join_user) { double('JoinUser', email: nil, id: nil) }

    let(:join_api_client) { instance_double('JoinAPI', find_user_by: nil, create_user: nil) }

    before do
      allow(JoinAPI).to receive(:client).and_return(join_api_client)
      allow(User).to receive(:where).and_return([dummy_user])
    end

    it 'only bother about users without join user id' do
      allow(User).to receive(:where).and_return([])

      described_class.new.run

      expect(join_api_client).not_to have_received(:find_user_by)
    end

    it 'finds a user if the user already exist' do
      allow(join_api_client).to receive(:find_user_by).and_return(dummy_join_user)

      described_class.new.run

      expect(join_api_client).to have_received(:find_user_by)
    end

    it 'create a new user if the user does not exist' do
      allow(join_api_client).to receive(:create_user).and_return(dummy_join_user)

      described_class.new.run

      expect(join_api_client).to have_received(:create_user)
    end

    it 'updates join user id for the user' do
      allow(join_api_client).to receive(:create_user).and_return(dummy_join_user)

      described_class.new.run

      expect(dummy_user).to have_received(:update!)
    end
  end
end
