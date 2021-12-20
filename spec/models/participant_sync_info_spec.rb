require 'rails_helper'

RSpec.describe ParticipantSyncInfo, type: :model do

  let(:participant) { build :heroku_connect_participant }

  describe 'database' do

    # TODO: test the sync_info scope
    # TODO: test the check_constraints
    # TODO: test the columns (null vs non-null too)
    # TODO: test the role and status columns returning a :symbol
    it { should have_db_index(:sfid) }
  end

  # TODO: write specs: https://app.asana.com/0/1201131148207877/1201515686512767

# The below use to be on HerokuConnect::Participant. Cut it over to the new
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

end
