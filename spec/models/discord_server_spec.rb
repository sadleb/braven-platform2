require 'rails_helper'

RSpec.describe DiscordServer, type: :model do
  it { should validate_presence_of :name }
  it { should validate_presence_of :discord_server_id }
  it { should validate_presence_of :webhook_id }
  it { should validate_presence_of :webhook_token }

  describe 'validating uniqueness' do
    before { create :discord_server }

    it { should validate_uniqueness_of(:name) }
    # Weird workaround for unique validations with numeric values, we have to
    # add `.case_insensitive` to the matcher.
    it { should validate_uniqueness_of(:discord_server_id).case_insensitive }
    it { should validate_uniqueness_of(:webhook_id).case_insensitive }
  end

  it { should validate_numericality_of(:discord_server_id) }
  it { should validate_numericality_of(:webhook_id) }

  describe '.webhook_url' do
    subject { discord_server.webhook_url }

    let(:discord_server) { create :discord_server }

    it 'combines base, id, token' do
      expect(subject).to eq(DiscordServer::WEBHOOK_URL_BASE + '/' +
                            discord_server.webhook_id + '/' +
                            discord_server.webhook_token)
    end

    context 'without webhook id' do
      let(:discord_server) { build :discord_server, webhook_id: nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'without webhook token' do
      let(:discord_server) { build :discord_server, webhook_token: nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end
  end

  describe '.server_url' do
    subject { discord_server.server_url }

    let(:discord_server) { create :discord_server }

    it 'combines base, id, token' do
      expect(subject).to eq(DiscordServer::SERVER_URL_BASE + '/' +
                            discord_server.discord_server_id)
    end

    context 'without server id' do
      let(:discord_server) { build :discord_server, discord_server_id: nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end
  end
end
