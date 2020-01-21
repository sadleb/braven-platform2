require "rails_helper"

RSpec.describe CourseContentUndosController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(:get => "/course_content_undos").to route_to("course_content_undos#index")
    end

    it "routes to #new" do
      expect(:get => "/course_content_undos/new").to route_to("course_content_undos#new")
    end

    it "routes to #show" do
      expect(:get => "/course_content_undos/1").to route_to("course_content_undos#show", :id => "1")
    end

    it "routes to #edit" do
      expect(:get => "/course_content_undos/1/edit").to route_to("course_content_undos#edit", :id => "1")
    end


    it "routes to #create" do
      expect(:post => "/course_content_undos").to route_to("course_content_undos#create")
    end

    it "routes to #update via PUT" do
      expect(:put => "/course_content_undos/1").to route_to("course_content_undos#update", :id => "1")
    end

    it "routes to #update via PATCH" do
      expect(:patch => "/course_content_undos/1").to route_to("course_content_undos#update", :id => "1")
    end

    it "routes to #destroy" do
      expect(:delete => "/course_content_undos/1").to route_to("course_content_undos#destroy", :id => "1")
    end
  end
end
