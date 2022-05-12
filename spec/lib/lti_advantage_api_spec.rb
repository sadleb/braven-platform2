require 'rails_helper'
require 'lti_advantage_api'
require 'lti_score'
require 'lti_result'

RSpec.describe LtiAdvantageAPI do
  let(:canvas_cloud_url) { Rails.application.secrets.canvas_url }
  let(:access_token) { FactoryBot.json(:lti_advantage_access_token) }
  let(:access_token_value) { JSON.parse(access_token)['access_token'] }
  let(:assignment_lti_launch) { create(:lti_launch_assignment) }
  subject(:api) { LtiAdvantageAPI.new(assignment_lti_launch) }

  before(:each) do
    stub_request(:post, LtiAdvantageAPI::OAUTH_ACCESS_TOKEN_URL).to_return(body: access_token)
  end

  describe '#initialize' do

    it 'gets an access token' do
      LtiAdvantageAPI.new(assignment_lti_launch)
      expect(WebMock).to have_requested(:post, LtiAdvantageAPI::OAUTH_ACCESS_TOKEN_URL)
        .with { |req|
        body = JSON.parse(req.body)
        body['grant_type'] == 'client_credentials' && \
        body['client_assertion_type'] == 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer' && \
        # These come from the launch request message
        body['scope'] == 'https://purl.imsglobal.org/spec/lti-ags/scope/lineitem https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly https://purl.imsglobal.org/spec/lti-ags/scope/score'
      }.once
    end

    it 'sets the authorization header' do
      stub_request(:get, assignment_lti_launch.request_message.line_items_url).to_return(body: '{"fake" : "response"}')
      api.get_line_items()
      expect(WebMock).to have_requested(:get, assignment_lti_launch.request_message.line_items_url)
        .with(headers: {'Authorization'=>'Bearer ' + access_token_value}).once
    end

  end

  describe '#create_score' do

    it 'posts the request' do
      score_service_url = "#{assignment_lti_launch.request_message.line_item_url}/scores"
      stub_request(:post, score_service_url).to_return(body: '{"resultUrl":"https://platformdomain/api/lti/courses/55/line_items/15/results/1"}')
      # Note that Canvas's parsing is pretty good for the scores. Integers, floats, and strings all work.
      lti_score = LtiScore.generate('55',10.0,10.0, LtiScore::STARTED, LtiScore::FULLY_GRADED, 'some comments')
      api.create_score(lti_score)
      expect(WebMock).to have_requested(:post, score_service_url).with(body: lti_score)
    end

    # Note: the course seems to need to be published and the userId be for a student in the course.
    # Write tests for this if we run into this situation in the wild.

  end

  describe "#get_result" do
    let(:score_result) { build :lti_result }
    let(:canvas_user_id) { assignment_lti_launch.request_message.canvas_user_id }
    let(:result_service_url) { "#{assignment_lti_launch.request_message.line_item_url}/results?user_id=#{canvas_user_id}" }

    it "gets the previous submission" do
      stub_request(:get, result_service_url).to_return(body: [score_result].to_json )
      response = api.get_result()
      expect(WebMock).to have_requested(:get, result_service_url)
      expect(response).to eq(LtiResult.new(score_result))
    end

    it "returns LtiResult with #present? false if there is no submission" do
      stub_request(:get, result_service_url).to_return(body: [].to_json )
      response = api.get_result()
      expect(WebMock).to have_requested(:get, result_service_url)
      expect(response).to eq(LtiResult.new(nil))
      expect(response.present?).to eq(false)
    end
  end

  describe "#get_line_item_for_user" do
    it "gets the previous submission" do
      canvas_user_id = 1234;
      url = "#{assignment_lti_launch.request_message.line_item_url}/results?user_id=#{canvas_user_id}"
      stub_request(:get, url).to_return(body: '{}')
      api.get_line_item_for_user(canvas_user_id)
      expect(WebMock).to have_requested(:get, url)
    end
  end
end
