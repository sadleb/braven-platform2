require 'rails_helper'
require 'canvas_api'

RSpec.describe CanvasAPI do

  CANVAS_URL = "http://canvas.example.com".freeze

  WebMock.disable_net_connect!

  it 'correctly sets authorization header' do
    stub_request(:any, /#{CANVAS_URL}.*/).
      with(headers: {'Authorization'=>'Bearer test-token'})

    canvas = CanvasAPI.new(CANVAS_URL, 'test-token')
    canvas.get('/test')

    expect(WebMock).to have_requested(:get, "#{CANVAS_URL}/api/v1/test").once
  end

  it 'updates course wiki page' do
    stub_request(:put, "#{CANVAS_URL}/api/v1/courses/1/pages/test")

    canvas = CanvasAPI.new(CANVAS_URL, 'test-token')
    canvas.update_course_page(1, 'test', 'test-body')

    expect(WebMock).to have_requested(:put, "#{CANVAS_URL}/api/v1/courses/1/pages/test").
      with(body: 'wiki_page%5Bbody%5D=%0A++++%3C%21--+BRAVEN_NEW_HTML+--%3E%0A++++%3Cdiv+class%3D%22bz-module%22%3E%0A++test-body%0A++++%3C%2Fdiv%3E%0A++').once
  end

  xit 'creates a new user' do
    # TODO: test the sync to lms method to create a new user
  end

  xit 'updates an existing' do
    # TODO: test the sync to lms method to update an existing user works (e.g. change their section or course enrollment
  end

  it 'finds an existing user' do
    #  TODO: test that the right api call happens
  end

  # TODO: add examples of the other calls I added to the API for the Sync To LMS project

end
