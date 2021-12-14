require 'rails_helper'

RSpec.describe HerokuConnect::CohortSchedule, type: :model do

  let(:cohort_schedule) { build :heroku_connect_cohort_schedule }
  subject { cohort_schedule }

  describe 'database' do
    # This is important b/c the Staging Sandbox Heroku Connect mappings
    # MUST exist and match the production mappings. We have CI configured
    # to point to a production follower DB, so it should tell us if there
    # is a mapping missing before deploying to prod
    HerokuConnect::CohortSchedule.default_columns.each do |column_name|
      it { is_expected.to have_db_column(column_name) }
    end

    it { should have_many(:participants) }
    it { should have_many(:cohorts) }
    it { should belong_to(:program) }

    it { should have_db_index(:sfid) }
    it { should have_db_index(:program__c) }
  end

  describe '#canvas_section_name' do
    let(:cohort_schedule) { build :heroku_connect_cohort_schedule, weekday__c: weekday, time__c: time}

    context 'with nil weekday and time' do
      let(:time) { nil }
      let(:weekday) { nil }
      it { is_expected.to have_attributes(:canvas_section_name => 'UnknownWeekday') }
    end

    context 'with nil weekday' do
      let(:time) { '6-8pm' }
      let(:weekday) { nil }
      it { is_expected.to have_attributes(:canvas_section_name => "UnknownWeekday, #{time}") }
    end

    context 'with nil time' do
      let(:time) { nil }
      let(:weekday) { 'Thursday' }
      it { is_expected.to have_attributes(:canvas_section_name => weekday) }
    end

    context 'with weekday and time' do
      let(:time) { '6-8pm' }
      let(:weekday) { 'Thursday' }
      it { is_expected.to have_attributes(:canvas_section_name => "#{weekday}, #{time}") }
    end
  end

  describe '#save' do
    it 'does not allow saving' do
      expect { cohort_schedule.save! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

end
