require 'rails_helper'
require 'zoom_api'

RSpec.describe ZoomAPI do

  WebMock.disable_net_connect!

  let(:zoom_client) { ZoomAPI.client }

  describe '#get_meeting_info' do
    let(:request_url_regex) { /#{ZoomAPI::BASE_URL}.*/ }

    context 'with whitespace in meeting_id' do
      it 'strips whitespace' do
        stub_request(:get, request_url_regex)

        zoom_client.get_meeting_info('555 555 5555')

        expect(WebMock).to have_requested(:get, "#{ZoomAPI::BASE_URL}/meetings/5555555555")
      end
    end
  end

  describe '#add_registrant' do
    let(:request_url_regex) { /#{ZoomAPI::BASE_URL}.*/ }

    context 'with whitespace in meeting_id' do
      it 'strips whitespace' do
        stub_request(:post, request_url_regex)

        zoom_client.add_registrant('555 555 6666', 'email@example.com', 'FirstName', 'LastName')

        expect(WebMock).to have_requested(:post, "#{ZoomAPI::BASE_URL}/meetings/5555556666/registrants")
      end
    end
  end

  describe '#cancel_registrants' do
    let(:request_url_regex) { /#{ZoomAPI::BASE_URL}.*/ }

    context 'with whitespace in meeting_id' do
      it 'strips whitespace' do
        stub_request(:put, request_url_regex)

        zoom_client.cancel_registrants('555 555 7777', ['email1@example.com', 'email2@example.com'])

        expect(WebMock).to have_requested(:put, "#{ZoomAPI::BASE_URL}/meetings/5555557777/registrants/status")
      end
    end
  end

  describe '#get_registrants' do
    let(:request_url_regex) { /#{ZoomAPI::BASE_URL}.*/ }

    context 'with whitespace in meeting_id' do
      it 'strips whitespace' do
        stub_request(:get, request_url_regex)

        zoom_client.get_registrants('555 555 8888')

        expect(WebMock).to have_requested(:get, "#{ZoomAPI::BASE_URL}/meetings/5555558888/registrants?page_size=300")
      end
    end
  end

end
