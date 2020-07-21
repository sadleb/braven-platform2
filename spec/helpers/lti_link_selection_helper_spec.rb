require 'rails_helper'

RSpec.describe LtiLinkSelectionHelper, type: :helper do

  before(:all) do
    ENV['LRS_URL'] = 'https://example.lrs.com/data/xAPI'
    ENV['LRS_AUTH_TOKEN'] = 'IFDJ_EXAMPLE_TOKENoasdfj'
  end

  describe '#to_query' do
    let(:lrs_proxy_url) { 
      uri = URI(root_url)
      uri.path = '/data/xAPI'
      uri
    }

    it 'creates the query with no activity_id or registration' do
      query = helper.launch_query('Some Name', 'someemail@example.com')
      expect(query).to eq("endpoint=#{lrs_proxy_url}&actor=%7B%22name%22%3A%5B%22Some%20Name%22%5D%2C%20%22mbox%22%3A%5B%22mailto%3Asomeemail%40example.com%22%5D%7D")
    end

    it 'creates the query with activity_id and registration' do
      query = helper.launch_query('Some Name', 'someemail@example.com', 'some_activity_id', 'some_registration')
      expect(query).to eq("endpoint=#{lrs_proxy_url}&actor=%7B%22name%22%3A%5B%22Some%20Name%22%5D%2C%20%22mbox%22%3A%5B%22mailto%3Asomeemail%40example.com%22%5D%7D&activity_id=some_activity_id&registration=some_registration")
    end

  end
end
