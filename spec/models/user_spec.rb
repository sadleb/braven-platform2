require 'rails_helper'

RSpec.describe User, type: :model do

  ##############
  # Associations
  ##############

  it { should have_many :program_memberships }
  it { should have_many(:programs).through(:program_memberships) }
  it { should have_many(:roles).through(:program_memberships) }

  #############
  # Validations
  #############

  it { should validate_presence_of :email }
  it { should validate_presence_of :first_name }
  it { should validate_presence_of :last_name }

  describe 'validating uniqueness' do
    before { create :user }
    
    it { should validate_uniqueness_of(:email).case_insensitive }
  end
  
  ###########
  # Callbacks
  ###########

  describe '.create' do
    context 'when bebraven.org email' do
      it "sets admin true" do
        user = create :user, email: 'test@bebraven.org'
        expect(user.reload.admin).to be(true)
      end
    end

    context "when non-braven email" do
      it "sets admin to false" do
        user = create :user, email: 'bob@example.com'
        expect(user.reload.admin).to be(false)
      end
    end

    context "when salesforce_id is set" do
      let(:sf_contact) { build(:salesforce_contact) }
      let(:sf_api) { class_double(SalesforceAPI).as_stubbed_const(:transfer_nested_constants => true) }
      let(:sf_api_client) { instance_double(SalesforceAPI, :get_contact_info => sf_contact) }
  
      it 'email and name are fetched from the salesforce_api and set' do
        allow(sf_api_client).to receive(:get_contact_info).and_return(sf_contact)
        allow(sf_api).to receive(:client).and_return(sf_api_client)

        user = create :user, salesforce_id: sf_contact['Id']

        user = user.reload
        expect(user.first_name).to eq(sf_contact['FirstName'])
        expect(user.last_name).to eq(sf_contact['LastName'])
        expect(user.email).to eq(sf_contact['Email'])
      end
    end

    context "when salesforce_id is not set" do
      let(:sf_api) { class_double(SalesforceAPI).as_stubbed_const(:transfer_nested_constants => true) }
      it 'the name and email are left alone' do
        user = create :user, first_name: 'fname', last_name: 'lname', email: 'test@email.com'
        user = user.reload
        expect(user.first_name).to eq('fname')
        expect(user.last_name).to eq('lname')
        expect(user.email).to eq('test@email.com')
        expect(sf_api).not_to receive(:client)
      end   
    end
  end

  ##################
  # Instance methods
  ##################

  describe 'full_name' do
    let(:user) { build :user, first_name: 'Bob', last_name: 'Smith' }
    
    subject { user.full_name }
    it { should eq('Bob Smith') }
  end
 
  describe '#start_membership(program_id, role_id)' do
    let!(:user) { create :user }
    let!(:program) { create :program }
    let!(:role) { create :role }
    
    subject { user.start_membership(program.id, role.id) }
    
    describe "when membership doesn't already exist" do
      it { expect(subject.user).to eq(user) }
      it { expect(subject.program).to eq(program) }
      it { expect(subject.role).to eq(role) }
      it { expect(subject.start_date).to eq(Date.today) }
      it { expect(subject.end_date).to eq(nil) }
    end
    
    describe 'when membership aleady exists' do
      let(:start_date) { Date.today - 100 }
      let!(:program_membership) { create :program_membership, user: user, program: program, role: role, start_date: start_date }
      
      it { should eq(program_membership) }
      
      it { expect(subject.user).to eq(user) }
      it { expect(subject.program).to eq(program) }
      it { expect(subject.role).to eq(role) }
      it { expect(subject.start_date).to eq(start_date) }
      it { expect(subject.end_date).to eq(nil) }
    end
  end
  
  describe '#end_membership(program_id, role_id)' do
    let!(:user) { create :user }
    let!(:program) { create :program }
    let!(:role) { create :role }
    let(:start_date) { Date.today - 100 }
    
    subject { user.end_membership(program.id, role.id) }
  
    describe 'when membership exists' do
      let!(:program_membership) { create :program_membership, user: user, program: program, role: role, start_date: start_date }
    
      it { should be_truthy }
      it { subject; expect(program_membership.reload.end_date).to eq(Date.yesterday) }
    end
    
    describe 'when membership does not exist' do
      it { should be_falsey }
    end
  end
  
  describe '#update_membership(program_id, old_role_id, new_role_id)' do
    let!(:user) { create :user }
    let!(:program) { create :program }
    let!(:old_role) { create :role, name: 'Old' }
    let!(:new_role) { create :role, name: 'New' }
    let!(:start_date) { Date.today - 100 }
    
    subject { user.update_membership(program.id, old_role.id, new_role.id) }

    describe 'when membership with old role exists' do
      let!(:program_membership) { create :program_membership, user: user, program: program, role: old_role, start_date: start_date }
    
      it { should be_truthy }
      
      it "ends the program membership with the old role" do
        expect(user).to receive(:end_membership).with(program.id, old_role.id)
        subject
      end
      
      it "creates a program membership with the new role" do
        expect(user).to receive(:start_membership).with(program.id, new_role.id)
        subject
      end
    end
    
    describe 'when membership does not exist' do
      it "attempts to end membership without breaking" do
        expect(user).to receive(:end_membership).with(program.id, old_role.id)
        subject
      end
      
      it "creates a program membership with the new role" do
        expect(user).to receive(:start_membership).with(program.id, new_role.id)
        subject
      end
    end
    
    describe 'when old role and new role are the same' do
      let(:new_role) { old_role }
      let!(:program_membership) { create :program_membership, user: user, program: program, role: old_role, start_date: start_date }
      
      it "does NOT attempt to end membership" do
        expect(user).to_not receive(:end_membership).with(program.id, old_role.id)
        subject
      end
      
      it "does NOT attempt to create a new membership" do
        expect(user).to_not receive(:start_membership).with(program.id, new_role.id)
        subject
      end
    end
  end
  
  describe '#current_membership(program_id)' do
    let!(:user) { create :user }
    let!(:program) { create :program }
    let!(:old_role) { create :role, name: 'Old' }
    let!(:new_role) { create :role, name: 'New' }

    let!(:old_membership) { create :program_membership, user: user, program: program, role: old_role, start_date: Date.today-100, end_date: Date.today-10 }
    let!(:new_membership) { create :program_membership, user: user, program: program, role: new_role, start_date: Date.today-9 }

    subject { user.reload.current_membership(program.id) }
    
    it { should eq(new_membership) }
  end
end
