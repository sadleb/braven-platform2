require 'rails_helper'
require 'lrs_launch_config'

RSpec.describe LrsLaunchConfig do

  describe '#to_query' do

    it 'creates the query with no activity_id or registration' do
      llc = LrsLaunchConfig.new('Some Name', 'someemail@example.com')
      expect(llc.to_query).to eq('endpoint=https://example.lrs.com/path/to/xapi&auth=Basic%20some_basic_auth_token_for_lrs_xapi_statements&actor=%7B%22name%22%3A%5B%22Some%20Name%22%5D%2C%20%22mbox%22%3A%5B%22mailto%3Asomeemail%40example.com%22%5D%7D')
    end

    it 'creates the query with activity_id and registration' do
      llc = LrsLaunchConfig.new('Some Name', 'someemail@example.com', 'some_activity_id', 'some_registration')
puts llc.to_query
      expect(llc.to_query).to eq('endpoint=https://example.lrs.com/path/to/xapi&auth=Basic%20some_basic_auth_token_for_lrs_xapi_statements&actor=%7B%22name%22%3A%5B%22Some%20Name%22%5D%2C%20%22mbox%22%3A%5B%22mailto%3Asomeemail%40example.com%22%5D%7D&activity_id=some_activity_id&registration=some_registration')
    end

  end
end
