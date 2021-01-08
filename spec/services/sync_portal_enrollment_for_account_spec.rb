# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncPortalEnrollmentForAccount do
  let(:fellow_canvas_course_id) { 11 }
  let(:portal_user) { CanvasAPI::LMSUser.new }
  let(:sf_participant) { SalesforceAPI::SFParticipant.new('first', 'last', 'test1@example.com') }
  let(:sf_program) { SalesforceAPI::SFProgram.new(432, 'Some Program', 'Some School', fellow_canvas_course_id) }
  let(:lms_section) { CanvasAPI::LMSSection.new(10, "test section") }
  let(:lms_enrollment) { CanvasAPI::LMSEnrollment.new(55, fellow_canvas_course_id, RoleConstants::STUDENT_ENROLLMENT, lms_section.id) }
  let(:lms_assignments) { [
    create(:canvas_assignment, course_id: fellow_canvas_course_id),
    create(:canvas_assignment, course_id: fellow_canvas_course_id),
    create(:canvas_assignment, course_id: fellow_canvas_course_id),
  ] }
  let(:lms_overrides) { [
    create(:canvas_assignment_override_section, assignment_id: lms_assignments.first['id'], course_section_id: lms_section.id),
    create(:canvas_assignment_override_section, assignment_id: lms_assignments.first['id'], course_section_id: lms_section.id),
    create(:canvas_assignment_override_section, assignment_id: lms_assignments.last['id'], course_section_id: lms_section.id),
  ] }
  let(:lms_client) { double(
    'CanvasAPI',
    find_enrollment: lms_enrollment,
    find_section_by: lms_section,
    enroll_user_in_course: nil,
    create_lms_section: lms_section,
    delete_enrollment: nil,
    get_assignments: lms_assignments,
    get_assignment_overrides: lms_overrides,
    create_assignment_overrides: nil,
  ) }
  # Create local models, with the assumption that a user that exists on Canvas must already exist locally too.
  # This all falls apart if that assumption is untrue (the tests will pass, but the code won't work), so be careful
  # if anything changes in this code in the future.
  # Note: This reflects Highlander layout, not the fallback used for Booster/Prod
  # (https://app.asana.com/0/1174274412967132/1197893935338145/f)
  let!(:user) { create(:registered_user, email: sf_participant.email) }
  let!(:course) { create(:course, canvas_course_id: lms_enrollment.course_id) }
  let!(:section) { create(:section, course_id: course.id, canvas_section_id: lms_section.id, name: lms_section.name) }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(lms_client)
  end

  describe '#run' do
    context 'for enrolled fellow participant' do
      before(:each) do
        sf_participant.role = SalesforceAPI::FELLOW
        sf_participant.status = SalesforceAPI::ENROLLED
      end

      it 'creates a section if it does not exists' do
        allow(lms_client).to receive(:find_section_by).and_return(nil)

        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run
        expect(lms_client).to have_received(:create_lms_section)
      end

      it 'creates a default section if no section on salesforce' do
        allow(lms_client).to receive(:find_section_by).and_return(nil)

        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run
        expect(lms_client)
          .to have_received(:create_lms_section)
          .with(course_id: fellow_canvas_course_id, name: SyncPortalEnrollmentForAccount::DEFAULT_SECTION)
      end

      # Add tests for other sections when implemented

      it 'does not create a section if it exists' do
        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run

        expect(lms_client).not_to have_received(:create_lms_section)
      end

      it 'does not re-enroll the user' do
        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run

        expect(lms_client).not_to have_received(:enroll_user_in_course)
      end

      it 'de-enrols a user if section changes' do
        new_section = CanvasAPI::LMSSection.new(28374)
        allow(lms_client).to receive(:find_enrollment).and_return(lms_enrollment)
        allow(lms_client).to receive(:find_section_by).and_return(new_section)

        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run

        expect(lms_client).to have_received(:delete_enrollment).once
      end

      it 'reenrols the user if section changes' do
        new_section = CanvasAPI::LMSSection.new(97863)
        allow(lms_client).to receive(:find_enrollment).and_return(lms_enrollment)
        allow(lms_client).to receive(:find_section_by).and_return(new_section)

        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run

        expect(lms_client).to have_received(:enroll_user_in_course).once
      end

      it 'de-enrols a user if role changes' do
        new_enrollment = CanvasAPI::LMSEnrollment.new(82738732, lms_enrollment.course_id, RoleConstants::TA_ENROLLMENT, lms_section.id)
        allow(lms_client).to receive(:find_enrollment).and_return(new_enrollment)

        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run

        expect(lms_client).to have_received(:delete_enrollment).once
      end

      it 'reenrols the user if role changes' do
        new_enrollment = CanvasAPI::LMSEnrollment.new(928798237, lms_enrollment.course_id, RoleConstants::TA_ENROLLMENT, lms_section.id)
        allow(lms_client).to receive(:find_enrollment).and_return(new_enrollment)

        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run

        expect(lms_client).to have_received(:enroll_user_in_course).once
      end
    end

    context 'for dropped fellow participant' do
      before(:each) do
        sf_participant.role = SalesforceAPI::FELLOW
        sf_participant.status = SalesforceAPI::DROPPED
      end

      it 'it drops the user if user is enrolled' do
        allow(lms_client).to receive(:find_enrollment).and_return(lms_enrollment)

        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .run

        expect(lms_client).to have_received(:delete_enrollment).once
      end
    end
  end

  describe "#find_or_create_section" do
    context "when canvas section already exists" do
      it "does not create a Canvas section" do
        SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

        expect(lms_client).not_to have_received(:create_lms_section)
      end

      it "returns a local section" do
        local_section = SyncPortalEnrollmentForAccount
          .new(portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

        expect(local_section).to eq(section)
      end
    end

    context "when canvas section does not already exist" do
      before :each do
        allow(lms_client).to receive(:find_section_by).and_return(
          nil,  # first call
          lms_section,  # second call, looking for the cohort-schedule section
        )
      end

      context "when participant in cohort-schedule only" do
        before :each do
          sf_participant.cohort_schedule = lms_section.name
        end

        it "creates the Canvas section" do
          SyncPortalEnrollmentForAccount
            .new(portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

          expect(lms_client).to have_received(:create_lms_section)
        end

        it "does not do anything with overrides" do
          SyncPortalEnrollmentForAccount
            .new(portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

          expect(lms_client).not_to have_received(:get_assignments)
          expect(lms_client).not_to have_received(:get_assignment_overrides)
          expect(lms_client).not_to have_received(:create_assignment_overrides)
        end

        it "returns a local section" do
          local_section = SyncPortalEnrollmentForAccount
            .new(portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

          expect(local_section).to eq(section)
        end
      end

      context "when participant in cohort" do
        # lms_section should be the cohort-schedule section.
        let(:lms_section) { CanvasAPI::LMSSection.new(11, "test cohort-schedule section") }
        let(:lms_cohort_section) { CanvasAPI::LMSSection.new(10, "test cohort section") }
        let!(:section) { create(:section, course_id: course.id, canvas_section_id: lms_cohort_section.id, name: lms_cohort_section.name) }

        before :each do
          sf_participant.cohort_schedule = lms_section.name
          sf_participant.cohort = lms_cohort_section.name
          allow(lms_client).to receive(:create_lms_section).and_return(lms_cohort_section)
        end

        it "creates the Canvas section" do
          SyncPortalEnrollmentForAccount
            .new(portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)

          expect(lms_client).to have_received(:create_lms_section)
        end

        it "copies assignment overrides" do
          SyncPortalEnrollmentForAccount
            .new(portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)

          expect(lms_client).to have_received(:get_assignments)
          expect(lms_client).to have_received(:get_assignment_overrides).exactly(lms_assignments.count).times
          expect(lms_client).to have_received(:create_assignment_overrides).once
        end

        it "returns a local section" do
          local_section = SyncPortalEnrollmentForAccount
            .new(portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)

          expect(local_section).to eq(section)
        end
      end
    end

  end
end
