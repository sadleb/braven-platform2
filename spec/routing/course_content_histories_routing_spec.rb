require "rails_helper"

RSpec.describe CourseContentHistoriesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(:get => "/course_content_histories").to route_to("course_content_histories#index")
    end

    it "routes to #new" do
      expect(:get => "/course_content_histories/new").to route_to("course_content_histories#new")
    end

    it "routes to #show" do
      expect(:get => "/course_content_histories/1").to route_to("course_content_histories#show", :id => "1")
    end

    it "routes to #edit" do
      expect(:get => "/course_content_histories/1/edit").to route_to("course_content_histories#edit", :id => "1")
    end


    it "routes to #create" do
      expect(:post => "/course_content_histories").to route_to("course_content_histories#create")
    end

    it "routes to #update via PUT" do
      expect(:put => "/course_content_histories/1").to route_to("course_content_histories#update", :id => "1")
    end

    it "routes to #update via PATCH" do
      expect(:patch => "/course_content_histories/1").to route_to("course_content_histories#update", :id => "1")
    end

    it "routes to #destroy" do
      expect(:delete => "/course_content_histories/1").to route_to("course_content_histories#destroy", :id => "1")
    end
  end
end
