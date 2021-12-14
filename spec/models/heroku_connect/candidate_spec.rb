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

  # This is actually stored in the coach_partner_role__c column for legacy reasons.
  # If that's not set, the role is assumed to be the Record Type. The formula field
  # in Salesforce is called "Volunteer_Role__c"
  describe '#candidate_role' do
    context 'with nil role' do
      let(:candidate) { build :heroku_connect_candidate, coach_partner_role__c: nil }
      it { is_expected.to have_attributes(:candidate_role => candidate.record_type.name) }
    end

    context 'when coach partner role set' do
      let(:candidate) { build :heroku_connect_candidate, coach_partner_role__c: HerokuConnect::Candidate::Role::COACH_PARTNER }
      it { is_expected.to have_attributes(:candidate_role => HerokuConnect::Candidate::Role::COACH_PARTNER) }
    end
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { candidate.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
