require "rails_helper"

RSpec.describe CustomContentsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(:get => "/projects").to route_to("custom_contents#index", type: "Project")
    end

    it "routes to #new" do
      expect(:get => "/projects/new").to route_to("custom_contents#new", type: "Project")
    end

    it "routes to #show" do
      expect(:get => "/projects/1").to route_to("custom_contents#show", id: "1", type: "Project")
    end

    it "routes to #edit" do
      expect(:get => "/projects/1/edit").to route_to("custom_contents#edit", id: "1", type: "Project")
    end

    it "routes to #create" do
      expect(:post => "/projects").to route_to("custom_contents#create", type: "Project")
    end

    it "routes to #update via PUT" do
      expect(:put => "/projects/1").to route_to("custom_contents#update", id: "1", type: "Project")
    end

    it "routes to #update via PATCH" do
      expect(:patch => "/projects/1").to route_to("custom_contents#update", id: "1", type: "Project")
    end

    it "routes to #destroy" do
      expect(:delete => "/projects/1").to route_to("custom_contents#destroy", id: "1", type: "Project")
    end
  end
end
