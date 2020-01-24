require "rails_helper"

RSpec.describe CourseContentAnswersController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(:get => "/course_content_answers").to route_to("course_content_answers#index")
    end

    it "routes to #show" do
      expect(:get => "/course_content_answers/1").to route_to("course_content_answers#show", :id => "1")
    end


    it "routes to #create" do
      expect(:post => "/course_content_answers").to route_to("course_content_answers#create")
    end

    it "routes to #update via PUT" do
      expect(:put => "/course_content_answers/1").to route_to("course_content_answers#update", :id => "1")
    end

    it "routes to #update via PATCH" do
      expect(:patch => "/course_content_answers/1").to route_to("course_content_answers#update", :id => "1")
    end

    it "routes to #destroy" do
      expect(:delete => "/course_content_answers/1").to route_to("course_content_answers#destroy", :id => "1")
    end
  end
end
