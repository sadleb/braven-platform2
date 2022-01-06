require 'rails_helper'

RSpec.describe DiscordScheduleHelper, type: :helper do
  describe ".render_discord_message" do
    let(:role1) { create(:discord_server_role) }
    let(:role2) { create(:discord_server_role) }
    let(:message) { "test <@&#{role1.discord_role_id}> <@&#{role2.discord_role_id}> <@&0> test" }

    it "replaces <@&ROLE_ID> with @ROLE_NAME" do
      expect(helper.render_discord_message(message)).to eq("test @#{role1.name} @#{role2.name} <@&0> test")
    end
  end
end
