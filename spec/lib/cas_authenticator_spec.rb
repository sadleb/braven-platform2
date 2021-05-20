require 'rails_helper'

RSpec.describe BravenCAS::CustomAuthenticator do

  let(:user_password) { 'valid_password' }
  let(:username) { nil }
  let(:login_password) { nil }
  let(:credentials) {
    {
      :username => username,
      :password => login_password,
    }
  }

  shared_examples 'can login' do
    context 'with valid credentials' do
      let(:username) { user.email }
      let(:login_password) { user_password }

      it '#validate returns true' do
        expect(subject.validate(credentials)).to eq(true)
      end
    end

    context 'with invalid credentials' do
      let(:username) { user.email }
      let(:login_password) { 'bad_password' }

      it '#validate returns false' do
        expect(subject.validate(credentials)).to eq(false)
      end
    end
  end

  shared_examples 'cannot login' do
    context 'with valid credentials' do
      let(:username) { user.email }
      let(:login_password) { user_password }

      it '#validate returns false' do
        expect(subject.validate(credentials)).to eq(false)
      end

      it '#valid_password? returns true' do
        expect(subject.valid_password?(credentials)).to eq(true)
        expect(subject.user).to eq(user)
      end

      it '#valid_password_for_unconfirmed_email? returns false' do
        expect(subject.valid_password_for_unconfirmed_email?(credentials)).to eq(false)
        expect(subject.user).not_to eq(user)
      end

      context 'for unconfirmed_email' do
        let(:unconfirmed_email) { 'unconfirmed_email@example.com' }
        let(:username) { unconfirmed_email }

        before(:each) do
          user.update!(email: unconfirmed_email)
        end

        it '#validate returns false' do
          expect(subject.validate(credentials)).to eq(false)
        end

        it '#valid_password? returns false' do
          expect(subject.valid_password?(credentials)).to eq(false)
          expect(subject.user).not_to eq(user)
        end

        it '#valid_password_for_unconfirmed_email? returns true' do
          expect(subject.valid_password_for_unconfirmed_email?(credentials)).to eq(true)
          expect(subject.user).to eq(user)
        end

        it 'sets the correct user when calling both #valid_password methods' do
          expect(subject.valid_password?(credentials)).to eq(false)
          expect(subject.valid_password_for_unconfirmed_email?(credentials)).to eq(true)
          expect(subject.user).to eq(user)
        end
      end
    end

    context 'with invalid credentials' do
      let(:username) { user.email }
      let(:login_password) { 'bad_password' }

      it '#validate returns false' do
        expect(subject.validate(credentials)).to eq(false)
      end

      it '#valid_password? returns false' do
        expect(subject.valid_password?(credentials)).to eq(false)
      end

      it '#valid_password_for_unconfirmed_email? returns false' do
        expect(subject.valid_password_for_unconfirmed_email?(credentials)).to eq(false)
      end
    end

  end

  context 'when unregistered user' do
    let(:user) { create :unregistered_user, password: user_password }
    it_behaves_like 'cannot login'
  end

  context 'when registered user' do
    let(:user) { create :registered_user, password: user_password }
    it_behaves_like 'can login'
  end

  context 'when unconfirmed user' do
    let(:user) { create :unconfirmed_user, password: user_password }
    it_behaves_like 'cannot login'
  end

end

