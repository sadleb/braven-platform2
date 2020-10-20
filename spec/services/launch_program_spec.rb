# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LaunchProgram do
  describe '#run' do
    let(:sf_program_id) { 'TestSalesforceProgramID' }
    let(:fellow_course_name) { 'Test Fellow Course Name' }
    let(:fellow_course_template) { create(:course_template, attributes_for(:course_template_with_resource)) }
    let(:lc_course_template) { create(:course_template_with_canvas_id) }
    let(:lc_course_name) { 'Test LC Course Name' }
    let(:canvas_create_course) { build(:canvas_course) }
    let(:canvas_copy_course) { build(:canvas_content_migration) }
    let(:canvas_client) { double('CanvasAPI', create_course: canvas_create_course, copy_course: canvas_copy_course) }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    subject(:launch_program) do
      LaunchProgram.new(sf_program_id, fellow_course_template.id, fellow_course_name, lc_course_template.id, lc_course_name).run
    end

    context "with canvas API success" do
      it "calls canvas API to copy both fellow and LC courses" do
        expect(canvas_client).to receive(:create_course).with(fellow_course_name).once
        expect(canvas_client).to receive(:create_course).with(lc_course_name).once
        expect(canvas_client).to receive(:copy_course).with(fellow_course_template.canvas_course_id, canvas_create_course['id']).once
        expect(canvas_client).to receive(:copy_course).with(lc_course_template.canvas_course_id, canvas_create_course['id']).once
        launch_program
      end

      it "creates new platform courses" do
        expect { launch_program }.to change(Course, :count).by(2)
        fellow_course = Course.find_by(name: fellow_course_name)
        expect(fellow_course.canvas_course_id).to eq canvas_create_course['id']
        expect(fellow_course.course_resource_id).to eq fellow_course_template.course_resource_id
        lc_course = Course.find_by(name: lc_course_name)
        expect(lc_course.canvas_course_id).to eq canvas_create_course['id']
        expect(lc_course.course_resource_id).to eq lc_course_template.course_resource_id
      end
    end

    context "with canvas API failure" do
      it "raises an exception" do
        allow(canvas_client).to receive(:copy_course).and_raise(RestClient::NotFound)
        expect { launch_program }.to raise_error(RestClient::NotFound)
      end
    end
  end

end
