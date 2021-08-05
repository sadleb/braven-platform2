# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncCanvasGrades do

  let(:service) { SyncCanvasGrades.new }
  let(:sf_client) { double(SalesforceAPI) }
  # Default: no courses. Override in context below where appropriate.
  let(:accelerator_course_ids) { [] }
  let(:canvas_client) { double(CanvasAPI) }

  describe "#run" do
    subject { service.run }

    before :each do
      allow(canvas_client).to receive(:get_account_rubrics_data).and_return([])
      allow(sf_client)
        .to receive(:get_current_and_future_accelerator_canvas_course_ids)
        .and_return(accelerator_course_ids)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    context "with no running programs" do
      it "exits early" do
        # Stub so we can check if it was called.
        allow(canvas_client).to receive(:get_submission_data)

        subject

        expect(sf_client).to have_received(:get_current_and_future_accelerator_canvas_course_ids)
        expect(canvas_client).not_to have_received(:get_submission_data)
      end
    end

    context "with some running programs" do
      let(:course) { create(:course) }
      let(:accelerator_course_ids) { [course.canvas_course_id] }
      let(:submission_data) { [create(:canvas_submission)] }
      let(:rubrics_data) { [create(:canvas_rubric)] }

      before :each do
        allow(canvas_client).to receive(:get_submission_data).and_return(submission_data)
        allow(canvas_client).to receive(:get_course_rubrics_data).and_return(rubrics_data)
        allow(canvas_client).to receive(:get_account_rubrics_data).and_return(rubrics_data)
      end

      it "syncs submissions and rubrics" do
        subject

        expect(CanvasSubmission.count).to eq(submission_data.length)
        expect(CanvasRubric.count).to eq(rubrics_data.length)
      end
    end
  end
end
