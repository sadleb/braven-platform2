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

  describe '#save' do
    it 'does not allow saving' do
      expect { participant.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
