require 'rails_helper'

RSpec.describe GradeUnsubmittedAssignmentsController, type: :controller do
  render_views

  context "with normal signin" do
    let(:user) { create :admin_user }
    let(:course) { create :course }
    let(:service) { instance_double(GradeUnsubmittedAssignments, run: nil) }

    before :each do
      sign_in user

      allow(GradeUnsubmittedAssignments).to receive(:new).and_return(service)
    end

    describe "POST #grade" do
      subject { post :grade, params: { course_id: course.id } }

      it "redirects to the course" do
        subject
        expect(response).to redirect_to(course)
      end

      it "calls the service" do
        subject
        expect(service).to have_received(:run)
      end
    end
  end
end
