# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LaunchProgram do
  let(:sf_program_id) { 'TestSalesforceProgramID' }
  let(:fellow_course_name) { 'Test Fellow Course Name' }
  let(:fellow_source_course) { create(:course, is_launched: false, canvas_course_id: 67675) }
  let(:lc_source_course) { create(:course, is_launched: false, canvas_course_id: 87566) }
  let(:lc_course_name) { 'Test LC Course Name' }
  let(:salesforce_program) { build(:salesforce_program_record, program_id: sf_program_id) }
  let(:fellow_section_names) { [] }
  let(:sf_api_client) { SalesforceAPI.new }

  before(:each) do
    allow(sf_api_client).to receive(:get_program_info).and_return(salesforce_program)
    allow(sf_api_client).to receive(:get_cohort_schedule_section_names).and_return(fellow_section_names)
    allow(sf_api_client).to receive(:set_canvas_course_ids)
    allow(SalesforceAPI).to receive(:client).and_return(sf_api_client)
  end

  subject(:launch_program) do
    LaunchProgram.new(sf_program_id, fellow_source_course.id, fellow_course_name, lc_source_course.id, lc_course_name)
  end

  describe '#initialize' do

    context 'with valid Program' do
      let(:fellow_section_names) { [ 'Test CohortSchedule 1', 'Test CohortSchedule 2' ] }

      it "doesn't raise error" do
        expect { launch_program }.not_to raise_error
      end
    end
    
    context 'with invalid Program' do
      it "raises error with bad Program ID" do
        allow(sf_api_client).to receive(:get_program_info).and_raise RestClient::BadRequest
        expect { launch_program }.to raise_error(RestClient::BadRequest)
      end

      it "raises an error when missing Cohort Schedules" do
        expect { launch_program }.to raise_error(LaunchProgram::LaunchProgramError).with_message(/No Cohort Schedules/)
      end
    end
  end

  describe '#run' do
    let(:fellow_section_names) { [ 'Test CohortSchedule 1', 'Test CohortSchedule 2' ] }
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

    before(:each) do
      allow(CloneCourse).to receive(:new)
        .with(fellow_source_course, fellow_course_name, fellow_section_names, salesforce_program['Default_Timezone__c'])
        .and_return(fellow_clone_course_service)
      allow(CloneCourse).to receive(:new)
        .with(lc_source_course, lc_course_name, [SectionConstants::DEFAULT_SECTION], salesforce_program['Default_Timezone__c'])
        .and_return(lc_clone_course_service)
      allow(fellow_clone_course_service).to receive(:run).and_return(fellow_clone_course_service)
      allow(lc_clone_course_service).to receive(:run).and_return(lc_clone_course_service)
      allow(fellow_clone_course_service).to receive(:wait_and_initialize).and_return(new_fellow_course)
      allow(lc_clone_course_service).to receive(:wait_and_initialize).and_return(new_lc_course)
    end

    context "with Canvas clone success" do
      it "initilizes the new course" do
        expect(fellow_clone_course_service).to receive(:run).once
        expect(fellow_clone_course_service).to receive(:wait_and_initialize).once
        expect(lc_clone_course_service).to receive(:run).once
        expect(lc_clone_course_service).to receive(:wait_and_initialize).once
        launch_program.run
      end

      it "updates Salesforce" do
        expect(sf_api_client).to receive(:set_canvas_course_ids)
          .with(sf_program_id, new_fellow_canvas_course_id, new_lc_canvas_course_id).once
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
