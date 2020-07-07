require 'rails_helper'

RSpec.describe LtiLaunch, type: :model do
  describe 'database' do
    it { is_expected.to have_db_column(:client_id).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:login_hint).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:lti_message_hint).of_type(:text) }
    it { is_expected.to have_db_column(:target_link_uri).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:nonce).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:state).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:id_token_payload).of_type(:text) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_index(:state) }
  end

  describe 'settings' do
    it { expect(described_class::LTI_LAUNCH_REDIRECT_URI).to eq "https://#{Rails.application.secrets.application_host}/lti/launch" }
  end

  describe 'methods' do
    describe '.current' do
      context 'without keypairs' do
        let(:lti_launch) { build(:lti_launch_resource) }

        it 'does something' do
          puts "### #{lti_launch.id_token_payload}"
        end
      end
    end
  end
end
