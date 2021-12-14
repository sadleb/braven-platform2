require 'rails_helper'

RSpec.describe HerokuConnect::Participant, type: :model do

  let(:participant) { build :heroku_connect_participant }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to a production follower DB, so it should tell us if there
    # is a mapping missing before deploying to prod
    HerokuConnect::Participant.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should belong_to(:contact) }
    it { should belong_to(:candidate) }
    it { should belong_to(:program) }
    it { should belong_to(:cohort) }
    it { should belong_to(:cohort_schedule) }
    it { should belong_to(:record_type) }

    it { should have_db_index(:sfid) }
    it { should have_db_index(:recordtypeid) }
    it { should have_db_index(:contact__c) }
    it { should have_db_index(:candidate__c) }
    it { should have_db_index(:program__c) }
    it { should have_db_index(:cohort__c) }
    it { should have_db_index(:cohort_schedule__c) }
  end

  describe '#teaching_assistant_sections' do
    let(:ta_assignments_collection) { instance_double(ActiveRecord::Associations::CollectionProxy) }
    let(:ta_assignments) { [] }
    let(:ta_caseloads_collection) { instance_double(ActiveRecord::Associations::CollectionProxy) }
    let(:ta_caseloads) { [] }
    let(:participant) { build :heroku_connect_participant }

    before(:each) do
      # These are not stored in the DB, so we need to stub it out.
      allow(ta_assignments_collection).to receive(:exists?).and_return(ta_assignments.present?)
      allow(ta_assignments_collection).to receive(:each).and_return(ta_assignments)
      allow(participant).to receive(:ta_assignments).and_return(ta_assignments_collection)
      allow(ta_caseloads_collection).to receive(:exists?).and_return(ta_caseloads.present?)
      allow(participant).to receive(:ta_caseloads).and_return(ta_caseloads_collection)
    end

    context 'no ta_assignments or ta_caseloads' do
      it 'returns an empty list' do
        expect(participant.teaching_assistant_sections).to eq([])
      end
    end

    context 'for Fellow' do
      let(:ta_assignment1) { build :heroku_connect_ta_assignment }
      let(:ta_assignments) { [ta_assignment1] }
      let(:participant) { ta_assignment1.fellow_participant }

      context 'with one ta_assignment' do
        it 'returns the TAs name in the list' do
          expect(participant.teaching_assistant_sections).to eq([ta_assignment1.ta_participant.full_name])
        end
      end

      context 'with two ta_assignments' do
        let(:ta_assignment2) { build :heroku_connect_ta_assignment, fellow_participant: participant }
        let(:ta_assignments) { [ta_assignment1, ta_assignment2] }

        it 'returns both TAs names in the list' do
          expect(participant.teaching_assistant_sections)
            .to eq([ta_assignment1.ta_participant.full_name, ta_assignment2.ta_participant.full_name])
        end
      end
    end

    context 'for TA' do
      let(:ta_assignment1) { build :heroku_connect_ta_assignment }
      let(:ta_caseloads) { [ta_assignment1] }
      let(:participant) { ta_assignment1.ta_participant }

      it 'returns this TAs name in the list' do
        expect(participant.teaching_assistant_sections).to eq([participant.full_name])
      end
    end
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { participant.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
