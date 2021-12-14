require 'rails_helper'

RSpec.describe HerokuConnect::TaAssignment, type: :model do

  let(:ta_assignment) { build :heroku_connect_ta_assignment }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to a production follower DB, so it should tell us if there
    # is a mapping missing before deploying to prod
    HerokuConnect::TaAssignment.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should belong_to(:fellow_participant) }
    it { should belong_to(:ta_participant) }
    it { should belong_to(:program) }

    it { should have_db_index(:sfid) }
    it { should have_db_index(:program__c) }
    it { should have_db_index(:fellow_participant__c) }
    it { should have_db_index(:ta_participant__c) }
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { ta_assignment.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
