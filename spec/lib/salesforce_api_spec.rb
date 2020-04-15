require 'rails_helper'
require 'salesforce_api'

RSpec.describe SalesforceAPI do

  before(:all) do

    ENV['SALESFORCE_HOST'] = 'test.salesforce.com'
    ENV['SALESFORCE_PLATFORM_CONSUMER_KEY'] = 'testkey'
    ENV['SALESFORCE_PLATFORM_CONSUMER_SECRET'] = 'testsecret'
    ENV['SALESFORCE_PLATFORM_USERNAME'] = 'testuser@example.com'
    ENV['SALESFORCE_PLATFORM_PASSWORD'] = 'testpassword' 
    ENV['SALESFORCE_PLATFORM_SECURITY_TOKEN'] = 'testtoken'
    SALESFORCE_LOGIN_URL = "https://#{ENV['SALESFORCE_HOST']}"
    SALESFORCE_INSTANCE_URL = 'https://test--staging22.bebraven.org'  

    WebMock.disable_net_connect!
  end

  before(:each) do

    login_response = { 
      'instance_url' => SALESFORCE_INSTANCE_URL,
      'access_token' => 'test-token'
    }.to_json

    stub_request(:post, "#{SALESFORCE_LOGIN_URL}/services/oauth2/token").to_return(body: login_response )

  end

  describe 'authentication' do
    let(:salesforce) { SalesforceAPI.new() }

    it 'gets an access token' do
      salesforce
      expect(WebMock).to have_requested(:post, "#{SALESFORCE_LOGIN_URL}/services/oauth2/token")
        .with(body: 'grant_type=password&client_id=testkey&client_secret=testsecret&username=testuser%40example.com&password=testpasswordtesttoken').once
    end

    it 'correctly sets authorization header' do
      stub_request(:any, /#{SALESFORCE_INSTANCE_URL}.*/)

      salesforce.get('/test')

      expect(WebMock).to have_requested(:get, "#{SALESFORCE_INSTANCE_URL}/test")
        .with(headers: {'Authorization'=>'Bearer test-token'}).once
    end
    
  end

  describe 'sync_to_lms' do
    let(:salesforce) { SalesforceAPI.new() }
    let(:course_id) { 71 }

    it 'gets program info' do
      request_url_regex = /#{SALESFORCE_INSTANCE_URL}\/services\/data\/.*/
      program_json = FactoryBot.json(:salesforce_program)
      stub_request(:get, request_url_regex).to_return(body: program_json )

      response = salesforce.get_program_info(course_id)

      expect(WebMock).to have_requested(:get, request_url_regex).once
      # Note: I'm going to test the actual response contents in the controller spec since the API returns a hash
      # meant for use in constructing a program model.
    end

    it 'gets users to sync' do
      request_url = "#{SALESFORCE_INSTANCE_URL}/services/apexrest/participants/currentandfuture/?course_id=#{course_id}" 
      participant_json = "[#{FactoryBot.json(:salesforce_participant_fellow)}]"
      stub_request(:get, request_url).to_return(body: participant_json)

      response = salesforce.get_participants(course_id)

      expect(WebMock).to have_requested(:get, request_url).once
      expect(response).to eq(JSON.parse(participant_json))
    end
  end

end
