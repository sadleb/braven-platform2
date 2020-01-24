require 'rails_helper'

RSpec.describe "CourseContentAnswers", type: :request do
  describe "GET /course_content_answers" do
    it "works! (now write some real specs)" do
      get course_content_answers_path
      expect(response).to have_http_status(200)
    end
  end
end
