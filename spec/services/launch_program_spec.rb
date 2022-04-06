# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LaunchProgram do
  let(:fellow_course_name) { 'Test Fellow Course Name' }
  let(:fellow_source_course) { create(:course, is_launched: false, canvas_course_id: 67675) }
  let(:lc_source_course) { create(:course, is_launched: false, canvas_course_id: 87566) }
  let(:lc_course_name) { 'Test LC Course Name' }
  let(:cohort_schedule1) { build(:heroku_connect_cohort_schedule) }
  let(:cohort_schedules) { [cohort_schedule1] }
  let(:program) { build(:heroku_connect_program_unlaunched, cohort_schedules: cohort_schedules) }

  subject(:launch_program) do
    LaunchProgram.new(program.sfid, fellow_source_course.id, fellow_course_name, lc_source_course.id, lc_course_name)
  end

  describe '#initialize' do

    context 'with valid Program' do
      it "doesn't raise error" do
        allow(HerokuConnect::Program).to receive(:find).and_return(program)
        expect { launch_program }.not_to raise_error
      end
    end

    context 'with invalid Program' do
      it "raises error with bad Program ID" do
        expect { launch_program }.to raise_error(ActiveRecord::RecordNotFound)
      end

      let(:cohort_schedules) { [] }
      it "raises an error when missing Cohort Schedules" do
        allow(HerokuConnect::Program).to receive(:find).and_return(program)
        expect { launch_program }.to raise_error(LaunchProgram::LaunchProgramError).with_message(/No Cohort Schedules/)
      end
    end
  end

  describe '#run' do
    let(:new_fellow_canvas_course_id) { 782374 }
    let(:new_lc_canvas_course_id) { 893576 }
    let(:new_fellow_course) {
      newc = fellow_source_course.dup
      newc.name = fellow_course_name
      newc.canvas_course_id = new_fellow_canvas_course_id
      newc.save!
      newc
    }
    let(:new_lc_course) {
      newc = lc_source_course.dup
      newc.name = lc_course_name
      newc.canvas_course_id = new_lc_canvas_course_id
      newc.save!
      newc
    }
    let(:fellow_clone_course_service) { double(CloneCourse) }
    let(:lc_clone_course_service) { double(CloneCourse) }
    let(:canvas_client) { instance_double(CanvasAPI) }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:create_enrollment_term).and_return({'id' => 1234})
      allow(CloneCourse).to receive(:new)
        .with(fellow_source_course, fellow_course_name, program)
        .and_return(fellow_clone_course_service)
      allow(CloneCourse).to receive(:new)
        .with(lc_source_course, lc_course_name, program)
        .and_return(lc_clone_course_service)
      allow(HerokuConnect::Program).to receive(:find).with(program.sfid).and_return(program)
      allow(fellow_clone_course_service).to receive(:run).and_return(fellow_clone_course_service)
      allow(lc_clone_course_service).to receive(:run).and_return(lc_clone_course_service)
      allow(fellow_clone_course_service).to receive(:wait_and_initialize).and_return(new_fellow_course)
      allow(lc_clone_course_service).to receive(:wait_and_initialize).and_return(new_lc_course)
    end

    it 'creates an enrollment term for the Program' do
      expect(canvas_client).to receive(:create_enrollment_term).with(program.term_name, program.sis_term_id)
      launch_program.run
    end

    context "with Canvas clone success" do
      it "initilizes the new course" do
        expect(fellow_clone_course_service).to receive(:run).once
        expect(fellow_clone_course_service).to receive(:wait_and_initialize).once
        expect(lc_clone_course_service).to receive(:run).once
        expect(lc_clone_course_service).to receive(:wait_and_initialize).once
        launch_program.run
      end

      it "marks the courses as launched" do
        launch_program.run
        expect(new_fellow_course.is_launched).to eq(true)
        expect(new_lc_course.is_launched).to eq(true)
      end
    end

  end # '#run'

end
