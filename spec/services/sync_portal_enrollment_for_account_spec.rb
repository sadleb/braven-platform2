# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncPortalEnrollmentForAccount do
  let(:fellow_canvas_course_id) { 11 }
  let(:sf_email) { 'test1@example.com' }
  let(:sf_participant) { SalesforceAPI::SFParticipant.new('first', 'last', sf_email, nil, nil, 'test_salesforce_id') }
  # Arbitrary Canvas user ID
  let(:canvas_email) { sf_email }
  let(:portal_user) { CanvasAPI::LMSUser.new(10, canvas_email) }
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
  let(:matching_lms_course_overrides) { [
    create(:canvas_assignment_override_user, assignment_id: lms_assignments.first['id'], student_ids: [portal_user.id]),
    create(:canvas_assignment_override_user, assignment_id: lms_assignments.last['id'], student_ids: [portal_user.id]),
  ] }
  let(:lms_course_overrides) { [
    matching_lms_course_overrides,
    create(:canvas_assignment_override_section, assignment_id: lms_assignments.first['id'], course_section_id: lms_section.id),
  ].flatten }
  let(:lms_client) { double(
    CanvasAPI,
    find_enrollment: lms_enrollment,
    find_section_by: lms_section,
    enroll_user_in_course: nil,
    create_lms_section: lms_section,
    delete_enrollment: nil,
    get_assignments: lms_assignments,
    get_assignment_overrides: lms_overrides,
    get_assignment_overrides_for_course: lms_course_overrides,
    create_assignment_overrides: nil,
  ) }
  let(:sync_from_salesforce_service) { double(SyncFromSalesforceContact) }
  # Create local models, with the assumption that a user that exists on Canvas must already exist locally too.
  # This all falls apart if that assumption is untrue (the tests will pass, but the code won't work), so be careful
  # if anything changes in this code in the future.
  # Note: This reflects Highlander layout, not the fallback used for Booster/Prod
  # (https://app.asana.com/0/1174274412967132/1197893935338145/f)
  let(:platform_email) { sf_email }
  let!(:user) { create(:registered_user, email: platform_email, salesforce_id: sf_participant.contact_id, canvas_user_id: portal_user.id) }
  let!(:course) { create(:course, canvas_course_id: lms_enrollment.course_id) }
  let!(:section) { create(:section, course_id: course.id, canvas_section_id: lms_section.id, name: lms_section.name) }

  before(:each) do
    allow(SyncFromSalesforceContact).to receive(:new).and_return(sync_from_salesforce_service)
    allow(CanvasAPI).to receive(:client).and_return(lms_client)
  end

  subject(:run_sync) do
    SyncPortalEnrollmentForAccount
      .new(user: user,
           portal_user: portal_user,
           salesforce_participant: sf_participant,
           salesforce_program: sf_program
       ).run
  end

  describe '#run' do
# TODO: need to write specs in follow-up PR. Fix this failing spec as part of that.
#    context 'for enrolled teaching assistant' do
#      before(:each) do
#        sf_participant.role = SalesforceAPI::TEACHING_ASSISTANT
#        sf_participant.status = SalesforceAPI::ENROLLED
#      end
#
#      it 'enrolls with limit removed' do
#        # because TAs need access to all users, not just users in their section.
#        run_sync
#        expect(lms_client).to have_received(:enroll_user_in_course).with(
#            portal_user.id, fellow_canvas_course_id, RoleConstants::TA_ENROLLMENT, lms_section.id, false
#        )
#      end
#    end

    context 'for enrolled fellow participant' do
      before(:each) do
        sf_participant.role = SalesforceAPI::FELLOW
        sf_participant.status = SalesforceAPI::ENROLLED
      end

      it 'creates a section if it does not exists' do
        allow(lms_client).to receive(:find_section_by).and_return(nil)
        run_sync
        expect(lms_client).to have_received(:create_lms_section)
      end


      it 'creates a default section if no section on salesforce' do
        allow(lms_client).to receive(:find_section_by).and_return(nil)
        run_sync
        expect(lms_client)
          .to have_received(:create_lms_section)
          .with(course_id: fellow_canvas_course_id, name: SectionConstants::DEFAULT_SECTION)
      end

      # Add tests for other sections when implemented

      it 'does not create a section if it exists' do
        run_sync
        expect(lms_client).not_to have_received(:create_lms_section)
      end

      it 'does not re-enroll the user' do
        run_sync
        expect(lms_client).not_to have_received(:enroll_user_in_course)
      end

      it 'de-enrols a user if section changes' do
        new_section = CanvasAPI::LMSSection.new(28374)
        allow(lms_client).to receive(:find_enrollment).and_return(lms_enrollment)
        allow(lms_client).to receive(:find_section_by).and_return(new_section)
        run_sync
        expect(lms_client).to have_received(:delete_enrollment).once
      end

      it 'reenrols the user if section changes' do
        new_section = CanvasAPI::LMSSection.new(97863)
        allow(lms_client).to receive(:find_enrollment).and_return(lms_enrollment)
        allow(lms_client).to receive(:find_section_by).and_return(new_section)
        run_sync
        expect(lms_client).to have_received(:enroll_user_in_course).once
      end

      it 're-creates assignment overrides if section changes' do
        new_section = CanvasAPI::LMSSection.new(97863)
        allow(lms_client).to receive(:find_enrollment).and_return(lms_enrollment)
        allow(lms_client).to receive(:find_section_by).and_return(new_section)

        run_sync

        # Note: the id was deleted from the overrides, their hashes modified in-place.
        expect(lms_client).to have_received(:create_assignment_overrides)
          .once
          .with(course.canvas_course_id, matching_lms_course_overrides)
      end


      it 'de-enrols a user if role changes' do
        new_enrollment = CanvasAPI::LMSEnrollment.new(82738732, lms_enrollment.course_id, RoleConstants::TA_ENROLLMENT, lms_section.id)
        allow(lms_client).to receive(:find_enrollment).and_return(new_enrollment)
        run_sync
        expect(lms_client).to have_received(:delete_enrollment).once
      end

      it 'reenrols the user if role changes' do
        new_enrollment = CanvasAPI::LMSEnrollment.new(928798237, lms_enrollment.course_id, RoleConstants::TA_ENROLLMENT, lms_section.id)
        allow(lms_client).to receive(:find_enrollment).and_return(new_enrollment)
        run_sync
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
        run_sync
        expect(lms_client).to have_received(:delete_enrollment).once
      end
    end

    context 'when Platform email doesnt match Salesforce email' do
      let(:sf_email) { 'salesforce.email.no.match@example.com' }
      let(:platform_email) { 'platform.email.no.match@example.com' }

      it 'calls SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).to receive(:run!).once
        run_sync
      end
    end

    context 'when Platform email matches Salesforce email exactly' do
      let(:sf_email) { 'exact_match@example.com' }
      let(:platform_email) { 'exact_match@example.com' }

      it 'doesnt call SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).not_to receive(:run!)
        run_sync
      end
    end

    context 'when Platform email matches Salesforce email case-insensitively' do
      let(:sf_email) { 'caseInsensitiveMatch@example.com' }
      let(:platform_email) { 'caseinsensitivematch@example.com' }

      it 'doesnt call SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).not_to receive(:run!)
        run_sync
      end
    end

    context 'when Canvas email doesnt match Salesforce email' do
      let(:sf_email) { 'salesforce.email.no.match@example.com' }
      let(:canvas_email) { 'canvas.email.no.match@example.com' }

      it 'calls SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).to receive(:run!).once
        run_sync
      end
    end

    context 'when Canvas email matches Salesforce email exactly' do
      let(:sf_email) { 'exact_match@example.com' }
      let(:canvas_email) { 'exact_match@example.com' }

      it 'doesnt call SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).not_to receive(:run!)
        run_sync
      end
    end

    context 'when Canvas email matches Salesforce email case-insensitively' do
      let(:sf_email) { 'caseInsensitiveMatch@example.com' }
      let(:canvas_email) { 'caseinsensitivematch@example.com' }

      it 'doesnt call SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).not_to receive(:run!)
        run_sync
      end
    end

    context 'when Canvas email doesnt match Platform email' do
      let(:platform_email) { 'platform.email.no.match@example.com' }
      let(:canvas_email) { 'canvas.email.no.match@example.com' }

      it 'calls SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).to receive(:run!).once
        run_sync
      end
    end

    context 'when Canvas email matches Platform email exactly' do
      let(:platform_email) { sf_email }
      let(:canvas_email) { sf_email }

      it 'doesnt call SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).not_to receive(:run!)
        run_sync
      end
    end

    context 'when Canvas email matches Platform email case-insensitively' do
      let(:sf_email) { 'SFEmail@example.com' }
      let(:platform_email) { sf_email }
      let(:canvas_email) { 'sfemail@example.com' }

      it 'doesnt call SyncFromSalesforceContact service' do
        expect(sync_from_salesforce_service).not_to receive(:run!)
        run_sync
      end
    end
  end

  describe "#find_or_create_section" do
    context "when canvas section already exists" do
      it "does not create a Canvas section" do
        SyncPortalEnrollmentForAccount
          .new(user: user,
               portal_user: portal_user,
               salesforce_participant: sf_participant,
               salesforce_program: sf_program)
          .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

        expect(lms_client).not_to have_received(:create_lms_section)
      end

      it "returns a local section" do
        local_section = SyncPortalEnrollmentForAccount
          .new(user: user,
               portal_user: portal_user,
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
            .new(user: user,
                 portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

          expect(lms_client).to have_received(:create_lms_section)
        end

        it "does not do anything with overrides" do
          SyncPortalEnrollmentForAccount
            .new(user: user,
                 portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_section.name)

          expect(lms_client).not_to have_received(:get_assignments)
          expect(lms_client).not_to have_received(:get_assignment_overrides)
          expect(lms_client).not_to have_received(:create_assignment_overrides)
        end

        it "returns a local section" do
          local_section = SyncPortalEnrollmentForAccount
            .new(user: user,
                portal_user: portal_user,
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
            .new(user: user,
                 portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)

          expect(lms_client).to have_received(:create_lms_section)
        end

        it "copies assignment overrides" do
          SyncPortalEnrollmentForAccount
            .new(user: user,
                portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)

          expect(lms_client).to have_received(:get_assignments)
          expect(lms_client).to have_received(:get_assignment_overrides).exactly(lms_assignments.count).times
          expect(lms_client).to have_received(:create_assignment_overrides).once
        end

        it "returns a local section" do
          local_section = SyncPortalEnrollmentForAccount
            .new(user: user,
                portal_user: portal_user,
                salesforce_participant: sf_participant,
                salesforce_program: sf_program)
            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)

          expect(local_section).to eq(section)
        end
      end
    end

  end
end
