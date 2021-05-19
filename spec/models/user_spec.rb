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
    it { should validate_uniqueness_of(:salesforce_id) }
    it { should validate_uniqueness_of(:signup_token) }
    it { should validate_uniqueness_of(:uuid) }
  end

  it { should validate_length_of(:salesforce_id).is_equal_to(18) }

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

    it 'sets uuid' do
      user = build(:user, uuid: nil)
      expect(user.uuid).to eq(nil)
      user.save!
      expect(user.uuid).not_to eq(nil)
      expect(user.uuid.length).to eq(SecureRandom.uuid.length)
    end
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

  describe '#ta_for?' do
    let(:course) { create :course }
    let(:section) { create :section, course: course }

    subject { user.ta_for?(target_user, course) }

    context 'target user is not a Fellow in the course' do
      let(:ta_section) { create :ta_section, course: course }
      let(:user) { create :ta_user, section: ta_section }

      context 'target user is a Fellow in another course' do
        let(:another_course) { create :course }
        let(:another_section) { create :section, course: another_course }
        let(:target_user) { create :fellow_user, section: another_section }
        it { should eq(false) }
      end

      context 'target user is not enrolled' do
        let(:target_user) { create :registered_user }
        it { should eq(false) }
      end

      context 'target user is another TA' do
        let(:target_user) { create :ta_user, section: ta_section, canvas_user_id: 111 }
        it { should eq(false) }
      end

      context 'target user is an LC' do
        let(:target_user) { create :ta_user, section: section, canvas_user_id: 111 }
        it { should eq(false) }
      end
    end

    context 'target user is a Fellow' do
      let(:target_user) { create :fellow_user, section: section }

      context 'user is TA in course' do
        let(:ta_section) { create :ta_section, course: course }
        let(:user) { create :ta_user, section: ta_section }
        it { should eq(true) }

        context 'with additional enrollment' do
          before(:each) do
            # This user is both a TA and an LC
            user.add_role RoleConstants::TA_ENROLLMENT, section
          end
          it { should eq(true) }
        end
      end

      context 'user is a TA in a different course' do
        let(:other_course) { create :course }
        let(:ta_section) { create :ta_section, course: other_course }
        let(:user) { create :ta_user, section: ta_section }
        it { should eq(false) }
      end

      context 'user is admin' do
        let(:user) { create :admin_user }
        it { should eq(false) }
      end

      context 'user is not enrolled' do
        let(:user) { create :registered_user }
        it { should eq(false) }
      end

      context 'user is in the same section' do
        context 'as LC' do
          let(:user) { create :ta_user, section: section }
          it { should eq(false) }
        end

        context 'as Fellow' do
          let(:user) { create :peer_user, section: section }
          it { should eq(false) }
        end
      end
    end

    context 'is TA for target but in different course' do
      let(:another_course) { create :course }

      let(:ta_section) { create :ta_section, course: another_course }
      let(:user) { create :ta_user, section: ta_section }

      let(:another_section) { create :section, course: another_course }
      let(:target_user) { create :fellow_user, section: another_section }

      it { should eq(false) }
    end
  end

  describe '#lc_for?' do
    let(:course) { create :course }
    let(:section) { create :section, course: course }

    subject { user.lc_for?(target_user, course) }

    context 'target user is a Fellow in the section' do
      let(:target_user) { create :fellow_user, section: section }

      context 'user is an LC' do
        context 'in the same section' do
          let(:user) { create :ta_user, section: section }
          it { should eq(true) }

          context 'with multiple enrollments' do
            let(:ta_section) { create :ta_section }
            before(:each) do
              # User is both an LC and TA for this course
              user.add_role RoleConstants::TA_ENROLLMENT, ta_section
            end
            it { should eq(true) }
          end
        end

        context 'in a different section' do
          let(:another_section) { create :section, course: course }
          let(:user) { create :ta_user, section: another_section }
          it { should eq(false) }
        end

        context 'in a different course' do
          let(:another_course) { create :course }
          let(:another_section) { create :section, course: course }
          let(:user) { create :ta_user, section: another_section }
          it { should eq(false) }
        end
      end

      context 'user is a Fellow in the same section' do
        let(:user) { create :fellow_user, section: section, canvas_user_id: 111 }
        it { should eq(false) }
      end

      context 'user is a TA in the course' do
        let(:ta_section) { create :ta_section, course: course }
        let(:user) { create :ta_user, section: ta_section }
        it { should eq(false) }
      end
    end

    context 'target user is not a Fellow in the section' do
      let(:user) { create :ta_user, section: section }

      context 'target user is a Fellow' do
        context 'in another section/cohort' do
          let(:another_section) { create :section, course: course }
          let(:target_user) { create :fellow_user, section: another_section }
          it { should eq(false) }
        end

        context 'in another course' do
          let(:another_course) { create :course }
          let(:another_section) { create :section, course: another_course }
          let(:target_user) { create :fellow_user, section: another_section }
          it { should eq(false) }
        end
      end

      context 'target user is another TA in the course' do
        let(:ta_section) { create :ta_section, course: course }
        let(:target_user) { create :ta_user, section: ta_section, canvas_user_id: 111 }
        it { should eq(false) }
      end

      context 'target user is another LC in the section' do
        let(:target_user) { create :ta_user, section: section, canvas_user_id: 111 }
        it { should eq(false) }
      end

      context 'target user is not enrolled' do
        let(:target_user) { create :registered_user }
        it { should eq(false) }
      end
    end

    context 'is LC for target but in different course' do
      let(:another_course) { create :course }
      let(:another_section) { create :section, course: another_course }
      let(:user) { create :ta_user, section: another_section }
      let(:target_user) { create :fellow_user, section: another_section }

      it { should eq(false) }
    end
  end

  describe 'can_view_submission_from?' do
    let(:course) { create :course }
    let(:section) { create :section, course: course }

    subject { user.can_view_submission_from?(target_user, course) }

    context 'target user is a Fellow' do
      let(:target_user) { create :fellow_user, section: section }

      context 'user is a TA in the same course' do
        let(:ta_section) { create :ta_section, course: course }
        let(:user) { create :ta_user, section: ta_section }
        it { should eq(true) }
      end

      context 'user is a TA in a different course' do
        let(:another_course) { create :course }
        let(:ta_section) { create :ta_section, course: another_course }
        let(:user) { create :ta_user, section: ta_section }
        it { should eq(false) }
      end

      context 'user is an LC in the same section' do
        let(:user) { create :ta_user, section: section }
        it { should eq(true) }
      end

      context 'user is an LC in a different section' do
        let(:another_section) { create :section, course: course }
        let(:user) { create :ta_user, section: another_section }
        it { should eq(false) }
      end

      context 'user is a Fellow in the same section' do
        let(:user) { create :peer_user, section: section }
        it { should eq(false) }
      end

      context 'user is not registered' do
        let(:user) { create :registered_user }
        it { should eq(false) }
      end

      context 'user is an admin' do
        let(:user) { create :admin_user }
        it { should eq(false) }
      end
    end
  end

  # Used to display the email you should log in with after clicking the button in
  # the confirmation email to activate your account
  describe '#after_confirmation_login_email' do
    subject { user.after_confirmation_login_email }

    context 'user hasnt changed their email' do
      let(:user) { build :registered_user }
      it { should eq(user.email) }
    end

    context 'user with unconfirmed email change' do
      let(:user) { create :reconfirmation_user }
      it { should eq(user.unconfirmed_email) }
    end
  end

  describe '.send_signup_email!' do
    let(:user) { create(:registered_user) }
    let(:token) { 'TestToken' }
    let(:sf_client) { double(SalesforceAPI, get_contact_signup_token: token) }
    let(:mailer_mail) { double(nil, deliver_now: nil) }
    let(:mailer) { double(nil, signup_email: mailer_mail) }

    context 'with raw token passed in' do
      subject { user.send_signup_email!(token) }

      before :each do
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        allow(SendSignupEmailMailer).to receive(:with).and_return(mailer)
      end

      it 'does not call salesforce' do
        subject
        expect(sf_client).not_to have_received(:get_contact_signup_token)
      end

      it 'calls signup mailer' do
        subject
        expect(mailer).to have_received(:signup_email)
      end
    end

    context 'with nothing passed in' do
      subject { user.send_signup_email! }

      before :each do
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        allow(SendSignupEmailMailer).to receive(:with).and_return(mailer)
      end

      it 'calls salesforce' do
        subject
        expect(sf_client).to have_received(:get_contact_signup_token)
      end

      it 'calls signup mailer' do
        subject
        expect(mailer).to have_received(:signup_email)
      end
    end
  end

  describe '.set_signup_token!' do
    subject { user.set_signup_token! }

    let(:user) { create(:registered_user) }

    it 'sets token/sent_at' do
      expect(user.signup_token).to eq(nil)
      expect(user.signup_token_sent_at).to eq(nil)
      subject
      expect(user.signup_token).not_to eq(nil)
      expect(user.signup_token_sent_at).not_to eq(nil)
    end

    it 'runs validations' do
      user.email = ''
      expect {
        subject
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'returns raw token' do
      raw_token = subject
      expect(raw_token).not_to eq(nil)
      expect(user.signup_token).to eq(Devise.token_generator.digest(User, :signup_token, raw_token))
    end
  end

  describe '.send_signup_token' do
    subject { user.send_signup_token(token) }

    let(:user) { create(:registered_user) }
    let(:token) { 'TestToken' }
    let(:sf_client) { double(SalesforceAPI, update_contact: nil) }

    before :each do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    end

    it 'calls salesforceapi' do
      subject
      expect(sf_client).to have_received(:update_contact)
        .with(user.salesforce_id, {'Signup_Token__c': token})
        .once
    end
  end

  describe '.signup_period_valid?' do
    subject { user.signup_period_valid? }

    let(:user) { create(:registered_user) }

    context 'with expired token' do
      before :each do
        user.set_signup_token!
        user.update!(signup_token_sent_at: 5.weeks.ago)
      end

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'with unexpired token' do
      before :each do
        user.set_signup_token!
        user.update!(signup_token_sent_at: 1.weeks.ago)
      end

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end
  end

  describe 'self.with_signup_token' do
    subject { User.with_signup_token(@token) }

    context 'with match' do
      let(:user) { create(:registered_user) }

      before :each do
        @token = user.set_signup_token!
      end

      it 'finds by the encoded token' do
        expect(subject).to eq(user)
      end
    end

    context 'without match' do
      let(:user) { create(:registered_user) }

      before :each do
        user.set_signup_token!
        @token = 'non-matching token'
      end

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end
  end

end
