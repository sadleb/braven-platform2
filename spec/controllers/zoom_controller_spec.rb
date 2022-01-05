require 'rails_helper'
require 'csv'

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
      let(:csv_path) { fixture_file_upload(Rails.root.join('spec/fixtures/zoom_link_csvs/utf8_comma_delimited_macOS.csv'), 'application/csv') }
      let(:generate_service) { instance_double(GenerateZoomLinks) }
      let(:meeting_id) { '1234567890' }
      let(:staff_email) { 'staff.to.send.generated.links.to@bebraven.org' }
      let(:base_params) { { meeting_id: meeting_id, participants: csv_path, email: staff_email } }
      let(:service_params) { { meeting_id: meeting_id, participants_file_path: anything, email: staff_email } }

      subject(:run_generate_links) do
        post :generate_zoom_links, params: base_params
      end

      before(:each) do
        allow(GenerateZoomLinks).to receive(:new).with(service_params).and_return(generate_service)
      end

      it 'calls validate_and_run on the GenerateZoomLinks service ' do
        expect(generate_service).to receive(:validate_and_run).once
        run_generate_links
      end

      before(:each) do
        allow(generate_service).to receive(:validate_and_run).and_return(GenerateZoomLinksJob)
      end

      it 'redirects to the the /generate_zoom_links path (same page)' do
        expect(run_generate_links).to redirect_to(generate_zoom_links_path)
      end
    end
  end
end