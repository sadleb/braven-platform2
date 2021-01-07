# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InitializeNewCourse do
  let(:new_course) { create :course_unlaunched }
  let(:section_names) { [ 'CohortSchedule 1', 'CohortSchedule 2' ] }
  let(:canvas_client) { double(CanvasAPI) }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:create_assignment_overrides)
    allow(canvas_client).to receive(:update_assignment_lti_launch_url)
    allow(canvas_client).to receive(:get_assignments).and_return([])
  end

  describe '#initialize' do
    subject(:initialize_new_course) do
      InitializeNewCourse.new(new_course, section_names)
    end

    shared_examples 'valid' do
      scenario 'does not raise error' do
        expect { initialize_new_course }.not_to raise_error
      end
    end

    context 'with sections' do
      it_behaves_like 'valid'
    end

    context 'without sections' do
      let(:section_names) { [] }
      it_behaves_like 'valid'
    end

    context 'without sections' do
      let(:section_names) { nil }
      it_behaves_like 'valid'
    end
  end

  describe '#run' do
    # Note: We're switching over to static endpoints for LTI launch URLs.
    # See TODO: # https://app.asana.com/0/1174274412967132/1199352155608256
    # We're intentionally not writing tests for InitializeNewCourse.run.
  end
end
