require 'rails_helper'

RSpec.describe TestUsersController, type: :controller do
  render_views

  context 'for signed in user' do
    let!(:user) { create :admin_user }

    before(:each) do
      sign_in user
    end

    describe "GET #index" do
      subject { get :index }

      it 'returns a success response' do
        subject
        expect(response).to be_successful
      end

      it 'has a required role select field with the correct role options' do
        subject
        expect(response.body)
          .to match(/<select required="required" class="form-control mb-0 select-element role-select" name="role\[\]" id="role\[\]">.*<option value="Fellow">.*<option value="Leadership Coach">.*<option value="Teaching Assistant">.*<option value="Coach Partner">.*<option value="Staff">.*<option value="Faculty">/m)
      end

      it 'has a required program select field' do
        subject
        expect(response.body)
          .to match(/<select required="required" class="form-control mb-0 select-element program-select" name="program_id\[\]" id="program_id\[\]">/)
      end

      it 'has a required first name input field' do
        subject
        expect(response.body)
          .to match(/<input class="form-control mb-0" required="required" placeholder="First name" type="text" name="first_name\[\]" id="first_name\[\]"/)
      end

      it 'has a required tag input field with a max length of 25 characters' do
        subject
        expect(response.body)
          .to match(/<input class="form-control mb-0" required="required" maxlength="25" placeholder="Tag" size="25" type="text" name="tag\[\]" id="tag\[\]"/)
      end

      it 'has a required email input field' do
        subject
        expect(response.body)
          .to match(/<input class="form-control mb-0" required="required" placeholder="you@example.com" autocomplete="email" type="email" name="email\[\]" id="email\[\]"/)
      end

      it 'has a hidden disabled cohort schedule select field' do
        subject
        expect(response.body)
          .to match(/<div class="form-group mb-1 cohort-schedule-area.*hidden="true">.*<select disabled="disabled" class="form-control mb-0 select-element cohort-schedule-select" name="cohort_schedule\[\]" id="cohort_schedule\[\]">/m)
      end

      it 'has a hidden disabled cohort section select field' do
        subject
        expect(response.body)
          .to match(/<div class="form-group mb-1 cohort-section-area.*hidden="true">.*<select disabled="disabled" class="form-control mb-0 select-element cohort-section-select" name="cohort_section\[\]" id="cohort_section\[\]">/m)
      end

      it 'has a hidden disabled ta assignment select field' do
        subject
        expect(response.body)
          .to match(/<div class="form-group mb-1 ta-form-area" hidden="true">.*<select disabled="disabled" class="form-control mb-0 select-element ta-select" name="ta\[\]" id="ta\[\]">/m)
      end
    end

    describe 'POST #post' do
      let(:user_params) { { "test"=>["params"]} }

      subject { post :post, params: user_params}

      before(:each) do
        allow(GenerateTestUsersJob).to receive(:perform_later).and_return(nil)
      end

      it 'calls the GenerateTestUsersJob' do
        expect(GenerateTestUsersJob).to receive(:perform_later).once
        subject
      end

      it 'redirects to the the /generate_test_users path (same page)' do
        subject
        expect(response).to redirect_to(generate_test_users_path)
        expect(flash[:notice]).to match /The generation process was started/
      end
    end
  end
end