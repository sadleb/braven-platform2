require 'rails_helper'

RSpec.describe HerokuConnect::RecordType, type: :model do

  let(:record_type) { build :heroku_connect_record_type }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to a production follower DB, so it should tell us if there
    # is a mapping missing before deploying to prod
    HerokuConnect::RecordType.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should have_many(:candidates) }
    it { should have_many(:participants) }
    it { should have_many(:programs) }

    it { should have_db_index(:sfid) }
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { record_type.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
