require 'rails_helper'

RSpec.describe DiscordServerChannel, type: :model do
  it { should validate_presence_of :name }
  it { should validate_presence_of :discord_channel_id }
  it { should validate_presence_of :position }
  it { should validate_presence_of :discord_server_id }

  describe 'validating uniqueness' do
    before { create :discord_server_channel }

    it { should validate_uniqueness_of(:name).scoped_to(:discord_server_id) }
    # Weird workaround for unique validations with numeric values, we have to
    # add `.case_insensitive` to the matcher.
    it { should validate_uniqueness_of(:discord_channel_id).case_insensitive }
  end

  it { should validate_numericality_of(:discord_channel_id) }
end
