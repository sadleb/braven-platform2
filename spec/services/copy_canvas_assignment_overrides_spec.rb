# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CopyCanvasAssignmentOverrides do

  let(:course) { create(:course) }
  let(:section) { create(:cohort_schedule_section, course: course) }
  let(:from_section) { create(:cohort_schedule_section) }
  let(:user) { create(:fellow_user, section: section) }
  let(:override_hashes) { [
    create(:canvas_assignment_override_section, course_section_id: from_section.canvas_section_id),
    create(:canvas_assignment_override_section, course_section_id: from_section.canvas_section_id),
    create(:canvas_assignment_override_section, course_section_id: from_section.canvas_section_id),
  ] }
  let!(:overrides) {
    CanvasAssignmentOverride.create(
      override_hashes.map do |override_hash|
        CanvasAssignmentOverride.parse_attributes(override_hash, course.canvas_course_id)
      end.flatten
    )
  }
  let(:service) { CopyCanvasAssignmentOverrides.new(course, section, overrides) }
  let(:canvas_client) { instance_double(CanvasAPI) }
  let(:canvas_assignments) { [] }
  let(:created_override_hashes) { [] }

  describe "#run" do
    subject { service.run }

    before :each do
      allow(canvas_client).to receive(:get_assignments).and_return(canvas_assignments)
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    context "with no matching assignments" do
      it "raises exception" do
        expect {
          subject
        }.to raise_error(CopyCanvasAssignmentOverrides::NoTranslatedOverridesError)
      end
    end

    context "with matching assignments" do
      let(:canvas_assignments) {
        override_hashes.map do |override_hash|
          create(:canvas_assignment, name: override_hash['assignment_name'])
        end
      }
      let(:created_override_hashes) {
        overrides.map do |override|
          override_hash = override.to_canvas_hash
          override_hash['id'] = create(:canvas_assignment_override)['id']
          override_hash['course_section_id'] = section.canvas_section_id
          # Technically the assignment ID should match the assignment name, but
          # for the purposes of these tests it doesn't matter.
          override_hash['assignment_id'] = canvas_assignments.first['id']
          override_hash
        end
      }

      it "creates translated overrides" do
        expect(canvas_client).to receive(:create_assignment_overrides) do |canvas_course_id, translated_hashes|
          expect(canvas_course_id).to eq(course.canvas_course_id)
          # Check translated hashes excludes any section/assignment ids in override_hashes.
          translated_hashes.each do |translated_hash|
            expect(translated_hash[:assignment_id]).not_to eq(nil)
            override_hashes.each do |override_hash|
              expect(translated_hash[:assignment_id]).not_to eq(override_hash["assignment_id"])
            end
            expect(translated_hash[:course_section_id]).not_to eq(nil)
            expect(translated_hash[:course_section_id]).not_to eq(from_section.canvas_section_id)
          end

          created_override_hashes
        end

        expect {
          subject
        }.to change(CanvasAssignmentOverride, :count).by(overrides.count)

        created_override_hashes.each do |override_hash|
          expect(CanvasAssignmentOverride.find_by(canvas_assignment_override_id: override_hash['id'])).not_to eq(nil)
        end
      end
    end
  end
end
