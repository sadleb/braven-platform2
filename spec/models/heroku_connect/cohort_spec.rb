require 'rails_helper'

RSpec.describe HerokuConnect::Cohort, type: :model do

  let(:cohort) { build :heroku_connect_cohort }
  subject { cohort }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to a production follower DB, so it should tell us if there
    # is a mapping missing before deploying to prod
    HerokuConnect::Cohort.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should have_many(:participants) }
    it { should belong_to(:program) }
    it { should belong_to(:cohort_schedule) }

    it { should have_db_index(:sfid) }
    it { should have_db_index(:program__c) }
    it { should have_db_index(:cohort_schedule__c) }
  end

  # For legacy reasons the primary LC when there are co-LCs is stored in dlrs_lc1_xxx
  # fields while the secondary LC is stored in dlrs_lc_xxx. This method just re-implements
  # the formula for the Zoom_Prefix__c field in Salesforce since Heroku Connect can't
  # sync formula fields.
  describe '#zoom_prefix' do
    # defauls: override in tests
    let(:lc1_first_name) { nil }
    let(:lc1_last_name) { nil }
    let(:lc2_first_name) { nil }
    let(:lc2_last_name) { nil }

    let(:cohort) {
      build(:heroku_connect_cohort,
        dlrs_lc1_first_name__c: lc1_first_name,
        dlrs_lc1_last_name__c: lc1_last_name,
        dlrs_lc_firstname__c: lc2_first_name,
        dlrs_lc_lastname__c: lc2_last_name,
        dlrs_lc_total__c: lc_count,
      )
    }

    context 'with missing names' do
      let(:lc_count) { nil }
      it { is_expected.to have_attributes(:zoom_prefix => nil) }
    end

    context 'with one LC' do
      let(:lc_count) { 1 }

      context 'with first name only' do
        let(:lc1_first_name) { 'PrimaryLCFirst' }
        it { is_expected.to have_attributes(:zoom_prefix => lc1_first_name) }
      end

      context 'with first name and last name' do
        let(:lc1_first_name) { 'PrimaryLCFirst' }
        let(:lc1_last_name) { 'PrimaryLCLast' }
        it { is_expected.to have_attributes(:zoom_prefix => 'PrimaryLCFirst P.') }
      end
    end

    context 'when two LCs' do
      let(:lc_count) { 2 }

      context 'with primary first name' do
        let(:lc1_first_name) { 'PrimaryLCFirst' }
        it { is_expected.to have_attributes(:zoom_prefix => 'PrimaryLCFirst') }

        context 'with secondary first name' do
          let(:lc2_first_name) { 'SecondaryLCFirst' }
          it { is_expected.to have_attributes(:zoom_prefix => 'PrimaryLCFirst / SecondaryLCFirst') }

          context 'and last name' do
            let(:lc2_last_name) { 'SecondaryLCLast' }
            it { is_expected.to have_attributes(:zoom_prefix => 'PrimaryLCFirst / SecondaryLCFirst S.') }
          end
        end
      end

      context 'with primary first name and last name' do
        let(:lc1_first_name) { 'PrimaryLCFirst' }
        let(:lc1_last_name) { 'PrimaryLCLast' }
        it { is_expected.to have_attributes(:zoom_prefix => 'PrimaryLCFirst P.') }

        context 'with secondary first name' do
          let(:lc2_first_name) { 'SecondaryLCFirst' }
          it { is_expected.to have_attributes(:zoom_prefix => 'PrimaryLCFirst P. / SecondaryLCFirst') }

          context 'and last name' do
            let(:lc2_last_name) { 'SecondaryLCLast' }
            it { is_expected.to have_attributes(:zoom_prefix => 'PrimaryLCFirst P. / SecondaryLCFirst S.') }
          end
        end
      end
    end
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { cohort.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
