require "rails_helper"
require "capybara_helper"

RSpec.describe DiscordScheduleController, type: :feature do
  let(:user) { create(:admin_user) }
  let(:discord_server1) { create(:discord_server) }
  let(:discord_server2) { create(:discord_server) }
  let!(:discord_server1_channels) { [
    create(:discord_server_channel, discord_server: discord_server1),
    create(:discord_server_channel, discord_server: discord_server1),
  ] }
  let!(:discord_server2_channels) { [
    create(:discord_server_channel, discord_server: discord_server2),
    create(:discord_server_channel, discord_server: discord_server2),
  ] }


  before(:each) do
    VCR.configure do |c|
      c.ignore_localhost = true
      # Must ignore the Capybara host IFF we are running tests that have browser AJAX requests to that host.
      c.ignore_hosts Capybara.server_host
    end

    visit cas_login_path
    fill_and_submit_login(user.email, user.password)
  end

  after(:each) do
    # Print JS console errors, just in case we need them.
    # From https://stackoverflow.com/a/36774327/12432170.
    errors = page.driver.browser.manage.logs.get(:browser)
    if errors.present?
      message = errors.map(&:message).join("\n")
      puts message
    end
  end

  describe "GET #new", js: true do
    let(:url) {
      new_discord_schedule_path
    }

    before(:each) do
      visit url
    end

    it 'starts with channel select disabled' do
      expect(page).to have_select('channel_id', disabled: true)
    end

    it 'loads relevant channels when server selected' do
      select discord_server1.name, from: 'server_id'
      expect(page).to have_select('channel_id',
        options: [''] + discord_server1_channels.map { |c| "##{c.name}" } + ['All cohort channels']
      )

      select discord_server2.name, from: 'server_id'
      expect(page).to have_select('channel_id',
        options: [''] + discord_server2_channels.map { |c| "##{c.name}" } + ['All cohort channels']
      )
    end

    it 'disables channel select when server reset to none' do
      select discord_server1.name, from: 'server_id'
      expect(page).to have_select('channel_id')
      select '', from: 'server_id'
      expect(page).to have_select('channel_id', disabled: true)
    end
  end
end
