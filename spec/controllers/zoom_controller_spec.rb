require 'rails_helper'

RSpec.describe ZoomController, type: :controller do
  render_views

  context 'for signed in user' do
    let!(:user) { create :admin_user }

    before(:each) do
      sign_in user
    end

    describe 'GET #init_generate_zoom_links' do
      subject(:show_generate_links) do
        get :init_generate_zoom_links
      end

      it 'has instructions' do
        show_generate_links
        expect(response.body).to match(/instructions to set up a Zoom Meeting/)
      end

      it 'has a field for the Meeting ID' do
        show_generate_links
        expect(response.body).to match(/<form.*<input .*type="text" name="meeting_id" id="meeting_id".*<\/form>/m)
      end

      it 'has a field to upload the .csv' do
        show_generate_links
        expect(response.body).to match(/<form.*<input class="form-control-file" required="required" type="file" name="participants" id="participants".*<\/form>/m)
      end
    end # GET #init_generate_zoom_links

    describe 'POST #generate_zoom_links' do
      let(:meeting_id) { '1234567890' }
      let(:staff_email) { 'staff.to.send.generated.links.to@bebraven.org' }
      let(:csv_path) { nil }
      let(:base_params) { { meeting_id: meeting_id, email: staff_email, participants: csv_path } }
      let(:params) { base_params }

      before(:each) do
        allow(GenerateZoomLinksJob).to receive(:perform_later)
      end

      subject(:run_generate_links) do
        post :generate_zoom_links, params: params
      end

      context 'with MacOS Excel - CSV UTF-8 (Comma Delimited).csv format' do
        let(:csv_path) { fixture_file_upload(Rails.root.join('spec/fixtures/zoom_link_csvs/', 'utf8_comma_delimited_macOS.csv'), 'application/csv') }

        it 'parses the participant registration info' do
          expect(GenerateZoomLinksJob).to receive(:perform_later)
            .with(meeting_id, staff_email, [{'email' =>'test@example.com', 'first_name' => 'Brian', 'last_name' => 'xTest'}]).once
          run_generate_links
        end
      end

      context 'with MacOS Excel - Comma Separated Values.csv format' do
        let(:csv_path) { fixture_file_upload(Rails.root.join('spec/fixtures/zoom_link_csvs/', 'comma_separated_values_macOS.csv'), 'application/csv') }

        it 'parses the participant registration info' do
          expect(GenerateZoomLinksJob).to receive(:perform_later)
            .with(meeting_id, staff_email, [{'email' =>'test@example.com', 'first_name' => 'Brian', 'last_name' => 'xTest'}]).once
          run_generate_links
        end
      end

      context 'with Google Sheets downloaded as .csv format' do
        let(:csv_path) { fixture_file_upload(Rails.root.join('spec/fixtures/zoom_link_csvs/', 'google_sheets.csv'), 'application/csv') }

        it 'parses the participant registration info' do
          expect(GenerateZoomLinksJob).to receive(:perform_later)
            .with(meeting_id, staff_email, [{'email' =>'test@example.com', 'first_name' => 'Brian', 'last_name' => 'xTest'}]).once
          run_generate_links
        end
      end
    end # END POST #generate_zoom_links
  end
end
