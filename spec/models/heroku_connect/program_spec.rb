require 'rails_helper'

RSpec.describe HerokuConnect::Program, type: :model do

  let(:program) { build :heroku_connect_program }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to a production follower DB, so it should tell us if there
    # is a mapping missing before deploying to prod
    HerokuConnect::Program.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should have_many(:candidates) }
    it { should have_many(:participants) }
    it { should have_many(:cohorts) }
    it { should have_many(:cohort_schedules) }
    it { should have_many(:ta_assignments) }
    it { should belong_to(:record_type) }

    it { should have_db_index(:sfid) }
    it { should have_db_index(:status__c) }
    it { should have_db_index(:recordtypeid) }
    it { should have_db_index(:canvas_cloud_accelerator_course_id__c) }
    it { should have_db_index(:canvas_cloud_lc_playbook_course_id__c) }
    it { should have_db_index(:discord_server_id__c) }
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { program.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
