require 'rails_helper'

RSpec.describe Role, type: :model do
  #############
  # Validations
  #############
  
  it { should validate_presence_of :name }

  describe 'validating uniqueness' do
    before { create :role }
    it { should validate_uniqueness_of(:name).case_insensitive }
  end
  
  ##############
  # Associations 
  ##############

  it { should have_many :program_memberships }
  it { should have_many(:users).through(:program_memberships) }
  it { should have_many(:programs).through(:program_memberships) }
  
  ##################
  # Instance methods
  ##################

  describe '#to_show' do
    let(:role) { build :role, name: 'Role' }
    subject { role.to_show }
    
    it { should eq({'name' => 'Role'}) }
  end
end
