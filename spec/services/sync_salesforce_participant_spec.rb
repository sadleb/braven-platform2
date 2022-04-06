# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceParticipant do
# TODO: reimplement specs after this refactoring: https://github.com/bebraven/platform/pull/922
# https://app.asana.com/0/1201131148207877/1201399664994348

# TODO: write specs for TA Caseload stuff
# https://app.asana.com/0/1201131148207877/1201348317908959

#  let(:fellow_canvas_course_id) { 11 }
#  let(:lc_playbook_canvas_course_id) { 12 }
#  let(:sf_email) { 'test1@example.com' }
#  let(:sf_participant) { SalesforceAPI::SFParticipant.new('first', 'last', sf_email, nil, nil, 'test_salesforce_id') }
#  # Arbitrary Canvas user ID
#  let(:canvas_email) { sf_email }
#  let(:portal_user) { CanvasAPI::LMSUser.new(10, canvas_email) }
#  let(:sf_program) { SalesforceAPI::SFProgram.new(432, 'Some Program', 'Some School', fellow_canvas_course_id, lc_playbook_canvas_course_id) }
#  let(:fellow_lms_section) { CanvasAPI::LMSSection.new(10, "test section") }
#  let(:fellow_lms_enrollment) { CanvasAPI::LMSEnrollment.new(55, fellow_canvas_course_id, RoleConstants::STUDENT_ENROLLMENT, fellow_lms_section.id) }
#  let(:fellow_lms_assignments) { [
#    create(:canvas_assignment, course_id: fellow_canvas_course_id),
#    create(:canvas_assignment, course_id: fellow_canvas_course_id),
#    create(:canvas_assignment, course_id: fellow_canvas_course_id),
#  ] }
#  let(:fellow_lms_overrides) { [
#    create(:canvas_assignment_override_section, assignment_id: fellow_lms_assignments.first['id'], course_section_id: fellow_lms_section.id),
#    create(:canvas_assignment_override_section, assignment_id: fellow_lms_assignments.first['id'], course_section_id: fellow_lms_section.id),
#    create(:canvas_assignment_override_section, assignment_id: fellow_lms_assignments.last['id'], course_section_id: fellow_lms_section.id),
#  ] }
#  let(:matching_fellow_fellow_lms_course_overrides) { [
#    create(:canvas_assignment_override_user, assignment_id: fellow_lms_assignments.first['id'], student_ids: [portal_user.id]),
#    create(:canvas_assignment_override_user, assignment_id: fellow_lms_assignments.last['id'], student_ids: [portal_user.id]),
#  ] }
#  let(:fellow_lms_course_overrides) { [
#    matching_fellow_fellow_lms_course_overrides,
#    create(:canvas_assignment_override_section, assignment_id: fellow_lms_assignments.first['id'], course_section_id: fellow_lms_section.id),
#  ].flatten }
#  let(:lms_client) { double(
#    CanvasAPI,
#    find_enrollment: fellow_lms_enrollment,
#    find_enrollments_for_course_and_user: [fellow_lms_enrollment],
#    find_section_by: fellow_lms_section,
#    enroll_user_in_course: nil,
#    create_lms_section: fellow_lms_section,
#    delete_enrollment: nil,
#    get_assignments: fellow_lms_assignments,
#    get_assignment_overrides: fellow_lms_overrides,
#    get_assignment_overrides_for_course: fellow_lms_course_overrides,
#    create_assignment_overrides: nil,
#  ) }
#  let(:sync_from_salesforce_service) { double(SyncSalesforceContact) }
#  let(:sync_ta_caseload_for_participant_service) { double(SyncTaCaseloadForParticipant) }
#  # Create local models, with the assumption that a user that exists on Canvas must already exist locally too.
#  # This all falls apart if that assumption is untrue (the tests will pass, but the code won't work), so be careful
#  # if anything changes in this code in the future.
#  # Note: This reflects Highlander layout, not the fallback used for Booster/Prod
#  # (https://app.asana.com/0/1174274412967132/1197893935338145/f)
#  let(:platform_email) { sf_email }
#  let!(:user) { create(:registered_user, email: platform_email, salesforce_id: sf_participant.contact_id, canvas_user_id: portal_user.id) }
#  let!(:fellow_course) { create(:course, canvas_course_id: fellow_lms_enrollment.course_id) }
#  let!(:fellow_section) { create(:section, course_id: fellow_course.id, canvas_section_id: fellow_lms_section.id, name: fellow_lms_section.name) }
#  let!(:lc_course) { create(:course, canvas_course_id: lc_playbook_canvas_course_id) }
#
#  before(:each) do
#    allow(SyncSalesforceContact).to receive(:new).and_return(sync_from_salesforce_service)
#    allow(SyncTaCaseloadForParticipant).to receive(:new).and_return(sync_ta_caseload_for_participant_service)
#    allow(CanvasAPI).to receive(:client).and_return(lms_client)
#  end
#
#  subject(:run_sync) do
#    SyncSalesforceParticipant
#      .new(user: user,
#           portal_user: portal_user,
#           salesforce_participant: sf_participant,
#           salesforce_program: sf_program
#       ).run
#  end
#
#  describe '#run' do
#    context 'for enrolled teaching assistant' do
#      before(:each) do
#        sf_participant.role = SalesforceAPI::TEACHING_ASSISTANT
#        sf_participant.status = SalesforceAPI::ENROLLED
#        allow(lms_client).to receive(:assign_account_role)
#        allow(sync_ta_caseload_for_participant_service).to receive(:run)
#      end
#
#      it 'enrolls in the fellow course with limit removed' do
#        # because TAs need access to all users, not just users in their section.
#        run_sync
#        expect(lms_client).to have_received(:enroll_user_in_course).with(
#            portal_user.id, fellow_canvas_course_id, RoleConstants::TA_ENROLLMENT, fellow_lms_section.id, false
#        )
#      end
#
#      it 'enrolls in the lc playbook course with limit removed' do
#        run_sync
#        expect(lms_client).to have_received(:enroll_user_in_course).with(
#            portal_user.id, lc_playbook_canvas_course_id, RoleConstants::TA_ENROLLMENT, anything, false
#        )
#      end
#
#      it 'assigns the CanTakeAttendanceForAll role' do
#        user.remove_role RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL # to be safe
#        run_sync
#        expect(user.has_role?(RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL)).to be(true)
#      end
#
#      it 'assigns the Staff Account role in Canvas' do
#        expect(lms_client).to receive(:assign_account_role).with(portal_user.id, CanvasConstants::STAFF_ACCOUNT_ROLE_ID).once
#        run_sync
#      end
#
#      it 'syncs the TA Caseload sections' do
#        expect(sync_ta_caseload_for_participant_service).to receive(:run).once
#        run_sync
#      end
#    end
#
#    context 'for enrolled fellow participant' do
#      before(:each) do
#        sf_participant.role = SalesforceAPI::FELLOW
#        sf_participant.status = SalesforceAPI::ENROLLED
#        allow(sync_ta_caseload_for_participant_service).to receive(:run)
#      end
#
#      it 'creates a section if it does not exists' do
#        allow(Section).to receive(:find_by).and_return(nil)
#        expect{ run_sync }.to change(Section, :count).by(1)
#      end
#
#
#      it 'creates a default section in Canvas if no section on salesforce' do
#        allow(Section).to receive(:find_by).and_return(nil)
#        allow(lms_client).to receive(:find_section_by).and_return(nil)
#        run_sync
#        expect(lms_client)
#          .to have_received(:create_lms_section)
#          .with(course_id: fellow_canvas_course_id, name: SectionConstants::DEFAULT_SECTION)
#      end
#
#      # Add tests for other sections when implemented
#
#      it 'does not create a section if it exists' do
#        allow(Section).to receive(:find_by).and_return(fellow_section)
#        run_sync
#        expect(lms_client).not_to have_received(:create_lms_section)
#      end
#
#      it 'does not re-enroll the user' do
#        run_sync
#        expect(lms_client).not_to have_received(:enroll_user_in_course)
#      end
#
#      it 'de-enrols a user if section changes' do
#        new_section = create(:section, course_id: fellow_course.id, canvas_section_id: fellow_lms_section.id + 1)
#        allow(lms_client).to receive(:find_enrollment).and_return(fellow_lms_enrollment)
#        allow(Section).to receive(:find_by).and_return(new_section)
#        run_sync
#        expect(lms_client).to have_received(:delete_enrollment).once
#      end
#
#      it 'reenrols the user if section changes' do
#        new_section = create(:section, course_id: fellow_course.id, canvas_section_id: fellow_lms_section.id + 1)
#        allow(lms_client).to receive(:find_enrollment).and_return(fellow_lms_enrollment)
#        allow(Section).to receive(:find_by).and_return(new_section)
#        run_sync
#        expect(lms_client).to have_received(:enroll_user_in_course).once
#      end
#
#      it 're-creates assignment overrides if section changes' do
#        new_section = create(:section, course_id: fellow_course.id, canvas_section_id: fellow_lms_section.id + 1)
#        allow(lms_client).to receive(:find_enrollment).and_return(fellow_lms_enrollment)
#        allow(Section).to receive(:find_by).and_return(new_section)
#
#        run_sync
#
#        # Note: the id was deleted from the overrides, their hashes modified in-place.
#        expect(lms_client).to have_received(:create_assignment_overrides)
#          .once
#          .with(fellow_course.canvas_course_id, matching_fellow_fellow_lms_course_overrides)
#      end
#
#
#      it 'de-enrols a user if role changes' do
#        new_enrollment = CanvasAPI::LMSEnrollment.new(82738732, fellow_lms_enrollment.course_id, RoleConstants::TA_ENROLLMENT, fellow_lms_section.id)
#        allow(lms_client).to receive(:find_enrollment).and_return(new_enrollment)
#        run_sync
#        expect(lms_client).to have_received(:delete_enrollment).once
#      end
#
#      it 'reenrols the user if role changes' do
#        new_enrollment = CanvasAPI::LMSEnrollment.new(928798237, fellow_lms_enrollment.course_id, RoleConstants::TA_ENROLLMENT, fellow_lms_section.id)
#        allow(lms_client).to receive(:find_enrollment).and_return(new_enrollment)
#        run_sync
#        expect(lms_client).to have_received(:enroll_user_in_course).once
#      end
#
#      it 'syncs the TA Caseload sections' do
#        expect(sync_ta_caseload_for_participant_service).to receive(:run).once
#        run_sync
#      end
#    end
#
#    context 'for dropped fellow participant' do
#      before(:each) do
#        sf_participant.role = SalesforceAPI::FELLOW
#        sf_participant.status = SalesforceAPI::DROPPED
#      end
#
#      it 'it drops the user if user is enrolled' do
#        allow(lms_client).to receive(:find_enrollment).and_return(fellow_lms_enrollment)
#        run_sync
#        expect(lms_client).to have_received(:delete_enrollment).once
#      end
#    end
#
#    context 'for dropped ta participant' do
#      let(:lc_lms_enrollment) { CanvasAPI::LMSEnrollment.new(56, fellow_canvas_course_id, RoleConstants::TA_ENROLLMENT, 'fake_section_id') }
#
#      before(:each) do
#        sf_participant.role = SalesforceAPI::TEACHING_ASSISTANT
#        sf_participant.status = SalesforceAPI::DROPPED
#        allow(lms_client).to receive(:unassign_account_role)
#      end
#
#      it 'it drops the user if user is enrolled' do
#        # a little hacky b/c we should do separate ones for each course, but i'd have to refact
#        allow(lms_client).to receive(:find_enrollment).with(portal_user.id, fellow_canvas_course_id).and_return(fellow_lms_enrollment)
#        allow(lms_client).to receive(:find_enrollment).with(portal_user.id, lc_playbook_canvas_course_id).and_return(lc_lms_enrollment)
#        run_sync
#        # once for Accelerator Course and once for LC Playbook
#        expect(lms_client).to have_received(:delete_enrollment).twice
#      end
#
#      # Note: we may consider changing this logic in the future if staff will be TA's
#      # in multiple courses at the same time. The could end up with a Dropped Participant in one,
#      # fighting with an Enrolled participant in another and the behavior will be whichever the last one
#      # to sync would determine. Cross that bridge when we get there. For now I think it's safe to remove
#      # the role for Dropped participants.
#      it 'it removes the CanTakeAttendanceForAll platform role' do
#        user.add_role RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL
#        run_sync
#        expect(user.has_role?(RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL)).to be(false)
#      end
#
#      # Same comment as above about potentially having 2 Participant records in different states at the same time.
#      it 'remove the Staff Account role in Canvas' do
#        expect(lms_client).to receive(:unassign_account_role).with(portal_user.id, CanvasConstants::STAFF_ACCOUNT_ROLE_ID).once
#        run_sync
#      end
#    end
#
#    context 'when Platform email doesnt match Salesforce email' do
#      let(:sf_email) { 'salesforce.email.no.match@example.com' }
#      let(:platform_email) { 'platform.email.no.match@example.com' }
#
#      it 'calls SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).to receive(:run!).once
#        run_sync
#      end
#    end
#
#    context 'when Platform email matches Salesforce email exactly' do
#      let(:sf_email) { 'exact_match@example.com' }
#      let(:platform_email) { 'exact_match@example.com' }
#
#      it 'doesnt call SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).not_to receive(:run!)
#        run_sync
#      end
#    end
#
#    context 'when Platform email matches Salesforce email case-insensitively' do
#      let(:sf_email) { 'caseInsensitiveMatch@example.com' }
#      let(:platform_email) { 'caseinsensitivematch@example.com' }
#
#      it 'doesnt call SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).not_to receive(:run!)
#        run_sync
#      end
#    end
#
#    context 'when Canvas email doesnt match Salesforce email' do
#      let(:sf_email) { 'salesforce.email.no.match@example.com' }
#      let(:canvas_email) { 'canvas.email.no.match@example.com' }
#
#      it 'calls SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).to receive(:run!).once
#        run_sync
#      end
#    end
#
#    context 'when Canvas email matches Salesforce email exactly' do
#      let(:sf_email) { 'exact_match@example.com' }
#      let(:canvas_email) { 'exact_match@example.com' }
#
#      it 'doesnt call SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).not_to receive(:run!)
#        run_sync
#      end
#    end
#
#    context 'when Canvas email matches Salesforce email case-insensitively' do
#      let(:sf_email) { 'caseInsensitiveMatch@example.com' }
#      let(:canvas_email) { 'caseinsensitivematch@example.com' }
#
#      it 'doesnt call SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).not_to receive(:run!)
#        run_sync
#      end
#    end
#
#    context 'when Canvas email doesnt match Platform email' do
#      let(:platform_email) { 'platform.email.no.match@example.com' }
#      let(:canvas_email) { 'canvas.email.no.match@example.com' }
#
#      it 'calls SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).to receive(:run!).once
#        run_sync
#      end
#    end
#
#    context 'when Canvas email matches Platform email exactly' do
#      let(:platform_email) { sf_email }
#      let(:canvas_email) { sf_email }
#
#      it 'doesnt call SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).not_to receive(:run!)
#        run_sync
#      end
#    end
#
#    context 'when Canvas email matches Platform email case-insensitively' do
#      let(:sf_email) { 'SFEmail@example.com' }
#      let(:platform_email) { sf_email }
#      let(:canvas_email) { 'sfemail@example.com' }
#
#      it 'doesnt call SyncSalesforceContact service' do
#        expect(sync_from_salesforce_service).not_to receive(:run!)
#        run_sync
#      end
#    end
#  end
#
#  describe "#find_or_create_section" do
#    context "when canvas section already exists" do
#      it "does not create a Canvas section" do
#        SyncSalesforceParticipant
#          .new(user: user,
#               portal_user: portal_user,
#               salesforce_participant: sf_participant,
#               salesforce_program: sf_program)
#          .send(:find_or_create_section, fellow_canvas_course_id, fellow_lms_section.name)
#
#        expect(lms_client).not_to have_received(:create_lms_section)
#      end
#
#      it "returns a local section" do
#        local_section = SyncSalesforceParticipant
#          .new(user: user,
#               portal_user: portal_user,
#               salesforce_participant: sf_participant,
#               salesforce_program: sf_program)
#          .send(:find_or_create_section, fellow_canvas_course_id, fellow_lms_section.name)
#
#        expect(local_section).to eq(fellow_section)
#      end
#    end
#
#    context "when canvas section does not already exist" do
#      let!(:fellow_section) { build(:section, course_id: fellow_course.id, canvas_section_id: fellow_lms_section.id, name: fellow_lms_section.name) }
#
#      context "when participant in cohort-schedule only" do
#        before :each do
#          sf_participant.cohort_schedule = fellow_lms_section.name
#        end
#
#        it "creates the Canvas section" do
#          SyncSalesforceParticipant
#            .new(user: user,
#                 portal_user: portal_user,
#                salesforce_participant: sf_participant,
#                salesforce_program: sf_program)
#            .send(:find_or_create_section, fellow_canvas_course_id, fellow_lms_section.name)
#
#          expect(lms_client).to have_received(:create_lms_section)
#        end
#
#        it "does not do anything with overrides" do
#          SyncSalesforceParticipant
#            .new(user: user,
#                 portal_user: portal_user,
#                salesforce_participant: sf_participant,
#                salesforce_program: sf_program)
#            .send(:find_or_create_section, fellow_canvas_course_id, fellow_lms_section.name)
#
#          expect(lms_client).not_to have_received(:get_assignments)
#          expect(lms_client).not_to have_received(:get_assignment_overrides)
#          expect(lms_client).not_to have_received(:create_assignment_overrides)
#        end
#
#        it "returns a local section" do
#          local_section = SyncSalesforceParticipant
#            .new(user: user,
#                portal_user: portal_user,
#                salesforce_participant: sf_participant,
#                salesforce_program: sf_program)
#            .send(:find_or_create_section, fellow_canvas_course_id, fellow_lms_section.name)
#
#          expect(local_section.course_id).to eq(fellow_section.course_id)
#          expect(local_section.canvas_section_id).to eq(fellow_section.canvas_section_id)
#          expect(local_section.name).to eq(fellow_section.name)
#        end
#      end
#
#      context "when participant in cohort" do
#        # fellow_lms_section should be the cohort-schedule section.
#        let(:fellow_lms_section) { CanvasAPI::LMSSection.new(11, "test cohort-schedule section") }
#        let(:lms_cohort_section) { CanvasAPI::LMSSection.new(10, "test cohort section") }
#        let!(:fellow_section) { build(:section, course_id: fellow_course.id, canvas_section_id: lms_cohort_section.id, name: lms_cohort_section.name) }
#
#        before :each do
#          sf_participant.cohort_schedule = fellow_lms_section.name
#          sf_participant.cohort = lms_cohort_section.name
#          allow(lms_client).to receive(:create_lms_section).and_return(lms_cohort_section)
#        end
#
#        it "creates the Canvas section" do
#          SyncSalesforceParticipant
#            .new(user: user,
#                 portal_user: portal_user,
#                salesforce_participant: sf_participant,
#                salesforce_program: sf_program)
#            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)
#
#          expect(lms_client).to have_received(:create_lms_section)
#        end
#
#        it "copies assignment overrides" do
#          SyncSalesforceParticipant
#            .new(user: user,
#                portal_user: portal_user,
#                salesforce_participant: sf_participant,
#                salesforce_program: sf_program)
#            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)
#
#          expect(lms_client).to have_received(:get_assignments)
#          expect(lms_client).to have_received(:get_assignment_overrides).exactly(fellow_lms_assignments.count).times
#          expect(lms_client).to have_received(:create_assignment_overrides).once
#        end
#
#        it "returns a local section" do
#          local_section = SyncSalesforceParticipant
#            .new(user: user,
#                portal_user: portal_user,
#                salesforce_participant: sf_participant,
#                salesforce_program: sf_program)
#            .send(:find_or_create_section, fellow_canvas_course_id, lms_cohort_section.name)
#
#          expect(local_section.course_id).to eq(fellow_section.course_id)
#          expect(local_section.canvas_section_id).to eq(fellow_section.canvas_section_id)
#          expect(local_section.name).to eq(fellow_section.name)
#        end
#      end
#    end
#
#  end
end
