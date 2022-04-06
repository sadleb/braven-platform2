# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateSection do

  describe '#run' do
    let(:canvas_client) { instance_double(CanvasAPI) }
    let(:canvas_section) { create :canvas_section, name: section.name }
    let(:course) { create :course_launched }

    # Set this in each test
    let(:section) { nil }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    subject(:run_service) do
      CreateSection.new(course, section.name, section.section_type, section.salesforce_id).run
    end

    shared_examples 'creates the local and Canvas section' do
      before(:each) do
        allow(canvas_client).to receive(:create_section).and_return(canvas_section)
      end

      it 'creates the local section' do
        expect{run_service}.to change(Section, :count).by(1)
        created_section = Section.find_by(salesforce_id: section.salesforce_id)
        expect(created_section.name).to eq(section.name)
        expect(created_section.section_type).to eq(section.section_type)
        expect(created_section.canvas_section_id).to eq(canvas_section['id'])
      end

      it 'creates the Canvas section' do
        expect(canvas_client).to receive(:create_section) do |canvas_course_id, section_name, section_sis_id|
          expect(canvas_course_id).to eq(course.canvas_course_id)
          expect(section_name).to eq(section.name)
          expect(section_sis_id).to eq(section.sis_id)
          canvas_section
        end
        run_service
      end
    end

    shared_examples 'on Canvas error' do
      before(:each) do
        allow(canvas_client).to receive(:create_section).and_raise(RestClient::BadRequest)
      end

      it 'rolls back the local Section' do
        expect{run_service}
          .to raise_error(RestClient::BadRequest)
          .and avoid_changing(Section, :count)
      end
    end

    context 'for Cohort section' do
      let(:section) { build :cohort_section, course: course }
      it_behaves_like 'creates the local and Canvas section'
      it_behaves_like 'on Canvas error'

      context 'when no salesforce_id is provided' do
        let(:section) { build :cohort_section, course: course, salesforce_id: nil }
        it 'raises an error' do
          expect{run_service}.to raise_error(ArgumentError)
        end
      end
    end

    context 'for Cohort Schedule section' do
      let(:section) { build :cohort_schedule_section, course: course }
      it_behaves_like 'creates the local and Canvas section'
      it_behaves_like 'on Canvas error'

      context 'when no salesforce_id is provided' do
        let(:section) { build :cohort_schedule_section, course: course, salesforce_id: nil }
        it 'raises an error' do
          expect{run_service}.to raise_error(ArgumentError)
        end
      end
    end

    context 'for Teaching Assistants section' do
      let(:section) { build :ta_section, course: course }
      it_behaves_like 'creates the local and Canvas section'
      it_behaves_like 'on Canvas error'

      context 'when no salesforce_id is provided' do
        let(:section) { build :ta_section, course: course, salesforce_id: nil }
        it 'works' do
          allow(canvas_client).to receive(:create_section).and_return(canvas_section)
          expect{run_service}.not_to raise_error
        end
      end
    end

    context 'for TA Caseload section' do
      let(:section) { build :ta_caseload_section, course: course }
      it_behaves_like 'creates the local and Canvas section'
      it_behaves_like 'on Canvas error'

      context 'when no salesforce_id is provided' do
        let(:section) { build :ta_caseload_section, course: course, salesforce_id: nil }
        it 'raises an error' do
          expect{run_service}.to raise_error(ArgumentError)
        end
      end
    end


  end # '#run'

end

