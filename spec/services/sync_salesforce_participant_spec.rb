# frozen_string_literal: true

require 'rails_helper'
require 'sis_import_data_set'

RSpec.describe SyncSalesforceParticipant do
  let(:program) { build :heroku_connect_program_launched}
  let(:user) { last_sync_info.user }
  let(:new_sync_info) {
    nsi = last_sync_info.dup
    nsi.sfid = last_sync_info.sfid # dup doesn't copy primary keys
    nsi
  }
  let(:participant) {
    ParticipantSyncInfo::Diff.new(last_sync_info, new_sync_info)
  }
  let(:diffing_mode_on) { true }
  let(:sis_import_data_set) { SisImportDataSet.new(program, diffing_mode_on) }
  let(:sync_contact_service) { instance_double(SyncSalesforceContact) }
  let(:create_section_service) { instance_double(CreateSection) }

  # Defaults. Make sure and set these to match what you are testing below.
  let(:cohort_schedule) { build :heroku_connect_cohort_schedule, program: program }
  let(:cohort) { build :heroku_connect_cohort, program: program, cohort_schedule: cohort_schedule }
  let(:cohort_section) { create :cohort_section,
    cohort: cohort,
    course: program.accelerator_course
  }
  let(:limit_section_privileges) { true }
  let(:enrollment_status) { HerokuConnect::Participant::Status::ENROLLED }
  let(:last_sync_info) { create :participant_sync_info_fellow,
    program: program,
    status: enrollment_status,
    cohort_schedule: cohort_schedule,
    cohort: cohort,
    cohort_section: cohort_section
  }

  before(:each) do
    allow(SyncSalesforceContact).to receive(:new).and_return(sync_contact_service)
    allow(sync_contact_service).to receive(:run).and_return(user)
    allow(CreateSection).to receive(:new).and_return(create_section_service)
    allow(create_section_service).to receive(:run)
  end

  describe '#run' do
    subject(:run_sync) do
      SyncSalesforceParticipant.new(sis_import_data_set, program, participant).run
    end

    context 'for Enrolled Participant' do
      let(:enrollment_status) { HerokuConnect::Participant::Status::ENROLLED }

      shared_examples 'syncs user' do
        it 'syncs the Contact' do
          expect(SyncSalesforceContact).to receive(:new)
            .with(participant.contact_id, program.time_zone)
            .and_return(sync_contact_service).once
          expect(sync_contact_service).to receive(:run).once
          run_sync
        end

        it 'adds the Canvas user to the SisImport' do
          expect(sis_import_data_set).to receive(:add_user).with(user).once
          run_sync
        end
      end

      context 'when new user' do
        before(:each) do
          User.destroy(participant.user_id)
          participant.user_id = nil
          participant.canvas_user_id = nil
        end

        it_behaves_like 'syncs user'

        it 'sets the user on ParticipantSyncInfo' do
          expect(participant.user).to be(nil) # sanity check
          run_sync
          expect(participant.user).to eq(user)
        end
      end

      context 'when existing user' do
        context 'when no Contact changes' do
          it 'doesnt sync the Contact' do
            expect(SyncSalesforceContact).not_to receive(:new)
            run_sync
          end
        end

        context 'when there are Contact changes' do
          before(:each) do
            participant.first_name = 'newFirstName'
          end
          it_behaves_like 'syncs user'
        end
      end

     context 'with enrollment changes' do
       before(:each) do
         allow(sis_import_data_set).to receive(:add_section)
         allow(sis_import_data_set).to receive(:add_enrollment)

         # ensure there is an enrollment change
         participant
         last_sync_info.update!(status: HerokuConnect::Participant::Status::DROPPED)
         expect(participant.enrollments_changed?).to eq(true)
       end

       # Set a cohort_schedule_section_to_test to either the Accelerator or LC Playbook section
       # before calling this.
       shared_examples 'handles Cohort Schedule section' do
         context 'for missing Cohort Schedule section' do
           it 'raises error if Participant doesnt have Cohort Schedule set' do
             participant.cohort_schedule_id = nil
             expect{run_sync}.to raise_error(SyncSalesforceProgram::NoCohortScheduleError)
           end

           it 'raises error if local Cohort Schedule section is missing' do
             cohort_schedule_section_to_test.destroy
             expect{run_sync}.to raise_error(SyncSalesforceProgram::MissingSectionError)
           end
         end

         it 'updates the local section name when it changes' do
           old_name = 'someOldName'
           cohort_schedule_section_to_test.update!(name: old_name)
           expect{run_sync}.to change{cohort_schedule_section_to_test.reload.name}
             .from(old_name).to(participant.cohort_schedule_section_name)
         end

         it 'adds the same Canvas section to the SisImport (with same SIS ID) even if the section name changes' do
           old_name = 'someOldName'
           cohort_schedule_section_to_test.update!(name: old_name)
           expect(sis_import_data_set).to receive(:add_section).with(cohort_schedule_section_to_test).once
           run_sync
         end

         it 'adds the Canvas section to the SisImport' do
           expect(sis_import_data_set).to receive(:add_section).with(cohort_schedule_section_to_test).once
           run_sync
         end

         it 'enrolls them in the local Cohort Schedule section' do
           if participant.cohort_id.blank? # only applies to unmapped Participants
             participant.user.remove_role participant.accelerator_course_role, cohort_schedule_section_to_test
             expect(participant.user.reload.has_role?(participant.accelerator_course_role, cohort_schedule_section_to_test)).to eq(false)
             run_sync
             expect(participant.user.reload.has_role?(participant.accelerator_course_role, cohort_schedule_section_to_test)).to eq(true)
           end
         end

         it 'enrolls them in the Canvas Cohort Schedule section' do
           canvas_role = participant.accelerator_course_role if cohort_schedule_section_to_test.course == program.accelerator_course
           canvas_role = participant.lc_playbook_course_role if cohort_schedule_section_to_test.course == program.lc_playbook_course
           expect(sis_import_data_set).to receive(:add_enrollment)
             .with(user, cohort_schedule_section_to_test, canvas_role, limit_section_privileges).once
           run_sync
         end
       end

       shared_examples 'handles Cohort section' do
         before(:each) do
           allow(sis_import_data_set).to receive(:add_section)
           allow(sis_import_data_set).to receive(:add_enrollment)
         end

         context 'for missing Cohort section' do
           # build instead of create so it's just in memory, not in the db.
           let(:cohort_section) { build :cohort_section,
             cohort: cohort,
             course: program.accelerator_course
           }
           # use a raw participant instead of Fellow or LC so they're not enrolled in a section (which creates one).
           let(:participant_raw) { build :heroku_connect_fellow_participant }
           let(:last_sync_info) { build :participant_sync_info_with_cohort,
             participant: participant_raw,
             program: program,
             status: enrollment_status,
             cohort_schedule: cohort_schedule,
             cohort: cohort,
             cohort_section: nil
           }

           it 'doesnt raise an error' do
             participant.cohort_id = nil
             expect{run_sync}.not_to raise_error
           end

           it 'creates local Cohort section if missing' do
             expect(create_section_service).to receive(:run) do
               cohort_section.save!
               cohort_section
             end
             expect{run_sync}.to change(Section, :count).by(1)
           end
         end

         it 'updates the local section name when it changes' do
           old_name = 'someOldName'
           cohort_section.update!(name: old_name)
           expect{run_sync}.to change{cohort_section.reload.name}
             .from(old_name).to(participant.cohort_section_name)
         end

         it 'adds the same Canvas section to the SisImport (with same SIS ID) even if the section name changes' do
           old_name = 'someOldName'
           cohort_section.update!(name: old_name)
           expect(sis_import_data_set).to receive(:add_section).with(cohort_section).once
           run_sync
         end

         it 'adds the Canvas section to the SisImport' do
           expect(sis_import_data_set).to receive(:add_section).with(cohort_section).once
           run_sync
         end

         it 'enrolls them in the local Cohort section' do
           if participant.cohort_id.present? # only applies to mapped Participants
             participant.user.remove_role participant.accelerator_course_role, cohort_section
             expect(participant.user.reload.has_role?(participant.accelerator_course_role, cohort_section)).to eq(false)
             run_sync
             expect(participant.user.reload.has_role?(participant.accelerator_course_role, cohort_section)).to eq(true)
           end
         end

         it 'enrolls them in the Canvas Cohort section' do
           expect(sis_import_data_set).to receive(:add_enrollment)
             .with(user, cohort_section, participant.accelerator_course_role, limit_section_privileges).once
           run_sync
         end

       end

       # Set the ta_section_to_test before calling this.
       shared_examples 'handles Teaching Assistants section' do
         let(:limit_section_privileges) { false }

         before(:each) do
           allow(sis_import_data_set).to receive(:add_section)
           allow(sis_import_data_set).to receive(:add_enrollment)
         end

         context 'for missing Teaching Assistants section' do
           it 'raises error if local section is missing' do
             ta_section_to_test.destroy
             expect{run_sync}.to raise_error(SyncSalesforceProgram::MissingSectionError)
           end
         end

         it 'adds the Canvas section to the SisImport' do
           expect(sis_import_data_set).to receive(:add_section).with(ta_section_to_test).once
           run_sync
         end

         it 'enrolls them in the local Teaching Assistants section' do
           participant.user.remove_role participant.accelerator_course_role, ta_section_to_test
           expect(participant.user.reload.has_role?(participant.accelerator_course_role, ta_section_to_test)).to eq(false)
           run_sync
           expect(participant.user.reload.has_role?(participant.accelerator_course_role, ta_section_to_test)).to eq(true)
         end

         it 'enrolls them in the Canvas Teaching Assistants section' do
           canvas_role = participant.accelerator_course_role if ta_section_to_test.course == program.accelerator_course
           canvas_role = participant.lc_playbook_course_role if ta_section_to_test.course == program.lc_playbook_course
           expect(sis_import_data_set).to receive(:add_enrollment)
             .with(user, ta_section_to_test, canvas_role, limit_section_privileges).once
           run_sync
         end
       end # 'handles Teaching Assistants section'

       # Set the participant to have an item in ta_caseload_enrollments before calling this
       shared_examples 'handles TA Caseloads' do
         let(:ta_caseload_section) { create :ta_caseload_section,
           course: program.accelerator_course,
           ta_caseload_info: participant.ta_caseload_enrollments.first
         }

         before(:each) do
           allow(sis_import_data_set).to receive(:add_section)
           allow(sis_import_data_set).to receive(:add_enrollment)
         end

         context 'for missing TA Caseload section' do
           # build instead of create so it's just in memory, not in the db.
           let(:ta_caseload_section) { build :ta_caseload_section,
             course: program.accelerator_course,
             ta_caseload_info: participant.ta_caseload_enrollments.first
           }
           it 'creates local TA Caseload section if missing' do
             expect(create_section_service).to receive(:run) do
               ta_caseload_section.save!
               ta_caseload_section
             end
             expect{run_sync}.to change(Section, :count).by(1)
           end
         end

         it 'adds the Canvas section to the SisImport' do
           expect(sis_import_data_set).to receive(:add_section).with(ta_caseload_section).once
           run_sync
         end

         # The local section is created just to be able to get an SIS ID, but doesn't
         # control any features or policies.
         it 'does not enroll them in the local TA Caseload section' do
           run_sync
           expect(participant.user.roles.where(resource: ta_caseload_section).blank?).to eq(true)
         end

         it 'enrolls them in the Canvas TA Caseload section' do
           expect(sis_import_data_set).to receive(:add_enrollment)
             .with(user, ta_caseload_section, participant.accelerator_course_role, limit_section_privileges).once
           run_sync
         end
       end

       context 'for Fellow' do
         let(:cohort_schedule_section_to_test) { participant.accelerator_cohort_schedule_section }

         context 'with Cohort mapped' do
           let(:last_sync_info) { create :participant_sync_info_fellow,
             program: program,
             status: enrollment_status,
             cohort_schedule: cohort_schedule,
             cohort: cohort,
             cohort_section: cohort_section
           }

           it_behaves_like 'handles Cohort Schedule section'
           it_behaves_like 'handles Cohort section'
         end

         context 'with Cohort not mapped' do
           let(:last_sync_info) { create :participant_sync_info_fellow_unmapped,
             program: program,
             status: enrollment_status,
             cohort_schedule: cohort_schedule,
             cohort: nil,
             cohort_section: nil
           }
           it_behaves_like 'handles Cohort Schedule section'
         end

         context 'with TA Assignments' do
           let(:last_sync_info) { create :participant_sync_info_fellow_with_ta_caseload,
             program: program,
             status: enrollment_status
           }
           it_behaves_like 'handles TA Caseloads'
         end
       end

       context 'for LC' do
         let(:last_sync_info) { create :participant_sync_info_lc,
           program: program,
           status: enrollment_status,
           cohort_schedule: cohort_schedule,
           cohort: cohort,
           cohort_section: cohort_section
         }
         context 'in Accelerator course' do
           let(:cohort_schedule_section_to_test) { participant.accelerator_cohort_schedule_section }
           it_behaves_like 'handles Cohort Schedule section'
         end

         context 'in LC Playbook course' do
           let(:cohort_schedule_section_to_test) { participant.lc_playbook_cohort_schedule_section }
           it_behaves_like 'handles Cohort Schedule section'
         end
       end

       context 'for Teaching Assistant' do
         let(:last_sync_info) { create :participant_sync_info_ta,
           program: program,
           status: enrollment_status
         }
         context 'in Accelerator course' do
           let(:ta_section_to_test) { participant.accelerator_ta_section }
           it_behaves_like 'handles Teaching Assistants section'
         end

         context 'in LC Playbook course' do
           let(:ta_section_to_test) { participant.lc_playbook_ta_section }
           it_behaves_like 'handles Teaching Assistants section'
         end

         it 'adds the Staff Account role to the SisImport' do
           expect(sis_import_data_set).to receive(:add_staff_account_role).with(participant.user).once
           run_sync
         end

         it 'gives them the local CanTakeAttendanceForAll? role' do
           expect(participant.user.has_role?(RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL)).to eq(false)
           run_sync
           expect(participant.user.reload.has_role?(RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL)).to eq(true)
         end

         context 'with TA Assignments' do
           let(:last_sync_info) { create :participant_sync_info_ta_with_ta_caseload,
             program: program,
             status: enrollment_status
           }
           it_behaves_like 'handles TA Caseloads'
         end
       end

      # TODO: check Staff, CP, and Faculty too.

      end # 'with enrollment changes'
    end # 'for Enrolled Participant'

    context 'for Dropped Participant' do
      let(:enrollment_status) { HerokuConnect::Participant::Status::DROPPED }
      let(:program2) { build :heroku_connect_program_launched }
      let(:cohort_schedule2) { build :heroku_connect_cohort_schedule, program: program2 }
      let!(:cohort_schedule_section2) { create :cohort_schedule_section,
        cohort_schedule: cohort_schedule2,
        course: program2.accelerator_course
      }

      shared_examples 'doesnt add to the Canvas SisImport' do
        it 'doesnt call add_xxx' do
          expect(sis_import_data_set).not_to receive(:add_user)
          expect(sis_import_data_set).not_to receive(:add_section)
          expect(sis_import_data_set).not_to receive(:add_enrollment)
          expect(sis_import_data_set).not_to receive(:add_staff_account_role)
          run_sync
        end
      end

      shared_examples 'syncs user' do
        it 'doesnt sync the Contact' do
          expect(SyncSalesforceContact).not_to receive(:new)
          expect(sync_contact_service).not_to receive(:run)
          run_sync
        end

        it_behaves_like 'doesnt add to the Canvas SisImport'
      end

      context 'when new user' do
        before(:each) do
          User.destroy(participant.user_id)
          participant.user_id = nil
          participant.canvas_user_id = nil
        end

        it_behaves_like 'syncs user'
        it_behaves_like 'doesnt add to the Canvas SisImport'

        it 'doesnt set the user on ParticipantSyncInfo' do
          run_sync
          expect(participant.user).to be(nil)
        end

        it 'doesnt create a User' do
          expect{run_sync}.to change(User, :count).by(0)
        end

      end

      context 'when existing user' do
        context 'when no Contact changes' do
          it 'doesnt sync the Contact' do
            expect(SyncSalesforceContact).not_to receive(:new)
            run_sync
          end
        end

        context 'when there are Contact changes' do
          before(:each) do
            participant.first_name = 'newFirstName'
          end
          it_behaves_like 'syncs user'
        end

        context 'when there are no enrollment changes' do
          it 'skips local User roles' do
            expect(participant.accelerator_enrollment_changed?).to eq(false) #sanity check
            expect(participant.user).not_to receive(:remove_section_roles)
            run_sync
          end
          it_behaves_like 'doesnt add to the Canvas SisImport'
        end

        context 'when there are enrollment changes' do
          before(:each) do
            participant
            last_sync_info.update!(status: HerokuConnect::Participant::Status::ENROLLED)
            expect(participant.enrollments_changed?).to eq(true)
          end

          shared_examples 'drops Accelerator enrollments' do
            it_behaves_like 'doesnt add to the Canvas SisImport'

            it 'drops local User section roles' do
              expect(participant.accelerator_enrollment_changed?).to eq(true) #sanity check
              allow(participant.user).to receive(:remove_section_roles)
              expect(participant.user).to receive(:remove_section_roles).with(program.accelerator_course).and_call_original.once
              run_sync
              expect((participant.user.roles & program.accelerator_course.roles).empty?).to eq(true)
            end

            it 'doesnt drop Section roles from other courses' do
              participant.user.add_role(participant.accelerator_course_role, cohort_schedule_section2)
              expect(participant.user.roles.where(name: participant.accelerator_course_role).count).to eq(2)
              run_sync
              expect(participant.user.roles.where(name: participant.accelerator_course_role).count).to eq(1)
              expect(participant.user.has_role?(participant.accelerator_course_role, cohort_schedule_section2)).to eq(true)
            end
          end

          shared_examples 'drops LC Playbook enrollments' do
            it_behaves_like 'doesnt add to the Canvas SisImport'

            it 'drops local User section roles' do
              expect(participant.lc_playbook_enrollment_changed?).to eq(true) #sanity check
              allow(participant.user).to receive(:remove_section_roles)
              expect(participant.user).to receive(:remove_section_roles).with(program.lc_playbook_course).and_call_original.once
              run_sync
              expect((participant.user.roles & program.lc_playbook_course.roles).empty?).to eq(true)
            end

            it 'doesnt drop Section roles from other courses' do
              participant.user.add_role(participant.lc_playbook_course_role, cohort_schedule_section2)
              expect(participant.user.roles.count).to eq(3)
              run_sync
              expect(participant.user.roles.count).to eq(1)
              expect(participant.user.has_role?(participant.lc_playbook_course_role, cohort_schedule_section2)).to eq(true)
            end
          end

          context 'for Fellow' do
            let(:last_sync_info) { create :participant_sync_info_fellow,
              program: program,
              status: enrollment_status,
              cohort_schedule: cohort_schedule,
              cohort: cohort,
              cohort_section: cohort_section
            }
            it_behaves_like 'drops Accelerator enrollments'

            context 'with TA Assignments' do
              let(:last_sync_info) { create :participant_sync_info_fellow_with_ta_caseload,
                program: program,
                status: enrollment_status
              }
              it_behaves_like 'doesnt add to the Canvas SisImport'
            end
          end

          context 'for LC' do
            let(:last_sync_info) { create :participant_sync_info_lc,
              program: program,
              status: enrollment_status,
              cohort_schedule: cohort_schedule,
              cohort: cohort,
              cohort_section: cohort_section
            }
            it_behaves_like 'drops Accelerator enrollments'
            it_behaves_like 'drops LC Playbook enrollments'
          end

          context 'for Teaching Assistant' do
            let(:last_sync_info) { create :participant_sync_info_ta,
              program: program,
              status: enrollment_status
            }
            it_behaves_like 'doesnt add to the Canvas SisImport'
            it_behaves_like 'drops Accelerator enrollments'
            it_behaves_like 'drops LC Playbook enrollments'

            it 'removes the local CanTakeAttendanceForAll? role' do
              participant.user.add_role(RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL)
              expect(participant.user.reload.has_role?(RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL)).to eq(true)
              run_sync
              expect(participant.user.reload.has_role?(RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL)).to eq(false)
            end

            context 'with TA Assignments' do
              let(:last_sync_info) { create :participant_sync_info_ta_with_ta_caseload,
                program: program,
                status: enrollment_status
              }
              it_behaves_like 'doesnt add to the Canvas SisImport'
            end
          end
        end

      end # 'when existing user'

    end # 'for Dropped Participant'

  end # '#run'
end
