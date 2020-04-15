require 'rails_helper'
require 'canvas_api'

RSpec.describe CanvasAPI do

  CANVAS_URL = "http://canvas.example.com".freeze
  CANVAS_API_URL = "#{CANVAS_URL}/api/v1".freeze

  WebMock.disable_net_connect!

  let(:canvas) { CanvasAPI.new(CANVAS_URL, 'test-token') }

  it 'correctly sets authorization header' do
    stub_request(:any, /#{CANVAS_API_URL}.*/)

    canvas.get('/test')

    expect(WebMock).to have_requested(:get, "#{CANVAS_API_URL}/test")
      .with(headers: {'Authorization'=>'Bearer test-token'}).once
  end

  describe 'Content Editor' do
    it 'updates course wiki page' do
      stub_request(:put, "#{CANVAS_API_URL}/courses/1/pages/test")

      canvas.update_course_page(1, 'test', 'test-body')

      expect(WebMock).to have_requested(:put, "#{CANVAS_API_URL}/courses/1/pages/test").
        with(body: 'wiki_page%5Bbody%5D=%0A++++%3C%21--+BRAVEN_NEW_HTML+--%3E%0A++++%3Cdiv+class%3D%22bz-module%22%3E%0A++test-body%0A++++%3C%2Fdiv%3E%0A++').once
    end
  end

  describe 'Sync To LMS' do
    let(:first_name) { 'TestFirstName' }
    let(:last_name) { 'TestLastName' }
    let(:username) { 'testusername' }
    let(:email) { 'test+email@bebraven.org' }
    let(:salesforce_id) { 'a2b17000000ijNRAAY' }
    let(:student_id) { '123456' }
    let(:timezone) { 'America/Los_Angeles' }
    let(:docusign_template_id) { 'abcdedfghijklmnop' }
    let(:course_id) { 71 }
    let(:user_id) { 100 }
    let(:canvas_role) { :StudentEnrollment }
    let(:section_id) { 50 }

    it 'creates a new user' do
      request_url = "#{CANVAS_API_URL}/accounts/1/users"
      stub_request(:post, request_url).to_return( body: FactoryBot.json(:canvas_user) )

      canvas.create_user(first_name, last_name, username, email, salesforce_id, student_id, timezone, docusign_template_id)

      expect(WebMock).to have_requested(:post, request_url)
        .with(body: "user%5Bshort_name%5D=#{first_name}&user%5Bsortable_name%5D=#{last_name}%2C+#{first_name}&user%5Bskip_registration%5D=true&user%5Btime_zone%5D=America%2FLos_Angeles&user%5Bdocusign_template_id%5D=#{docusign_template_id}&pseudonym%5Bunique_id%5D=#{username}&pseudonym%5Bsend_confirmation%5D=false&communication_channel%5Btype%5D=email&communication_channel%5Baddress%5D=test%2Bemail%40bebraven.org&communication_channel%5Bskip_confirmation%5D=true&communication_channel%5Bconfirmation_url%5D=true&pseudonym%5Bsis_user_id%5D=BVSFID#{salesforce_id}-SISID#{student_id}").once
    end

    it 'finds an existing user' do
      request_url = "#{CANVAS_API_URL}/accounts/1/users?search_term=#{CGI.escape(email)}"
      response_user = FactoryBot.json(:canvas_user)
      response_json = "[#{response_user}]"
      stub_request(:get, request_url).to_return( body: response_json ) 

      response = canvas.find_user_in_canvas(email)

      expect(WebMock).to have_requested(:get, request_url)
        .with(headers: {'Authorization'=>'Bearer test-token'}).once
      expect(response).to eq(JSON.parse(response_user))
    end

    it 'enrolls user in course / section' do
      request_url = "#{CANVAS_API_URL}/courses/#{course_id}/enrollments"
      stub_request(:post, request_url).to_return( body: FactoryBot.json(:canvas_enrollment_student) )

      canvas.enroll_user_in_course(user_id, course_id, canvas_role, section_id)

      expect(WebMock).to have_requested(:post, request_url)
        .with(body: 'enrollment%5Buser_id%5D=100&enrollment%5Btype%5D=StudentEnrollment&enrollment%5Benrollment_state%5D=active&enrollment%5Blimit_privileges_to_course_section%5D=true&enrollment%5Bnotify%5D=false&enrollment%5Bcourse_section_id%5D=50').once   
    end

    xit 'fetches paginated responses' do
      # TODO: implement test of canvas.get_all_from_pagination(response)
    end

  end

end
