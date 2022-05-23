# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceProgram do
  let(:program) { build :heroku_connect_program_launched}
  let(:course) { program.accelerator_course }
  let(:last_sync_info1) { create :participant_sync_info_fellow, program: program }
  let(:participant_diff1) {
    new_sync_info = last_sync_info1.dup
    new_sync_info.sfid = last_sync_info1.sfid # dup doesn't copy primary keys
    new_sync_info.first_name = 'changedFirstName' # Default to have changes so sync logic runs
    ParticipantSyncInfo::Diff.new(last_sync_info1, new_sync_info)
  }
  let(:participant_diffs) { [participant_diff1] }
  let(:sis_import_status) { SisImportStatus.new(create :canvas_sis_import) }
  let(:max_duration) { 1.minute.to_i }
  let(:force_zoom_update) { false }
  let(:force_canvas_update) { false }
  let(:canvas_client) { instance_double(CanvasAPI) }
  let(:sf_client) { instance_double(SalesforceAPI) }
  let(:sync_participant_service) { instance_double(SyncSalesforceParticipant, run: nil) }
  let(:sync_zoom_service) { instance_double(SyncZoomLinksForParticipant, run: nil) }

  before(:each) do
    allow(SyncSalesforceParticipant).to receive(:new).and_return(sync_participant_service)
    allow(SyncZoomLinksForParticipant).to receive(:new).and_return(sync_zoom_service)
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:send_sis_import_zipfile_for_data_set).and_return(sis_import_status)
    allow(canvas_client).to receive(:send_sis_import_zipfile_for_full_batch_update).and_return(sis_import_status)
    allow(ParticipantSyncInfo).to receive(:diffs_for_program).with(program).and_return(participant_diffs)
    allow(Honeycomb).to receive(:add_alert)
    allow(Honeycomb).to receive(:add_field)
  end

  describe '#run' do
    subject(:run_sync_program) do
      SyncSalesforceProgram.new(program, max_duration, force_canvas_update, force_zoom_update).run
    end

    context 'for Program without Canvas course IDs' do
      let(:program) { build :heroku_connect_program_unlaunched}
      let(:participant_diffs) { [] }

      it 'skips the sync with no error and no alerts' do
        expect(Honeycomb).to receive(:add_field)
          .with('sync_salesforce_program.skip_reason', /Program ID: .* hasn't been launched/)
          .once
        expect(Honeycomb).not_to receive(:add_alert)
        result = run_sync_program
        expect(result.count).to be(nil)
      end
    end

    context 'with missing Course model' do
      before(:each) do
        # make the canvas_course_id not match the program
        course.update!(canvas_course_id: course.canvas_course_id + 100)
      end

      it 'raises an error' do
        expect{run_sync_program}.to raise_error(SyncSalesforceProgram::MissingCourseModelsError)
      end
    end

    context 'when Program Id out of sync with Course model' do
      it 'updates the models' do
        mismatched_program_id = program.sfid.reverse
        course.update!(salesforce_program_id: mismatched_program_id)
        expect{run_sync_program}.to change{ course.reload.salesforce_program_id}
          .from(mismatched_program_id).to(program.sfid)
      end

      it 'clears the mismatched models' do
        mismatched_program_id = program.sfid.reverse
        course.update!(salesforce_program_id: mismatched_program_id)
        old_course = create(:course_launched,
          canvas_course_id: course.canvas_course_id + 100, salesforce_program_id: program.sfid
        )
        expect{run_sync_program}.to change{ old_course.reload.salesforce_program_id}
          .from(program.sfid).to(nil)
      end
    end

    context 'when Program Id matches' do
      it 'is a NOOP' do
        expect(course.salesforce_program_id).to eq(program.sfid)
        expect{run_sync_program}.not_to change{ course.reload.salesforce_program_id }
      end
    end

    context 'when max duration reached' do
      let(:sis_import_status) { SisImportStatus.new(create :canvas_sis_import_running) }
      let(:max_duration) { 0 }

      it 'exits early' do
        expect{run_sync_program}.to raise_error(SyncSalesforceProgram::ExitedEarlyError)
      end
    end

    context 'when Canvas has SisImport errors' do
      let(:sis_import_status) { SisImportStatus.new(create :canvas_sis_import_failed) }
      it 'raises an error' do
        expect{run_sync_program}.to raise_error(SyncSalesforceProgram::SisImportFailedError)
      end
    end

    context 'when previous Canvas SisImport had errors' do
      let(:last_sis_import_status) { SisImportStatus.new(create :canvas_sis_import_failed) }
      it 'turns diffing mode off' do
        program.accelerator_course.update!(last_canvas_sis_import_id: last_sis_import_status.sis_import_id)
        expect(canvas_client).to receive(:get_sis_import_status).and_return(last_sis_import_status)
        expect(SisImportDataSet).to receive(:new).with(program, false).and_call_original
        run_sync_program
      end
    end

    context 'when no Participants have changed' do
      before(:each) do
        participant_diff1.first_name = last_sync_info1.first_name
        expect(participant_diff1.changed?).to be(false) #sanity check
      end

      it 'skips the sync' do
        expect(Honeycomb).to receive(:add_field)
          .with('sync_salesforce_program.skip_reason', 'No Participant changes.').once
        result = run_sync_program
        expect(result.count).to be(1)
      end

      context 'with force_zoom_update' do
        let(:force_zoom_update) { true }
        it 'runs the sync' do
          expect(sync_zoom_service).to receive(:run).once
          run_sync_program
        end
      end

      context 'with force_canvas_update' do
        let(:force_canvas_update) { true }
        it 'runs the sync in batch mode' do
          expect(canvas_client).to receive(:send_sis_import_zipfile_for_full_batch_update).once
          run_sync_program
        end
      end
    end

    context 'when Participants have changed' do

      context 'when no errors' do
        # Diffing mode is optimized so that Canvas only processes the changes from the previous sync.
        # This is the default mode
        it 'sends the data to Canvas in diffing mode' do
          expect(SisImportDataSet).to receive(:new).with(program, true).and_call_original
          expect(canvas_client).to receive(:send_sis_import_zipfile_for_data_set)
          run_sync_program
        end

        it 'has no failed_participants' do
          result = run_sync_program
          expect(result.failed_participants).to be_empty
        end

        it 'saves the latest ParticipantSyncInfo' do
          ParticipantSyncInfo.destroy_all
          expect{run_sync_program}.to change(ParticipantSyncInfo, :count).by(1)
        end

        it 'syncs Zoom Participant info' do
          expect(SyncZoomLinksForParticipant).to receive(:new)
          .with(participant_diff1, force_zoom_update)
          .and_return(sync_zoom_service).once
          expect(sync_zoom_service).to receive(:run).once
          run_sync_program
        end

        it 'syncs Canvas Participant info' do
          expect(SyncSalesforceParticipant).to receive(:new)
            .with(instance_of(SisImportDataSet), program, participant_diff1)
            .and_return(sync_participant_service).once
          expect(sync_participant_service).to receive(:run).once
          run_sync_program
        end
      end

      context 'when all changed Participants have errors' do
        before(:each) do
          expect(sync_participant_service).to receive(:run).and_raise(SyncSalesforceProgram::DuplicateParticipantError)
        end

        it 'skips the sync and raises error' do
          expect(Honeycomb).to receive(:add_field)
            .with('sync_salesforce_program.skip_reason', 'No Participants that needed a sync were successfully synced.')
            .once
          expect(canvas_client).not_to receive(:send_sis_import_zipfile_for_data_set)
          expect{run_sync_program}.to raise_error(SyncSalesforceProgram::SyncParticipantsError)
        end

        it 'doesnt save the ParticipantSyncInfo' do
          ParticipantSyncInfo.destroy_all
          expect{run_sync_program}.to raise_error.and change(ParticipantSyncInfo, :count).by(0)
        end
      end

      context 'when some Participants have errors' do
        let(:last_sync_info2) { create :participant_sync_info_fellow, program: program }
        let(:participant_diff2) {
          new_sync_info = last_sync_info2.dup
          new_sync_info.sfid = last_sync_info2.sfid # dup doesn't copy primary keys
          new_sync_info.first_name = 'changedFirstName' # Default to have changes so sync logic runs
          ParticipantSyncInfo::Diff.new(last_sync_info2, new_sync_info)
        }
        let(:participant_diffs) { [participant_diff1, participant_diff2] }

        context 'for a duplicate Participant' do
          it 'skips the sync for that user and raises an error' do
            ParticipantSyncInfo.destroy_all
            participant_diff2.contact_id = participant_diff1.contact_id
            expect(sync_zoom_service).to receive(:run).once
            expect(sync_participant_service).to receive(:run).once
            expect{run_sync_program}.to raise_error(SyncSalesforceProgram::SyncParticipantsError)
            expect(ParticipantSyncInfo.count).to eq(1)
          end
        end

        context 'for errors creating a Section in Platform or Canvas' do
          it 'fails the entire sync' do
            ParticipantSyncInfo.destroy_all
            expect(canvas_client).not_to receive(:send_sis_import_zipfile_for_data_set)
            expect(sync_participant_service).to receive(:run).and_raise(SyncSalesforceProgram::SectionSetupError)
            expect{run_sync_program}.to raise_error(SyncSalesforceProgram::SectionSetupError)
            expect(ParticipantSyncInfo.count).to eq(0)
          end
        end

        context 'for a missing Cohort Schedule' do
          let(:last_sync_info2) { create :participant_sync_info_fellow, program: program, cohort_schedule_id: nil }

          context 'for Participant who hasnt created an account yet' do
            it 'skips the sync with no errors' do
              ParticipantSyncInfo.destroy_all
              participant_diff2.user_id = nil # this is what makes them not have an account
              expect(sync_zoom_service).to receive(:run).once
              expect(sync_participant_service).to receive(:run).once
              expect(Honeycomb).not_to receive(:add_alert)
              expect(Honeycomb).to receive(:add_field)
                .with('sync_salesforce_program.participant.skip_reason', /Maybe they are missing a Cohort Schedule/)
                .once
              result = nil
              expect{result=run_sync_program}.not_to raise_error
              expect(result.count).to eq(2)
              expect(result.failed_participants).to be_empty
            end
          end

          context 'for Participant who has created an account yet' do
            it 'skips the sync for that user and raises an error' do
              ParticipantSyncInfo.destroy_all
              expect(participant_diff2.user_id).not_to be(nil) # sanity check
              expect(sync_zoom_service).to receive(:run).twice
              expect(SyncSalesforceParticipant).to receive(:new)
                .with(instance_of(SisImportDataSet), program, participant_diff2)
                .and_raise(SyncSalesforceProgram::NoCohortScheduleError)
              expect{run_sync_program}.to raise_error(SyncSalesforceProgram::SyncParticipantsError)
              expect(ParticipantSyncInfo.count).to eq(1)
            end
          end
        end

      end # 'when some Participants have errors'
    end # 'when Participants have changed'
  end #run'
end
