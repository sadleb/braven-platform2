require 'rails_helper'

RSpec.describe ProgramMembership, type: :model do
  ##############
  # Associations
  ##############

  it { should belong_to :user }
  it { should belong_to :program }
  it { should belong_to :role }
  
  ########
  # Scopes
  ########

  describe '#current' do
    let!(:membership_end_past)    { create :program_membership, start_date: start_date, end_date: Date.today - 10 }
    let!(:membership_end_future)  { create :program_membership, start_date: start_date, end_date: Date.today + 10 }
    let!(:membership_end_today)   { create :program_membership, start_date: start_date, end_date: Date.today }
    let!(:membership_end_nil)     { create :program_membership, start_date: start_date }
    
    subject { ProgramMembership.current }

    describe 'when start date is in the past' do
      let(:start_date) { Date.today - 100 }
      
      it { should_not include(membership_end_past) }
      it { should     include(membership_end_future) }
      it { should     include(membership_end_today) }
      it { should     include(membership_end_nil) }
    end
    
    describe 'when start date is today' do
      let(:start_date) { Date.today }
      
      it { should_not include(membership_end_past) }
      it { should     include(membership_end_future) }
      it { should     include(membership_end_today) }
      it { should     include(membership_end_nil) }
    end
    
    describe 'when start date is in the future' do
      let(:start_date) { Date.today + 1 }
      
      it { should_not include(membership_end_past) }
      it { should_not include(membership_end_future) }
      it { should_not include(membership_end_today) }
      it { should_not include(membership_end_nil) }
    end
  end
  
  ##################
  # Instance methods
  ##################

  describe '#current?' do
    let(:program_membership) { build :program_membership, start_date: start_date, end_date: end_date }
    
    subject { program_membership.current? }

    describe 'when start date is in the past' do
      let(:start_date) { Date.today - 100 }
      
      describe 'and end date is in the past' do
        let(:end_date) { Date.today - 1}
        it { should be_falsey }
      end
      
      describe 'and end date is today' do
        let(:end_date) { Date.today }
        it { should be_truthy }
      end
      
      describe 'and end date is in the future' do
        let(:end_date) { Date.today + 100 }
        it { should be_truthy }
      end
      
      describe 'and end date is nil' do
        let(:end_date) { nil }
        it { should be_truthy }
      end
    end
    
    describe 'when start date is today' do
      let(:start_date) { Date.today }
      
      describe 'and end date is in the past' do
        let(:end_date) { Date.today - 1}
        it { should be_falsey }
      end
      
      describe 'and end date is today' do
        let(:end_date) { Date.today }
        it { should be_truthy }
      end
      
      describe 'and end date is in the future' do
        let(:end_date) { Date.today + 100 }
        it { should be_truthy }
      end
      
      describe 'and end date is nil' do
        let(:end_date) { nil }
        it { should be_truthy }
      end
    end
    
    describe 'when start date is in the future' do
      let(:start_date) { Date.today + 1 }
      
      describe 'and end date is in the past' do
        let(:end_date) { Date.today - 1}
        it { should be_falsey }
      end
      
      describe 'and end date is today' do
        let(:end_date) { Date.today }
        it { should be_falsey }
      end
      
      describe 'and end date is in the future' do
        let(:end_date) { Date.today + 100 }
        it { should be_falsey }
      end
      
      describe 'and end date is nil' do
        let(:end_date) { nil }
        it { should be_falsey }
      end
    end
  end
end
