# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncCanvasAssignmentOverrides do

  let(:service) { SyncCanvasAssignmentOverrides.new }
  # Default: no courses. Override in context below where appropriate.
  let(:accelerator_course_ids) { [] }
  let(:canvas_client) { double(CanvasAPI) }

  describe "#run" do
    subject { service.run }

    before :each do
      allow(HerokuConnect::Program)
        .to receive(:current_and_future_accelerator_canvas_course_ids)
        .and_return(accelerator_course_ids)
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    context "with no running programs" do
      it "exits early" do
        # Stub so we can check if it was called.
        allow(canvas_client).to receive(:get_assignment_overrides_for_course)

        subject

        expect(HerokuConnect::Program).to have_received(:current_and_future_accelerator_canvas_course_ids)
        expect(canvas_client).not_to have_received(:get_assignment_overrides_for_course)
      end
    end

    context "with some running programs" do
      let(:course) { create(:course) }
      let(:accelerator_course_ids) { [course.canvas_course_id] }
      let(:overrides_data) { [
        # One section-level override
        create(:canvas_assignment_override_section),
        # One student-level override with 2 students
        create(:canvas_assignment_override_user, student_ids: [1, 2]),
      ] }

      before :each do
        allow(canvas_client).to receive(:get_assignment_overrides_for_course).and_return(overrides_data)
      end

      it "syncs overrides" do
        subject

        # 1 section + 2 user = 3 rows
        expect(CanvasAssignmentOverride.count).to eq(3)
      end

      it "maintains uniqueness" do
        # Run the sync twice
        subject
        subject

        # 1 section + 2 user = 3 rows
        expect(CanvasAssignmentOverride.count).to eq(3)
      end
    end
  end
end
