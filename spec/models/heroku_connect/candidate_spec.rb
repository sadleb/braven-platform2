require 'rails_helper'

RSpec.describe HerokuConnect::Candidate, type: :model do

  let(:candidate) { build :heroku_connect_candidate }
  subject { candidate }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to a production follower DB, so it should tell us if there
    # is a mapping missing before deploying to prod
    HerokuConnect::Candidate.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should belong_to(:contact) }
    it { should belong_to(:program) }
    it { should belong_to(:record_type) }
    it { should have_one(:participant) }

    it { should have_db_index(:sfid) }
    it { should have_db_index(:recordtypeid) }
    it { should have_db_index(:contact__c) }
    it { should have_db_index(:participant__c) }
    it { should have_db_index(:program__c) }
  end

  describe '#role' do
    context 'with nil candidate_role_select' do
      let(:candidate) { build :heroku_connect_candidate, coach_partner_role__c: nil }
      it { is_expected.to have_attributes(:role => candidate.record_type.name) }
    end

    context 'when coach partner role set' do
      let(:candidate) { build :heroku_connect_candidate, coach_partner_role__c: SalesforceConstants::Role::COACH_PARTNER }
      it { is_expected.to have_attributes(:role => SalesforceConstants::Role::COACH_PARTNER) }
    end
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { candidate.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

  describe '#is_teaching_assistant?' do
    context 'with a candidate who is a teaching assistant' do
      let(:candidate) { build :heroku_connect_ta_candidate, coach_partner_role__c: SalesforceConstants::Role::TEACHING_ASSISTANT}
      it 'returns true' do
        expect(candidate.is_teaching_assistant?).to eq(true)
      end
    end

    context 'with a candidate who has an empty role is a teaching assistant' do
      let(:candidate) { build :heroku_connect_ta_candidate, coach_partner_role__c: nil}
      it 'returns true' do
        expect(candidate.is_teaching_assistant?).to eq(true)
      end
    end

    context 'with a candidate who is not a teaching assistant (staff)' do
      let(:candidate) { build :heroku_connect_ta_candidate, coach_partner_role__c: SalesforceConstants::Role::STAFF }
      it 'returns true' do
        expect(candidate.is_teaching_assistant?).to eq(false)
      end
    end

    context 'with a test user candidate who is a teaching assistant' do
      let(:candidate) { build :heroku_connect_ta_candidate, coach_partner_role__c: :Test}
      it 'returns true' do
        expect(candidate.is_teaching_assistant?).to eq(true)
      end
    end
  end
end
