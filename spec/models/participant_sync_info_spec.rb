require 'rails_helper'

RSpec.describe ParticipantSyncInfo, type: :model do


  describe 'database' do
    let(:participant) { build :participant_sync_info }

    it { should have_db_index(:sfid) }
    it { should have_db_index([:contact_id, :program_id]) }

    it { should belong_to(:user).required }
    it { should belong_to(:accelerator_course).required }
    it { should belong_to(:lc_playbook_course).optional }
    it { should belong_to(:cohort_section).optional }
    it { should belong_to(:accelerator_cohort_schedule_section).optional }
    it { should belong_to(:lc_playbook_cohort_schedule_section).optional }

    it 'role_category is a symbol' do
      expect(participant.role_category).to be_a(Symbol)
    end

    it 'status is a symbol' do
      expect(participant.role_category).to be_a(Symbol)
    end
  end

  describe '#is_mapped_to_cohort?' do
    context 'when mapped to cohort' do
    let(:participant) { build :participant_sync_info_with_cohort }
      it 'returns true' do
        expect(participant.is_mapped_to_cohort?).to eq(true)
      end
    end

    context 'when not mapped to cohort' do
    let(:participant) { build :participant_sync_info, cohort: nil }
      it 'returns false' do
        expect(participant.is_mapped_to_cohort?).to eq(false)
      end
    end
  end

  describe ParticipantSyncInfo::Diff do
    let(:program) { build :heroku_connect_program_launched }
    let(:heroku_connect_participant) { build :heroku_connect_participant, program: program, contact: contact }
    let(:new_sync_info) { build :participant_sync_info, participant: heroku_connect_participant }
    let(:last_sync_info) {
      nsi = new_sync_info.dup
      nsi.sfid = new_sync_info.sfid # dup doesn't copy primary keys
      nsi
    }
    let!(:participant) {
      ParticipantSyncInfo::Diff.new(last_sync_info, new_sync_info)
    }

    # Defaults. Make sure and set these to match what you are testing below.
    let(:salesforce_email) { 'exact_match@example.com' }
    let(:platform_email) { 'exact_match@example.com' }
    let(:contact) { build :heroku_connect_contact, email: salesforce_email }
    let(:user) { create :unregistered_user, email: platform_email, contact: contact }

    context 'with bad args' do
      it 'raises error' do
        expect{ParticipantSyncInfo::Diff.new(nil, nil)}.to raise_error(ArgumentError)
      end
    end

    shared_examples 'not changed' do
      it 'changed? returns false' do
        expect(participant.changed?).to eq(false)
      end
    end

    shared_examples 'contact not changed' do
      it 'contact_changed? returns false' do
        expect(participant.contact_changed?).to eq(false)
      end
    end

    context 'when no changes' do
      it_behaves_like 'not changed'
      it_behaves_like 'contact not changed'
    end

    shared_examples 'detects changes' do

      shared_examples 'changed' do
        it 'returns true' do
          expect(participant.changed?).to eq(true)
        end
      end

      shared_examples 'enrollments changed' do
        it 'returns true' do
          expect(participant.enrollments_changed?).to eq(true)
        end
      end

      shared_examples 'zoom info changed' do
        it 'returns true' do
          expect(participant.zoom_info_changed?).to eq(true)
        end
        it_behaves_like 'changed'
      end

      describe '#contact_changed?' do
        shared_examples 'contact changed' do
          it 'returns true' do
            expect(participant.contact_changed?).to eq(true)
          end
          it_behaves_like 'changed'
          it_behaves_like 'zoom info changed'
        end

        context 'when contact_id changes' do
          before { new_sync_info.contact_id = new_sync_info.contact_id.to_i + 1 }
          it_behaves_like 'contact changed'
        end

        context 'when email changes' do
          before { new_sync_info.email = "#{new_sync_info.email}.new" }
          it_behaves_like 'contact changed'
        end

        context 'when first_name changes' do
          before { new_sync_info.first_name = "#{new_sync_info.first_name}.new" }
          it_behaves_like 'contact changed'
        end

        context 'when last_name changes' do
          before { new_sync_info.last_name = "#{new_sync_info.last_name}.new" }
          it_behaves_like 'contact changed'
        end

        # Edge case, but can happen due to a bad Contact merge.
        context 'when canvas_user_id changes' do
          before { new_sync_info.canvas_user_id = new_sync_info.canvas_user_id.to_i + 1 }
          it_behaves_like 'contact changed'
        end

        # Edge case, but can happen due to a bad Contact merge.
        context 'when user_id changes' do
          before { new_sync_info.user_id = new_sync_info.user_id.to_i + 1 }
          it_behaves_like 'contact changed'
        end
      end # '#contact_changed?'

      describe '#accelerator_enrollment_changed?' do
        shared_examples 'enrollment changed' do
          it 'returns true' do
            expect(participant.accelerator_enrollment_changed?).to eq(true)
          end
          it_behaves_like 'changed'
          it_behaves_like 'enrollments changed'
          it_behaves_like 'zoom info changed'
        end

        context 'when role_category changes' do
          before { new_sync_info.role_category = :FakeRoleCategory }
          it_behaves_like 'enrollment changed'
        end

        context 'when status changes' do
          before { new_sync_info.status = :FakeStatus }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_id changes' do
          before { new_sync_info.cohort_id = 'fake_cohort_id' }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_section_name changes' do
          before { new_sync_info.cohort_section_name = 'fake_cohort_section_name' }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_schedule_id changes' do
          before { new_sync_info.cohort_schedule_id = 'fake_cohort_schedule_id' }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_schedule_weekday changes' do
          before { new_sync_info.cohort_schedule_weekday = 'FriYay' }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_schedule_time changes' do
          before { new_sync_info.cohort_schedule_time = '3-3:01am' }
          it_behaves_like 'enrollment changed'
        end

        context 'when candidate_role_select changes' do
          before { new_sync_info.candidate_role_select = :FakeRole }
          it_behaves_like 'enrollment changed'
        end

        # Edge case that can only really happen for dev or test Program's.
        context 'when canvas_accelerator_course_id changes' do
          before { new_sync_info.canvas_accelerator_course_id = new_sync_info.canvas_accelerator_course_id.to_i + 1 }
          it_behaves_like 'enrollment changed'
        end

      end # '#accelerator_enrollment_changed?'

      describe 'lc_playbook_enrollment_changed#?' do
        shared_examples 'enrollment changed' do
          it 'returns true' do
            expect(participant.lc_playbook_enrollment_changed?).to eq(true)
          end
          it_behaves_like 'changed'
          it_behaves_like 'enrollments changed'
        end

        context 'when role_category changes' do
          before { new_sync_info.role_category = :FakeRoleCategory }
          it_behaves_like 'enrollment changed'
        end

        context 'when status changes' do
          before { new_sync_info.status = :FakeStatus }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_schedule_id changes' do
          before { new_sync_info.cohort_schedule_id = 'fake_cohort_schedule_id' }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_schedule_weekday changes' do
          before { new_sync_info.cohort_schedule_weekday = 'FriYay' }
          it_behaves_like 'enrollment changed'
        end

        context 'when cohort_schedule_time changes' do
          before { new_sync_info.cohort_schedule_time = '3-3:01am' }
          it_behaves_like 'enrollment changed'
        end

        # Edge case that can only really happen for dev or test Program's.
        context 'when canvas_lc_playbook_course_id changes' do
          before { new_sync_info.canvas_lc_playbook_course_id = new_sync_info.canvas_lc_playbook_course_id.to_i + 1 }
          it_behaves_like 'enrollment changed'
        end

      end # '#lc_playbook_enrollment_changed?'

      describe '#ta_caseload_sections_changed?' do
        shared_examples 'ta caseload changed' do
          it 'returns true' do
            expect(participant.ta_caseload_sections_changed?).to eq(true)
          end
          it_behaves_like 'changed'
          it_behaves_like 'enrollments changed'
        end

        context 'when status changes' do
          before { new_sync_info.status = :FakeStatus }
          it_behaves_like 'ta caseload changed'
        end

        context 'when ta_caseload_enrollments changes' do
          before { new_sync_info.ta_caseload_enrollments = [{"ta_name"=>"fakeTaName", "ta_participant_id"=>"fake_ta_participant_id"}] }
          it_behaves_like 'ta caseload changed'
        end
      end # '#ta_caseload_sections_changed?'

      describe '#cohort_schedule_name_changed?' do
        shared_examples 'cohort schedule name changed' do
          it 'returns true' do
            expect(participant.cohort_schedule_name_changed?).to eq(true)
          end
          it_behaves_like 'changed'
        end

        context 'when cohort_schedule_weekday changes' do
          before { new_sync_info.cohort_schedule_weekday = 'FriYay' }
          it_behaves_like 'cohort schedule name changed'
        end

        context 'when cohort_schedule_time changes' do
          before { new_sync_info.cohort_schedule_time = '3-3:01am' }
          it_behaves_like 'cohort schedule name changed'
        end

      end # '#cohort_schedule_name_changed?'

      describe '#zoom_info_changed?' do
        shared_examples 'zoom meeting id 1 changed' do
          it 'returns true' do
            expect(participant.zoom_meeting_id_1_changed?).to eq(true)
          end
          it_behaves_like 'zoom info changed'
        end

        shared_examples 'zoom meeting id 2 changed' do
          it 'returns true' do
            expect(participant.zoom_meeting_id_2_changed?).to eq(true)
          end
          it_behaves_like 'zoom info changed'
        end

        context 'when zoom_meeting_id_1 changes' do
          before { new_sync_info.zoom_meeting_id_1 = new_sync_info.zoom_meeting_id_1.to_i + 1 }
          it_behaves_like 'zoom meeting id 1 changed'
        end

        context 'when zoom_meeting_id_2 changes' do
          before { new_sync_info.zoom_meeting_id_2 = new_sync_info.zoom_meeting_id_2.to_i + 1 }
          it_behaves_like 'zoom meeting id 2 changed'
        end

        context 'when lc1_first_name changes' do
          before { new_sync_info.lc1_first_name = 'lc1NewName' }
          it_behaves_like 'zoom info changed'
        end

        context 'when lc2_first_name changes' do
          before { new_sync_info.lc2_first_name = 'lc2NewName' }
          it_behaves_like 'zoom info changed'
        end

        context 'when lc1_last_name changes' do
          before { new_sync_info.lc1_last_name = 'lc1NewLastName' }
          it_behaves_like 'zoom info changed'
        end

        context 'when lc2_last_name changes' do
          before { new_sync_info.lc2_last_name = 'lc2NewLastName' }
          it_behaves_like 'zoom info changed'
        end

      end # '#zoom_info_changed?'

    end # 'detects changes'

    context 'for first time sync' do
      let(:last_sync_info) { nil }
      it 'doesnt raise error' do
        expect{participant}.not_to raise_error
      end
      it_behaves_like 'detects changes'
    end

    context 'for subsequent syncs' do
      it_behaves_like 'detects changes'
    end

    describe '#should_sync?' do
      shared_examples 'handles should_sync logic for Fellows and LCs' do
        shared_examples 'should sync' do
          it 'should_sync? returns true' do
            expect(participant.should_sync?).to eq(true)
          end
        end

        shared_examples 'should not sync' do
          it 'should_sync? returns false' do
            expect(participant.should_sync?).to eq(false)
          end
        end

        context 'when cohort_schedule_id.blank?' do
          before { new_sync_info.cohort_schedule_id = nil }

          # These users at one point got a cohort_schedule_id and were synced,
          # giving them a user_id in SF. But now they no longer have one so we
          # start throwing errors during the sync.
          context 'with user_id' do
            before { expect(participant.user_id).not_to be(nil) }
            it_behaves_like 'should sync'
          end

          # No cohort schedule and never synced. Wait until they get a cohort schedule
          # to start syncing them.
          context 'when user_id.blank?' do
            before { new_sync_info.user_id = nil }
            it_behaves_like 'should not sync'
          end
        end
      end

      context 'when Fellow' do
        let(:heroku_connect_participant) { build :heroku_connect_fellow_participant, program: program, contact: contact }
        it_behaves_like 'handles should_sync logic for Fellows and LCs'
      end

      context 'when LC' do
        let(:heroku_connect_participant) { build :heroku_connect_lc_participant, program: program, contact: contact }
        it_behaves_like 'handles should_sync logic for Fellows and LCs'
      end
    end

  end
end

# TODO:
# The below used to be on HerokuConnect::Participant. Cut it over to the new
# method on ParticipantSyncInfo
#  describe '#teaching_assistant_full_names' do
#    let(:ta_assignments_collection) { instance_double(ActiveRecord::Associations::CollectionProxy) }
#    let(:ta_assignments) { [] }
#    let(:ta_caseloads_collection) { instance_double(ActiveRecord::Associations::CollectionProxy) }
#    let(:ta_caseloads) { [] }
#
#    before(:each) do
#      # These are not stored in the DB, so we need to stub it out.
#      allow(ta_assignments_collection).to receive(:exists?).and_return(ta_assignments.present?)
#      allow(ta_assignments_collection).to receive(:each).and_return(ta_assignments)
#      allow(participant).to receive(:ta_assignments).and_return(ta_assignments_collection)
#      allow(ta_caseloads_collection).to receive(:exists?).and_return(ta_caseloads.present?)
#      allow(participant).to receive(:ta_caseloads).and_return(ta_caseloads_collection)
#    end
#
#    context 'no ta_assignments or ta_caseloads' do
#      it 'returns an empty list' do
#        expect(participant.teaching_assistant_sections).to eq([])
#      end
#    end
#
#    context 'for Fellow' do
#      let(:ta_assignment1) { build :heroku_connect_ta_assignment }
#      let(:ta_assignments) { [ta_assignment1] }
#      let(:participant) { ta_assignment1.fellow_participant }
#
#      context 'with one ta_assignment' do
#        it 'returns the TAs name in the list' do
#          expect(participant.teaching_assistant_sections).to eq([ta_assignment1.ta_participant.full_name])
#        end
#      end
#
#      context 'with two ta_assignments' do
#        let(:ta_assignment2) { build :heroku_connect_ta_assignment, fellow_participant: participant }
#        let(:ta_assignments) { [ta_assignment1, ta_assignment2] }
#
#        it 'returns both TAs names in the list' do
#          expect(participant.teaching_assistant_sections)
#            .to eq([ta_assignment1.ta_participant.full_name, ta_assignment2.ta_participant.full_name])
#        end
#      end
#    end
#
#    context 'for TA' do
#      let(:ta_assignment1) { build :heroku_connect_ta_assignment }
#      let(:ta_caseloads) { [ta_assignment1] }
#      let(:participant) { ta_assignment1.ta_participant }
#
#      it 'returns this TAs name in the list' do
#        expect(participant.teaching_assistant_sections).to eq([participant.full_name])
#      end
#    end
#  end
