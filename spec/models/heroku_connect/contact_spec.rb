require 'rails_helper'

RSpec.describe HerokuConnect::Contact, type: :model do

  let(:contact) { build :heroku_connect_contact }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to production, so it should tell us if there is a mapping missing
    # before deploying to prod
    HerokuConnect::Contact.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should have_many(:participants) }
    it { should have_many(:candidates) }

    it { should have_db_index(:sfid) }
    it { should have_db_index(:email) }
    it { should have_db_index(:canvas_cloud_user_id__c) }
    it { should have_db_index(:discord_user_id__c) }
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { contact.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
