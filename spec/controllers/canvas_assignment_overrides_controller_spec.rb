require 'rails_helper'

RSpec.describe CanvasAssignmentOverridesController, type: :controller do
  render_views

  context "with normal signin" do
    let(:user) { create :admin_user }
    let(:course) { create :course }
    let(:section) { create :section, course: course }
    let(:from_course) { create :course }
    let(:from_section) { create :section, course: from_course }
    let(:override_hash) { create :canvas_assignment_override_section, course_section_id: from_section.canvas_section_id }
    let!(:override) { CanvasAssignmentOverride.create(CanvasAssignmentOverride.parse_attributes(override_hash, from_course.canvas_course_id).first) }
    let(:offset) { 3 }

    before :each do
      sign_in user
    end

    describe "GET #index" do
      subject { get :index, params: { course_id: from_course.id } }

      it "returns a success response" do
        subject
        expect(response).to be_successful
      end

      it "lists overrides" do
        subject
        expect(response.body).to match /Assignment Dates for #{from_course.name}/
        expect(response.body).to match /Section: #{from_section.name}/
      end
    end

    describe "GET #copy_from_course" do
      subject { get :copy_from_course, params: { course_id: course.id } }

      it "returns a success response" do
        subject
        expect(response).to be_successful
      end

      it "includes a form" do
        subject
        expect(response.body).to match /<form/
      end
    end

    describe "GET #preview" do
      subject { get :preview, params: {
        course_id: course.id,
        from_course: from_course.id,
        from_section: from_section.canvas_section_id,
        to_section: section.canvas_section_id,
        date_offset: offset,
      } }

      it "returns a success response" do
        subject
        expect(response).to be_successful
      end

      it "includes a form" do
        subject
        expect(response.body).to match /<form/
      end

      it "shows shifted overrides" do
        subject
        expect(response.body).to match /#{(override.due_at + offset.days).strftime("%a, %B %d, %Y")}/
      end
    end

    describe "POST #bulk_create" do
      subject { post :bulk_create, params: {
        course_id: course.id,
        from_course: from_course.id,
        from_section: from_section.canvas_section_id,
        to_section: section.canvas_section_id,
        date_offset: offset,
      } }

      let(:service) { instance_double(CopyCanvasAssignmentOverrides, run: nil) }
      
      before :each do
        allow(CopyCanvasAssignmentOverrides).to receive(:new).and_return(service)
      end

      it "redirects to copy_from_course" do
        expect(subject).to redirect_to copy_from_course_course_canvas_assignment_overrides_path(course: course)
      end

      it "runs the service" do
        expect(service).to receive(:run).once
        subject
      end
    end
  end
end
