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
      with(body: 'wiki_page%5Bbody%5D=%0A++++%3C%21--+BRAVEN_NEW_HTML+--%3E%0A++test-body').once
  end
end
