require 'rails_helper'

RSpec.describe User, type: :model do

  ##############
  # Associations
  ##############

  #############
  # Validations
  #############

  it { should validate_presence_of :email }
  it { should validate_presence_of :first_name }
  it { should validate_presence_of :last_name }

  describe 'validating uniqueness' do
    before { create :registered_user }
    
    it { should validate_uniqueness_of(:email).case_insensitive }
  end
  
  ###########
  # Callbacks
  ###########

  describe '.create' do
    let(:sf_contact) { build(:salesforce_contact) }
    let(:canvas_user) { build(:canvas_user) }
    let(:sf_api_client) { instance_double(SalesforceAPI) }
    let!(:sf_api) { class_double(SalesforceAPI, :client => sf_api_client).as_stubbed_const(:transfer_nested_constants => true) }
    let(:canvas_api_client) { instance_double(CanvasAPI, :find_user_in_canvas => nil, :get_user_enrollments => nil, :get_sections => []) }
    let!(:canvas_api) { class_double(CanvasAPI, :client => canvas_api_client).as_stubbed_const(:transfer_nested_constants => true) }

  end

  ##################
  # Instance methods
  ##################

  describe 'full_name' do
    let(:user) { build :registered_user }
    
    subject { user.full_name }
    it { should eq("#{user.first_name} #{user.last_name}") }
  end

  describe '#sections' do
    let(:user) { create :registered_user }
    subject { user.sections }

    context 'no roles in sections' do
      it { should eq([])}
    end

    context 'no roles in sections' do
      before(:each) do
        user.add_role :admin
      end

      it { should eq([])}
    end

    context 'multiple roles in same section of course' do
      let(:course) { create :course }
      let(:section) { create :section }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        user.add_role RoleConstants::TA_ENROLLMENT, section
      end

      it { should eq([section])}
    end

    context 'multiple roles in different courses' do
      let(:accelerator_course) { create :course }
      let(:accelerator_section) { create :section, course: accelerator_course }
      let(:lc_playbook_course) { create :course }
      let(:lc_playbook_section) { create :section, course: lc_playbook_course }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, lc_playbook_section
        user.add_role RoleConstants::TA_ENROLLMENT, accelerator_section
      end

      it { should contain_exactly(accelerator_section, lc_playbook_section) }
    end
  end
end
